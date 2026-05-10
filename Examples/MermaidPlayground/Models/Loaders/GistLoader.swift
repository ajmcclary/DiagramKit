//
//  GistLoader.swift
//  MermaidPlayground
//
//  Loads Mermaid diagram source and optional config from a GitHub Gist.
//  Targets the public Gist API (no auth required for public gists).
//  Config is sanitized via ConfigSanitizer.stripUnsafe before returning.
//
//  URL format: https://gist.github.com/{user}/{id}[/{revision}]
//

import Foundation
import DiagramKitModel

// MARK: - GistLoader

/// Loads Mermaid source from a GitHub Gist.
///
/// Looks for files named `code.mmd` (source) and `config.json` (config).
/// Falls back to any `.mmd` / `.mermaid` / `.txt` file for source.
/// Config is sanitized through ``ConfigSanitizer/stripUnsafe(from:)``
/// before being returned.
public enum GistLoader {

    // MARK: - Errors

    public enum LoadError: Swift.Error, Sendable, LocalizedError {
        /// The provided URL does not contain a recognizable Gist path.
        case invalidURL(URL)
        /// The Gist does not contain any recognizable Mermaid source files.
        case noMermaidFiles(String)
        /// A network or HTTP error occurred.
        case networkError(String)
        /// The Gist was not found (404).
        case notFound(String)
        /// The response could not be parsed.
        case invalidResponse(String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL(let url):
                return "Not a valid Gist URL: \(url.absoluteString)"
            case .noMermaidFiles(let id):
                return "Gist \(id) does not contain a code.mmd or .mmd file."
            case .networkError(let detail):
                return "Network error: \(detail)"
            case .notFound(let id):
                return "Gist \(id) not found."
            case .invalidResponse(let detail):
                return "Unexpected Gist API response: \(detail)"
            }
        }
    }

    // MARK: - Public API

    /// Extract the gist ID from a GitHub Gist URL.
    ///
    /// Accepts:
    /// - `https://gist.github.com/{user}/{id}`
    /// - `https://gist.github.com/{user}/{id}/{revision}`
    ///
    /// - Parameter url: A GitHub Gist URL.
    /// - Returns: The gist ID string, or nil if the URL doesn't match.
    public static func extractGistID(from url: URL) -> String? {
        let path = url.path
        let components = path.split(separator: "/")
        // Expected: ["", "user", "id"] or ["", "user", "id", "revision"]
        guard components.count >= 2 else { return nil }
        return String(components.last(where: { $0.count >= 10 }) ?? components[components.count - 1])
    }

    /// Load diagram source and config from a Gist URL.
    ///
    /// Fetches the Gist metadata via the GitHub API, extracts source from
    /// `code.mmd` (or the first `.mmd` file), and config from `config.json`.
    ///
    /// Revisions are not loaded in this version; they will be included in a
    /// future update that fetches the Gist commit history.
    ///
    /// - Parameter url: A GitHub Gist URL.
    /// - Throws: ``LoadError`` on failure.
    /// - Returns: A ``LoaderResult`` with the source, optional config, and metadata.
    public static func load(from url: URL) async throws -> LoaderResult {
        guard let gistID = extractGistID(from: url) else {
            throw LoadError.invalidURL(url)
        }

        let apiURL = URL(string: "https://api.github.com/gists/\(gistID)")!
        let response = try await fetchGistAPI(url: apiURL, gistID: gistID)

        // Find source file
        let sourceFile = findSourceFile(in: response.files)
        guard let sourceFile else {
            throw LoadError.noMermaidFiles(gistID)
        }

        // Read source content
        let source = try await readFileContent(sourceFile)

        // Read config if present
        var configJSON: String?
        if let configFile = response.files["config.json"] {
            configJSON = try await readFileContent(configFile)
            // Sanitize config
            if let rawConfig = configJSON,
               let configData = rawConfig.data(using: .utf8),
               let jsonValue = try? JSONDecoder().decode(JSONValue.self, from: configData) {
                let cleaned = ConfigSanitizer.stripUnsafe(from: jsonValue)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let cleanedData = try? encoder.encode(cleaned) {
                    configJSON = String(data: cleanedData, encoding: .utf8) ?? rawConfig
                }
            }
        }

        // Build label
        let owner = response.owner?.login ?? "unknown"
        let description = response.description ?? "Gist \(String(gistID.prefix(7)))"
        let label = "Gist by \(owner): \(description)"

        return LoaderResult(
            source: source,
            configJSON: configJSON,
            label: label,
            sourceURL: url,
            revisions: nil // Revisions deferred to Phase 5.1
        )
    }

    // MARK: - Private helpers

    /// Find a Mermaid source file in the Gist.
    ///
    /// Priority: `code.mmd` > first `.mmd` file > first `.mermaid` file > first `.txt` file.
    private static func findSourceFile(in files: [String: GistFile]) -> GistFile? {
        if let codeFile = files["code.mmd"] {
            return codeFile
        }
        if let mmdFile = files.first(where: { $0.key.hasSuffix(".mmd") }) {
            return mmdFile.value
        }
        if let mermaidFile = files.first(where: { $0.key.hasSuffix(".mermaid") }) {
            return mermaidFile.value
        }
        if let txtFile = files.first(where: { $0.key.hasSuffix(".txt") }) {
            return txtFile.value
        }
        return nil
    }

    /// Read file content, fetching from raw_url if truncated.
    private static func readFileContent(_ file: GistFile) async throws -> String {
        if file.truncated, let rawURL = file.rawURL {
            return try await fetchText(from: rawURL)
        }
        return file.content ?? ""
    }

    /// Fetch the Gist API response.
    private static func fetchGistAPI(url: URL, gistID: String) async throws -> GistResponse {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoadError.networkError("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 404:
            throw LoadError.notFound(gistID)
        case 403:
            throw LoadError.networkError("GitHub API rate limit exceeded. Try again later.")
        default:
            throw LoadError.networkError("HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(GistResponse.self, from: data)
        } catch {
            throw LoadError.invalidResponse(error.localizedDescription)
        }
    }

    /// Fetch plain text from a URL.
    private static func fetchText(from url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LoadError.networkError("Failed to fetch \(url.absoluteString)")
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Gist API response types

/// Mirror of the GitHub Gist API v3 response (fields we care about).
private struct GistResponse: Decodable {
    let description: String?
    let files: [String: GistFile]
    let owner: GistOwner?
    let htmlUrl: String?

    enum CodingKeys: String, CodingKey {
        case description
        case files
        case owner
        case htmlUrl
    }
}

/// A single file in a Gist.
private struct GistFile: Decodable {
    let filename: String?
    let content: String?
    let truncated: Bool
    let rawUrl: String?

    enum CodingKeys: String, CodingKey {
        case filename
        case content
        case truncated
        case rawUrl
    }

    /// `raw_url` is the GitHub API key; we map it to `rawURL`.
    var rawURL: URL? {
        guard let rawUrl else { return nil }
        return URL(string: rawUrl)
    }
}

/// Owner info from the Gist API.
private struct GistOwner: Decodable {
    let login: String
}

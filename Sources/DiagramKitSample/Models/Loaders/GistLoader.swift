//
//  GistLoader.swift
//  DiagramPlayground
//
//  Loads diagram source and optional config from a GitHub Gist.
//  Recognizes all five supported source formats by file extension:
//  Mermaid (.mmd/.mermaid), D2 (.d2), Graphviz (.dot/.gv),
//  Structurizr (.dsl), and PlantUML (.puml/.plantuml/.iuml/.pu).
//  Config is sanitized via ConfigSanitizer.stripUnsafe before returning.
//
//  URL format: https://gist.github.com/{user}/{id}[/{revision}]
//

import Foundation
import DiagramKitModel

// MARK: - GistLoader

/// Loads diagram source from a GitHub Gist.
///
/// Looks for any file whose extension maps to a known `SourceFormat`,
/// preferring an exact `code.<ext>` match. Config is read from
/// `config.json` and sanitized through ``ConfigSanitizer/stripUnsafe(from:)``
/// before being returned.
public enum GistLoader {

    // MARK: - Errors

    public enum LoadError: Swift.Error, Sendable, LocalizedError {
        /// The provided URL does not contain a recognizable Gist path.
        case invalidURL(URL)
        /// The Gist does not contain any recognizable diagram source files.
        case noSourceFiles(String)
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
            case .noSourceFiles(let id):
                return "Gist \(id) does not contain a recognized diagram source file."
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
        let components = url.pathComponents.filter { $0 != "/" }

        // gist.github.com/{id}
        if components.count == 1 {
            return isValidGistID(components[0]) ? components[0] : nil
        }

        // gist.github.com/{user}/{id}[/revision]
        if components.count >= 2 {
            let gistID = components[1]
            return isValidGistID(gistID) ? gistID : nil
        }

        return nil
    }

    /// A gist ID is a hex hash; require ≥10 alphanumeric characters. This
    /// also rejects path segments containing spaces or `/` (which arrive
    /// percent-decoded from `pathComponents`) so they can never be spliced
    /// into the API URL — the old `count >= 10` check let those through and
    /// crashed the force-unwrapped `URL(string:)`.
    private static func isValidGistID(_ id: String) -> Bool {
        id.count >= 10 && id.allSatisfy { $0.isLetter || $0.isNumber }
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

        guard let apiURL = URL(string: "https://api.github.com/gists/\(gistID)") else {
            throw LoadError.invalidURL(url)
        }
        let response = try await fetchGistAPI(url: apiURL, gistID: gistID)

        // Find source file
        guard let match = findSourceFile(in: response.files) else {
            throw LoadError.noSourceFiles(gistID)
        }

        // Read source content
        let source = try await readFileContent(match.file)

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
            sourceFormat: match.format,
            revisions: nil // Revisions deferred to Phase 5.1
        )
    }

    // MARK: - Private helpers

    /// A file found in a Gist that maps to a known `SourceFormat`.
    fileprivate struct SourceMatch {
        let file: GistFile
        let format: SourceFormat
    }

    /// Find a diagram source file in the Gist.
    ///
    /// Priority:
    ///  1. `code.<ext>` exact-name match for any known format extension.
    ///  2. The alphabetically-first filename whose extension maps to a
    ///     `SourceFormat`.
    ///  3. First `.txt` file (treated as Mermaid for backward compatibility).
    private static func findSourceFile(in files: [String: GistFile]) -> SourceMatch? {
        // 1. Exact `code.<ext>` match. Probe extensions in registry order so a
        //    Gist that ships e.g. both `code.mmd` and `code.d2` would deterministically
        //    pick Mermaid first (matches the umbrella's importer fallback order).
        for format in SourceFormat.allCases {
            for ext in format.fileExtensions {
                if let file = files["code.\(ext)"] {
                    return SourceMatch(file: file, format: format)
                }
            }
        }

        // 2. First recognized-extension filename, alphabetically by name.
        let sorted = files.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        for (name, file) in sorted {
            if let format = SourceFormat.from(filename: name) {
                return SourceMatch(file: file, format: format)
            }
        }

        // 3. .txt fallback as Mermaid.
        if let txt = sorted.first(where: { $0.key.lowercased().hasSuffix(".txt") }) {
            return SourceMatch(file: txt.value, format: .mermaid)
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

    /// Fetch the Gist API response. The host is the hard-coded, trusted
    /// GitHub API endpoint, so scheme validation is redundant but the size
    /// cap still applies.
    private static func fetchGistAPI(url: URL, gistID: String) async throws -> GistResponse {
        let data: Data
        let httpResponse: HTTPURLResponse
        do {
            (data, httpResponse) = try await RemoteFetch.boundedData(from: url)
        } catch let fetchError as RemoteFetch.FetchError {
            throw LoadError.networkError(RemoteFetch.describe(fetchError))
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

    /// Fetch plain text from a gist `raw_url`, bounded by the size cap.
    private static func fetchText(from url: URL) async throws -> String {
        let data: Data
        let httpResponse: HTTPURLResponse
        do {
            (data, httpResponse) = try await RemoteFetch.boundedData(from: url)
        } catch let fetchError as RemoteFetch.FetchError {
            throw LoadError.networkError(RemoteFetch.describe(fetchError))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw LoadError.networkError("Failed to fetch \(url.absoluteString) (HTTP \(httpResponse.statusCode))")
        }

        // Surface a decode failure rather than silently returning "" — an
        // empty source with a success toast is a confusing outcome.
        guard let text = String(data: data, encoding: .utf8) else {
            throw LoadError.invalidResponse("Content at \(url.absoluteString) is not UTF-8 text.")
        }
        return text
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

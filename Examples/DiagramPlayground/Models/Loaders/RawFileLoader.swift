//
//  RawFileLoader.swift
//  DiagramPlayground
//
//  Loads diagram source or config from arbitrary HTTP(S) URLs.
//  Supports loading code and config from separate URLs, or a single URL
//  whose content type is auto-detected (JSON → config, plain text → source).
//  Source format is sniffed from the URL's path extension when present.
//  Config is sanitized via ConfigSanitizer.stripUnsafe before returning.
//

import Foundation
import DiagramKitModel

// MARK: - RawFileLoader

/// Loads diagram source/config from raw URLs.
///
/// Content type is detected automatically for single-URL loads:
/// - If the content parses as valid JSON, it's treated as config.
/// - Otherwise it's treated as source text and the URL extension is
///   sniffed for a `SourceFormat`.
///
/// For two-URL loads, `codeURL` is treated as source and `configURL` as config.
/// Config is sanitized through ``ConfigSanitizer/stripUnsafe(from:)``
/// before being returned.
public enum RawFileLoader {

    // MARK: - Errors

    public enum LoadError: Swift.Error, Sendable, LocalizedError {
        /// Both code URL and config URL are nil or empty.
        case noURLsProvided
        /// The URL could not be parsed.
        case invalidURL(String)
        /// A network or HTTP error occurred.
        case networkError(String)
        /// The response could not be decoded as UTF-8 text.
        case invalidContent(String)

        public var errorDescription: String? {
            switch self {
            case .noURLsProvided:
                return "No URL to load from."
            case .invalidURL(let string):
                return "Not a valid URL: \(string)"
            case .networkError(let detail):
                return "Network error: \(detail)"
            case .invalidContent(let detail):
                return "Could not read content: \(detail)"
            }
        }
    }

    // MARK: - Public API

    /// Load Mermaid source and/or config from one or two URLs.
    ///
    /// - Parameters:
    ///   - codeURL: URL to load Mermaid source from.
    ///   - configURL: URL to load config JSON from.
    /// - Throws: ``LoadError`` on failure.
    /// - Returns: A ``LoaderResult`` with the loaded content.
    public static func load(
        codeURL: URL?,
        configURL: URL?
    ) async throws -> LoaderResult {
        // If both URLs are provided, load each directly
        if let codeURL, let configURL {
            async let sourceTask = fetchText(from: codeURL)
            async let configTask = fetchText(from: configURL)

            let source = try await sourceTask
            let rawConfig = try await configTask
            let sanitizedConfig = sanitizeConfig(rawConfig)

            return LoaderResult(
                source: source,
                configJSON: sanitizedConfig ?? rawConfig,
                label: "Loaded from URL",
                sourceURL: codeURL,
                sourceFormat: SourceFormat.from(url: codeURL)
            )
        }

        // Single URL: auto-detect content type
        let url: URL
        if let codeURL {
            url = codeURL
        } else if let configURL {
            url = configURL
        } else {
            throw LoadError.noURLsProvided
        }

        let content = try await fetchText(from: url)

        // Detect: try JSON parse → config, otherwise source
        if let jsonData = content.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: jsonData)) != nil {
            // Content is JSON — treat as config
            let sanitized = sanitizeConfig(content)
            return LoaderResult(
                source: "", // Caller must have existing source or handle empty
                configJSON: sanitized ?? content,
                label: "Config from \(url.host ?? "URL")",
                sourceURL: url
            )
        } else {
            // Content is plain text — treat as source
            return LoaderResult(
                source: content,
                configJSON: nil,
                label: "Source from \(url.host ?? "URL")",
                sourceURL: url,
                sourceFormat: SourceFormat.from(url: url)
            )
        }
    }

    // MARK: - Private helpers

    /// Fetch UTF-8 text from a URL.
    private static func fetchText(from url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoadError.networkError("Invalid response type from \(url.absoluteString)")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw LoadError.networkError("HTTP \(httpResponse.statusCode) from \(url.absoluteString)")
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw LoadError.invalidContent("Content at \(url.absoluteString) is not UTF-8 text.")
        }

        return text
    }

    /// Sanitize a config JSON string via ``ConfigSanitizer/stripUnsafe(from:)``.
    /// Returns nil if the JSON is invalid or unchanged after sanitization.
    private static func sanitizeConfig(_ rawJSON: String) -> String? {
        guard let data = rawJSON.data(using: .utf8),
              let jsonValue = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return nil
        }

        let cleaned = ConfigSanitizer.stripUnsafe(from: jsonValue)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let cleanedData = try? encoder.encode(cleaned),
              let cleanedString = String(data: cleanedData, encoding: .utf8) else {
            return nil
        }

        // Only return if something was actually stripped
        return cleanedString != rawJSON ? cleanedString : nil
    }
}

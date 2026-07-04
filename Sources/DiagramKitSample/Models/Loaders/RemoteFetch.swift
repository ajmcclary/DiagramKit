//
//  RemoteFetch.swift
//  DiagramPlayground
//
//  Shared hardening for the remote loaders (Gist, raw URL). Every fetch
//  from user-supplied input goes through here so scheme/host validation,
//  a download size cap, and a request timeout are applied uniformly.
//

import Foundation

// MARK: - RemoteFetch

/// Bounded, validated HTTP(S) fetch used by the sample app's loaders.
enum RemoteFetch {

    /// Hard cap on the number of bytes buffered from any single remote
    /// response. A hostile or misbehaving endpoint cannot exhaust memory.
    static let maxBytes = 8 * 1024 * 1024 // 8 MB

    /// Default request timeout. Prevents a hung endpoint from pinning the
    /// loading spinner indefinitely.
    static let defaultTimeout: TimeInterval = 30

    enum FetchError: Swift.Error, Sendable {
        case invalidScheme(String)
        case disallowedHost(String)
        case tooLarge(limit: Int)
        case notHTTP
    }

    // MARK: - Validation

    /// Reject anything that isn't a plain `http`/`https` URL, and block
    /// loopback / link-local / private-range hosts. This is a best-effort
    /// SSRF guard: the app fetches URLs the user pastes, so a `file://`
    /// scheme (local file read) or a `http://169.254.169.254/…` metadata
    /// probe must not be honored.
    static func validateUserURL(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw FetchError.invalidScheme(url.scheme ?? "(none)")
        }
        if let host = url.host?.lowercased(), isBlockedHost(host) {
            throw FetchError.disallowedHost(host)
        }
    }

    /// Loopback, link-local, and RFC-1918 private ranges plus `localhost`.
    static func isBlockedHost(_ host: String) -> Bool {
        let h = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if h == "localhost" || h.hasSuffix(".localhost") { return true }
        if h == "::1" || h == "0.0.0.0" { return true }
        if h.hasPrefix("127.") { return true }          // loopback
        if h.hasPrefix("169.254.") { return true }      // link-local / cloud metadata
        if h.hasPrefix("10.") { return true }           // private
        if h.hasPrefix("192.168.") { return true }      // private
        if h.hasPrefix("172.") {                        // 172.16.0.0–172.31.255.255
            let parts = h.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), (16...31).contains(second) {
                return true
            }
        }
        return false
    }

    // MARK: - Fetch

    /// Fetch a URL's body with scheme/host validation and the size cap,
    /// returning the raw bytes plus the HTTP response so the caller can
    /// apply its own status-code policy.
    ///
    /// - Parameter validateScheme: pass `false` only for hard-coded,
    ///   trusted hosts (e.g. the GitHub API endpoint) — never for
    ///   user-supplied URLs.
    static func boundedData(
        from url: URL,
        validateScheme: Bool = true,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> (Data, HTTPURLResponse) {
        if validateScheme { try validateUserURL(url) }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FetchError.notHTTP
        }
        // Reject up front when the server honestly advertises an oversized body.
        if http.expectedContentLength > Int64(maxBytes) {
            throw FetchError.tooLarge(limit: maxBytes)
        }

        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > maxBytes { throw FetchError.tooLarge(limit: maxBytes) }
        }
        return (data, http)
    }

    /// Human-readable summary of a `FetchError` for surfacing in loader errors.
    static func describe(_ error: FetchError) -> String {
        switch error {
        case .invalidScheme(let s):
            return "scheme '\(s)' is not allowed (http/https only)"
        case .disallowedHost(let h):
            return "host '\(h)' is not allowed (loopback/private addresses are blocked)"
        case .tooLarge(let limit):
            return "response exceeds the \(limit / 1024 / 1024) MB limit"
        case .notHTTP:
            return "response was not a valid HTTP response"
        }
    }
}

#if os(macOS)
import Foundation
import Darwin

// MARK: - RemoteFetch

/// Bounded, validated HTTP(S) fetch used for diagram image nodes.
public enum RemoteFetch {

    /// Hard cap on the number of bytes buffered from any single remote
    /// response. A hostile or misbehaving endpoint cannot exhaust memory.
    public static let maxBytes = 8 * 1024 * 1024 // 8 MB

    /// Default request timeout. Prevents a hung endpoint from pinning the
    /// loading spinner indefinitely.
    public static let defaultTimeout: TimeInterval = 30

    public enum FetchError: Swift.Error, Sendable {
        case invalidScheme(String)
        case disallowedHost(String)
        case tooLarge(limit: Int)
        case notHTTP
        case timedOut
        case resolutionFailed(String)
        case transportFailed(Int32)
        case tooManyRedirects
    }

    // MARK: - Validation

    /// Reject anything that isn't a plain `http`/`https` URL, and block
    /// loopback / link-local / private-range hosts. This is a best-effort
    /// SSRF guard: the app fetches URLs the user pastes, so a `file://`
    /// scheme (local file read) or a `http://169.254.169.254/…` metadata
    /// probe must not be honored.
    public static func validateUserURL(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw FetchError.invalidScheme(url.scheme ?? "(none)")
        }
        guard let host = url.host?.lowercased(), !host.isEmpty,
              url.user == nil, url.password == nil, isValidHostSyntax(host), !isBlockedHost(host),
              url.port.map({ (1...65535).contains($0) }) ?? true else {
            throw FetchError.disallowedHost(url.host ?? "(none)")
        }
    }

    /// `true` for an IP literal (bracketed or not) or an ASCII hostname of
    /// non-empty labels made of letters, digits, `-` and `_`, none starting
    /// with `-` (one trailing dot allowed). The host is pinned through curl's
    /// `--resolve host:port:addr`, where a leading `-` means "remove this
    /// pin" and curl then resolves the name itself; any other punctuation
    /// has no place in a hostname either.
    static func isValidHostSyntax(_ host: String) -> Bool {
        let literal = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        var v4 = in_addr(), v6 = in6_addr()
        if inet_pton(AF_INET6, literal, &v6) == 1 || inet_pton(AF_INET, literal, &v4) == 1 { return true }
        var name = Substring(host)
        if name.hasSuffix(".") { name = name.dropLast() }
        guard !name.isEmpty, name.utf8.count <= 253 else { return false }
        return name.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
            !label.isEmpty && label.utf8.count <= 63 && label.first != "-"
                && label.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_") }
        }
    }

    /// Loopback, link-local, private, CGNAT and unspecified addresses plus
    /// `localhost`, in every literal form the resolver accepts (decimal,
    /// hex and octal IPv4, shorthand like `127.1`, IPv6 ULA / link-local /
    /// v4-mapped, and the NAT64, 6to4 and Teredo prefixes that embed an
    /// IPv4 address). DNS answers are checked and pinned by the transport before connecting.
    public static func isBlockedHost(_ host: String) -> Bool {
        var h = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        while h.hasSuffix(".") { h.removeLast() }
        if h.contains("%") { return true }
        if h.isEmpty || h == "localhost" || h.hasSuffix(".localhost") { return true }
        var v4 = in_addr()
        if !h.contains(":"), inet_aton(h, &v4) != 0 {
            return isBlockedIPv4(UInt32(bigEndian: v4.s_addr))
        }
        var v6 = in6_addr()
        if inet_pton(AF_INET6, h, &v6) == 1 {
            let bytes = withUnsafeBytes(of: v6) { Array($0) }
            if bytes.allSatisfy({ $0 == 0 }) { return true }                              // ::
            if bytes[0..<15].allSatisfy({ $0 == 0 }) && bytes[15] == 1 { return true }     // ::1
            if bytes[0] == 0xFF { return true }
            if bytes[0] & 0xFE == 0xFC { return true }                                    // fc00::/7
            if bytes[0] == 0xFE && bytes[1] & 0xC0 == 0xC0 { return true }
            if bytes[0] == 0xFE && bytes[1] & 0xC0 == 0x80 { return true }                // fe80::/10
            if bytes[0..<12].allSatisfy({ $0 == 0 }) {
                let compatible = bytes[12...15].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
                if isBlockedIPv4(compatible) { return true }
            }
            if bytes[0..<10].allSatisfy({ $0 == 0 }) && bytes[10] == 0xFF && bytes[11] == 0xFF {
                let mapped = bytes[12...15].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }    // ::ffff:a.b.c.d
                return isBlockedIPv4(mapped)
            }
            // Prefixes that carry an IPv4 address a gateway may forward to.
            func v4(_ range: ClosedRange<Int>) -> UInt32 { bytes[range].reduce(UInt32(0)) { $0 << 8 | UInt32($1) } }
            if bytes[0...3].elementsEqual([0x00, 0x64, 0xFF, 0x9B]) {
                // NAT64: 64:ff9b::/96 (well-known) ends in the address;
                // 64:ff9b:1::/48 (local use) can place it anywhere.
                if bytes[4] == 0x00, bytes[5] == 0x01 { return true }
                if bytes[4...11].allSatisfy({ $0 == 0 }), isBlockedIPv4(v4(12...15)) { return true }
            }
            if bytes[0] == 0x20, bytes[1] == 0x02, isBlockedIPv4(v4(2...5)) { return true }             // 6to4 2002::/16
            if bytes[0...3].elementsEqual([0x20, 0x01, 0x00, 0x00]) {                                                 // Teredo 2001::/32
                if isBlockedIPv4(v4(4...7)) || isBlockedIPv4(~v4(12...15)) { return true }
            }
        } else if h.contains(":") { return true }
        return false
    }

    private static func isBlockedIPv4(_ address: UInt32) -> Bool {
        let a = address >> 24, b = (address >> 16) & 0xFF
        switch a {
        case 0, 10, 127: return true
        case 169: return b == 254
        case 172: return (16...31).contains(b)
        case 192: return b == 168 || (b == 0 && (address >> 8) & 0xFF == 0)          // 192.0.0.0/24
        case 198: return b == 18 || b == 19                                             // benchmarking 198.18.0.0/15
        case 100: return (64...127).contains(b)                                         // CGNAT
        default: return a >= 224
        }
    }

    /// Resolve, validate and pin each HTTP(S) hop under one resource deadline.
    /// The URL hostname remains intact for HTTP Host and TLS certificate checks.
    public static func boundedData(
        from url: URL,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> (Data, HTTPURLResponse) {
        try await PinnedRemoteTransport.fetch(url, timeout: timeout)
    }

    /// Human-readable summary of a `FetchError` for surfacing in loader errors.
    public static func describe(_ error: FetchError) -> String {
        switch error {
        case .invalidScheme(let s):
            return "scheme '\(s)' is not allowed (http/https only)"
        case .disallowedHost(let h):
            return "host '\(h)' is not allowed (loopback/private addresses are blocked)"
        case .tooLarge(let limit):
            return "response exceeds the \(limit / 1024 / 1024) MB limit"
        case .notHTTP:
            return "response was not a valid HTTP response"
        case .timedOut: return "the download exceeded its time limit"
        case .resolutionFailed(let host): return "could not resolve host '\(host)'"
        case .transportFailed(let code): return "download failed (transport status \(code))"
        case .tooManyRedirects: return "the download redirected too many times"
        }
    }
}
#endif

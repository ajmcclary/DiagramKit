import Foundation

/// Marker harvested from a single source line.
public struct RecoveryMarker<Kind: Sendable & Equatable>: Sendable, Equatable {
    public let lineNumber: Int  // 1-based
    public let kind: Kind

    public init(lineNumber: Int, kind: Kind) {
        self.lineNumber = lineNumber
        self.kind = kind
    }
}

/// Result of a pre-lexer scan over source.
public struct RecoveryMarkerScanResult<Kind: Sendable & Equatable>: Sendable, Equatable {
    public let markers: [RecoveryMarker<Kind>]
    public let lines: [String]

    public init(markers: [RecoveryMarker<Kind>], lines: [String]) {
        self.markers = markers
        self.lines = lines
    }
}

/// Generic comment-encoded recovery-marker scanner. Each format slice
/// configures its line-comment prefix and supplies a `parseKind` closure that
/// maps the post-sentinel arg string to a typed `Kind` (`nil` for malformed
/// markers, handled by the caller).
public struct RecoveryMarkerScanner<Kind: Sendable & Equatable>: Sendable {

    public let commentPrefix: String
    public let sentinel: String
    private let parseKind: @Sendable (String) -> Kind?

    public init(
        commentPrefix: String,
        sentinel: String = RecoveryMarkerSyntax.sentinel,
        parseKind: @escaping @Sendable (String) -> Kind?
    ) {
        self.commentPrefix = commentPrefix
        self.sentinel = sentinel
        self.parseKind = parseKind
    }

    /// Walk every line of `source`. Each line beginning (after leading
    /// whitespace) with `commentPrefix + sentinel` is offered to `parseKind`.
    /// Returns markers paired with 1-based line numbers, plus the source
    /// split into lines for downstream correlation.
    public func scan(source: String) -> RecoveryMarkerScanResult<Kind> {
        var markers: [RecoveryMarker<Kind>] = []
        let lines = source.components(separatedBy: "\n")
        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            var trimmed = rawLine
            while let first = trimmed.first, first == " " || first == "\t" {
                trimmed.removeFirst()
            }
            guard trimmed.hasPrefix(commentPrefix) else { continue }
            trimmed.removeFirst(commentPrefix.count)
            while let first = trimmed.first, first == " " || first == "\t" {
                trimmed.removeFirst()
            }
            guard trimmed.hasPrefix(sentinel) else { continue }
            var rest = String(trimmed.dropFirst(sentinel.count))
            while let last = rest.last, last == " " || last == "\t" || last == "\r" {
                rest.removeLast()
            }
            if let kind = parseKind(rest) {
                markers.append(RecoveryMarker(lineNumber: lineNumber, kind: kind))
            }
        }
        return RecoveryMarkerScanResult(markers: markers, lines: lines)
    }
}

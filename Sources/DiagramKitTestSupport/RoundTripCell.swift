import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel

/// Static description of a (importer, exporter, family) cell in the
/// round-trip matrix. Allowed losses are case-tag-only — actual `RoundTripLoss`
/// payload is checked against this set via `loss.kind`.
public struct RoundTripCell<I: DiagramSourceImporter, E: DiagramExporter>: Sendable {
    public let importer: I
    public let exporter: E
    public let family: DiagramType
    public let allowedLosses: Set<RoundTripLossKind>

    public init(
        importer: I,
        exporter: E,
        family: DiagramType,
        allowedLosses: Set<RoundTripLossKind>
    ) {
        self.importer = importer
        self.exporter = exporter
        self.family = family
        self.allowedLosses = allowedLosses
    }
}

/// One fixture instance within a cell. `path` is the relative path under
/// `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.
/// `additionalAllowedLosses` extends the cell's allow-list for this specific
/// fixture (used when a fixture intentionally exercises a lossy path the cell
/// as a whole does not).
public struct RoundTripFixture: Sendable, CustomStringConvertible {
    public let path: String
    public let source: String
    public let additionalAllowedLosses: Set<RoundTripLossKind>
    public let note: String?

    public init(
        path: String,
        source: String,
        additionalAllowedLosses: Set<RoundTripLossKind> = [],
        note: String? = nil
    ) {
        self.path = path
        self.source = source
        self.additionalAllowedLosses = additionalAllowedLosses
        self.note = note
    }

    public var description: String { "RoundTripFixture(\(path))" }
}

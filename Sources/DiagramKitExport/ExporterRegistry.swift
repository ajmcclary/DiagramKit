import DiagramKitModel

/// A collection of format exporters, keyed by `DiagramFormatID`.
///
/// Lookup is by format ID: `exporter(named:)` returns the exporter
/// registered for that format, or `nil`. This is format-targeted dispatch —
/// callers ask for `.d2` and get the D2 exporter regardless of whether
/// Mermaid also supports the diagram type.
///
/// Multiple exporters may support the same diagram type — that is expected
/// in a multi-format toolkit. Format overlap is normal; the format ID is
/// the authoritative dispatch key.
public struct ExporterRegistry: Sendable {
    private var exportersByID: [DiagramFormatID: any DiagramExporter]

    public init(exportersByID: [DiagramFormatID: any DiagramExporter] = [:]) {
        self.exportersByID = exportersByID
    }

    /// All registered exporters as an array, sorted deterministically by
    /// `formatID.rawValue`. Callers iterating this collection get the same
    /// order across runs, which matters for diagnostic ordering and for
    /// snapshot-style tests that compare the registered exporter list.
    public var exporters: [any DiagramExporter] {
        exportersByID
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map(\.value)
    }

    /// Returns a new registry with `exporter` registered under its format ID.
    /// Replaces any existing exporter with the same format ID.
    public func registering(_ exporter: any DiagramExporter) -> Self {
        var dict = exportersByID
        dict[exporter.formatID] = exporter
        return ExporterRegistry(exportersByID: dict)
    }

    /// The exporter registered for the given format ID, or `nil`.
    public func exporter(named formatID: DiagramFormatID) -> (any DiagramExporter)? {
        exportersByID[formatID]
    }

    /// All diagram types supported by any exporter in this registry.
    public var supportedDiagramTypes: Set<DiagramType> {
        exportersByID.values.reduce(into: []) { $0.formUnion($1.supportedDiagramTypes) }
    }

    /// Empty registry — no exporters registered.
    public static let empty = ExporterRegistry()
}

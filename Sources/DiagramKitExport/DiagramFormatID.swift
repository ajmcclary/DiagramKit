/// Canonical identifier for a diagram source format.
///
/// Used to look up exporters by format in `ExporterRegistry`.
/// Matches the canonical lowercase IDs already used in `CorpusEntry`
/// (`DiagramKitTestSupport`) and `ImporterRegistry` probe collision tests.
public struct DiagramFormatID: Sendable, Hashable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public var description: String { rawValue }

    public static let mermaid     = DiagramFormatID(rawValue: "mermaid")
    public static let d2          = DiagramFormatID(rawValue: "d2")
    public static let graphviz    = DiagramFormatID(rawValue: "graphviz")
    public static let structurizr = DiagramFormatID(rawValue: "structurizr")
    public static let plantuml    = DiagramFormatID(rawValue: "plantuml")
}

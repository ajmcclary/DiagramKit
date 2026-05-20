import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// D2 source-format exporter.
///
/// Emits valid D2 source for flowchart diagrams from `DiagramDocument`.
/// Matching the current `D2Importer` which only produces `.flowchart`.
public struct D2Exporter: DiagramExporter {
    public let name = "D2"
    public let formatID = DiagramFormatID.d2

    public let supportedDiagramTypes: Set<DiagramType> = [
        .flowchart,
        .classDiagram,
        .stateDiagram,
        .erDiagram,
        .architecture,
    ]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .flowchart(let model):
            return try D2FlowchartExport.emit(model, title: document.title)
        case .classDiagram(let model):
            return try D2ClassExport.emit(model, title: document.title)
        case .stateDiagram(let graph):
            return try D2StateExport.emit(graph, title: document.title)
        case .erDiagram(let model):
            return try D2ERExport.emit(model, title: document.title)
        case .architecture(let arch):
            return try D2ArchitectureExport.emit(arch, title: document.title)
        default:
            return .unsupportedDiagram(formatName: name, type: document.type)
        }
    }
}

// MARK: - D2 Flowchart Export

enum D2FlowchartExport {

    static func emit(_ model: ParsedGraphModel, title: String? = nil) throws -> DiagramExportResult {
        var sink = D2FlowchartExportSink()
        let diagnostics = FlowchartExportWalker.walk(model, title: title, into: &sink)
        return DiagramExportResult(
            source: sink.lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    fileprivate static func sanitizeD2ID(_ raw: String) -> String {
        var result = ""
        for (i, ch) in raw.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                if i == 0, ch.isNumber { result.append("_") }
                result.append(ch)
            case " ", "-", ".":
                result.append("_")
            default: break
            }
        }
        return result.isEmpty ? "node" : result
    }

    fileprivate static func escapeD2String(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }

    /// Map a Mermaid `NodeShape` to a D2 shape name. `lossy == true`
    /// means the mapping discards visual identity (multiple Mermaid
    /// shapes collapse to the same D2 shape, or D2 has no native
    /// equivalent) and a `.lossyTransform(.shapeDowngrade, …)`
    /// diagnostic must be paired with this node.
    fileprivate static func d2Shape(for shape: original_src_types.NodeShape) -> (name: String, lossy: Bool) {
        switch shape {
        case .rectangle: return ("rectangle", false)
        case .rounded: return ("rectangle", true)
        case .diamond: return ("diamond", false)
        case .circle: return ("circle", false)
        case .doublecircle, .smallCircle, .framedCircle, .filledCircle, .crossedCircle:
            return ("circle", true)
        case .hexagon: return ("hexagon", false)
        case .cylinder: return ("cylinder", false)
        case .horizontalCylinder, .linedCylinder:
            return ("cylinder", true)
        case .stadium: return ("stadium", false)
        case .parallelogram: return ("parallelogram", false)
        case .parallelogramAlt, .trapezoid, .trapezoidAlt:
            return ("parallelogram", true)
        default: return ("rectangle", true)
        }
    }

    fileprivate static func singleLineTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ")
    }
}

// MARK: - Sink

private struct D2FlowchartExportSink: FlowchartExportSink {
    var lines: [String] = []
    var diagnostics: [DiagramDiagnostic] = []

    mutating func begin(title: String?) {
        if let title, !title.isEmpty {
            lines.append("# title: \(D2FlowchartExport.singleLineTitle(title))")
        }
    }

    mutating func direction(_ direction: original_src_types.Direction) {
        switch direction {
        case .LR, .RL: lines.append("direction: right")
        default:        lines.append("direction: down")
        }
    }

    mutating func node(id: String, node: original_src_types.MermaidNode) {
        let sanitizedId = D2FlowchartExport.sanitizeD2ID(id)
        let mapped = D2FlowchartExport.d2Shape(for: node.shape)
        lines.append("\(sanitizedId): \"\(D2FlowchartExport.escapeD2String(node.label))\"")
        if mapped.name != "rectangle" {
            // `id.shape: value` attribute syntax round-trips cleanly
            // through D2Parser, unlike the multi-line `id { shape: … }`
            // block (which D2Parser reads as a subgraph).
            lines.append("\(sanitizedId).shape: \(mapped.name)")
        }
        if mapped.lossy {
            diagnostics.append(
                .lossyTransform(
                    .shapeDowngrade,
                    message: "Node '\(id)' shape '\(node.shape.rawValue)' downgraded to D2 '\(mapped.name)' — D2 has no native equivalent"
                )
            )
        }
    }

    mutating func edge(_ edge: original_src_types.MermaidEdge) {
        let sanitizedSrc = D2FlowchartExport.sanitizeD2ID(edge.source)
        let sanitizedTgt = D2FlowchartExport.sanitizeD2ID(edge.target)
        if let label = edge.label, !label.isEmpty {
            lines.append("\(sanitizedSrc) -> \(sanitizedTgt): \"\(D2FlowchartExport.escapeD2String(label))\"")
        } else {
            lines.append("\(sanitizedSrc) -> \(sanitizedTgt)")
        }
    }

    mutating func end() {}
}

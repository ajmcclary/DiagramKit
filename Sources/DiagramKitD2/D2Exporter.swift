import Foundation
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

    /// Flowchart only — matches D2Importer's current coverage.
    public let supportedDiagramTypes: Set<DiagramType> = [
        .flowchart,
    ]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .flowchart(let model):
            return try D2FlowchartExport.emit(model, title: document.title)
        default:
            return DiagramExportResult(
                source: "",
                diagnostics: [
                    DiagramDiagnostic(
                        severity: .unsupported,
                        message: "D2 export for '\(document.type.rawValue)' is not supported"
                    )
                ]
            )
        }
    }
}

// MARK: - D2 Flowchart Export

enum D2FlowchartExport {

    static func emit(_ model: ParsedGraphModel, title: String? = nil) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        if let title, !title.isEmpty {
            lines.append("# title: \(singleLineTitle(title))")
        }

        // Direction
        switch model.direction {
        case .LR, .RL:
            lines.append("direction: right")
        default:
            lines.append("direction: down")
        }

        // Nodes
        for (nodeId, node) in model.nodesInOrder {
            let sanitizedId = sanitizeD2ID(nodeId)
            let shape = d2Shape(for: node.shape)
            var nodeBlock = "\(sanitizedId): \"\(escapeD2String(node.label))\""

            if shape != "rectangle" {
                nodeBlock += " {\n    shape: \(shape)\n  }"
            }

            lines.append(nodeBlock)
        }

        // Edges
        for edge in model.edges {
            let sanitizedSrc = sanitizeD2ID(edge.source)
            let sanitizedTgt = sanitizeD2ID(edge.target)

            var edgeLine: String
            if let label = edge.label, !label.isEmpty {
                edgeLine = "\(sanitizedSrc) -> \(sanitizedTgt): \"\(escapeD2String(label))\""
            } else {
                edgeLine = "\(sanitizedSrc) -> \(sanitizedTgt)"
            }

            lines.append(edgeLine)
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func sanitizeD2ID(_ raw: String) -> String {
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

    private static func escapeD2String(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }

    private static func d2Shape(for shape: original_src_types.NodeShape) -> String {
        switch shape {
        case .rectangle: return "rectangle"
        case .rounded: return "rectangle"  // TODO: border-radius
        case .diamond: return "diamond"
        case .circle, .doublecircle, .smallCircle, .framedCircle, .filledCircle, .crossedCircle:
            return "circle"
        case .hexagon: return "hexagon"
        case .cylinder, .horizontalCylinder, .linedCylinder:
            return "cylinder"
        case .stadium: return "stadium"
        case .parallelogram, .parallelogramAlt, .trapezoid, .trapezoidAlt:
            return "parallelogram"
        default: return "rectangle"
        }
    }

    private static func singleLineTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ")
    }
}

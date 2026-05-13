import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

enum DOTFlowchartExport {

    static func emit(_ model: ParsedGraphModel, title: String? = nil) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        lines.append("digraph G {")

        if let title, !title.isEmpty {
            lines.append("  labelloc=\"t\";")
            lines.append("  label=\(quoted(singleLineTitle(title)));")
        }

        switch model.direction {
        case .LR, .RL:
            lines.append("  rankdir=LR;")
        default:
            lines.append("  rankdir=TB;")
        }

        for (nodeId, node) in model.nodesInOrder {
            let sanitizedId = sanitizeDOTID(nodeId)
            let shape = dotShape(for: node.shape)
            let label = node.label.isEmpty ? nodeId : node.label
            lines.append("  \(sanitizedId) [label=\(quoted(label)), shape=\(shape)];")
        }

        for edge in model.edges {
            let src = sanitizeDOTID(edge.source)
            let tgt = sanitizeDOTID(edge.target)
            if let label = edge.label, !label.isEmpty {
                lines.append("  \(src) -> \(tgt) [label=\(quoted(label))];")
            } else {
                lines.append("  \(src) -> \(tgt);")
            }
        }

        lines.append("}")

        return DiagramExportResult(
            source: lines.joined(separator: "\n"),
            diagnostics: diagnostics
        )
    }

    private static func quoted(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return "\"\(escaped)\""
    }

    private static func sanitizeDOTID(_ id: String) -> String {
        // DOT bareword IDs match [A-Za-z\200-\377_][0-9A-Za-z\200-\377_]*.
        // Anything else gets quoted.
        let allowedFirst = CharacterSet.letters.union(CharacterSet(charactersIn: "_"))
        let allowedTail = allowedFirst.union(.decimalDigits)
        guard let first = id.unicodeScalars.first,
              allowedFirst.contains(first),
              id.unicodeScalars.dropFirst().allSatisfy({ allowedTail.contains($0) }) else {
            return quoted(id)
        }
        return id
    }

    private static func singleLineTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "\n", with: " ")
             .replacingOccurrences(of: "\r", with: " ")
    }

    private static func dotShape(for shape: original_src_types.NodeShape) -> String {
        switch shape {
        case .rectangle, .rounded: return "box"
        case .stadium: return "ellipse"
        case .circle, .doublecircle, .smallCircle, .framedCircle, .filledCircle, .crossedCircle: return "circle"
        case .diamond: return "diamond"
        case .hexagon: return "hexagon"
        case .parallelogram, .parallelogramAlt: return "parallelogram"
        case .trapezoid, .trapezoidAlt: return "trapezium"
        case .cylinder, .horizontalCylinder, .linedCylinder: return "cylinder"
        case .subroutine: return "box3d"
        case .triangle, .flippedTriangle: return "triangle"
        case .ellipse: return "ellipse"
        case .document, .linedDocument, .stackedDocument, .taggedDocument: return "note"
        default: return "box"
        }
    }
}

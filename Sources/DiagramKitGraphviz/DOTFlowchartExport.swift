import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

enum DOTFlowchartExport {

    static func emit(_ model: ParsedGraphModel, title: String? = nil) throws -> DiagramExportResult {
        var sink = DOTFlowchartExportSink()
        let diagnostics = FlowchartExportWalker.walk(model, title: title, into: &sink)
        return DiagramExportResult(
            source: sink.lines.joined(separator: "\n"),
            diagnostics: diagnostics
        )
    }

    fileprivate static func quoted(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return "\"\(escaped)\""
    }

    fileprivate static func sanitizeDOTID(_ id: String) -> String {
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

    fileprivate static func singleLineTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "\n", with: " ")
             .replacingOccurrences(of: "\r", with: " ")
    }

    fileprivate static func dotShape(for shape: original_src_types.NodeShape) -> String {
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

// MARK: - Sink

private struct DOTFlowchartExportSink: FlowchartExportSink {
    var lines: [String] = []

    mutating func begin(title: String?) {
        lines.append("digraph G {")
        if let title, !title.isEmpty {
            lines.append("  labelloc=\"t\";")
            lines.append("  label=\(DOTFlowchartExport.quoted(DOTFlowchartExport.singleLineTitle(title)));")
        }
    }

    mutating func direction(_ direction: original_src_types.Direction) {
        switch direction {
        case .LR, .RL: lines.append("  rankdir=LR;")
        default:        lines.append("  rankdir=TB;")
        }
    }

    mutating func node(id: String, node: original_src_types.MermaidNode) {
        let sanitizedId = DOTFlowchartExport.sanitizeDOTID(id)
        let shape = DOTFlowchartExport.dotShape(for: node.shape)
        let label = node.label.isEmpty ? id : node.label
        lines.append("  \(sanitizedId) [label=\(DOTFlowchartExport.quoted(label)), shape=\(shape)];")
    }

    mutating func edge(_ edge: original_src_types.MermaidEdge) {
        let src = DOTFlowchartExport.sanitizeDOTID(edge.source)
        let tgt = DOTFlowchartExport.sanitizeDOTID(edge.target)
        if let label = edge.label, !label.isEmpty {
            lines.append("  \(src) -> \(tgt) [label=\(DOTFlowchartExport.quoted(label))];")
        } else {
            lines.append("  \(src) -> \(tgt);")
        }
    }

    mutating func end() {
        lines.append("}")
    }
}

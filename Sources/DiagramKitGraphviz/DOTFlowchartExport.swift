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
            source: sink.lines.joined(separator: "\n") + "\n",
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

    /// Map a Mermaid `NodeShape` to a DOT shape name. `lossy == true`
    /// means the mapping discards visual identity (multiple Mermaid
    /// shapes collapse to the same DOT shape, or DOT has no native
    /// equivalent) and a `.lossyTransform(.shapeDowngrade, …)`
    /// diagnostic must be paired with this node.
    fileprivate static func dotShape(for shape: original_src_types.NodeShape) -> (name: String, lossy: Bool) {
        switch shape {
        case .rectangle: return ("box", false)
        case .rounded: return ("box", true)
        case .stadium: return ("ellipse", true)
        case .circle: return ("circle", false)
        case .doublecircle, .smallCircle, .framedCircle, .filledCircle, .crossedCircle: return ("circle", true)
        case .diamond: return ("diamond", false)
        case .hexagon: return ("hexagon", false)
        case .parallelogram: return ("parallelogram", false)
        case .parallelogramAlt: return ("parallelogram", true)
        case .trapezoid: return ("trapezium", false)
        case .trapezoidAlt: return ("trapezium", true)
        case .cylinder: return ("cylinder", false)
        case .horizontalCylinder, .linedCylinder: return ("cylinder", true)
        case .subroutine: return ("box3d", true)
        case .triangle: return ("triangle", false)
        case .flippedTriangle: return ("triangle", true)
        case .ellipse: return ("ellipse", false)
        case .document: return ("note", true)
        case .linedDocument, .stackedDocument, .taggedDocument: return ("note", true)
        default: return ("box", true)
        }
    }
}

// MARK: - Sink

private struct DOTFlowchartExportSink: FlowchartExportSink {
    var lines: [String] = []
    var diagnostics: [DiagramDiagnostic] = []

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
        let mapped = DOTFlowchartExport.dotShape(for: node.shape)
        let label = node.label.isEmpty ? id : node.label
        lines.append("  \(sanitizedId) [label=\(DOTFlowchartExport.quoted(label)), shape=\(mapped.name)];")
        if mapped.lossy {
            diagnostics.append(
                .lossyTransform(
                    .shapeDowngrade,
                    message: "Node '\(id)' shape '\(node.shape.rawValue)' downgraded to DOT '\(mapped.name)' — DOT has no native equivalent"
                )
            )
        }
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

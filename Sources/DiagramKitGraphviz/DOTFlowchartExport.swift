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
        DOTHygiene.quoted(s)
    }

    fileprivate static func sanitizeDOTID(_ id: String) -> String {
        DOTHygiene.quoteBarewordID(id)
    }

    fileprivate static func singleLineTitle(_ title: String) -> String {
        DOTHygiene.singleLine(title)
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
    var formatName: String { "Graphviz DOT" }

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
        var attrs: [String] = []
        if let label = edge.label, !label.isEmpty {
            attrs.append("label=\(DOTFlowchartExport.quoted(label))")
        }
        // Edge styles map onto native DOT attributes. The residual loss is
        // DiagramKit's own DOT importer (which reads only the label
        // attribute today), so pair the emission with a styleDrop
        // diagnostic for the round-trip harness.
        switch edge.style {
        case .solid: break
        case .dotted: attrs.append("style=dotted")
        case .thick: attrs.append("style=bold")
        case .invisible: attrs.append("style=invis")
        }
        if edge.style != .solid {
            diagnostics.append(.lossyTransform(
                .styleDrop,
                message: "Edge '\(edge.source)' -> '\(edge.target)' style '\(edge.style.rawValue)' emitted as a DOT style attribute but not restored by DiagramKit's DOT import"
            ))
        }
        if edge.arrowHeadStart != .none {
            attrs.append("dir=both")
            diagnostics.append(.lossyTransform(
                .styleDrop,
                message: "Edge '\(edge.source)' -> '\(edge.target)' start arrowhead emitted as dir=both but not restored by DiagramKit's DOT import"
            ))
        }
        if edge.arrowHeadEnd != .arrow && edge.arrowHeadEnd != .none {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "Edge '\(edge.source)' -> '\(edge.target)' end arrowhead type '\(edge.arrowHeadEnd.rawValue)' has no faithful DOT attribute mapping in this exporter"
            ))
        }
        if attrs.isEmpty {
            lines.append("  \(src) -> \(tgt);")
        } else {
            lines.append("  \(src) -> \(tgt) [\(attrs.joined(separator: ", "))];")
        }
    }

    mutating func end() {
        lines.append("}")
    }
}

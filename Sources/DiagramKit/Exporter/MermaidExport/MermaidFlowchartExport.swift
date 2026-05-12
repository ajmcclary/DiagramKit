import Foundation
import DiagramKitModel
import DiagramKitImport

/// Emits Mermaid flowchart source from a `ParsedGraphModel`.
enum MermaidFlowchartExport {

    static func emit(_ model: ParsedGraphModel) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        // Direction
        let dirString: String
        switch model.direction {
        case .TD: dirString = "TD"
        case .TB: dirString = "TB"
        case .LR: dirString = "LR"
        case .BT: dirString = "BT"
        case .RL: dirString = "RL"
        }
        lines.append("graph \(dirString)")

        // Build subgraph hierarchy
        let subgraphMap: [String: original_src_types.MermaidSubgraph] = Dictionary(
            uniqueKeysWithValues: model.subgraphs.map { ($0.id, $0) }
        )
        var emittedSubgraphs = Set<String>()

        // Emit nodes
        for (nodeId, node) in model.nodesInOrder {
            if let subgraph = subgraphMap[nodeId] {
                emitSubgraph(subgraph, subgraphMap: subgraphMap, emitted: &emittedSubgraphs, lines: &lines, diagnostics: &diagnostics, indent: 0)
            } else {
                let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(nodeId)
                diagnostics.append(contentsOf: idDiags)

                let shapeStr = shapeMarker(for: node.shape)
                var nodeLine: String
                if node.label.isEmpty || node.label == nodeId {
                    nodeLine = "  \(sanitizedId)\(shapeStr)"
                } else {
                    let (escaped, escDiags) = MermaidExportHelpers.escapeBracketLabel(node.label)
                    diagnostics.append(contentsOf: escDiags)
                    nodeLine = "  \(sanitizedId)\(shapeStr.prefix(1))\(escaped)\(shapeStr.suffix(from: shapeStr.index(after: shapeStr.startIndex)))"
                }
                lines.append(nodeLine)

                // Node styles (from model-level nodeStyles dictionary)
                if let nodeStyle = model.nodeStyles[nodeId], !nodeStyle.isEmpty {
                    let styleLine = "  style \(sanitizedId) \(formatCSS(nodeStyle))"
                    lines.append(styleLine)
                }
            }
        }

        // Emit edges
        for (i, edge) in model.edges.enumerated() {
            let (sanitizedSrc, srcDiags) = MermaidExportHelpers.sanitizeIdentifier(edge.source)
            let (sanitizedTgt, tgtDiags) = MermaidExportHelpers.sanitizeIdentifier(edge.target)
            diagnostics.append(contentsOf: srcDiags)
            diagnostics.append(contentsOf: tgtDiags)

            let arrowStr = arrowString(
                style: edge.style,
                arrowHeadStart: edge.arrowHeadStart,
                arrowHeadEnd: edge.arrowHeadEnd
            )

            var edgeLine = "  \(sanitizedSrc) \(arrowStr) \(sanitizedTgt)"

            if let label = edge.label, !label.isEmpty {
                let (escaped, escDiags) = MermaidExportHelpers.escapeEdgeLabel(label)
                diagnostics.append(contentsOf: escDiags)
                edgeLine += "|\(escaped)|"
            }

            // Edge ID
            if let edgeId = edge.id {
                edgeLine = "  \(sanitizedSrc) \(edgeId)@\(arrowStr) \(sanitizedTgt)"
                if let _ = edge.label {
                    // Edge IDs with labels: label is embedded in the edge syntax
                    // This is best-effort — Mermaid edge IDs and labels together
                    // have complex syntax
                }
            }

            lines.append(edgeLine)

            // Link styles
            if let linkStyle = model.linkStyles[i], !linkStyle.isEmpty {
                lines.append("  linkStyle \(i) \(formatCSS(linkStyle))")
            }
        }

        // Class defs
        for (name, styles) in model.classDefs.sorted(by: { $0.key < $1.key }) {
            lines.append("  classDef \(name) \(formatCSS(styles))")
        }

        // Class assignments
        for (nodeId, classNames) in model.classAssignments.sorted(by: { $0.key < $1.key }) {
            let (sanitizedId, _) = MermaidExportHelpers.sanitizeIdentifier(nodeId)
            lines.append("  class \(sanitizedId) \(classNames.joined(separator: ","))")
        }

        // Node styles
        for (nodeId, styles) in model.nodeStyles.sorted(by: { $0.key < $1.key }) {
            let (sanitizedId, _) = MermaidExportHelpers.sanitizeIdentifier(nodeId)
            lines.append("  style \(sanitizedId) \(formatCSS(styles))")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // MARK: - Subgraph emission

    private static func emitSubgraph(
        _ subgraph: original_src_types.MermaidSubgraph,
        subgraphMap: [String: original_src_types.MermaidSubgraph],
        emitted: inout Set<String>,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic],
        indent: Int
    ) {
        let pad = String(repeating: "  ", count: indent)
        let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(subgraph.id)
        diagnostics.append(contentsOf: idDiags)

        if subgraph.label.isEmpty {
            lines.append("\(pad)subgraph \(sanitizedId)")
        } else {
            let (escaped, escDiags) = MermaidExportHelpers.escapeBracketLabel(subgraph.label)
            diagnostics.append(contentsOf: escDiags)
            lines.append("\(pad)subgraph \(sanitizedId) [\(escaped)]")
        }

        if let dir = subgraph.direction {
            lines.append("\(pad)  direction \(dir.rawValue)")
        }

        emitted.insert(subgraph.id)

        for childSubgraph in subgraph.children {
            emitSubgraph(childSubgraph, subgraphMap: subgraphMap, emitted: &emitted, lines: &lines, diagnostics: &diagnostics, indent: indent + 1)
        }

        lines.append("\(pad)end")
    }

    // MARK: - Shape markers

    private static func shapeMarker(for shape: original_src_types.NodeShape) -> String {
        switch shape {
        case .rectangle: return "[]"
        case .rounded: return "()"
        case .stadium: return "([])"
        case .subroutine: return "[[]]"
        case .cylinder: return "[(%)]"
        case .diamond: return "{}"
        case .hexagon: return "{{}}"
        case .circle: return "(())"
        case .doublecircle: return "((()))"
        case .trapezoid: return "[/]"
        case .trapezoidAlt: return "[\\]"
        case .asymmetric: return ">]"
        case .ellipse: return "(-)"
        case .parallelogram: return "[/]"
        case .parallelogramAlt: return "[\\]"
        case .bang: return ">]"
        case .cloud: return "[]"
        case .dataStore: return "[]"
        case .text: return "[]"
        case .notchedRectangle: return "[]"
        case .linedRectangle: return "[]"
        case .smallCircle: return "(())"
        case .framedCircle: return "(())"
        case .fork: return "{}"
        case .join: return "{}"
        case .hourglass: return "{}"
        case .braceL: return "{}"
        case .braceR: return "{}"
        case .braces: return "{}"
        case .lightningBolt: return "[]"
        case .document: return "[]"
        case .delay: return "[]"
        case .horizontalCylinder: return "[]"
        case .linedCylinder: return "[]"
        case .curvedTrapezoid: return "[]"
        case .dividedRectangle: return "[]"
        case .triangle: return "[]"
        case .windowPane: return "[]"
        case .filledCircle: return "(())"
        case .linedDocument: return "[]"
        case .notchedPentagon: return "[]"
        case .flippedTriangle: return "[]"
        case .slopedRectangle: return "[]"
        case .stackedDocument: return "[]"
        case .stackedRectangle: return "[]"
        case .flag: return "[]"
        case .bowTieRectangle: return "[]"
        case .crossedCircle: return "(())"
        case .taggedDocument: return "[]"
        case .taggedRectangle: return "[]"
        case .iconSquare: return "[]"
        case .iconCircle: return "(())"
        case .icon: return "[]"
        case .iconRounded: return "()"
        case .imageSquare: return "[]"
        case .state: return "[]"
        case .choice: return "{}"
        case .note: return "[]"
        case .stateStart: return "([])"
        case .stateEnd: return "([])"
        case .stateDivider: return "[]"
        case .stateNote: return "[]"
        case .roundedWithTitle: return "()"
        case .rectWithTitle: return "[]"
        case .labelRect: return "[]"
        case .anchor: return "[]"
        case .invisible: return "[]"
        }
    }

    // MARK: - Arrow string

    private static func arrowString(
        style: original_src_types.EdgeStyle,
        arrowHeadStart: original_src_types.ArrowHeadType,
        arrowHeadEnd: original_src_types.ArrowHeadType
    ) -> String {
        let startMarker = arrowHeadMarker(arrowHeadStart)
        let endMarker = arrowHeadMarker(arrowHeadEnd)

        let lineStr: String
        switch style {
        case .solid: lineStr = "--"
        case .dotted: lineStr = "-."
        case .thick: lineStr = "=="
        case .invisible: lineStr = "~~"
        }

        if endMarker == ">" {
            return "\(startMarker)\(lineStr)\(endMarker)"
        } else {
            return "\(startMarker)\(lineStr)\(endMarker)"
        }
    }

    private static func arrowHeadMarker(_ type: original_src_types.ArrowHeadType) -> String {
        switch type {
        case .none: return ""
        case .arrow: return ">"
        case .open: return "o"
        case .circle: return "o"
        case .cross: return "x"
        case .diamond: return "d"
        }
    }

    // MARK: - CSS formatting

    private static func formatCSS(_ styles: [String: String]) -> String {
        styles.map { "\($0.key):\($0.value)" }.joined(separator: ",")
    }
}

import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid flowchart source from a `ParsedGraphModel`.
enum MermaidFlowchartExport {

    static func emit(_ model: ParsedGraphModel) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        // Collision-aware identifier emission shared across nodes,
        // subgraphs, edges, classAssignments, and nodeStyles. Nodes and
        // subgraphs occupy the same id namespace, so a single
        // `usedAliases` set and a single `aliasMap` cover both. Edges
        // and post-pass styles look up via `aliasMap` so collided ids
        // (`foo bar`, `foo!bar` → `foo_bar` / `foo_bar_2`) resolve to
        // the right endpoint.
        var usedAliases: Set<String> = []
        var aliasMap: [String: String] = [:]

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
                emitSubgraph(subgraph, subgraphMap: subgraphMap, emitted: &emittedSubgraphs, usedAliases: &usedAliases, aliasMap: &aliasMap, lines: &lines, diagnostics: &diagnostics, indent: 0)
            } else {
                let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(
                    nodeId,
                    usedAliases: &usedAliases
                )
                diagnostics.append(contentsOf: idDiags)
                aliasMap[nodeId] = sanitizedId

                let shape = shapeMarker(for: node.shape)
                if shape.lossy {
                    diagnostics.append(.lossyTransform(
                        .shapeDowngrade,
                        message: "Mermaid flowchart has no native marker for shape '\(node.shape)'; emitted with fallback marker (node '\(nodeId)')"
                    ))
                }
                var nodeLine: String
                if node.label.isEmpty || node.label == nodeId {
                    nodeLine = "  \(sanitizedId)\(shape.open)\(shape.close)"
                } else {
                    let (escaped, escDiags) = MermaidExportHelpers.escapeBracketLabel(node.label)
                    diagnostics.append(contentsOf: escDiags)
                    nodeLine = "  \(sanitizedId)\(shape.open)\(escaped)\(shape.close)"
                }
                lines.append(nodeLine)

                // Node styles (from model-level nodeStyles dictionary)
                if let nodeStyle = model.nodeStyles[nodeId], !nodeStyle.isEmpty {
                    let styleLine = "  style \(sanitizedId) \(formatCSS(nodeStyle))"
                    lines.append(styleLine)
                }
            }
        }

        // Emit any subgraph whose id didn't appear in `nodesInOrder`.
        // The earlier loop only fires `emitSubgraph` when a node id
        // collides with a subgraph id; subgraphs declared independently
        // (the common case) would otherwise be silently dropped from
        // the exported source.
        for subgraph in model.subgraphs where !emittedSubgraphs.contains(subgraph.id) {
            emitSubgraph(subgraph, subgraphMap: subgraphMap, emitted: &emittedSubgraphs, usedAliases: &usedAliases, aliasMap: &aliasMap, lines: &lines, diagnostics: &diagnostics, indent: 0)
        }

        // Emit edges
        for (i, edge) in model.edges.enumerated() {
            let (sanitizedSrc, srcDiags): (String, [DiagramDiagnostic]) = aliasMap[edge.source].map { ($0, []) }
                ?? MermaidExportHelpers.sanitizeIdentifier(edge.source)
            let (sanitizedTgt, tgtDiags): (String, [DiagramDiagnostic]) = aliasMap[edge.target].map { ($0, []) }
                ?? MermaidExportHelpers.sanitizeIdentifier(edge.target)
            diagnostics.append(contentsOf: srcDiags)
            diagnostics.append(contentsOf: tgtDiags)

            let arrowStr = arrowString(
                style: edge.style,
                arrowHeadStart: edge.arrowHeadStart,
                arrowHeadEnd: edge.arrowHeadEnd
            )

            var emittedArrow = arrowStr

            if let label = edge.label, !label.isEmpty {
                let (escaped, escDiags) = MermaidExportHelpers.escapeEdgeLabel(label)
                diagnostics.append(contentsOf: escDiags)
                emittedArrow = textEmbeddedArrowString(
                    style: edge.style,
                    arrowHeadStart: edge.arrowHeadStart,
                    arrowHeadEnd: edge.arrowHeadEnd,
                    label: escaped
                )
            }

            var edgeLine = "  \(sanitizedSrc) \(emittedArrow) \(sanitizedTgt)"

            // Edge ID
            if let edgeId = edge.id {
                edgeLine = "  \(sanitizedSrc) \(edgeId)@\(emittedArrow) \(sanitizedTgt)"
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
            let sanitizedId = aliasMap[nodeId] ?? MermaidExportHelpers.sanitizeIdentifier(nodeId).sanitized
            lines.append("  class \(sanitizedId) \(classNames.joined(separator: ","))")
        }

        // Node styles
        for (nodeId, styles) in model.nodeStyles.sorted(by: { $0.key < $1.key }) {
            let sanitizedId = aliasMap[nodeId] ?? MermaidExportHelpers.sanitizeIdentifier(nodeId).sanitized
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
        usedAliases: inout Set<String>,
        aliasMap: inout [String: String],
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic],
        indent: Int
    ) {
        let pad = String(repeating: "  ", count: indent)
        let (sanitizedId, idDiags) = MermaidExportHelpers.sanitizeIdentifier(
            subgraph.id,
            usedAliases: &usedAliases
        )
        diagnostics.append(contentsOf: idDiags)
        aliasMap[subgraph.id] = sanitizedId

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
            emitSubgraph(childSubgraph, subgraphMap: subgraphMap, emitted: &emitted, usedAliases: &usedAliases, aliasMap: &aliasMap, lines: &lines, diagnostics: &diagnostics, indent: indent + 1)
        }

        lines.append("\(pad)end")
    }

    // MARK: - Shape markers

    /// Mermaid open/close wrappers for each `NodeShape`, plus a `lossy`
    /// flag indicating whether the chosen marker drops fidelity.
    /// Canonical flowchart shapes (`rectangle`, `rounded`, `stadium`,
    /// `subroutine`, `cylinder`, `diamond`, `hexagon`, `circle`,
    /// `doublecircle`, `trapezoid`/`trapezoidAlt`, `asymmetric`,
    /// `ellipse`, `parallelogram`/`parallelogramAlt`) are emitted as-is.
    /// Shapes from other diagram families (state, mindmap, v11 icon
    /// shapes, etc.) have no flowchart marker and fall back to a
    /// nearest-equivalent — the caller emits a `.warning` diagnostic.
    private static func shapeMarker(for shape: original_src_types.NodeShape) -> (open: String, close: String, lossy: Bool) {
        switch shape {
        case .rectangle: return ("[", "]", false)
        case .rounded: return ("(", ")", false)
        case .stadium: return ("([", "])", false)
        case .subroutine: return ("[[", "]]", false)
        case .cylinder: return ("[(", ")]", false)
        case .diamond: return ("{", "}", false)
        case .hexagon: return ("{{", "}}", false)
        case .circle: return ("((", "))", false)
        case .doublecircle: return ("(((", ")))", false)
        case .trapezoid: return ("[/", "/]", false)
        case .trapezoidAlt: return ("[\\", "\\]", false)
        case .asymmetric: return (">", "]", false)
        case .ellipse: return ("(-", "-)", false)
        case .parallelogram: return ("[/", "\\]", false)
        case .parallelogramAlt: return ("[\\", "/]", false)
        case .bang: return (">", "]", true)
        case .cloud: return ("[", "]", true)
        case .dataStore: return ("[", "]", true)
        case .text: return ("[", "]", true)
        case .notchedRectangle: return ("[", "]", true)
        case .linedRectangle: return ("[", "]", true)
        case .smallCircle: return ("((", "))", true)
        case .framedCircle: return ("((", "))", true)
        case .fork: return ("{", "}", true)
        case .join: return ("{", "}", true)
        case .hourglass: return ("{", "}", true)
        case .braceL: return ("{", "}", true)
        case .braceR: return ("{", "}", true)
        case .braces: return ("{", "}", true)
        case .lightningBolt: return ("[", "]", true)
        case .document: return ("[", "]", true)
        case .delay: return ("[", "]", true)
        case .horizontalCylinder: return ("[", "]", true)
        case .linedCylinder: return ("[", "]", true)
        case .curvedTrapezoid: return ("[", "]", true)
        case .dividedRectangle: return ("[", "]", true)
        case .triangle: return ("[", "]", true)
        case .windowPane: return ("[", "]", true)
        case .filledCircle: return ("((", "))", true)
        case .linedDocument: return ("[", "]", true)
        case .notchedPentagon: return ("[", "]", true)
        case .flippedTriangle: return ("[", "]", true)
        case .slopedRectangle: return ("[", "]", true)
        case .stackedDocument: return ("[", "]", true)
        case .stackedRectangle: return ("[", "]", true)
        case .flag: return ("[", "]", true)
        case .bowTieRectangle: return ("[", "]", true)
        case .crossedCircle: return ("((", "))", true)
        case .taggedDocument: return ("[", "]", true)
        case .taggedRectangle: return ("[", "]", true)
        case .iconSquare: return ("[", "]", true)
        case .iconCircle: return ("((", "))", true)
        case .icon: return ("[", "]", true)
        case .iconRounded: return ("(", ")", true)
        case .imageSquare: return ("[", "]", true)
        case .state: return ("[", "]", true)
        case .choice: return ("{", "}", true)
        case .note: return ("[", "]", true)
        case .stateStart: return ("([", "])", true)
        case .stateEnd: return ("([", "])", true)
        case .stateDivider: return ("[", "]", true)
        case .stateNote: return ("[", "]", true)
        case .roundedWithTitle: return ("(", ")", true)
        case .rectWithTitle: return ("[", "]", true)
        case .labelRect: return ("[", "]", true)
        case .anchor: return ("[", "]", true)
        case .invisible: return ("[", "]", true)
        }
    }

    // MARK: - Arrow string

    private static func textEmbeddedArrowString(
        style: original_src_types.EdgeStyle,
        arrowHeadStart: original_src_types.ArrowHeadType,
        arrowHeadEnd: original_src_types.ArrowHeadType,
        label: String
    ) -> String {
        let startPrefix = arrowHeadStart == .arrow ? "<" : ""

        switch style {
        case .dotted:
            let close = arrowHeadEnd == .none ? "-.-" : ".->"
            return "\(startPrefix)-. \(label) \(close)"
        case .thick:
            let close = arrowHeadEnd == .none ? "===" : "==>"
            return "\(startPrefix)== \(label) \(close)"
        case .solid:
            let close = arrowHeadEnd == .none ? "---" : "-->"
            return "\(startPrefix)-- \(label) \(close)"
        case .invisible:
            return "~~~"
        }
    }

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

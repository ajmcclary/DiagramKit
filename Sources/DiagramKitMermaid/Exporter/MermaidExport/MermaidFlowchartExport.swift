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

                let emission = shapeEmission(for: node.shape)
                var nodeLine: String
                switch emission {
                case .marker(let open, let close):
                    if node.label.isEmpty || node.label == nodeId {
                        nodeLine = "  \(sanitizedId)\(open)\(close)"
                    } else {
                        let (escaped, escDiags) = MermaidExportHelpers.escapeBracketLabel(node.label)
                        diagnostics.append(contentsOf: escDiags)
                        nodeLine = "  \(sanitizedId)\(open)\(escaped)\(close)"
                    }
                case .metadata:
                    if node.label.isEmpty || node.label == nodeId {
                        nodeLine = "  \(sanitizedId)"
                    } else {
                        let (escaped, escDiags) = MermaidExportHelpers.escapeBracketLabel(node.label)
                        diagnostics.append(contentsOf: escDiags)
                        nodeLine = "  \(sanitizedId)[\(escaped)]"
                    }
                }
                let pairs = metadataPairs(for: node, emission: emission)
                if !pairs.isEmpty {
                    nodeLine += "@{ \(pairs.joined(separator: ", ")) }"
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

    // MARK: - Shape emission

    /// Emission form for a `NodeShape`: the 15 classic flowchart
    /// shapes use their native bracket markers; every other shape is
    /// emitted as v11 `@{ shape: <rawValue> }` metadata, which the
    /// parser resolves back losslessly (`resolve(alias:)` accepts
    /// every rawValue).
    private enum ShapeEmission {
        case marker(open: String, close: String)
        case metadata(shapeName: String)
    }

    private static func shapeEmission(for shape: original_src_types.NodeShape) -> ShapeEmission {
        switch shape {
        case .rectangle: return .marker(open: "[", close: "]")
        case .rounded: return .marker(open: "(", close: ")")
        case .stadium: return .marker(open: "([", close: "])")
        case .subroutine: return .marker(open: "[[", close: "]]")
        case .cylinder: return .marker(open: "[(", close: ")]")
        case .diamond: return .marker(open: "{", close: "}")
        case .hexagon: return .marker(open: "{{", close: "}}")
        case .circle: return .marker(open: "((", close: "))")
        case .doublecircle: return .marker(open: "(((", close: ")))")
        case .trapezoid: return .marker(open: "[/", close: "/]")
        case .trapezoidAlt: return .marker(open: "[\\", close: "\\]")
        case .asymmetric: return .marker(open: ">", close: "]")
        case .ellipse: return .marker(open: "(-", close: "-)")
        case .parallelogram: return .marker(open: "[/", close: "\\]")
        case .parallelogramAlt: return .marker(open: "[\\", close: "/]")
        default: return .metadata(shapeName: shape.rawValue)
        }
    }

    /// Metadata pairs for a node's `@{ … }` block: the shape (when
    /// emission is metadata-form) plus any parser-visible
    /// `NodeProperties`. `properties.shape` and `.label` are skipped —
    /// shape comes from `node.shape`, the label from the bracket text.
    private static func metadataPairs(
        for node: original_src_types.MermaidNode,
        emission: ShapeEmission
    ) -> [String] {
        var pairs: [String] = []
        if case .metadata(let shapeName) = emission {
            pairs.append("shape: \(shapeName)")
        }
        guard let props = node.properties else { return pairs }
        if let icon = props.icon { pairs.append("icon: \"\(icon)\"") }
        if let form = props.form { pairs.append("form: \"\(form)\"") }
        if let pos = props.pos { pairs.append("pos: \"\(pos)\"") }
        if let img = props.img { pairs.append("img: \"\(img)\"") }
        if let w = props.w { pairs.append("w: \(formatNumber(w))") }
        if let h = props.h { pairs.append("h: \(formatNumber(h))") }
        return pairs
    }

    private static func formatNumber(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
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

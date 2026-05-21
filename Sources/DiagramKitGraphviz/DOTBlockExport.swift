import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// `BlockDiagram` → DOT source. Wraps the body in `digraph G { … }`,
/// emits the `family=block` marker so the importer can dispatch, and
/// always pairs lossy native emissions with recovery markers. Composite
/// containers become `subgraph cluster_<id> { … }`; leaves become
/// `<id> [label="…", shape=<native or downgrade>]`; edges become
/// `<src> -> <tgt> [label="…"];`. Grid column structure travels
/// exclusively via `block-cols` markers — DOT has no native grid.
enum DOTBlockExport {

    static func emit(_ block: BlockDiagram, title: String?) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append("digraph G {")
        // Family marker is always inside the graph body so it
        // survives a `dot`-tool reformat.
        lines.append("  \(DOTRecoveryMarker.emitFamily("block"))")
        if let t = title, !t.isEmpty {
            lines.append("  label=\"\(escape(singleLine(t)))\";")
        }

        emit(
            childIDs: block.rootChildren,
            parentID: block.rootId,
            db: block.blockDatabase,
            indent: "  ",
            into: &lines,
            diagnostics: &diagnostics
        )

        for (idx, edge) in block.edges.enumerated() {
            emit(edge: edge, index: idx, indent: "  ", into: &lines, diagnostics: &diagnostics)
        }

        for className in block.classes.keys.sorted() {
            guard let def = block.classes[className] else { continue }
            let stylesCsv = def.styles.joined(separator: ";")
            lines.append("  \(DOTRecoveryMarker.emitBlockClassDef(className: className, stylesCsv: stylesCsv))")
        }

        if let t = block.accTitle, !t.isEmpty {
            lines.append("  \(DOTRecoveryMarker.emitBlockAccTitle(t))")
        }
        if let d = block.accDescr, !d.isEmpty {
            lines.append("  \(DOTRecoveryMarker.emitBlockAccDescr(d))")
        }

        lines.append("}")

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    // MARK: - Tree emission

    private static func emit(
        childIDs: [String],
        parentID: String,
        db: [String: BlockNode],
        indent: String,
        into lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        for (col, id) in childIDs.enumerated() {
            guard let node = db[id] else { continue }
            switch node.type {
            case .space:
                lines.append("\(indent)\(DOTRecoveryMarker.emitBlockSpace(parentID: parentID, columnIndex: col))")
                continue

            case .composite:
                lines.append("\(indent)subgraph cluster_\(sanitize(id)) {")
                let inner = indent + "  "
                if !node.label.isEmpty {
                    lines.append("\(inner)label=\"\(escape(node.label))\";")
                }
                emit(
                    childIDs: node.children,
                    parentID: id,
                    db: db,
                    indent: inner,
                    into: &lines,
                    diagnostics: &diagnostics
                )
                lines.append("\(indent)}")
                if let cols = node.columns, cols >= 1 {
                    lines.append("\(indent)\(DOTRecoveryMarker.emitBlockCols(containerID: id, columns: cols))")
                }

            default:
                emitLeaf(node, indent: indent, into: &lines, diagnostics: &diagnostics)
            }

            if let styles = node.styles, !styles.isEmpty {
                lines.append("\(indent)\(DOTRecoveryMarker.emitBlockStyle(nodeID: id, stylesCsv: styles.joined(separator: ";")))")
            }
            if let classes = node.classes {
                for className in classes {
                    lines.append("\(indent)\(DOTRecoveryMarker.emitBlockClassApply(nodeID: id, className: className))")
                }
            }
            if let span = node.widthInColumns, span > 1 {
                lines.append("\(indent)\(DOTRecoveryMarker.emitBlockWidth(nodeID: id, widthInColumns: span))")
            }
        }
    }

    // MARK: - Leaf emission

    private static func emitLeaf(
        _ node: BlockNode,
        indent: String,
        into lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let mapped = dotShape(for: node.type)
        var attrs = "label=\"\(escape(node.label))\""
        if mapped.name != "box" {
            attrs += ", shape=\(mapped.name)"
        }
        lines.append("\(indent)\(sanitize(node.id)) [\(attrs)];")
        if mapped.lossy {
            lines.append("\(indent)\(DOTRecoveryMarker.emitBlockShapeFallback(nodeID: node.id, rawValue: node.type.rawValue))")
            diagnostics.append(.lossyTransform(
                .shapeDowngrade,
                message: "block shape '\(node.type.rawValue)' downgraded to DOT '\(mapped.name)'"
            ))
        }
        if node.type == .blockArrow, let dirs = node.directions, !dirs.isEmpty {
            let csv = dirs.map(\.rawValue).joined(separator: ",")
            lines.append("\(indent)\(DOTRecoveryMarker.emitBlockArrowDir(nodeID: node.id, directionsCsv: csv))")
        }
    }

    // MARK: - Edge emission

    private static func emit(
        edge: BlockEdge,
        index: Int,
        indent: String,
        into lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let label = edge.label ?? ""
        if !label.isEmpty {
            lines.append("\(indent)\(sanitize(edge.start)) -> \(sanitize(edge.end)) [label=\"\(escape(label))\"];")
        } else {
            lines.append("\(indent)\(sanitize(edge.start)) -> \(sanitize(edge.end));")
        }
        // Always emit attrs marker for round-trip identity.
        lines.append("\(indent)\(DOTRecoveryMarker.emitBlockEdgeAttrs(edgeIndex: index, thickness: edge.thickness, pattern: edge.pattern, arrowStart: edge.arrowTypeStart, arrowEnd: edge.arrowTypeEnd))")
    }

    // MARK: - Shape mapping

    private static func dotShape(for type: BlockNodeType) -> (name: String, lossy: Bool) {
        switch type {
        case .square, .na:        return ("box", false)
        case .round:               return ("ellipse", false)
        case .circle:              return ("circle", false)
        case .doublecircle:        return ("doublecircle", false)
        case .diamond:             return ("diamond", false)
        case .hexagon:             return ("hexagon", false)
        case .stadium:             return ("box", true)
        case .subroutine:          return ("box3d", false)
        case .cylinder:            return ("cylinder", false)
        case .leanRight:           return ("parallelogram", true)
        case .leanLeft:            return ("parallelogram", true)
        case .trapezoid:           return ("trapezium", false)
        case .invTrapezoid:        return ("invtrapezium", false)
        case .rectLeftInvArrow, .blockArrow:
            return ("box", true)
        case .space, .composite, .classDef, .applyClass, .applyStyles,
             .columnSetting, .edge:
            return ("box", false)
        }
    }

    // MARK: - Sanitization / escaping

    private static func sanitize(_ raw: String) -> String {
        var out = ""
        for (i, ch) in raw.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                if i == 0, ch.isNumber { out.append("_") }
                out.append(ch)
            case " ", "-", ".":
                out.append("_")
            default:
                continue
            }
        }
        return out.isEmpty ? "node" : out
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ")
    }
}

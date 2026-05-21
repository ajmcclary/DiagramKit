import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// `BlockDiagram` → D2 source. Always emits `family=block` so the
/// importer can dispatch even on marker-less consumers. All
/// block-specific metadata that D2's vocabulary cannot express is
/// preserved via comment-encoded recovery markers; visual fidelity for
/// shapes that map to native D2 shapes (square / round / circle /
/// diamond / hexagon / stadium / cylinder) requires no markers.
public enum D2BlockExporter {

    public static func emit(_ block: BlockDiagram, title: String? = nil) -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append(D2RecoveryMarker.emitFamily("block"))
        if let title, !title.isEmpty {
            lines.append("title: \"\(escape(title))\"")
        }

        // Emit child tree.
        emit(
            childIDs: block.rootChildren,
            parentID: block.rootId,
            db: block.blockDatabase,
            depth: 0,
            into: &lines,
            diagnostics: &diagnostics
        )

        // Emit edges with paired marker per index.
        for (idx, edge) in block.edges.enumerated() {
            emit(edge: edge, index: idx, into: &lines, diagnostics: &diagnostics)
        }

        // ClassDef table.
        for className in block.classes.keys.sorted() {
            guard let def = block.classes[className] else { continue }
            let stylesCsv = def.styles.joined(separator: ";")
            lines.append(D2RecoveryMarker.emitBlockClassDef(
                className: className,
                stylesCsv: stylesCsv
            ))
        }

        // Accessibility markers.
        if let t = block.accTitle, !t.isEmpty {
            lines.append(D2RecoveryMarker.emitBlockAccTitle(t))
        }
        if let d = block.accDescr, !d.isEmpty {
            lines.append(D2RecoveryMarker.emitBlockAccDescr(d))
        }

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
        depth: Int,
        into lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let indent = String(repeating: "  ", count: depth)
        for (col, id) in childIDs.enumerated() {
            guard let node = db[id] else { continue }
            switch node.type {
            case .space:
                lines.append(D2RecoveryMarker.emitBlockSpace(
                    parentID: parentID,
                    columnIndex: col
                ))
                continue

            case .composite:
                lines.append("\(indent)\(id): \"\(escape(node.label))\" {")
                emit(
                    childIDs: node.children,
                    parentID: id,
                    db: db,
                    depth: depth + 1,
                    into: &lines,
                    diagnostics: &diagnostics
                )
                lines.append("\(indent)}")
                if let cols = node.columns, cols >= 1 {
                    lines.append(D2RecoveryMarker.emitBlockCols(
                        containerID: id,
                        columns: cols
                    ))
                }

            default:
                emitLeaf(node, indent: indent, into: &lines, diagnostics: &diagnostics)
            }

            // Inline styles + class applies + width span — emitted
            // outside the container body / after the leaf line.
            if let styles = node.styles, !styles.isEmpty {
                lines.append(D2RecoveryMarker.emitBlockStyle(
                    nodeID: id,
                    stylesCsv: styles.joined(separator: ";")
                ))
            }
            if let classes = node.classes {
                for className in classes {
                    lines.append(D2RecoveryMarker.emitBlockClassApply(
                        nodeID: id,
                        className: className
                    ))
                }
            }
            if let span = node.widthInColumns, span > 1 {
                lines.append(D2RecoveryMarker.emitBlockWidth(
                    nodeID: id,
                    widthInColumns: span
                ))
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
        let mapped = d2Shape(for: node.type)
        lines.append("\(indent)\(node.id): \"\(escape(node.label))\"")
        if mapped.name != "rectangle" {
            lines.append("\(indent)\(node.id).shape: \(mapped.name)")
        }
        if mapped.lossy {
            lines.append(D2RecoveryMarker.emitBlockShapeFallback(
                nodeID: node.id,
                rawValue: node.type.rawValue
            ))
            diagnostics.append(.lossyTransform(
                .shapeDowngrade,
                message: "block shape '\(node.type.rawValue)' downgraded to D2 '\(mapped.name)'"
            ))
        }
        if node.type == .blockArrow, let dirs = node.directions, !dirs.isEmpty {
            let csv = dirs.map(\.rawValue).joined(separator: ",")
            lines.append(D2RecoveryMarker.emitBlockArrowDir(
                nodeID: node.id,
                directionsCsv: csv
            ))
        }
    }

    // MARK: - Edge emission

    private static func emit(
        edge: BlockEdge,
        index: Int,
        into lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let label = edge.label ?? ""
        if !label.isEmpty {
            lines.append("\(edge.start) -> \(edge.end): \"\(escape(label))\"")
        } else {
            lines.append("\(edge.start) -> \(edge.end)")
        }
        // Always emit the attrs marker — guarantees round-trip
        // identity even when downstream tools rewrite native edge
        // attributes.
        lines.append(D2RecoveryMarker.emitBlockEdgeAttrs(
            edgeIndex: index,
            thickness: edge.thickness,
            pattern: edge.pattern,
            arrowStart: edge.arrowTypeStart,
            arrowEnd: edge.arrowTypeEnd
        ))
    }

    // MARK: - Shape mapping

    private static func d2Shape(for type: BlockNodeType) -> (name: String, lossy: Bool) {
        switch type {
        case .square, .na:        return ("rectangle", false)
        case .round:               return ("oval", false)
        case .circle:              return ("circle", false)
        case .doublecircle:        return ("circle", true)
        case .diamond:             return ("diamond", false)
        case .hexagon:             return ("hexagon", false)
        case .stadium:             return ("stadium", false)
        case .subroutine:          return ("package", true)
        case .cylinder:            return ("cylinder", false)
        case .leanRight:           return ("parallelogram", true)
        case .leanLeft:            return ("parallelogram", true)
        case .trapezoid, .invTrapezoid, .rectLeftInvArrow, .blockArrow:
            return ("rectangle", true)
        case .space, .composite, .classDef, .applyClass, .applyStyles,
             .columnSetting, .edge:
            return ("rectangle", false)
        }
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

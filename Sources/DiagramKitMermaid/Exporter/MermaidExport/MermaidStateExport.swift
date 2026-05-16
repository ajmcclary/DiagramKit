import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `stateDiagram-v2` source from a `ParsedGraphModel`
/// (the `DiagramPayload.stateDiagram` payload).
///
/// Pseudostate ids (whose `NodeShape` is `.stateStart` or `.stateEnd`)
/// are rewritten back into `[*]` at edge endpoints — matching the
/// convention `PlantUMLStateExport` uses, and avoiding the suffix-based
/// rewrite that would corrupt user-authored ids like `customer_start`.
/// Note nodes (`.stateNote`) and their dotted attachment edges are
/// re-emitted as `note left/right of <target> : <text>` rather than as
/// raw nodes.
///
/// Concurrency dividers (`--`) inside a composite collapse the
/// composite's region children into a single flattened body and emit a
/// `.subgraphFlatten` diagnostic. `classDef` / `class` / `style` /
/// `click` declarations and `accTitle` / `accDescr` are deferred from
/// v1 and surface as `.styleDrop` / `.accessibilityDrop` diagnostics.
enum MermaidStateExport {

    static func emit(_ model: ParsedGraphModel) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []
        var usedAliases: Set<String> = []
        var aliasMap: [String: String] = [:]

        lines.append("stateDiagram-v2")

        // 1. Classify nodes by role.
        var pseudostateIDs: Set<String> = []
        var noteIDs: Set<String> = []
        for (id, node) in model.nodesInOrder {
            switch node.shape {
            case .stateStart, .stateEnd: pseudostateIDs.insert(id)
            case .stateNote: noteIDs.insert(id)
            default: break
            }
        }

        // 2. Map each note node to its (target, position) via the
        // dotted attachment edges the parser emitted in `_addStateNote`:
        //   posEnum == .right → targetId → noteId
        //   posEnum == .left  → noteId   → targetId
        var noteAttachments: [String: (target: String, position: String)] = [:]
        for edge in model.edges where edge.style == .dotted {
            if noteIDs.contains(edge.source), !noteIDs.contains(edge.target) {
                noteAttachments[edge.source] = (target: edge.target, position: "left")
            } else if noteIDs.contains(edge.target), !noteIDs.contains(edge.source) {
                noteAttachments[edge.target] = (target: edge.source, position: "right")
            }
        }

        // 3. Build ownership map so composite-owned ids aren't emitted
        // at top level.
        var ownedBy: [String: String] = [:]
        for subgraph in model.subgraphs {
            collectOwnership(subgraph, ownerID: subgraph.id, into: &ownedBy)
        }
        let compositeIDs = Set(allSubgraphIDs(in: model.subgraphs))

        // 4. Sanitize every non-pseudostate, non-note id up front so
        // edge rewriting at step 7 has a consistent alias map even for
        // composite-owned ids.
        for (id, _) in model.nodesInOrder where !pseudostateIDs.contains(id) && !noteIDs.contains(id) {
            let (sanitized, idDiags) = MermaidExportHelpers.sanitizeIdentifier(id, usedAliases: &usedAliases)
            diagnostics.append(contentsOf: idDiags)
            aliasMap[id] = sanitized
        }
        for sub in model.subgraphs {
            sanitizeSubgraphIDs(sub, usedAliases: &usedAliases, aliasMap: &aliasMap, diagnostics: &diagnostics)
        }

        // 5. Emit top-level states.
        for (id, node) in model.nodesInOrder {
            if pseudostateIDs.contains(id) { continue }
            if noteIDs.contains(id) { continue }
            if ownedBy[id] != nil { continue }
            if compositeIDs.contains(id) { continue }

            let sanitized = aliasMap[id] ?? id
            emitStateDecl(id: sanitized, node: node, indent: 2, into: &lines)
        }

        // 6. Emit composite states recursively.
        for subgraph in model.subgraphs {
            emitComposite(
                subgraph,
                indent: 2,
                model: model,
                pseudostateIDs: pseudostateIDs,
                noteIDs: noteIDs,
                noteAttachments: noteAttachments,
                aliasMap: aliasMap,
                lines: &lines,
                diagnostics: &diagnostics
            )
        }

        // 7. Emit top-level notes (composite-scoped notes are handled
        // inside emitComposite).
        for (id, node) in model.nodesInOrder where noteIDs.contains(id) {
            if ownedBy[id] != nil { continue }
            guard let attach = noteAttachments[id] else { continue }
            let target = aliasMap[attach.target] ?? attach.target
            let safeText = singleLine(node.label)
            lines.append("  note \(attach.position) of \(target) : \(safeText)")
        }

        // 8. Emit transitions, rewriting pseudostates back to `[*]` and
        // skipping the synthetic dotted note attachment edges.
        for edge in model.edges {
            if noteIDs.contains(edge.source) || noteIDs.contains(edge.target) { continue }
            let source = pseudostateIDs.contains(edge.source) ? "[*]" : (aliasMap[edge.source] ?? edge.source)
            let target = pseudostateIDs.contains(edge.target) ? "[*]" : (aliasMap[edge.target] ?? edge.target)
            if let label = edge.label, !label.isEmpty {
                lines.append("  \(source) --> \(target) : \(singleLine(label))")
            } else {
                lines.append("  \(source) --> \(target)")
            }
        }

        // 9. Drop-with-diagnostic for features deferred from v1.
        if !model.classDefs.isEmpty || !model.classAssignments.isEmpty
            || !model.nodeStyles.isEmpty || !model.nodeInteractions.isEmpty {
            diagnostics.append(.lossyTransform(
                .styleDrop,
                message: "Mermaid state export does not yet re-emit classDef / class / style / click declarations"
            ))
        }
        if model.accTitle != nil || model.accDescr != nil {
            diagnostics.append(.lossyTransform(
                .accessibilityDrop,
                message: "Mermaid state export does not yet re-emit accTitle / accDescr"
            ))
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // MARK: - State declaration

    private static func emitStateDecl(
        id sanitized: String,
        node: original_src_types.MermaidNode,
        indent: Int,
        into lines: inout [String]
    ) {
        let pad = String(repeating: " ", count: indent)
        switch node.shape {
        case .choice:
            lines.append("\(pad)state \(sanitized) <<choice>>")
        case .fork:
            lines.append("\(pad)state \(sanitized) <<fork>>")
        case .join:
            lines.append("\(pad)state \(sanitized) <<join>>")
        default:
            if !node.label.isEmpty, node.label != sanitized, node.label != node.id {
                lines.append("\(pad)state \"\(escapeQuoted(node.label))\" as \(sanitized)")
            } else if !node.label.isEmpty, node.label != node.id {
                lines.append("\(pad)state \"\(escapeQuoted(node.label))\" as \(sanitized)")
            } else {
                lines.append("\(pad)state \(sanitized)")
            }
        }
    }

    // MARK: - Composite emission

    private static func emitComposite(
        _ subgraph: original_src_types.MermaidSubgraph,
        indent: Int,
        model: ParsedGraphModel,
        pseudostateIDs: Set<String>,
        noteIDs: Set<String>,
        noteAttachments: [String: (target: String, position: String)],
        aliasMap: [String: String],
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let pad = String(repeating: " ", count: indent)
        let sanitizedId = aliasMap[subgraph.id] ?? subgraph.id

        if !subgraph.label.isEmpty, subgraph.label != subgraph.id {
            lines.append("\(pad)state \"\(escapeQuoted(subgraph.label))\" as \(sanitizedId) {")
        } else {
            lines.append("\(pad)state \(sanitizedId) {")
        }

        // Detect concurrency-region children (`<parent>_region_<int>`)
        // and flatten them with a diagnostic. Regions can't be
        // re-emitted today because we don't emit `--` dividers.
        let regionPrefix = "\(subgraph.id)_region_"
        let hasRegions = subgraph.children.contains { child in
            child.id.hasPrefix(regionPrefix) && Int(child.id.dropFirst(regionPrefix.count)) != nil
        }
        if hasRegions {
            diagnostics.append(.lossyTransform(
                .subgraphFlatten,
                message: "Mermaid state export flattens concurrency regions in composite '\(subgraph.id)' (-- divider not yet re-emitted)"
            ))
        }

        // Collect every child node id (own + flattened regions).
        var flattenedChildNodeIds = subgraph.nodeIds
        for child in subgraph.children where child.id.hasPrefix(regionPrefix) {
            flattenedChildNodeIds.append(contentsOf: child.nodeIds)
        }

        // Emit owned non-pseudostate, non-note states.
        for childId in flattenedChildNodeIds {
            if pseudostateIDs.contains(childId) { continue }
            if noteIDs.contains(childId) { continue }
            guard let entry = model.nodesInOrder.first(where: { $0.id == childId }) else { continue }
            let sanitized = aliasMap[childId] ?? childId
            emitStateDecl(id: sanitized, node: entry.node, indent: indent + 2, into: &lines)
        }

        // Emit nested non-region composite children.
        for child in subgraph.children where !child.id.hasPrefix(regionPrefix) {
            emitComposite(
                child,
                indent: indent + 2,
                model: model,
                pseudostateIDs: pseudostateIDs,
                noteIDs: noteIDs,
                noteAttachments: noteAttachments,
                aliasMap: aliasMap,
                lines: &lines,
                diagnostics: &diagnostics
            )
        }

        // Emit composite-scoped notes.
        let innerPad = String(repeating: " ", count: indent + 2)
        for childId in flattenedChildNodeIds where noteIDs.contains(childId) {
            guard let entry = model.nodesInOrder.first(where: { $0.id == childId }),
                  let attach = noteAttachments[childId] else { continue }
            let target = aliasMap[attach.target] ?? attach.target
            lines.append("\(innerPad)note \(attach.position) of \(target) : \(singleLine(entry.node.label))")
        }

        lines.append("\(pad)}")
    }

    // MARK: - Ownership helpers

    private static func collectOwnership(
        _ subgraph: original_src_types.MermaidSubgraph,
        ownerID: String,
        into map: inout [String: String]
    ) {
        for nodeId in subgraph.nodeIds {
            map[nodeId] = ownerID
        }
        for child in subgraph.children {
            // Concurrency regions transfer ownership of their member
            // ids up to the composite parent so we don't try to emit
            // those ids twice when flattening.
            let regionPrefix = "\(ownerID)_region_"
            if child.id.hasPrefix(regionPrefix) {
                for nodeId in child.nodeIds {
                    map[nodeId] = ownerID
                }
            } else {
                collectOwnership(child, ownerID: child.id, into: &map)
            }
        }
    }

    private static func allSubgraphIDs(in subgraphs: [original_src_types.MermaidSubgraph]) -> [String] {
        var ids: [String] = []
        for subgraph in subgraphs {
            ids.append(subgraph.id)
            ids.append(contentsOf: allSubgraphIDs(in: subgraph.children))
        }
        return ids
    }

    private static func sanitizeSubgraphIDs(
        _ subgraph: original_src_types.MermaidSubgraph,
        usedAliases: inout Set<String>,
        aliasMap: inout [String: String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        if aliasMap[subgraph.id] == nil {
            let (sanitized, idDiags) = MermaidExportHelpers.sanitizeIdentifier(subgraph.id, usedAliases: &usedAliases)
            diagnostics.append(contentsOf: idDiags)
            aliasMap[subgraph.id] = sanitized
        }
        for child in subgraph.children {
            sanitizeSubgraphIDs(child, usedAliases: &usedAliases, aliasMap: &aliasMap, diagnostics: &diagnostics)
        }
    }

    // MARK: - String helpers

    /// Mermaid quoted-label escape: `"` → `\"`, `\` → `\\`.
    private static func escapeQuoted(_ text: String) -> String {
        var out = ""
        for ch in singleLine(text) {
            switch ch {
            case "\"": out.append("\\\"")
            case "\\": out.append("\\\\")
            default: out.append(ch)
            }
        }
        return out
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

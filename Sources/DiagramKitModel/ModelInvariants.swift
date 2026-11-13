import Foundation
import DiagramKitCommon

// Structural invariants every layout, renderer and exporter relies on —
// unique ids and acyclic containment — are checked by the Mermaid parsers
// (`duplicateId`, `selfParenting`, the block database walk) but not by the
// D2 / DOT / PlantUML / Structurizr mappers, which build the same models.
// A duplicated D2 block or DOT boundary then made a containment cycle that
// every recursive pass (layout, SVG, ASCII, each exporter) followed until
// the stack overflowed. `DiagramLoader` runs this on every import result so
// all of those passes can trust the model, whichever importer built it.

/// The document with containment cycles in block, C4 and architecture
/// models broken and repeated container ids reduced to their first
/// declaration, plus a diagnostic for each kind of repair. A model that
/// already satisfies the invariants (every Mermaid-parsed one) comes back
/// unchanged.
public func _enforceModelInvariants(_ document: DiagramDocument) -> (DiagramDocument, [DiagramDiagnostic]) {
    var document = document
    var diagnostics: [DiagramDiagnostic] = []
    switch document.payload {
    case .block(var model):
        if _breakBlockCycles(&model) {
            document.payload = .block(model)
            diagnostics.append(.lossyTransform(
                .subgraphFlatten,
                message: "[Block] a block was listed inside itself or more than once; extra placements were dropped"
            ))
        }
    case .c4(var model):
        if _breakC4BoundaryCycles(&model) {
            document.payload = .c4(model)
            diagnostics.append(.lossyTransform(
                .boundaryFlatten,
                message: "[C4] a boundary was declared twice or nested in itself; the repeat was dropped or moved to the top level"
            ))
        }
    case .architecture(var model):
        if _breakArchitectureGroupCycles(&model) {
            document.payload = .architecture(model)
            diagnostics.append(.lossyTransform(
                .subgraphFlatten,
                message: "[Architecture] a group was declared twice or nested in itself; the repeat was dropped or moved to the top level"
            ))
        }
    default:
        break
    }
    return (document, diagnostics)
}

/// Each block is placed once, under its first parent, and never inside
/// itself. Returns whether anything changed.
private func _breakBlockCycles(_ model: inout BlockDiagram) -> Bool {
    var changed = false
    var placed: Set<String> = [model.rootId]
    var database = model.blockDatabase

    func admit(_ ids: [String]) -> [String] {
        var kept: [String] = []
        for id in ids {
            guard database[id] != nil, !placed.contains(id) else {
                changed = true
                continue
            }
            placed.insert(id)
            kept.append(id)
        }
        return kept
    }

    // Breadth-first from the root, so every block keeps its shallowest
    // placement. `rootChildren` (read by the ASCII renderer) is kept in
    // step with the root block's `children` (read by the layout).
    var queue: [String] = []
    if var root = database[model.rootId] {
        let kept = admit(root.children)
        if kept != root.children {
            root.children = kept
            database[model.rootId] = root
        }
        queue = kept
    }
    let rootKept = Set(queue)
    var rootChildren: [String] = []
    for id in model.rootChildren {
        if rootKept.contains(id) {
            if rootChildren.contains(id) { changed = true } else { rootChildren.append(id) }
        } else {
            let kept = admit([id])
            rootChildren += kept
            queue += kept
        }
    }
    if rootChildren != model.rootChildren {
        model.rootChildren = rootChildren
        changed = true
    }
    var head = 0
    while head < queue.count {
        let id = queue[head]
        head += 1
        guard var block = database[id] else { continue }
        let kept = admit(block.children)
        if kept != block.children {
            block.children = kept
            database[id] = block
        }
        queue.append(contentsOf: kept)
    }
    if changed { model.blockDatabase = database }
    return changed
}

/// One boundary per alias (the first declaration wins), and a boundary
/// whose parent chain loops is moved to the top level (`global`).
private func _breakC4BoundaryCycles(_ model: inout C4Diagram) -> Bool {
    var changed = false
    var seen: Set<String> = []
    var boundaries: [C4Boundary] = []
    for boundary in model.boundaries {
        if seen.insert(boundary.alias).inserted {
            boundaries.append(boundary)
        } else {
            changed = true
        }
    }
    let parentOf = Dictionary(boundaries.map { ($0.alias, $0.parentBoundary) }, uniquingKeysWith: { first, _ in first })
    for index in boundaries.indices where boundaries[index].alias != "global" {
        var visited: Set<String> = [boundaries[index].alias]
        var cursor = boundaries[index].parentBoundary
        while cursor != "global", !cursor.isEmpty, let next = parentOf[cursor] {
            if !visited.insert(cursor).inserted {
                boundaries[index].parentBoundary = "global"
                changed = true
                break
            }
            cursor = next
        }
        if boundaries[index].parentBoundary == boundaries[index].alias {
            boundaries[index].parentBoundary = "global"
            changed = true
        }
    }
    if changed { model.boundaries = boundaries }
    return changed
}

/// One group per id (the first declaration wins), and a group whose parent
/// chain loops is moved to the top level.
private func _breakArchitectureGroupCycles(_ model: inout ArchitectureDiagram) -> Bool {
    var changed = false
    var seen: Set<String> = []
    var groups: [ArchitectureGroup] = []
    for group in model.groups {
        if seen.insert(group.id).inserted {
            groups.append(group)
        } else {
            changed = true
        }
    }
    let parentOf = Dictionary(groups.map { ($0.id, $0.parentGroupId) }, uniquingKeysWith: { first, _ in first })
    for index in groups.indices {
        var visited: Set<String> = [groups[index].id]
        var cursor = groups[index].parentGroupId
        while let current = cursor {
            if !visited.insert(current).inserted {
                groups[index].parentGroupId = nil
                changed = true
                break
            }
            cursor = parentOf[current] ?? nil
        }
    }
    if changed { model.groups = groups }
    return changed
}

/// Throws `DiagramInputLimitError(.nestingDepth)` when a treemap or a C4 /
/// architecture boundary hierarchy nests deeper than
/// `_maxParserNestingDepth`. Their parsers accept any depth, but the SVG
/// render of a 1,000-level treemap or C4 diagram overflowed the worker
/// stack. Checked once for every importer, iteratively.
public func _checkModelNestingDepth(_ document: DiagramDocument) throws {
    switch document.payload {
    case .treemap(let model):
        var stack: [(nodes: [TreemapNode], depth: Int)] = [(model.nodes, 1)]
        while let (nodes, depth) = stack.popLast() {
            for node in nodes {
                guard let children = node.children, !children.isEmpty else { continue }
                try _checkParserNestingDepth(depth + 1, "treemap sections")
                stack.append((children, depth + 1))
            }
        }
    case .c4(let model):
        let parentOf = Dictionary(model.boundaries.map { ($0.alias, $0.parentBoundary) }, uniquingKeysWith: { first, _ in first })
        for boundary in model.boundaries {
            var depth = 1
            var cursor = boundary.parentBoundary
            var seen: Set<String> = [boundary.alias]
            while cursor != "global", let next = parentOf[cursor], seen.insert(cursor).inserted {
                depth += 1
                try _checkParserNestingDepth(depth, "C4 boundaries")
                cursor = next
            }
        }
    case .architecture(let model):
        let parentOf = Dictionary(model.groups.map { ($0.id, $0.parentGroupId) }, uniquingKeysWith: { first, _ in first })
        for group in model.groups {
            var depth = 1
            var cursor = group.parentGroupId
            var seen: Set<String> = [group.id]
            while let current = cursor, seen.insert(current).inserted {
                depth += 1
                try _checkParserNestingDepth(depth, "architecture groups")
                cursor = parentOf[current] ?? nil
            }
        }
    default:
        break
    }
}

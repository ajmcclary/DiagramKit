// Phase 8: Interactivity Primitives — Slice 8A
// PositionedGraph extension — dispatches lookup construction to family builders.

import DiagramKitCommon

extension PositionedGraph {

    /// A spatial index over all bounded elements in this positioned graph.
    /// Built eagerly; element counts are small enough that construction
    /// cost is negligible.
    public var lookup: DiagramBoundsLookup {
        switch content {
        case .flowchart(let nodes, let edges, let groups):
            return _flowchartLookup(diagramType: .flowchart, nodes: nodes, edges: edges, groups: groups)
        case .stateDiagram(let nodes, let edges, let groups):
            return _flowchartLookup(diagramType: .stateDiagram, nodes: nodes, edges: edges, groups: groups)
        case .sequenceDiagram(let actors, let messages, let blocks,
                              let lifelines, let activations, let notes,
                              let boxes, let bottomActors, let rectHighlights,
                              _, _, _):
            return _sequenceLookup(
                actors: actors, messages: messages,
                blocks: blocks, lifelines: lifelines,
                activations: activations, notes: notes,
                boxes: boxes, bottomActors: bottomActors,
                rectHighlights: rectHighlights
            )
        case .classDiagram(let classes, let relationships, let namespaces,
                           let notes, _, _, _):
            return _classLookup(
                classes: classes, relationships: relationships,
                namespaces: namespaces, notes: notes
            )
        case .erDiagram(let entities, let relationships, _, _, _, _):
            return _erLookup(entities: entities, relationships: relationships)
        case .c4(let c4):
            return _c4Lookup(c4)
        // Long-tail families (Slice 8G)
        case .xyChart(let chart):
            return _xyChartLookup(chart)
        case .pie(let pie):
            return _pieLookup(pie)
        case .journey(let journey):
            return _journeyLookup(journey)
        case .gantt(let gantt):
            return _ganttLookup(gantt)
        case .quadrantChart(let quadrant):
            return _quadrantChartLookup(quadrant)
        case .requirement(let req):
            return _requirementLookup(req)
        case .gitGraph(let git):
            return _gitGraphLookup(git)
        case .mindmap(let mindmap):
            return _mindmapLookup(mindmap)
        case .timeline(let timeline):
            return _timelineLookup(timeline)
        case .sankey(let sankey):
            return _sankeyLookup(sankey)
        case .block(let block):
            return _blockLookup(block)
        case .packet(let packet):
            return _packetLookup(packet)
        case .kanban(let kanban):
            return _kanbanLookup(kanban)
        case .architecture(let arch):
            return _architectureLookup(arch)
        case .radar(let radar):
            return _radarLookup(radar)
        case .treemap(let treemap):
            return _treemapLookup(treemap)
        case .venn(let venn):
            return _vennLookup(venn)
        case .ishikawa(let ishikawa):
            return _ishikawaLookup(ishikawa)
        case .treeView(let treeView):
            return _treeViewLookup(treeView)
        case .eventModeling(let eventModeling):
            return _eventModelingLookup(eventModeling)
        case .wardleyBeta(let wardley):
            return _wardleyBetaLookup(wardley)
        case .zenuml(let zenuml):
            return _zenumlLookup(zenuml)
        }
    }
}

// MARK: - Internal helper: ID override wrapper

/// Wraps any `DiagramStableElement`, overriding its `stableElementID`.
/// Used for source-order duplicate disambiguation; no layout geometry
/// is included in the override.
struct _DiagramStableIDOverride<T: DiagramStableElement>: DiagramStableElement {
    let wrapped: T
    let overrideID: String
    var stableElementID: String { overrideID }
    var stableElementBounds: DiagramRect { wrapped.stableElementBounds }
    var stableElementLabel: String? { wrapped.stableElementLabel }
}

// MARK: - Internal helper: duplicate disambiguation

/// Disambiguates duplicate `stableElementID` values by appending a
/// source-order suffix `/1`, `/2`, etc. to second and subsequent
/// occurrences.
func _disambiguateIDs<T: DiagramStableElement>(
    _ items: [T],
    kind: DiagramBoundsLookup.ElementKind,
    into target: inout [(any DiagramStableElement, kind: DiagramBoundsLookup.ElementKind)]
) {
    var counts: [String: Int] = [:]
    for item in items {
        let base = item.stableElementID
        let n = counts[base, default: 0]
        counts[base] = n + 1
        if n > 0 {
            target.append((
                _DiagramStableIDOverride(wrapped: item, overrideID: "\(base)/\(n)"),
                kind
            ))
        } else {
            target.append((item, kind))
        }
    }
}

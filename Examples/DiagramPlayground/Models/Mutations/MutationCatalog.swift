//
//  MutationCatalog.swift
//  DiagramPlayground
//
//  Phase 10 / Task 10.2 — typed catalog of every mutation surfaced
//  in the design's MutationsCatalogCard. groupIntoSubgraph is no
//  longer fictional (Phase 5 landed it); flagged via `wasFiction`
//  for parity with the JSX comment.
//

import Foundation

public struct MutationCatalogEntry: Identifiable, Sendable, Hashable {
    public enum Group: String, Sendable, CaseIterable, Hashable {
        case document
        case node
        case edge
        case subgraph
        case sentinel

        public var label: String {
            switch self {
            case .document: return "Document"
            case .node:     return "Node"
            case .edge:     return "Edge"
            case .subgraph: return "Subgraph"
            case .sentinel: return "Sentinel"
            }
        }
    }

    public let id: String
    public let group: Group
    public let label: String
    public let rationale: String
    /// Visual stage the demo button bounces to.
    public let demoStage: VisualEditorState.Stage
    /// Was a design-fiction case at plan time. Phase 5 landed
    /// `groupIntoSubgraph`; left here so the card can flag the
    /// transition.
    public let wasFiction: Bool

    public init(
        id: String,
        group: Group,
        label: String,
        rationale: String,
        demoStage: VisualEditorState.Stage,
        wasFiction: Bool = false
    ) {
        self.id = id
        self.group = group
        self.label = label
        self.rationale = rationale
        self.demoStage = demoStage
        self.wasFiction = wasFiction
    }
}

public enum MutationCatalog {
    public static let all: [MutationCatalogEntry] = [
        MutationCatalogEntry(
            id: "setTitle",
            group: .document,
            label: "setTitle(_:)",
            rationale: "Replace the diagram title; round-trip stable.",
            demoStage: .nodeSelected
        ),
        MutationCatalogEntry(
            id: "noop",
            group: .document,
            label: ".noop",
            rationale: "Sentinel mutation — registers a no-op undo entry for testing.",
            demoStage: .idle
        ),
        MutationCatalogEntry(
            id: "insertNode",
            group: .node,
            label: "FlowchartMutation.insertNode(id:label:type:)",
            rationale: "Append a new node with a typed shape.",
            demoStage: .labelEdited
        ),
        MutationCatalogEntry(
            id: "setLabel",
            group: .node,
            label: ".setLabel(of:to:)",
            rationale: "Rewrite the label of any selectable element.",
            demoStage: .labelEdited
        ),
        MutationCatalogEntry(
            id: "deleteElement",
            group: .node,
            label: ".deleteElement(_:)",
            rationale: "Remove a node or edge from the document.",
            demoStage: .nodeSelected
        ),
        MutationCatalogEntry(
            id: "insertEdge",
            group: .edge,
            label: "FlowchartMutation.insertEdge(id:from:to:label:)",
            rationale: "Connect two existing flowchart nodes.",
            demoStage: .edgeDrag
        ),
        MutationCatalogEntry(
            id: "groupIntoSubgraph",
            group: .subgraph,
            label: "FlowchartMutation.groupIntoSubgraph(selections:title:)",
            rationale: "Wrap the marquee selection in a fresh subgraph block. Landed in Phase 5.",
            demoStage: .subgraphCommitted,
            wasFiction: true
        ),
        MutationCatalogEntry(
            id: "resizeTask",
            group: .node,
            label: "GanttMutation.resizeTask(taskId:newEndTime:)",
            rationale: "Commit a Gantt bar drag as a new task end date — round-trips through MermaidExporter's gantt arm.",
            demoStage: .edgeDrag
        ),
        MutationCatalogEntry(
            id: "performMutation",
            group: .sentinel,
            label: "DiagramEditor.perform(_:)",
            rationale: "Generic envelope all DiagramMutation cases route through.",
            demoStage: .idle
        )
    ]
}

//
//  CanvasContextMenu.swift
//  DiagramPlayground
//
//  Right-click menu for the flowchart canvas (visual editor plan 3).
//  The canvas resolves the element under the cursor at menu-open time
//  (via continuous hover tracking) and passes it here.
//

import SwiftUI
import DiagramKitModel
import DiagramKitInteractive

struct CanvasContextMenu: View {
    @Bindable var store: LiveEditorStore
    let element: DiagramSelection?

    var body: some View {
        if !store.state.marqueeSelection.isEmpty {
            multiSelectionMenu
        } else if let element {
            if element.elementID.hasPrefix("node:") {
                nodeMenu(element)
            } else if element.elementID.hasPrefix("edge:") {
                edgeMenu(element)
            } else if element.elementID.hasPrefix("group:") {
                groupMenu(element)
            } else {
                emptyCanvasMenu
            }
        } else {
            emptyCanvasMenu
        }
    }

    // MARK: - Node

    @ViewBuilder
    private func nodeMenu(_ element: DiagramSelection) -> some View {
        let nodeID = String(element.elementID.dropFirst(5))
        Button("Edit…") {
            store.editor?.selection = element
            store.setVisualStage(.labelEdited)
        }
        Menu("Change shape") {
            ForEach(ShapeCatalogCategory.allCases) { category in
                Section(category.title) {
                    ForEach(category.items) { item in
                        Button(item.name) {
                            Task {
                                try? await store.performFlowchartMutation(
                                    .setNodeShape(of: element, toShape: item.alias)
                                )
                            }
                        }
                    }
                }
            }
        }
        Menu("Move to subgraph") {
            if store.subgraphID(containing: nodeID) != nil {
                Button("Root (no subgraph)") {
                    move(element, to: nil)
                }
            }
            ForEach(store.flowchartSubgraphs, id: \.id) { sub in
                if sub.id != store.subgraphID(containing: nodeID) {
                    Button(sub.label) {
                        move(element, to: sub.id)
                    }
                }
            }
        }
        Divider()
        deleteButton(element, label: "Delete")
    }

    private func move(_ element: DiagramSelection, to target: String?) {
        Task {
            try? await store.performFlowchartMutation(
                .moveToSubgraph(selections: [element], target: target)
            )
        }
    }

    // MARK: - Edge

    @ViewBuilder
    private func edgeMenu(_ element: DiagramSelection) -> some View {
        Button("Edit…") {
            store.editor?.selection = element
            store.setVisualStage(.labelEdited)
        }
        Divider()
        deleteButton(element, label: "Delete")
    }

    // MARK: - Group

    @ViewBuilder
    private func groupMenu(_ element: DiagramSelection) -> some View {
        let groupID = String(element.elementID.dropFirst(6))
        Button("Rename…") {
            store.openRenamePrompt(subgraphID: groupID)
        }
        Button("Ungroup") {
            Task {
                try? await store.performFlowchartMutation(.ungroupSubgraph(id: groupID))
            }
        }
        Divider()
        deleteButton(element, label: "Delete Subgraph")
    }

    // MARK: - Multi-selection

    @ViewBuilder
    private var multiSelectionMenu: some View {
        Button("Group into subgraph…") {
            store.openSubgraphPrompt()
        }
        Divider()
        Button("Delete \(store.state.marqueeSelection.count) elements", role: .destructive) {
            Task { await store.deleteMarqueeSelection() }
        }
    }

    // MARK: - Empty canvas

    @ViewBuilder
    private var emptyCanvasMenu: some View {
        Menu("Add shape") {
            ForEach(ShapeCatalogCategory.allCases) { category in
                Section(category.title) {
                    ForEach(category.items) { item in
                        Button(item.name) {
                            Task { await store.insertShapeFromCatalog(alias: item.alias) }
                        }
                    }
                }
            }
        }
        Button("Add subgraph") {
            store.openEmptySubgraphPrompt()
        }
    }

    // MARK: - Shared

    private func deleteButton(_ element: DiagramSelection, label: String) -> some View {
        Button(label, role: .destructive) {
            Task { try? await store.performMutation(.deleteElement(element)) }
        }
    }
}

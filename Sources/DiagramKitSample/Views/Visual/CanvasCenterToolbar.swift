//
//  CanvasCenterToolbar.swift
//  DiagramPlayground
//
//  Floating bottom-center toolbar for the visual canvas. Plan 2
//  ships the Shapes catalog button; Subgraph / Icon / Image /
//  Rearrange / Theme buttons land with visual-editor plans 3–6.
//

import SwiftUI

struct CanvasCenterToolbar: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var showShapeCatalog = false

    var body: some View {
        HStack(spacing: 4) {
            Button {
                showShapeCatalog.toggle()
            } label: {
                Label("Shapes", systemImage: "square.on.circle")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Browse and add shapes")
            .accessibilityIdentifier(A11yID.Visual.shapesButton)
            .popover(isPresented: $showShapeCatalog, arrowEdge: .top) {
                ShapeCatalogView(theme: store.previewTheme) { alias in
                    showShapeCatalog = false
                    Task { await store.insertShapeFromCatalog(alias: alias) }
                }
            }

            Button {
                store.openEmptySubgraphPrompt()
            } label: {
                Label("Subgraph", systemImage: "rectangle.3.group")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Add a labeled group to the canvas")
            .accessibilityIdentifier(A11yID.Visual.subgraphButton)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.centerToolbar)
    }
}

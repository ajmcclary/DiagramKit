//
//  InspectorView.swift
//  DiagramPlayground
//
//  Phase 1 / Task 1.5 — five-section accordion on the right edge of
//  the v2 PlaygroundShell. Replaces the bespoke DiagramEditorPane
//  drawer for the Code workspace mode; the drawer keeps being used
//  by the existing inspector toggle in iPad compact layouts.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct InspectorView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InspectorDocumentSection(store: store)
                InspectorRenderBackendSection(store: store)
                InspectorThemeSection(store: store)
                ThemeBuilderCard(store: store)
                MutationsCatalogCard(store: store)
                PlatformRow(store: store)
                InspectorDiagnosticsSection(store: store)
                InspectorHistorySection(store: store)
                InspectorCitationsToggle(store: store)
            }
            .padding(16)
        }
        .frame(width: 320)
        .background(.regularMaterial)
    }
}

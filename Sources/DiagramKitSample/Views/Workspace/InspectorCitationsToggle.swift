//
//  InspectorCitationsToggle.swift
//  DiagramPlayground
//
//  Toggle for the v2 per-screen citation overlay. Phase 1 persists
//  the flag; the overlay system is wired in Phase 10.
//

import SwiftUI
import DesignKitThemes

struct InspectorCitationsToggle: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        Toggle(isOn: $store.state.showCitations) {
            Text("Show citations")
                .dsFont(.caption)
        }
        .toggleStyle(.ds)
        .padding(Tokens.Spacing.sm)
        .background { DSSurface(role: .card) { Color.clear } }
        .a11yToggle(
            label: "Show citations",
            isOn: store.state.showCitations,
            id: A11yID.Inspector.citationsToggle
        )
    }
}

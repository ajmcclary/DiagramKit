//
//  InspectorCitationsToggle.swift
//  DiagramPlayground
//
//  Toggle for the v2 per-screen citation overlay. Phase 1 persists
//  the flag; the overlay system is wired in Phase 10.
//

import SwiftUI

struct InspectorCitationsToggle: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        Toggle(isOn: $store.state.showCitations) {
            Label("Show citations", systemImage: "quote.bubble")
                .font(.system(size: 12, weight: .medium))
        }
        .toggleStyle(.switch)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.06))
        )
        .a11yToggle(
            label: "Show citations",
            isOn: store.state.showCitations,
            id: A11yID.Inspector.citationsToggle
        )
    }
}

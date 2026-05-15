//
//  ImporterProbeView.swift
//  DiagramPlayground
//
//  Phase 9 / Task 9.2 — placeholder; full body lands in Task 9.2.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct ImporterProbeView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        Color(store.theme.background)
            .accessibilityIdentifier("probe.view")
    }
}

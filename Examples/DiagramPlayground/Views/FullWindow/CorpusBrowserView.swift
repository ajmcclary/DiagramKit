//
//  CorpusBrowserView.swift
//  DiagramPlayground
//
//  Phase 8 / Task 8.5 — placeholder; full browser lands in Task 8.5.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct CorpusBrowserView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        Color(store.theme.background)
            .accessibilityIdentifier("corpus.browser.grid")
    }
}

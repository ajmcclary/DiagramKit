//
//  SnippetsLibraryView.swift
//  DiagramPlayground
//
//  Phase 9 / Task 9.3 — placeholder; full body lands in Task 9.3.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SnippetsLibraryView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        Color(store.theme.background)
            .accessibilityIdentifier("snippets.view")
    }
}

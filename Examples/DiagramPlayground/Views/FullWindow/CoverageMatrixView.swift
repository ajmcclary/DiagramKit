//
//  CoverageMatrixView.swift
//  DiagramPlayground
//
//  Phase 8 / Task 8.3 — placeholder; full grid lands in Task 8.3.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct CoverageMatrixView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        Color(store.theme.background)
            .accessibilityIdentifier("coverage.matrix.grid")
    }
}

//
//  GanttEditCanvas.swift
//  DiagramPlayground
//
//  Phase 4 / Task 4.2 — placeholder; the full canvas lands in Task 4.2.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct GanttEditCanvas: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        Color(store.previewTheme.background)
            .accessibilityIdentifier(A11yID.Visual.canvas)
    }
}

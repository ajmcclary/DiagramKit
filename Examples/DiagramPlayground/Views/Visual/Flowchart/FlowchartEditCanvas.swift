//
//  FlowchartEditCanvas.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.3 — flowchart edit canvas. Phase 3.2 lands a
//  DiagramView-backed scaffold so VisualPane compiles; Task 3.3
//  swaps the body for a custom Canvas with selection rings, handles,
//  and double-click → labelEdited transitions.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct FlowchartEditCanvas: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        ZStack {
            DiagramView(
                source: store.previewSource,
                theme: store.previewTheme,
                layoutConfig: store.previewLayoutConfig,
                sourceFormat: store.state.sourceFormat.formatID
            )
        }
        .accessibilityIdentifier(A11yID.Visual.canvas)
    }
}

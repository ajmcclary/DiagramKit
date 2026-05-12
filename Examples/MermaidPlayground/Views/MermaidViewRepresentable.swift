//
//  DiagramNativeViewRepresentable.swift
//  MermaidPlayground
//
//  SwiftUI wrapper for DiagramNativeView (cross-platform).
//  Publishes render completion status back to LiveEditorStore.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit

@MainActor
struct DiagramNativeViewRepresentable: UIViewRepresentable {
    let source: String
    let theme: DiagramTheme
    let layoutConfig: LayoutConfig
    let store: LiveEditorStore

    func makeUIView(context: Context) -> DiagramNativeView {
        let view = DiagramNativeView()
        bindPreparationUpdates(from: view)
        view.theme = theme
        view.source = source
        view.layoutConfig = layoutConfig
        return view
    }

    func updateUIView(_ view: DiagramNativeView, context: Context) {
        bindPreparationUpdates(from: view)

        // Update theme using bmColorEquals (not hexString round-trip)
        if !view.theme.background.bmColorEquals(theme.background) ||
           !view.theme.foreground.bmColorEquals(theme.foreground) {
            view.theme = theme
        }

        // Update source (triggers re-render in DiagramLayer)
        if view.source != source {
            view.source = source
        }

        // Update layout config
        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }
    }

    private func bindPreparationUpdates(from view: DiagramNativeView) {
        view.mermaidLayer.onPrepareComplete = { [weak view] in
            publishPreparationState(from: view)
        }
    }

    private func publishPreparationState(from view: DiagramNativeView?) {
        let store = store
        Task { @MainActor in
            guard let view else { return }
            store.didCompleteRender(
                parseError: view.parseError,
                diagramBounds: view.diagramBounds
            )
        }
    }
}

#elseif canImport(AppKit)
import AppKit

@MainActor
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct DiagramNativeViewRepresentable: NSViewRepresentable {
    let source: String
    let theme: DiagramTheme
    let layoutConfig: LayoutConfig
    let store: LiveEditorStore

    func makeNSView(context: Context) -> DiagramNativeView {
        let view = DiagramNativeView()
        bindPreparationUpdates(from: view)
        view.theme = theme
        view.source = source
        view.layoutConfig = layoutConfig
        return view
    }

    func updateNSView(_ view: DiagramNativeView, context: Context) {
        bindPreparationUpdates(from: view)

        // Update theme using bmColorEquals (not hexString round-trip)
        if !view.theme.background.bmColorEquals(theme.background) ||
           !view.theme.foreground.bmColorEquals(theme.foreground) {
            view.theme = theme
        }

        // Update source (triggers re-render in DiagramLayer)
        if view.source != source {
            view.source = source
        }

        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }
    }

    private func bindPreparationUpdates(from view: DiagramNativeView) {
        view.mermaidLayer.onPrepareComplete = { [weak view] in
            publishPreparationState(from: view)
        }
    }

    private func publishPreparationState(from view: DiagramNativeView?) {
        let store = store
        Task { @MainActor in
            guard let view else { return }
            store.didCompleteRender(
                parseError: view.parseError,
                diagramBounds: view.diagramBounds
            )
        }
    }
}

#endif
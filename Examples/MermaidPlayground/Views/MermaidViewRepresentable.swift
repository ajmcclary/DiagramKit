//
//  MermaidViewRepresentable.swift
//  MermaidPlayground
//
//  SwiftUI wrapper for MermaidView (cross-platform).
//  Publishes render completion status back to LiveEditorStore.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit

@MainActor
struct MermaidViewRepresentable: UIViewRepresentable {
    let source: String
    let theme: DiagramTheme
    let layoutConfig: LayoutConfig
    let store: LiveEditorStore

    func makeUIView(context: Context) -> MermaidView {
        let view = MermaidView()
        bindPreparationUpdates(from: view)
        view.theme = theme
        view.source = source
        view.layoutConfig = layoutConfig
        return view
    }

    func updateUIView(_ view: MermaidView, context: Context) {
        bindPreparationUpdates(from: view)

        // Update theme using bmColorEquals (not hexString round-trip)
        if !view.theme.background.bmColorEquals(theme.background) ||
           !view.theme.foreground.bmColorEquals(theme.foreground) {
            view.theme = theme
        }

        // Update source (triggers re-render in MermaidLayer)
        if view.source != source {
            view.source = source
        }

        // Update layout config
        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }
    }

    private func bindPreparationUpdates(from view: MermaidView) {
        view.mermaidLayer.onPrepareComplete = { [weak view] in
            publishPreparationState(from: view)
        }
    }

    private func publishPreparationState(from view: MermaidView?) {
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
struct MermaidViewRepresentable: NSViewRepresentable {
    let source: String
    let theme: DiagramTheme
    let layoutConfig: LayoutConfig
    let store: LiveEditorStore

    func makeNSView(context: Context) -> MermaidView {
        let view = MermaidView()
        bindPreparationUpdates(from: view)
        view.theme = theme
        view.source = source
        view.layoutConfig = layoutConfig
        return view
    }

    func updateNSView(_ view: MermaidView, context: Context) {
        bindPreparationUpdates(from: view)

        // Update theme using bmColorEquals (not hexString round-trip)
        if !view.theme.background.bmColorEquals(theme.background) ||
           !view.theme.foreground.bmColorEquals(theme.foreground) {
            view.theme = theme
        }

        // Update source (triggers re-render in MermaidLayer)
        if view.source != source {
            view.source = source
        }

        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }
    }

    private func bindPreparationUpdates(from view: MermaidView) {
        view.mermaidLayer.onPrepareComplete = { [weak view] in
            publishPreparationState(from: view)
        }
    }

    private func publishPreparationState(from view: MermaidView?) {
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
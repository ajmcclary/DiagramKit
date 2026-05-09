//
//  MermaidViewRepresentable.swift
//  MermaidPlayground
//
//  SwiftUI wrapper for MermaidView (cross-platform)
//

import SwiftUI
import BeautifulMermaid
import DiagramKitModel

#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit

@MainActor
struct MermaidViewRepresentable: UIViewRepresentable {
    let source: String
    let theme: DiagramTheme

    @Binding var parseError: Error?
    @Binding var diagramBounds: CGRect

    func makeUIView(context: Context) -> MermaidView {
        let view = MermaidView()
        bindPreparationUpdates(from: view)
        view.theme = theme
        view.source = source
        return view
    }

    func updateUIView(_ view: MermaidView, context: Context) {
        bindPreparationUpdates(from: view)

        // Update theme
        if view.theme.background.hexString != theme.background.hexString ||
           view.theme.foreground.hexString != theme.foreground.hexString {
            view.theme = theme
        }

        // Update source (triggers re-render)
        if view.source != source {
            view.source = source
        }

    }

    private func bindPreparationUpdates(from view: MermaidView) {
        view.mermaidLayer.onPrepareComplete = { [weak view] in
            publishPreparationState(from: view)
        }
    }

    private func publishPreparationState(from view: MermaidView?) {
        let parseError = $parseError
        let diagramBounds = $diagramBounds
        Task { @MainActor in
            guard let view else { return }
            parseError.wrappedValue = view.parseError
            diagramBounds.wrappedValue = view.diagramBounds
        }
    }
}

#elseif canImport(AppKit)
import AppKit

@MainActor
struct MermaidViewRepresentable: NSViewRepresentable {
    let source: String
    let theme: DiagramTheme

    @Binding var parseError: Error?
    @Binding var diagramBounds: CGRect

    func makeNSView(context: Context) -> MermaidView {
        let view = MermaidView()
        bindPreparationUpdates(from: view)
        view.theme = theme
        view.source = source
        return view
    }

    func updateNSView(_ view: MermaidView, context: Context) {
        bindPreparationUpdates(from: view)

        // Update theme
        if view.theme.background.hexString != theme.background.hexString ||
           view.theme.foreground.hexString != theme.foreground.hexString {
            view.theme = theme
        }

        // Update source (triggers re-render)
        if view.source != source {
            view.source = source
        }

    }

    private func bindPreparationUpdates(from view: MermaidView) {
        view.mermaidLayer.onPrepareComplete = { [weak view] in
            publishPreparationState(from: view)
        }
    }

    private func publishPreparationState(from view: MermaidView?) {
        let parseError = $parseError
        let diagramBounds = $diagramBounds
        Task { @MainActor in
            guard let view else { return }
            parseError.wrappedValue = view.parseError
            diagramBounds.wrappedValue = view.diagramBounds
        }
    }
}

#endif

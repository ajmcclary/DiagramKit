import SwiftUI
import DiagramKitCommon
import DiagramKitModel

#if canImport(UIKit)
import UIKit

/// A SwiftUI view that renders a Mermaid diagram.
@available(iOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
@MainActor
public struct MermaidDiagramView: UIViewRepresentable {
    private let source: String
    private let theme: DiagramTheme
    private let layoutConfig: LayoutConfig
    @Binding private var parseError: Error?
    @Binding private var diagramBounds: CGRect

    public init(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        parseError: Binding<Error?> = .constant(nil),
        diagramBounds: Binding<CGRect> = .constant(.zero)
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
        self._parseError = parseError
        self._diagramBounds = diagramBounds
    }

    public func makeUIView(context: Context) -> MermaidView {
        let view = MermaidView()
        bindPreparationUpdates(from: view)
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        return view
    }

    public func updateUIView(_ view: MermaidView, context: Context) {
        bindPreparationUpdates(from: view)

        if view.theme != theme {
            view.theme = theme
        }

        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }

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

/// A SwiftUI view that renders a Mermaid diagram.
@available(macOS 26.0, *)
@MainActor
public struct MermaidDiagramView: NSViewRepresentable {
    private let source: String
    private let theme: DiagramTheme
    private let layoutConfig: LayoutConfig
    @Binding private var parseError: Error?
    @Binding private var diagramBounds: CGRect

    public init(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        parseError: Binding<Error?> = .constant(nil),
        diagramBounds: Binding<CGRect> = .constant(.zero)
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
        self._parseError = parseError
        self._diagramBounds = diagramBounds
    }

    public func makeNSView(context: Context) -> MermaidView {
        let view = MermaidView()
        bindPreparationUpdates(from: view)
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        return view
    }

    public func updateNSView(_ view: MermaidView, context: Context) {
        bindPreparationUpdates(from: view)

        if view.theme != theme {
            view.theme = theme
        }

        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }

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

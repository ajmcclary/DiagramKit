// Apple-only SwiftUI/UIView wrappers gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import SwiftUI
import DiagramKitCommon
import DiagramKitModel
import DiagramKitRenderingCG

#if canImport(UIKit)
import UIKit

/// A SwiftUI view that renders a Mermaid diagram.
@available(iOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
@MainActor
public struct DiagramView: UIViewRepresentable {
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

    public func makeUIView(context: Context) -> DiagramNativeView {
        let view = DiagramNativeView()
        bindPreparationUpdates(from: view)
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        return view
    }

    public func updateUIView(_ view: DiagramNativeView, context: Context) {
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

    private func bindPreparationUpdates(from view: DiagramNativeView) {
        view.mermaidLayer.onPrepareComplete = { [weak view] in
            publishPreparationState(from: view)
        }
    }

    private func publishPreparationState(from view: DiagramNativeView?) {
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
public struct DiagramView: NSViewRepresentable {
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

    public func makeNSView(context: Context) -> DiagramNativeView {
        let view = DiagramNativeView()
        bindPreparationUpdates(from: view)
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        return view
    }

    public func updateNSView(_ view: DiagramNativeView, context: Context) {
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

    private func bindPreparationUpdates(from view: DiagramNativeView) {
        view.mermaidLayer.onPrepareComplete = { [weak view] in
            publishPreparationState(from: view)
        }
    }

    private func publishPreparationState(from view: DiagramNativeView?) {
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

// MARK: - Phase 0 backward-compat deprecated alias

@available(iOS 26.0, macCatalyst 26.0, visionOS 26.0, macOS 26.0, *)
@available(*, deprecated, renamed: "DiagramView")
public typealias MermaidDiagramView = DiagramView
#endif

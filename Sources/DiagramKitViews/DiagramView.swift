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

    public func makeCoordinator() -> Coordinator {
        Coordinator(parseError: $parseError, diagramBounds: $diagramBounds)
    }

    public func makeUIView(context: Context) -> DiagramNativeView {
        let view = DiagramNativeView()
        context.coordinator.attach(to: view)
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        return view
    }

    public func updateUIView(_ view: DiagramNativeView, context: Context) {
        context.coordinator.updateBindings(parseError: $parseError, diagramBounds: $diagramBounds)

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

    public final class Coordinator {
        fileprivate var parseError: Binding<Error?>
        fileprivate var diagramBounds: Binding<CGRect>
        fileprivate weak var view: DiagramNativeView?
        fileprivate var token: AnyObject?

        fileprivate init(parseError: Binding<Error?>, diagramBounds: Binding<CGRect>) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
        }

        @MainActor
        fileprivate func attach(to view: DiagramNativeView) {
            self.view = view
            self.token = view.mermaidLayer.addPrepareCompletionHandler { [weak self, weak view] in
                self?.publish(from: view)
            }
        }

        @MainActor
        fileprivate func updateBindings(parseError: Binding<Error?>, diagramBounds: Binding<CGRect>) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
        }

        @MainActor
        fileprivate func publish(from view: DiagramNativeView?) {
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

    public func makeCoordinator() -> Coordinator {
        Coordinator(parseError: $parseError, diagramBounds: $diagramBounds)
    }

    public func makeNSView(context: Context) -> DiagramNativeView {
        let view = DiagramNativeView()
        context.coordinator.attach(to: view)
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        return view
    }

    public func updateNSView(_ view: DiagramNativeView, context: Context) {
        context.coordinator.updateBindings(parseError: $parseError, diagramBounds: $diagramBounds)

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

    public final class Coordinator {
        fileprivate var parseError: Binding<Error?>
        fileprivate var diagramBounds: Binding<CGRect>
        fileprivate weak var view: DiagramNativeView?
        fileprivate var token: AnyObject?

        fileprivate init(parseError: Binding<Error?>, diagramBounds: Binding<CGRect>) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
        }

        @MainActor
        fileprivate func attach(to view: DiagramNativeView) {
            self.view = view
            self.token = view.mermaidLayer.addPrepareCompletionHandler { [weak self, weak view] in
                self?.publish(from: view)
            }
        }

        @MainActor
        fileprivate func updateBindings(parseError: Binding<Error?>, diagramBounds: Binding<CGRect>) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
        }

        @MainActor
        fileprivate func publish(from view: DiagramNativeView?) {
            guard let view else { return }
            parseError.wrappedValue = view.parseError
            diagramBounds.wrappedValue = view.diagramBounds
        }
    }
}

#endif

// MARK: - Phase 0 backward-compat deprecated alias

@available(iOS 26.0, macCatalyst 26.0, visionOS 26.0, macOS 26.0, *)
@available(*, deprecated, renamed: "DiagramView", message: "Will be removed in the next major version.")
public typealias MermaidDiagramView = DiagramView
#endif

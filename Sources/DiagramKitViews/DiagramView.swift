// Apple-only SwiftUI/UIView wrappers gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import SwiftUI
import DiagramKitCommon
import DiagramKitModel
import DiagramKitRenderingCG

#if canImport(UIKit)
import UIKit

/// A SwiftUI view that renders a diagram.
@available(iOS 26.0, *)
@MainActor
public struct DiagramView: UIViewRepresentable {
    private let source: String
    private let theme: DiagramTheme
    private let layoutConfig: LayoutConfig
    private let sourceFormat: DiagramFormatID?
    @Binding private var parseError: Error?
    @Binding private var diagramBounds: CGRect
    @Binding private var boundsLookup: DiagramBoundsLookup?

    public init(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        sourceFormat: DiagramFormatID? = nil,
        parseError: Binding<Error?> = .constant(nil),
        diagramBounds: Binding<CGRect> = .constant(.zero),
        boundsLookup: Binding<DiagramBoundsLookup?> = .constant(nil)
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
        self.sourceFormat = sourceFormat
        self._parseError = parseError
        self._diagramBounds = diagramBounds
        self._boundsLookup = boundsLookup
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            parseError: $parseError,
            diagramBounds: $diagramBounds,
            boundsLookup: $boundsLookup
        )
    }

    public func makeUIView(context: Context) -> DiagramNativeView {
        let view = DiagramNativeView()
        context.coordinator.attach(to: view)
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.sourceFormat = sourceFormat
        view.source = source
        return view
    }

    /// Takes the size SwiftUI proposes, so a `.frame` smaller than the
    /// diagram scales the drawing down instead of overflowing it. See
    /// ``DiagramViewSizing``.
    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: DiagramNativeView,
        context: Context
    ) -> CGSize? {
        DiagramViewSizing.size(for: proposal, naturalSize: uiView.diagramBounds.size)
    }

    public func updateUIView(_ view: DiagramNativeView, context: Context) {
        context.coordinator.updateBindings(
            parseError: $parseError,
            diagramBounds: $diagramBounds,
            boundsLookup: $boundsLookup
        )

        if view.theme != theme {
            view.theme = theme
        }

        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }

        if view.sourceFormat != sourceFormat {
            view.sourceFormat = sourceFormat
        }

        if view.source != source {
            view.source = source
        }
    }

    public final class Coordinator {
        fileprivate var parseError: Binding<Error?>
        fileprivate var diagramBounds: Binding<CGRect>
        fileprivate var boundsLookup: Binding<DiagramBoundsLookup?>
        fileprivate weak var view: DiagramNativeView?
        fileprivate var token: AnyObject?

        fileprivate init(
            parseError: Binding<Error?>,
            diagramBounds: Binding<CGRect>,
            boundsLookup: Binding<DiagramBoundsLookup?>
        ) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
            self.boundsLookup = boundsLookup
        }

        @MainActor
        fileprivate func attach(to view: DiagramNativeView) {
            self.view = view
            self.token = view.diagramLayer.addPrepareCompletionHandler { [weak self, weak view] in
                self?.publish(from: view)
            }
        }

        @MainActor
        fileprivate func updateBindings(
            parseError: Binding<Error?>,
            diagramBounds: Binding<CGRect>,
            boundsLookup: Binding<DiagramBoundsLookup?>
        ) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
            self.boundsLookup = boundsLookup
        }

        @MainActor
        fileprivate func publish(from view: DiagramNativeView?) {
            guard let view else { return }
            parseError.wrappedValue = view.parseError
            diagramBounds.wrappedValue = view.diagramBounds
            boundsLookup.wrappedValue = view.diagramLayer.preparedDiagram?.positioned.lookup
        }
    }
}

#elseif canImport(AppKit)
import AppKit

/// A SwiftUI view that renders a diagram.
@available(macOS 26.0, *)
@MainActor
public struct DiagramView: NSViewRepresentable {
    private let source: String
    private let theme: DiagramTheme
    private let layoutConfig: LayoutConfig
    private let sourceFormat: DiagramFormatID?
    @Binding private var parseError: Error?
    @Binding private var diagramBounds: CGRect
    @Binding private var boundsLookup: DiagramBoundsLookup?

    public init(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        sourceFormat: DiagramFormatID? = nil,
        parseError: Binding<Error?> = .constant(nil),
        diagramBounds: Binding<CGRect> = .constant(.zero),
        boundsLookup: Binding<DiagramBoundsLookup?> = .constant(nil)
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
        self.sourceFormat = sourceFormat
        self._parseError = parseError
        self._diagramBounds = diagramBounds
        self._boundsLookup = boundsLookup
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            parseError: $parseError,
            diagramBounds: $diagramBounds,
            boundsLookup: $boundsLookup
        )
    }

    public func makeNSView(context: Context) -> DiagramNativeView {
        let view = DiagramNativeView()
        context.coordinator.attach(to: view)
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.sourceFormat = sourceFormat
        view.source = source
        return view
    }

    /// Takes the size SwiftUI proposes, so a `.frame` smaller than the
    /// diagram scales the drawing down instead of overflowing it. See
    /// ``DiagramViewSizing``.
    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: DiagramNativeView,
        context: Context
    ) -> CGSize? {
        DiagramViewSizing.size(for: proposal, naturalSize: nsView.diagramBounds.size)
    }

    public func updateNSView(_ view: DiagramNativeView, context: Context) {
        context.coordinator.updateBindings(
            parseError: $parseError,
            diagramBounds: $diagramBounds,
            boundsLookup: $boundsLookup
        )

        if view.theme != theme {
            view.theme = theme
        }

        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }

        if view.sourceFormat != sourceFormat {
            view.sourceFormat = sourceFormat
        }

        if view.source != source {
            view.source = source
        }
    }

    public final class Coordinator {
        fileprivate var parseError: Binding<Error?>
        fileprivate var diagramBounds: Binding<CGRect>
        fileprivate var boundsLookup: Binding<DiagramBoundsLookup?>
        fileprivate weak var view: DiagramNativeView?
        fileprivate var token: AnyObject?

        fileprivate init(
            parseError: Binding<Error?>,
            diagramBounds: Binding<CGRect>,
            boundsLookup: Binding<DiagramBoundsLookup?>
        ) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
            self.boundsLookup = boundsLookup
        }

        @MainActor
        fileprivate func attach(to view: DiagramNativeView) {
            self.view = view
            self.token = view.diagramLayer.addPrepareCompletionHandler { [weak self, weak view] in
                self?.publish(from: view)
            }
        }

        @MainActor
        fileprivate func updateBindings(
            parseError: Binding<Error?>,
            diagramBounds: Binding<CGRect>,
            boundsLookup: Binding<DiagramBoundsLookup?>
        ) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
            self.boundsLookup = boundsLookup
        }

        @MainActor
        fileprivate func publish(from view: DiagramNativeView?) {
            guard let view else { return }
            parseError.wrappedValue = view.parseError
            diagramBounds.wrappedValue = view.diagramBounds
            boundsLookup.wrappedValue = view.diagramLayer.preparedDiagram?.positioned.lookup
        }
    }
}

#endif

// MARK: - Sizing

/// How `DiagramView` answers a SwiftUI size proposal.
///
/// The native view draws the diagram aspect-fitted to its own bounds, so the
/// view is as flexible as a resizable image: it takes whatever size it is
/// given, larger or smaller than the diagram. Without this, SwiftUI falls
/// back to the native view's `intrinsicContentSize` and default compression
/// resistance, which lets the view grow but never shrink — a frame below the
/// diagram's natural size left the drawing at 100%, overflowing the frame
/// from its centre.
///
/// - A proposed dimension is taken as is.
/// - An unspecified dimension (`nil`, as from `fixedSize()` or a scroll
///   view's scrolling axis) is the diagram's natural one, scaled down with
///   the other dimension when that one is proposed below natural size, so a
///   width-constrained diagram keeps its aspect ratio instead of
///   letterboxing.
enum DiagramViewSizing {
    static func size(for proposal: ProposedViewSize, naturalSize: CGSize) -> CGSize {
        let natural = CGSize(
            width: max(naturalSize.width, 0),
            height: max(naturalSize.height, 0)
        )
        switch (usable(proposal.width), usable(proposal.height)) {
        case let (width?, height?):
            return CGSize(width: width, height: height)
        case let (width?, nil):
            return CGSize(width: width, height: natural.height * shrink(width, natural.width))
        case let (nil, height?):
            return CGSize(width: natural.width * shrink(height, natural.height), height: height)
        case (nil, nil):
            return natural
        }
    }

    /// A proposed dimension the view can take: not NaN, never negative.
    private static func usable(_ dimension: CGFloat?) -> CGFloat? {
        guard let dimension, !dimension.isNaN else { return nil }
        return max(dimension, 0)
    }

    /// The factor (at most 1) that fits `natural` into `proposed`.
    private static func shrink(_ proposed: CGFloat, _ natural: CGFloat) -> CGFloat {
        guard natural > 0 else { return 1 }
        return min(proposed / natural, 1)
    }
}

// MARK: - Phase 0 backward-compat deprecated alias

@available(iOS 26.0, macOS 26.0, *)
@available(*, deprecated, renamed: "DiagramView", message: "Will be removed in the next major version.")
public typealias MermaidDiagramView = DiagramView
#endif

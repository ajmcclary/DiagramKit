// Apple-only SwiftUI/UIView wrappers gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import DiagramKitModel
import DiagramKitRenderingCG
import DiagramKitCommon
import CoreGraphics
@preconcurrency import QuartzCore

#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// PreparedDiagram moved to DiagramKitRenderingCG/PreparedDiagram.swift

/// A CALayer subclass that manages the Mermaid diagram rendering pipeline:
/// parse -> layout -> draw.
@MainActor
public class DiagramLayer: CALayer {

    // MARK: - Public Properties

    public var source: String = "" {
        didSet {
            if source != oldValue { prepareDiagram() }
        }
    }

    public var theme: DiagramTheme = .default {
        didSet { prepareDiagram() }
    }

    public var layoutConfig: LayoutConfig = LayoutConfig() {
        didSet { prepareDiagram() }
    }

    public private(set) var parseError: Error?
    public private(set) var diagramBounds: CGRect = .zero
    public private(set) var preparedDiagram: PreparedDiagram?
    private var preparationTask: Task<Void, Never>?

    /// Compatibility callback fired after a non-cancelled preparation completes.
    /// For multiple observers (e.g. host view + SwiftUI binding), prefer
    /// ``addPrepareCompletionHandler(_:)`` which supports fan-out.
    public var onPrepareComplete: (@MainActor () -> Void)?

    private struct CompletionHandlerEntry {
        let token: ObjectIdentifier
        let handler: @MainActor () -> Void
    }
    private var prepareHandlers: [CompletionHandlerEntry] = []
    private final class HandlerToken {}

    // MARK: - Initialization

    public override init() {
        super.init()
        commonInit()
    }

    public override init(layer: Any) {
        super.init(layer: layer)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        preparationTask?.cancel()
    }

    /// CALayer's overridden initializers are `nonisolated` (forced by the
    /// parent's signature), so `commonInit()` is too. The writes below land
    /// on CALayer-inherited properties, which `@preconcurrency QuartzCore`
    /// exposes as nonisolated. When the umbrella drops `@preconcurrency`,
    /// this method must move to `@MainActor` — but that requires the inits
    /// to be `@MainActor` first, which is only legal once CALayer's own
    /// inits are visible as `@MainActor`.
    private nonisolated func commonInit() {
        needsDisplayOnBoundsChange = true
        #if os(visionOS)
        contentsScale = 2.0
        #elseif targetEnvironment(macCatalyst) || canImport(UIKit)
        contentsScale = UIScreen.main.scale
        #elseif canImport(AppKit)
        contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        #endif
    }

    // MARK: - Preparation observers

    /// Register a handler called after every non-cancelled preparation completes
    /// (both success and parse-error paths). Multiple handlers may be installed;
    /// each receives the event. Returns a token to pass to
    /// ``removePrepareCompletionHandler(_:)``.
    @discardableResult
    public func addPrepareCompletionHandler(
        _ handler: @escaping @MainActor () -> Void
    ) -> AnyObject {
        let token = HandlerToken()
        prepareHandlers.append(CompletionHandlerEntry(
            token: ObjectIdentifier(token),
            handler: handler
        ))
        return token
    }

    public func removePrepareCompletionHandler(_ token: AnyObject) {
        let id = ObjectIdentifier(token)
        prepareHandlers.removeAll { $0.token == id }
    }

    // MARK: - Bitmap Rendering

    public func renderImage(scale: CGFloat = 2.0) -> BMImage? {
        guard let prepared = preparedDiagram else { return nil }
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return nil }
        let size = CGSize(width: diagBounds.width, height: diagBounds.height)
        return DiagramBitmapRenderer.render(
            size: size,
            scale: scale,
            theme: theme
        ) { ctx in
            ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
            prepared.render(in: ctx, bounds: diagBounds)
        }
    }

    // MARK: - Private Methods

    private func notifyPrepareComplete() {
        onPrepareComplete?()
        for entry in prepareHandlers {
            entry.handler()
        }
    }

    private func prepareDiagram() {
        preparationTask?.cancel()
        parseError = nil

        guard !source.isEmpty else {
            preparedDiagram = nil
            diagramBounds = .zero
            setNeedsDisplay()
            notifyPrepareComplete()
            return
        }

        let source = source
        let theme = theme
        let layoutConfig = layoutConfig

        let preparer = DiagramViewPreparerEnvironment.current

        preparationTask = Task { @MainActor [weak self] in
            let result: Result<PreparedDiagram, Error>
            do {
                let prepared: PreparedDiagram
                if let preparer {
                    prepared = try await preparer.prepare(source, theme, layoutConfig)
                } else {
                    prepared = try await DiagramPreparation.prepare(
                        source: source, theme: theme, layoutConfig: layoutConfig
                    )
                }
                result = .success(prepared)
            } catch {
                result = .failure(error)
            }

            // Cancelled tasks must not publish stale state or fire callbacks.
            guard !Task.isCancelled, let self else { return }
            switch result {
            case .success(let prepared):
                self.preparedDiagram = prepared
                self.diagramBounds = prepared.bounds
            case .failure(let error):
                _reportDiagramIssueIfNeeded(error, operation: "DiagramLayer.prepareDiagram")
                self.parseError = error
            }
            self.setNeedsDisplay()
            self.notifyPrepareComplete()
        }
    }
}

// MARK: - Phase 0 backward-compat deprecated alias

@available(*, deprecated, renamed: "DiagramLayer", message: "Will be removed in the next major version.")
public typealias MermaidLayer = DiagramLayer
#endif

// Apple-only SwiftUI/UIView wrappers gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import DiagramKitModel
import DiagramKitRenderingCG
import DiagramKitCommon
import CoreGraphics

// PreparedDiagram moved to DiagramKitRenderingCG/PreparedDiagram.swift

/// A plain observable model object that manages the diagram rendering
/// pipeline: parse -> layout -> expose prepared state.
///
/// Historically this type subclassed `CALayer` (hence the name), but it
/// never implemented `draw(in:)`, was never added to a layer tree, and
/// its `needsDisplayOnBoundsChange` / `contentsScale` /
/// `setNeedsDisplay()` surface was dead — `DiagramNativeView` paints
/// from the prepared model directly. It is now a ordinary `@MainActor`
/// class exposing exactly the live pipeline state; the public name is
/// retained for source compatibility (`MermaidLayer` remains a
/// deprecated alias). `renderImage(scale:)` and `DiagramNativeView`
/// remain the supported ways to obtain pixels.
@MainActor
public final class DiagramLayer {

    // MARK: - Public Properties

    public var source: String = "" {
        didSet {
            if source != oldValue { prepareDiagram() }
        }
    }

    /// Theme only affects rendering; the equality guard skips the whole
    /// pipeline when the value is unchanged (M-CG-2).
    public var theme: DiagramTheme = .default {
        didSet {
            guard theme != oldValue else { return }
            prepareDiagram()
        }
    }

    /// Layout configuration drives parse + layout, so any change
    /// re-prepares; the equality guard skips no-op writes (M-CG-2).
    public var layoutConfig: LayoutConfig = LayoutConfig() {
        didSet {
            guard layoutConfig != oldValue else { return }
            prepareDiagram()
        }
    }

    public var sourceFormat: DiagramFormatID? {
        didSet {
            if sourceFormat != oldValue { prepareDiagram() }
        }
    }

    public private(set) var parseError: Error?
    public private(set) var diagramBounds: CGRect = .zero
    public private(set) var preparedDiagram: PreparedDiagram?
    private var preparationTask: Task<Void, Never>?

    /// Monotonic generation token bumped each time `prepareDiagram` starts a
    /// new task. Publication is gated on `preparationGeneration ==
    /// captured`, so a task that finishes after the next call started will
    /// drop its result on the floor instead of publishing stale state.
    /// Today the MainActor isolation makes the race practically
    /// unreachable; this guard makes the invariant explicit so a future
    /// move of publication off MainActor can't silently break it.
    private var preparationGeneration: UInt64 = 0

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

    public init() {}

    deinit {
        preparationTask?.cancel()
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
        // M-CG-1: a superseded render's task is cancelled; the worker
        // thread drops at the `Task.checkCancellation` entry point in
        // `DiagramWorkerThread.run`, so a source edit per keystroke no
        // longer runs every spawned 8 MB render to completion.
        preparationTask?.cancel()
        preparationGeneration &+= 1
        let myGeneration = preparationGeneration
        parseError = nil

        guard !source.isEmpty else {
            preparedDiagram = nil
            diagramBounds = .zero
            notifyPrepareComplete()
            return
        }

        let source = source
        let theme = theme
        let layoutConfig = layoutConfig
        let sourceFormat = sourceFormat

        let preparer = DiagramViewPreparerEnvironment.current

        preparationTask = Task { @MainActor [weak self] in
            let result: Result<PreparedDiagram, Error>
            do {
                let prepared: PreparedDiagram
                if let preparer {
                    prepared = try await preparer.prepare(source, theme, layoutConfig, sourceFormat)
                } else {
                    prepared = try await DiagramPreparation.prepare(
                        source: source,
                        theme: theme,
                        layoutConfig: layoutConfig,
                        sourceFormat: sourceFormat
                    )
                }
                result = .success(prepared)
            } catch {
                result = .failure(error)
            }

            // Cancelled tasks (or tasks whose live generation has
            // already advanced past this one) must not publish stale
            // state or fire callbacks.
            guard !Task.isCancelled, let self, self.preparationGeneration == myGeneration else { return }
            switch result {
            case .success(let prepared):
                self.preparedDiagram = prepared
                self.diagramBounds = prepared.bounds
                self.parseError = nil
            case .failure(let error):
                _reportDiagramIssueIfNeeded(error, operation: "DiagramLayer.prepareDiagram")
                // Clear-on-failure semantics: stale `preparedDiagram`
                // and `diagramBounds` would otherwise leave the previous
                // successful render on screen with `parseError` floating
                // separately. Bindings consumers can now observe failure
                // as a state change (nil prepared + non-nil error).
                self.preparedDiagram = nil
                self.diagramBounds = .zero
                self.parseError = error
            }
            self.notifyPrepareComplete()
        }
    }
}

// MARK: - Phase 0 backward-compat deprecated alias

@available(*, deprecated, renamed: "DiagramLayer", message: "Will be removed in the next major version.")
public typealias MermaidLayer = DiagramLayer
#endif

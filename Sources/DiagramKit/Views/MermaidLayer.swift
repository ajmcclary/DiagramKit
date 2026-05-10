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
public class MermaidLayer: CALayer {

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

    /// Called after the diagram is prepared (parsed + laid out).
    public var onPrepareComplete: (@MainActor () -> Void)?

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

    // MARK: - Bitmap Rendering

    public func renderImage(scale: CGFloat = 2.0) -> BMImage? {
        guard let prepared = preparedDiagram else { return nil }
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return nil }
        let size = CGSize(width: diagBounds.width, height: diagBounds.height)
        return MermaidBitmapRenderer.render(
            size: size,
            scale: scale,
            theme: theme
        ) { ctx in
            ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
            prepared.render(in: ctx, bounds: diagBounds)
        }
    }

    // MARK: - Private Methods

    private func prepareDiagram() {
        preparationTask?.cancel()
        parseError = nil

        guard !source.isEmpty else {
            preparedDiagram = nil
            diagramBounds = .zero
            setNeedsDisplay()
            onPrepareComplete?()
            return
        }

        let source = source
        let theme = theme
        let layoutConfig = layoutConfig

        // Make sure the default preparer is installed before the first
        // view-side preparation call. The reference here is what causes
        // `_MermaidPreparerBootstrap.didInstall` to fire on first access.
        _ = _MermaidPreparerBootstrap.didInstall
        let preparer = MermaidViewPreparerEnvironment.current
            ?? MermaidViewPreparer(prepare: MermaidPreparation.prepare(source:theme:layoutConfig:))

        preparationTask = Task { [weak self] in
            do {
                let prepared = try await preparer.prepare(source, theme, layoutConfig)
                guard !Task.isCancelled else { return }
                self?.preparedDiagram = prepared
                self?.diagramBounds = prepared.bounds
            } catch {
                guard !Task.isCancelled else { return }
                _reportMermaidIssueIfNeeded(error, operation: "MermaidLayer.prepareDiagram")
                self?.parseError = error
            }

            self?.setNeedsDisplay()
            self?.onPrepareComplete?()
        }
    }
}
#endif

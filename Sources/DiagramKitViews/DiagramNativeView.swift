// Apple-only SwiftUI/UIView wrappers gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitRenderingCG
import CoreGraphics
import QuartzCore

#if canImport(UIKit)
import UIKit

/// A UIView subclass that renders diagrams
@MainActor
public class DiagramNativeView: UIView {

    public let diagramLayer: DiagramLayer

    /// Deprecated alias for ``diagramLayer``.
    @available(*, deprecated, renamed: "diagramLayer", message: "Renamed for format-neutral naming. Will be removed in the next major version.")
    public var mermaidLayer: DiagramLayer { diagramLayer }

    public var source: String {
        get { diagramLayer.source }
        set { diagramLayer.source = newValue }
    }

    public var theme: DiagramTheme {
        get { diagramLayer.theme }
        set {
            diagramLayer.theme = newValue
            backgroundColor = newValue.background
        }
    }

    public var layoutConfig: LayoutConfig {
        get { diagramLayer.layoutConfig }
        set { diagramLayer.layoutConfig = newValue }
    }

    public var sourceFormat: DiagramFormatID? {
        get { diagramLayer.sourceFormat }
        set { diagramLayer.sourceFormat = newValue }
    }

    public var parseError: Error? { diagramLayer.parseError }
    public var diagramBounds: CGRect { diagramLayer.diagramBounds }

    private var invalidationToken: AnyObject?

    public override init(frame: CGRect) {
        self.diagramLayer = DiagramLayer()
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.diagramLayer = DiagramLayer()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = diagramLayer.theme.background
        contentMode = .redraw
        invalidationToken = diagramLayer.addPrepareCompletionHandler { [weak self] in
            self?.invalidateIntrinsicContentSize()
            self?.setNeedsDisplay()
        }
        _assertPreparerEnvironmentConfigured()
    }

    public override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let viewBounds = bounds

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(viewBounds)
        }

        guard let prepared = diagramLayer.preparedDiagram else { return }
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return }
        guard viewBounds.width > 0, viewBounds.height > 0 else { return }

        let scaleX = viewBounds.width / diagBounds.width
        let scaleY = viewBounds.height / diagBounds.height
        let fitScale = min(scaleX, scaleY)

        let scaledWidth = diagBounds.width * fitScale
        let scaledHeight = diagBounds.height * fitScale
        let offsetX = (viewBounds.width - scaledWidth) / 2
        let offsetY = (viewBounds.height - scaledHeight) / 2

        ctx.saveGState()
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: fitScale, y: fitScale)
        ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
        prepared.render(in: ctx, bounds: diagBounds)
        ctx.restoreGState()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    public override var intrinsicContentSize: CGSize {
        diagramBounds.size
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        let db = diagramBounds
        guard db.width > 0, db.height > 0 else {
            return super.sizeThatFits(size)
        }
        let fitScale = min(size.width / db.width, size.height / db.height)
        return CGSize(width: db.width * fitScale, height: db.height * fitScale)
    }
}

#elseif canImport(AppKit)
import AppKit

/// An NSView subclass that renders diagrams
@MainActor
public class DiagramNativeView: NSView {

    public let diagramLayer: DiagramLayer

    /// Deprecated alias for ``diagramLayer``.
    @available(*, deprecated, renamed: "diagramLayer", message: "Renamed for format-neutral naming. Will be removed in the next major version.")
    public var mermaidLayer: DiagramLayer { diagramLayer }

    public var source: String {
        get { diagramLayer.source }
        set { diagramLayer.source = newValue }
    }

    public var theme: DiagramTheme {
        get { diagramLayer.theme }
        set {
            diagramLayer.theme = newValue
            layer?.backgroundColor = newValue.background.cgColor
        }
    }

    public var layoutConfig: LayoutConfig {
        get { diagramLayer.layoutConfig }
        set { diagramLayer.layoutConfig = newValue }
    }

    public var sourceFormat: DiagramFormatID? {
        get { diagramLayer.sourceFormat }
        set { diagramLayer.sourceFormat = newValue }
    }

    public var parseError: Error? { diagramLayer.parseError }
    public var diagramBounds: CGRect { diagramLayer.diagramBounds }

    public override init(frame frameRect: NSRect) {
        self.diagramLayer = DiagramLayer()
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        self.diagramLayer = DiagramLayer()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.backgroundColor = diagramLayer.theme.background.cgColor
        diagramLayer.onPrepareComplete = { [weak self] in
            self?.invalidateIntrinsicContentSize()
            self?.needsDisplay = true
        }
        _assertPreparerEnvironmentConfigured()
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let rect = bounds

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(rect)
        }

        guard let prepared = diagramLayer.preparedDiagram else { return }
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return }
        guard rect.width > 0, rect.height > 0 else { return }

        let scaleX = rect.width / diagBounds.width
        let scaleY = rect.height / diagBounds.height
        let fitScale = min(scaleX, scaleY)

        let scaledWidth = diagBounds.width * fitScale
        let scaledHeight = diagBounds.height * fitScale
        let offsetX = (rect.width - scaledWidth) / 2
        let offsetY = (rect.height - scaledHeight) / 2

        ctx.saveGState()
        // Flip for AppKit (y=0 at bottom -> y=0 at top)
        ctx.translateBy(x: 0, y: rect.height)
        ctx.scaleBy(x: 1, y: -1)
        // Apply centering and scale
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: fitScale, y: fitScale)
        ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
        prepared.render(in: ctx, bounds: diagBounds)
        ctx.restoreGState()
    }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: diagramBounds.width, height: diagramBounds.height)
    }
}

#endif

// MARK: - Preparer environment assertion

/// In DEBUG builds, fail loudly if `DiagramViewPreparerEnvironment` has not
/// been configured by the time a view is constructed — that means the host
/// app forgot to call `DiagramEngine.bootstrap()` (or equivalent setup)
/// and view rendering will silently fall back to `DiagramPreparation.prepare`
/// without the umbrella's canonical worker wiring.
///
/// In release builds the check is a no-op so the fallback path still works.
@MainActor
private func _assertPreparerEnvironmentConfigured() {
    #if DEBUG
    guard DiagramViewPreparerEnvironment.current == nil else { return }
    assertionFailure(
        "DiagramNativeView was constructed before DiagramViewPreparerEnvironment was configured. " +
        "Call `DiagramEngine.bootstrap()` (from `import DiagramKit`) once at app startup, " +
        "or install a stub preparer via `DiagramViewPreparerEnvironment.configure(_:)` in tests."
    )
    #endif
}

// MARK: - Phase 0 backward-compat deprecated alias

@available(*, deprecated, renamed: "DiagramNativeView", message: "Will be removed in the next major version.")
public typealias MermaidView = DiagramNativeView
#endif

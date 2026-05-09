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

        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        let size = CGSize(width: diagBounds.width * scale, height: diagBounds.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0

        let uiRenderer = UIGraphicsImageRenderer(size: size, format: format)
        return uiRenderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            if !theme.transparent {
                ctx.setFillColor(theme.background.cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
            prepared.render(in: ctx, bounds: diagBounds)
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: diagBounds.width * scale, height: diagBounds.height * scale)
        let image = NSImage(size: size)
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        // Flip for AppKit (lockFocus context has y=0 at bottom)
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)

        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)

        prepared.render(in: ctx, bounds: diagBounds)

        image.unlockFocus()
        return image
        #endif
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

        preparationTask = Task { [weak self] in
            do {
                let prepared = try await withCheckedThrowingContinuation { continuation in
                    let thread = Thread {
                        do {
                            let result = try MermaidPipeline.prepare(
                                source: source,
                                theme: theme,
                                layoutConfig: layoutConfig
                            )
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    thread.name = "BeautifulMermaid layer worker"
                    thread.stackSize = 8 * 1024 * 1024
                    thread.start()
                }
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

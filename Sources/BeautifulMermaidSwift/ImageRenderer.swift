import Foundation
import CoreGraphics
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public final class MermaidImageRenderer {
    public var theme: DiagramTheme
    public var layoutConfig: LayoutConfig
    public var scale: CGFloat = 2.0

    public init(theme: DiagramTheme = .default, config: LayoutConfig = LayoutConfig()) {
        self.theme = theme
        self.layoutConfig = config
    }

    public func prepare(from source: String) async throws -> PreparedDiagram {
        let theme = theme
        let layoutConfig = layoutConfig
        return try await MermaidRenderer._runOnWorker {
            try MermaidPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig
            )
        }
    }

    func prepareSync(from source: String) throws -> PreparedDiagram {
        try MermaidPipeline.prepare(source: source, theme: theme, layoutConfig: layoutConfig)
    }

    @MainActor
    public func renderImage(from source: String, scale overrideScale: CGFloat? = nil) async throws -> BMImage? {
        let theme = theme
        let layoutConfig = layoutConfig
        let prepared = try await MermaidRenderer._runOnWorker {
            try MermaidPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig
            )
        }
        let image = _renderPrepared(prepared, scale: overrideScale ?? scale)
        if image == nil {
            _reportMermaidIssue("MermaidImageRenderer.renderImage(from source:) returned nil.")
        }
        return image
    }

    @MainActor
    public func renderImage(from positioned: PositionedGraph, scale overrideScale: CGFloat? = nil) -> BMImage? {
        let image = _renderPrepared(
            PreparedDiagram(positioned: positioned, theme: theme),
            scale: overrideScale ?? scale
        )
        if image == nil {
            _reportMermaidIssue("MermaidImageRenderer.renderImage(from positioned:) returned nil.")
        }
        return image
    }

    @MainActor
    public func renderImage(from source: String, size: CGSize) async throws -> BMImage? {
        let theme = theme
        let layoutConfig = layoutConfig
        let prepared = try await MermaidRenderer._runOnWorker {
            try MermaidPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig
            )
        }
        let image = _renderPreparedFitted(prepared, size: size)
        if image == nil {
            _reportMermaidIssue("MermaidImageRenderer.renderImage(from source:size:) returned nil.")
        }
        return image
    }

    public func renderSVG(from source: String) async throws -> String {
        let theme = theme
        return try await MermaidRenderer._runOnWorker {
            try MermaidPipeline.renderSVG(source: source, theme: theme)
        }
    }

    func renderSVGSync(from source: String) throws -> String {
        let options = RenderOptions(
            bg: _hex(theme.background),
            fg: _hex(theme.foreground),
            line: _hex(theme.effectiveLine()),
            accent: _hex(theme.effectiveAccent()),
            muted: _hex(theme.effectiveMuted()),
            surface: _hex(theme.effectiveSurface()),
            border: _hex(theme.effectiveBorder()),
            transparent: false
        )

        let svg = try _renderMermaidSVG(source, options)
        let resolvedSvg = _resolveSvgCssVariables(svg)
        return _flattenKnownSvgTokens(resolvedSvg, theme: theme)
    }

    #if targetEnvironment(macCatalyst) || canImport(UIKit)
    @MainActor
    public func renderPNG(from source: String) async throws -> Data? {
        guard let image = try await renderImage(from: source) else { return nil }
        return image.pngData()
    }

    @MainActor
    public func renderJPEG(from source: String, quality: CGFloat = 0.9) async throws -> Data? {
        guard let image = try await renderImage(from: source) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }
    #elseif canImport(AppKit)
    @MainActor
    public func renderPNG(from source: String) async throws -> Data? {
        guard let image = try await renderImage(from: source),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    @MainActor
    public func renderJPEG(from source: String, quality: CGFloat = 0.9) async throws -> Data? {
        guard let image = try await renderImage(from: source),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
    #endif

    // MARK: - Platform image rendering

    /// Centralized bitmap/image creation. Accepts a draw closure that receives
    /// a y-down `CGContext` normalized to diagram space. Handles
    /// UIKit/AppKit context setup, background fill, and AppKit y-axis flip.
    @MainActor
    private func renderBitmap(
        size: CGSize,
        scale: CGFloat,
        draw: (CGContext) -> Void
    ) -> BMImage? {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let uiRenderer = UIGraphicsImageRenderer(size: size, format: format)
        return uiRenderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            if !theme.transparent {
                ctx.setFillColor(theme.background.cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            draw(ctx)
        }
        #elseif canImport(AppKit)
        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)
        guard pixelWidth > 0, pixelHeight > 0,
              let ctx = CGContext(
                  data: nil, width: pixelWidth, height: pixelHeight,
                  bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ) else { return nil }

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: pixelWidth, height: pixelHeight)))
        }

        // Raw AppKit CGContext bitmaps are y-up (origin bottom-left). Renderer
        // code assumes a y-down outer context — the same convention
        // UIGraphicsImageRenderer applies on UIKit/Catalyst.
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: 1, y: -1)
        ctx.scaleBy(x: scale, y: scale)

        draw(ctx)

        guard let cgImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: size)
        #endif
    }

    @MainActor
    private func _renderPrepared(_ prepared: PreparedDiagram, scale: CGFloat) -> BMImage? {
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return nil }
        let size = CGSize(width: diagBounds.width, height: diagBounds.height)
        return renderBitmap(size: size, scale: scale) { ctx in
            ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
            prepared.render(in: ctx, bounds: diagBounds)
        }
    }

    @MainActor
    private func _renderPreparedFitted(_ prepared: PreparedDiagram, size: CGSize) -> BMImage? {
        let diagBounds = prepared.bounds
        guard diagBounds.width > 0, diagBounds.height > 0 else { return nil }
        let scaleX = size.width / diagBounds.width
        let scaleY = size.height / diagBounds.height
        let fitScale = min(scaleX, scaleY)
        return renderBitmap(size: size, scale: scale) { ctx in
            let scaledWidth = diagBounds.width * fitScale
            let scaledHeight = diagBounds.height * fitScale
            let offsetX = (size.width - scaledWidth) / 2
            let offsetY = (size.height - scaledHeight) / 2
            ctx.translateBy(x: offsetX, y: offsetY)
            ctx.scaleBy(x: fitScale, y: fitScale)
            ctx.translateBy(x: -diagBounds.minX, y: -diagBounds.minY)
            prepared.render(in: ctx, bounds: diagBounds)
        }
    }
}

extension MermaidImageRenderer {
    @MainActor
    public static func render(
        _ source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) async throws -> BMImage? {
        let renderer = MermaidImageRenderer(theme: theme)
        renderer.scale = scale
        return try await renderer.renderImage(from: source)
    }

    @MainActor
    public static func render(
        _ source: String,
        size: CGSize,
        theme: DiagramTheme = .default
    ) async throws -> BMImage? {
        let renderer = MermaidImageRenderer(theme: theme)
        return try await renderer.renderImage(from: source, size: size)
    }
}

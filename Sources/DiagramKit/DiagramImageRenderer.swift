// Apple-only renderer pipeline gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import DiagramKitRenderingCG
import DiagramKitCommon
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Stateful renderer that turns a diagram source string into `BMImage`
/// / PNG / JPEG via the standard parse → layout → CG-render pipeline.
/// Settable `theme`, `layoutConfig`, `scale`, and optional
/// `sourceFormat` let one renderer instance render many inputs without
/// re-allocating. For one-off renders, the static `render(_:...)`
/// overloads below are usually more convenient.
public final class DiagramImageRenderer {
    /// Visual theme applied during CG rendering. Mutable so a single
    /// renderer can switch themes between calls.
    public var theme: DiagramTheme
    /// Layout configuration (padding, spacing, etc.) used during the
    /// layout step.
    public var layoutConfig: LayoutConfig
    /// Optional source-format hint. When `nil`, the registry picks an
    /// importer by probing the source string.
    public var sourceFormat: DiagramFormatID?
    /// Bitmap scale factor applied during `renderImage`. Default `2.0`.
    public var scale: CGFloat = 2.0

    /// Build a renderer with the given theme, layout config, and
    /// optional source-format hint. `scale` defaults to `2.0` and is
    /// settable on the instance.
    public init(
        theme: DiagramTheme = .default,
        config: LayoutConfig = LayoutConfig(),
        sourceFormat: DiagramFormatID? = nil
    ) {
        self.theme = theme
        self.layoutConfig = config
        self.sourceFormat = sourceFormat
    }

    /// Parse + layout `source` on the diagram worker thread, returning
    /// a `PreparedDiagram` you can render multiple times without
    /// re-parsing.
    public func prepare(from source: String) async throws -> PreparedDiagram {
        let theme = theme
        let layoutConfig = layoutConfig
        let sourceFormat = sourceFormat
        return try await DiagramEngine._runOnWorker {
            try DiagramPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig,
                sourceFormat: sourceFormat
            )
        }
    }

    func prepareSync(from source: String) throws -> PreparedDiagram {
        try DiagramPipeline.prepare(
            source: source,
            theme: theme,
            layoutConfig: layoutConfig,
            sourceFormat: sourceFormat
        )
    }

    /// Parse, lay out, and render `source` to a `BMImage`. `nil` is
    /// returned (and an issue reported) if the layout produced an empty
    /// bounding box. `overrideScale` takes precedence over `self.scale`.
    @MainActor
    public func renderImage(from source: String, scale overrideScale: CGFloat? = nil) async throws -> BMImage? {
        let theme = theme
        let layoutConfig = layoutConfig
        let sourceFormat = sourceFormat
        let prepared = try await DiagramEngine._runOnWorker {
            try DiagramPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig,
                sourceFormat: sourceFormat
            )
        }
        let image = _renderPrepared(prepared, scale: overrideScale ?? scale)
        if image == nil {
            _reportDiagramIssue("DiagramImageRenderer.renderImage(from source:) returned nil.")
        }
        return image
    }

    /// Render an already-positioned graph to a `BMImage`. Bypasses
    /// parse + layout. Use when you have a cached `PositionedGraph`.
    @MainActor
    public func renderImage(from positioned: PositionedGraph, scale overrideScale: CGFloat? = nil) -> BMImage? {
        let image = _renderPrepared(
            PreparedDiagram(positioned: positioned, theme: theme),
            scale: overrideScale ?? scale
        )
        if image == nil {
            _reportDiagramIssue("DiagramImageRenderer.renderImage(from positioned:) returned nil.")
        }
        return image
    }

    /// Parse, lay out, and render `source` fit into the given pixel
    /// `size`, centred and aspect-preserved.
    @MainActor
    public func renderImage(from source: String, size: CGSize) async throws -> BMImage? {
        let theme = theme
        let layoutConfig = layoutConfig
        let sourceFormat = sourceFormat
        let prepared = try await DiagramEngine._runOnWorker {
            try DiagramPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig,
                sourceFormat: sourceFormat
            )
        }
        let image = _renderPreparedFitted(prepared, size: size)
        if image == nil {
            _reportDiagramIssue("DiagramImageRenderer.renderImage(from source:size:) returned nil.")
        }
        return image
    }

    /// Parse + layout + emit SVG markup. `idPolicy` controls how
    /// diagram-element IDs are generated (default `.unique` mints fresh
    /// per call so multiple SVGs can coexist in the same DOM).
    public func renderSVG(from source: String, idPolicy: SVGIDPolicy = .unique) async throws -> String {
        let theme = theme
        let layoutConfig = layoutConfig
        let sourceFormat = sourceFormat
        return try await DiagramEngine._runOnWorker {
            try DiagramPipeline.renderSVG(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig,
                idPolicy: idPolicy,
                sourceFormat: sourceFormat
            )
        }
    }

    func renderSVGSync(from source: String, idPolicy: SVGIDPolicy = .unique) throws -> String {
        try DiagramPipeline.renderSVG(
            source: source,
            theme: theme,
            layoutConfig: layoutConfig,
            idPolicy: idPolicy,
            sourceFormat: sourceFormat
        )
    }

    #if canImport(UIKit)
    /// Render `source` and encode as PNG `Data`. Returns `nil` if the
    /// underlying image was empty.
    @MainActor
    public func renderPNG(from source: String) async throws -> Data? {
        guard let image = try await renderImage(from: source) else { return nil }
        return image.pngData()
    }

    /// Render `source` and encode as JPEG `Data` at the given quality
    /// (`0.0`–`1.0`, default `0.9`).
    @MainActor
    public func renderJPEG(from source: String, quality: CGFloat = 0.9) async throws -> Data? {
        guard let image = try await renderImage(from: source) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }
    #elseif canImport(AppKit)
    /// Render `source` and encode as PNG `Data`. Returns `nil` if the
    /// underlying image was empty or could not be bitmapped.
    @MainActor
    public func renderPNG(from source: String) async throws -> Data? {
        guard let image = try await renderImage(from: source),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Render `source` and encode as JPEG `Data` at the given quality
    /// (`0.0`–`1.0`, default `0.9`).
    @MainActor
    public func renderJPEG(from source: String, quality: CGFloat = 0.9) async throws -> Data? {
        guard let image = try await renderImage(from: source),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
    #endif

    // MARK: - Platform image rendering

    /// Bitmap creation now routes through the shared
    /// `DiagramBitmapRenderer` so the UIKit/AppKit setup can't drift
    /// between `DiagramImageRenderer` and `DiagramLayer`.
    @MainActor
    private func renderBitmap(
        size: CGSize,
        scale: CGFloat,
        draw: (CGContext) -> Void
    ) -> BMImage? {
        DiagramBitmapRenderer.render(size: size, scale: scale, theme: theme, draw: draw)
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

extension DiagramImageRenderer {
    /// One-shot convenience: build a renderer with the given theme +
    /// scale and render `source` to a `BMImage`. Equivalent to
    /// `DiagramImageRenderer(theme: …).renderImage(from: source)`.
    @MainActor
    public static func render(
        _ source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0,
        sourceFormat: DiagramFormatID? = nil
    ) async throws -> BMImage? {
        let renderer = DiagramImageRenderer(theme: theme, sourceFormat: sourceFormat)
        renderer.scale = scale
        return try await renderer.renderImage(from: source)
    }

    /// One-shot convenience: render `source` fit into `size`,
    /// centred and aspect-preserved.
    @MainActor
    public static func render(
        _ source: String,
        size: CGSize,
        theme: DiagramTheme = .default,
        sourceFormat: DiagramFormatID? = nil
    ) async throws -> BMImage? {
        let renderer = DiagramImageRenderer(theme: theme, sourceFormat: sourceFormat)
        return try await renderer.renderImage(from: source, size: size)
    }
}
#endif

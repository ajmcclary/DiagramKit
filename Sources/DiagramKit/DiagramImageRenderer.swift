// Apple-only renderer pipeline gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import DiagramKitRenderingCG
import DiagramKitCommon
import CoreGraphics
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public final class DiagramImageRenderer {
    public var theme: DiagramTheme
    public var layoutConfig: LayoutConfig
    public var sourceFormat: DiagramFormatID?
    public var scale: CGFloat = 2.0

    public init(
        theme: DiagramTheme = .default,
        config: LayoutConfig = LayoutConfig(),
        sourceFormat: DiagramFormatID? = nil
    ) {
        self.theme = theme
        self.layoutConfig = config
        self.sourceFormat = sourceFormat
    }

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

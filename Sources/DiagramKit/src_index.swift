// Apple-only — depends on Models gated SVG/layout symbols. `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
// Ported from original/src/index.ts
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

// RenderOptions + DiagramColors moved to DiagramKitModel/RenderOptions.swift

private enum _IndexDefaults {
    static let bg = "#FFFFFF"
    static let fg = "#27272A"
}

// `_DiagramRoutingType`, `detectDiagramType`, `_decodeXML`, and the 27
// `_render*SvgCase` helpers previously lived here as a parallel SVG
// routing surface that parsed + laid out inline. Both have been
// replaced: detection now flows through `DiagramRegistry.detect`, and
// `_renderDiagramSVG` routes parse → layout → positioned render via
// `SVGRenderRegistry`. The remaining content in this file is just the
// `_renderDiagramSVG` adapter and the public SVG entry points.

private func buildColors(_ options: RenderOptions) -> DiagramColors {
    DiagramColors(
        bg: options.bg ?? _IndexDefaults.bg,
        fg: options.fg ?? _IndexDefaults.fg,
        line: options.line,
        accent: options.accent,
        muted: options.muted,
        surface: options.surface,
        border: options.border
    )
}

/// Render Mermaid source to SVG by routing through the canonical
/// positioned-graph path (parse → layout → positioned render).
/// Preserved for the two callers that thread `RenderOptions` rather
/// than `DiagramTheme`: `DiagramPipeline.renderSVG(_:options:)` and
/// `DiagramImageRenderer.renderSVGSync(from:idPolicy:)`. The legacy
/// source-based SVG path (with its 27 `_render*SvgCase` functions) was
/// retired in Phase 2 (audit A4).
func _renderDiagramSVG(
    _ text: String,
    _ options: RenderOptions = RenderOptions(),
    layoutConfig: LayoutConfig = LayoutConfig()
) throws -> String {
    let document = try DiagramLoader.parseDocument(
        text,
        registry: DiagramPipeline.defaultRegistry
    )
    let positioned = try GraphLayout(config: layoutConfig).layout(document)

    let colors = buildColors(options)
    let font = options.font ?? DiagramFontResolver.shared.svgFontFamily
    let transparent = options.transparent ?? false
    let diagramId = SVGIDGenerator.id(for: text, policy: options.idPolicy)

    return try SVGRenderRegistry.render(
        positioned: positioned,
        diagramId: diagramId,
        colors: colors,
        font: font,
        transparent: transparent
    )
}

// MARK: - Public SVG rendering API

public func renderDiagramSVG(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try await DiagramEngine._runOnWorker {
        try DiagramPipeline.renderSVG(text, options: options)
    }
}

public func renderDiagramSVGAsync(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try await renderDiagramSVG(text, options)
}

// MARK: - Deprecated compat wrappers

@available(*, deprecated, renamed: "renderDiagramSVG(_:_:)", message: "Will be removed in the next major version.")
public func renderMermaidSVG(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try await renderDiagramSVG(text, options)
}

@available(*, deprecated, renamed: "renderDiagramSVGAsync(_:_:)", message: "Will be removed in the next major version.")
public func renderMermaidSVGAsync(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try await renderDiagramSVGAsync(text, options)
}

@available(*, deprecated, renamed: "renderDiagramSVG(_:_:)", message: "Will be removed in the next major version.")
public func renderMermaid(
    _ text: String,
    _ options: RenderOptions = RenderOptions()
) async throws -> String {
    try await renderDiagramSVG(text, options)
}

public final class original_src_index {
    public init() {}
}
#endif

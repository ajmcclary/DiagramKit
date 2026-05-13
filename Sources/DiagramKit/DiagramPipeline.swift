import Foundation
import DiagramKitModel
import DiagramKitCommon
import DiagramKitImport
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML
import DiagramKitExport
import DiagramKitMermaid
#if canImport(CoreGraphics)
import DiagramKitRenderingCG
#endif

/// Stateless namespace for Mermaid diagram pipeline operations.
///
/// All methods are synchronous and nonisolated — callers are responsible
/// for dispatching to an appropriate thread when stack requirements
/// exceed the cooperative thread pool budget (~512 KB).
public enum DiagramPipeline {

    // MARK: - Entry-point boundary

    /// Centralized pipeline entry point. Every public method delegates to this
    /// helper so that font registration and issue reporting are applied
    /// uniformly.
    private static func runPipeline<T>(
        operation: String,
        registerFonts: Bool = true,
        _ work: () throws -> T
    ) throws -> T {
        if registerFonts {
            #if canImport(CoreGraphics)
            DiagramFontRegistry.registerBundledFontsIfNeeded()
            #endif
        }
        return try _withDiagramIssueReporting(operation: operation, work)
    }

    // MARK: - Default registry

    /// Default registry: Structurizr first, PlantUML second, Graphviz third, D2 fourth, Mermaid last (broad fallback).
    public static let defaultRegistry: ImporterRegistry = ImporterRegistry(
        importers: [StructurizrImporter(), PlantUMLImporter(), GraphvizImporter(), D2Importer(), MermaidImporter()]
    )

    /// Default export registry, keyed by format ID.
    /// Mermaid is the primary exporter with the broadest type coverage.
    /// D2, Structurizr, and PlantUML are registered for format conversion.
    /// Dispatch is by format ID — callers request `.d2` and get the D2
    /// exporter regardless of Mermaid's overlapping coverage.
    public static let defaultExportRegistry: ExporterRegistry = {
        var registry = ExporterRegistry.empty
            .registering(MermaidExporter())
        registry = registry.registering(D2Exporter())
        registry = registry.registering(StructurizrExporter())
        registry = registry.registering(PlantUMLExporter())
        return registry
    }()

    // MARK: - Parse

    private static func loadDocument(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try DiagramLoader.parseDocument(source, registry: registry)
    }

    public static func parse(_ source: String) throws -> DiagramDocument {
        try runPipeline(operation: "DiagramPipeline.parse", registerFonts: true) {
            try loadDocument(source, registry: defaultRegistry)
        }
    }

    public static func parse(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try runPipeline(operation: "DiagramPipeline.parse(registry:)", registerFonts: true) {
            try loadDocument(source, registry: registry)
        }
    }

    // MARK: - Layout

    public static func layout(
        _ source: String,
        config: LayoutConfig = LayoutConfig(),
        registry: ImporterRegistry = defaultRegistry
    ) throws -> PositionedGraph {
        try runPipeline(operation: "DiagramPipeline.layout(source:)") {
            let graph = try loadDocument(source, registry: registry)
            return try GraphLayout(config: config).layout(graph)
        }
    }

    public static func layout(
        _ graph: DiagramDocument,
        config: LayoutConfig = LayoutConfig()
    ) throws -> PositionedGraph {
        try runPipeline(operation: "DiagramPipeline.layout(graph:)") {
            try GraphLayout(config: config).layout(graph)
        }
    }

    #if canImport(CoreGraphics)
    // MARK: - Prepare

    public static func prepare(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        registry: ImporterRegistry = defaultRegistry
    ) throws -> PreparedDiagram {
        try runPipeline(operation: "DiagramPipeline.prepare") {
            let graph = try loadDocument(source, registry: registry)
            let positioned = try GraphLayout(config: layoutConfig).layout(graph)
            return PreparedDiagram(positioned: positioned, theme: theme)
        }
    }

    // MARK: - Render SVG

    /// Render a diagram to SVG through the positioned-graph path when the
    /// diagram family supports it (currently: xyChart, quadrantChart,
    /// sankey, radar). Falls back to the source-based pipeline for other
    /// families.
    public static func renderSVG(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        idPolicy: SVGIDPolicy = .unique,
        registry: ImporterRegistry = defaultRegistry
    ) throws -> String {
        try runPipeline(operation: "DiagramPipeline.renderSVG") {
            let graph = try loadDocument(source, registry: registry)
            let positioned = try GraphLayout(config: layoutConfig).layout(graph)

            let colors = DiagramColors(
                bg: theme.background.cssColorString,
                fg: theme.foreground.cssColorString,
                line: (theme.line ?? theme.foreground).cssColorString,
                accent: (theme.accent ?? theme.foreground).cssColorString,
                muted: (theme.muted ?? theme.foreground).cssColorString,
                surface: (theme.surface ?? theme.background).cssColorString,
                border: (theme.border ?? theme.foreground).cssColorString
            )
            let font = DiagramFontResolver.shared.svgFontFamily
            let diagramId = SVGIDGenerator.id(for: source, policy: idPolicy)

            do {
                let svg = try SVGRenderRegistry.render(
                    positioned: positioned,
                    diagramId: diagramId,
                    colors: colors,
                    font: font,
                    transparent: false
                )
                let resolved = _resolveSvgCssVariables(svg)
                return _flattenKnownSvgTokens(resolved, theme: theme)
            } catch DiagramError.notYetImplemented {
                // Fall back to source-based pipeline for families not yet
                // on the positioned path.
                return try DiagramImageRenderer(theme: theme, config: layoutConfig)
                    .renderSVGSync(from: source, idPolicy: idPolicy)
            }
        }
    }

    /// Render a pre-positioned diagram to SVG. Only families with a
    /// positioned entry point in `SVGRenderRegistry` are supported.
    public static func renderSVG(
        positioned: PositionedGraph,
        theme: DiagramTheme = .default
    ) throws -> String {
        try runPipeline(operation: "DiagramPipeline.renderSVG(positioned:)") {
            let colors = DiagramColors(
                bg: theme.background.cssColorString,
                fg: theme.foreground.cssColorString,
                line: (theme.line ?? theme.foreground).cssColorString,
                accent: (theme.accent ?? theme.foreground).cssColorString,
                muted: (theme.muted ?? theme.foreground).cssColorString,
                surface: (theme.surface ?? theme.background).cssColorString,
                border: (theme.border ?? theme.foreground).cssColorString
            )
            let font = DiagramFontResolver.shared.svgFontFamily
            let diagramId = SVGIDGenerator.id(
                for: "\(positioned.diagram.type.rawValue)-\(positioned.width)x\(positioned.height)",
                policy: .unique
            )
            let svg = try SVGRenderRegistry.render(
                positioned: positioned,
                diagramId: diagramId,
                colors: colors,
                font: font,
                transparent: false
            )
            let resolved = _resolveSvgCssVariables(svg)
            return _flattenKnownSvgTokens(resolved, theme: theme)
        }
    }

    public static func renderSVG(
        _ text: String,
        options: RenderOptions = RenderOptions()
    ) throws -> String {
        try runPipeline(operation: "DiagramPipeline.renderSVG(options:)") {
            try _renderDiagramSVG(text, options)
        }
    }

    // MARK: - Render ASCII

    public static func renderASCII(
        source: String,
        theme: DiagramTheme = .default
    ) throws -> String {
        try runPipeline(operation: "DiagramPipeline.renderASCII") {
            let colors: [String: String] = [
                "fg": theme.foreground.hexString,
                "border": (theme.border ?? theme.foreground).hexString,
                "line": (theme.line ?? theme.foreground).hexString,
                "arrow": (theme.line ?? theme.foreground).hexString,
            ]
            let asciiTheme = original_src_ascii_index.diagramColorsToAsciiTheme(colors)
            let options = original_src_ascii_index.AsciiRenderOptions(theme: asciiTheme)
            return try original_src_ascii_index.renderMermaidASCII(source, options: options)
        }
    }
    #endif
}

// MARK: - Phase 0 backward-compat deprecated alias

@available(*, deprecated, renamed: "DiagramPipeline", message: "Will be removed in the next major version.")
public typealias MermaidPipeline = DiagramPipeline

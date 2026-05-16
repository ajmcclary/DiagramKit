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
    /// D2, Graphviz, Structurizr, and PlantUML are registered for format
    /// conversion. Dispatch is by format ID — callers request `.d2` and
    /// get the D2 exporter regardless of Mermaid's overlapping coverage.
    public static let defaultExportRegistry: ExporterRegistry = {
        var registry = ExporterRegistry.empty
            .registering(MermaidExporter())
        registry = registry.registering(D2Exporter())
        registry = registry.registering(DOTExporter())
        registry = registry.registering(StructurizrExporter())
        registry = registry.registering(PlantUMLExporter())
        return registry
    }()

    // MARK: - Parse

    private static func loadImportResult(
        _ source: String,
        sourceFormat: DiagramFormatID? = nil,
        registry: ImporterRegistry
    ) throws -> DiagramImportResult {
        if let sourceFormat {
            return try DiagramLoader.parse(source, as: sourceFormat, registry: registry)
        }
        return try DiagramLoader.parseImportResult(source, registry: registry)
    }

    private static func loadDocument(
        _ source: String,
        sourceFormat: DiagramFormatID? = nil,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try loadImportResult(source, sourceFormat: sourceFormat, registry: registry).document
    }

    private static func uniqueDiagnostics(_ diagnostics: [DiagramDiagnostic]) -> [DiagramDiagnostic] {
        var seen: Set<DiagramDiagnostic> = []
        var result: [DiagramDiagnostic] = []
        for diagnostic in diagnostics where seen.insert(diagnostic).inserted {
            result.append(diagnostic)
        }
        return result
    }

    /// Throw `DiagramError.unsupportedOnPlatform` if `document.type`'s
    /// descriptor declares `linuxSupport == false` and the current
    /// runtime platform is Linux. No-op on every other platform.
    private static func _assertPlatformSupport(_ document: DiagramDocument) throws {
        #if os(Linux)
        let descriptor = try DiagramRegistry.descriptor(for: document.type)
        if !descriptor.linuxSupport {
            throw DiagramError.unsupportedOnPlatform(
                family: document.type,
                reason: descriptor.linuxUnsupportedReason ?? "no reason provided",
                platform: "Linux"
            )
        }
        #endif
    }

    /// Parse `source` into a `DiagramDocument` using the default
    /// importer registry's format-probe order. Throws on parse failure
    /// or if no importer claims the source.
    public static func parse(_ source: String) throws -> DiagramDocument {
        try runPipeline(operation: "DiagramPipeline.parse", registerFonts: true) {
            try loadDocument(source, registry: defaultRegistry)
        }
    }

    /// Parse `source` and force interpretation as `sourceFormat`. Skips
    /// the registry's probe step.
    public static func parse(
        _ source: String,
        as sourceFormat: DiagramFormatID,
        registry: ImporterRegistry = defaultRegistry
    ) throws -> DiagramDocument {
        try runPipeline(operation: "DiagramPipeline.parse(as:)", registerFonts: true) {
            try loadDocument(source, sourceFormat: sourceFormat, registry: registry)
        }
    }

    /// Parse `source` against a caller-supplied registry. Use when you
    /// need a custom importer set (e.g. test fixtures, restricted formats).
    public static func parse(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try runPipeline(operation: "DiagramPipeline.parse(registry:)", registerFonts: true) {
            try loadDocument(source, registry: registry)
        }
    }

    // MARK: - Layout

    /// Parse + lay out `source` in one call. Returns the
    /// `PositionedGraph` that downstream renderers consume.
    public static func layout(
        _ source: String,
        config: LayoutConfig = LayoutConfig(),
        sourceFormat: DiagramFormatID? = nil,
        registry: ImporterRegistry = defaultRegistry
    ) throws -> PositionedGraph {
        try runPipeline(operation: "DiagramPipeline.layout(source:)") {
            let graph = try loadDocument(source, sourceFormat: sourceFormat, registry: registry)
            return try GraphLayout(config: config).layout(graph)
        }
    }

    /// Lay out an already-parsed `DiagramDocument`. Use when you've
    /// cached the parsed model and want to re-layout with different
    /// config.
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

    /// Parse + lay out + bind to `theme` so the result can be rendered
    /// multiple times without redoing parse/layout. The returned
    /// `PreparedDiagram` carries both parse-tier and layout-tier
    /// diagnostics on its `diagnostics` slot.
    public static func prepare(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        sourceFormat: DiagramFormatID? = nil,
        registry: ImporterRegistry = defaultRegistry
    ) throws -> PreparedDiagram {
        try runPipeline(operation: "DiagramPipeline.prepare") {
            let importResult = try loadImportResult(
                source,
                sourceFormat: sourceFormat,
                registry: registry
            )
            let positioned = try GraphLayout(config: layoutConfig).layout(importResult.document)
            return PreparedDiagram(
                positioned: positioned,
                theme: theme,
                importDiagnostics: importResult.diagnostics
            )
        }
    }
    #endif

    // MARK: - Render SVG

    /// Render a diagram to SVG through the positioned-graph path. Every
    /// diagram family registered in `SVGRenderRegistry` carries a
    /// `renderPositioned` closure, so this is the canonical SVG entry
    /// point: parse → layout → positioned render. The legacy source-based
    /// fallback was retired in Phase 2 (audit A4).
    public static func renderSVG(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        idPolicy: SVGIDPolicy = .unique,
        sourceFormat: DiagramFormatID? = nil,
        registry: ImporterRegistry = defaultRegistry
    ) throws -> String {
        try runPipeline(operation: "DiagramPipeline.renderSVG") {
            let graph = try loadDocument(source, sourceFormat: sourceFormat, registry: registry)
            try _assertPlatformSupport(graph)
            let positioned = try GraphLayout(config: layoutConfig).layout(graph)

            let colors = DiagramColors(
                bg: theme.background.cssColorString,
                fg: theme.foreground.cssColorString,
                line: theme.effectiveLine().cssColorString,
                accent: theme.effectiveAccent().cssColorString,
                muted: theme.effectiveMuted().cssColorString,
                surface: theme.effectiveSurface().cssColorString,
                border: theme.effectiveBorder().cssColorString
            )
            let font = DiagramFontResolver.shared.svgFontFamily
            let diagramId = SVGIDGenerator.id(for: source, policy: idPolicy)

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

    /// Render a pre-positioned diagram to SVG. Only families with a
    /// positioned entry point in `SVGRenderRegistry` are supported.
    public static func renderSVG(
        positioned: PositionedGraph,
        theme: DiagramTheme = .default
    ) throws -> String {
        try runPipeline(operation: "DiagramPipeline.renderSVG(positioned:)") {
            try _assertPlatformSupport(positioned.diagram)
            let colors = DiagramColors(
                bg: theme.background.cssColorString,
                fg: theme.foreground.cssColorString,
                line: theme.effectiveLine().cssColorString,
                accent: theme.effectiveAccent().cssColorString,
                muted: theme.effectiveMuted().cssColorString,
                surface: theme.effectiveSurface().cssColorString,
                border: theme.effectiveBorder().cssColorString
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

    // MARK: - Render ASCII

    /// Parse + lay out + emit ASCII art. Returns the rendered text and
    /// any diagnostics produced during import/layout. The string-only
    /// `String.renderDiagramASCII(...)` helper forwards `.text` for
    /// callers that don't need the diagnostics tuple.
    public static func renderASCII(
        source: String,
        theme: DiagramTheme = .default,
        sourceFormat: DiagramFormatID? = nil
    ) throws -> AsciiRenderOutput {
        try runPipeline(operation: "DiagramPipeline.renderASCII") {
            let importResult = try loadImportResult(
                source,
                sourceFormat: sourceFormat,
                registry: defaultRegistry
            )
            try _assertPlatformSupport(importResult.document)
            let colors: [String: String] = [
                "fg": theme.foreground.hexString,
                "border": (theme.border ?? theme.foreground).hexString,
                "line": (theme.line ?? theme.foreground).hexString,
                "arrow": (theme.line ?? theme.foreground).hexString,
            ]
            let asciiTheme = original_src_ascii_index.diagramColorsToAsciiTheme(colors)
            let options = original_src_ascii_index.AsciiRenderOptions(theme: asciiTheme)
            let mermaidSource: String
            var diagnostics = importResult.diagnostics

            if importResult.formatID == .mermaid {
                mermaidSource = source
            } else {
                let exportResult = try DiagramExportLoader.export(
                    importResult.document,
                    to: .mermaid,
                    registry: defaultExportRegistry
                )
                diagnostics.append(contentsOf: exportResult.diagnostics)
                guard !exportResult.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return AsciiRenderOutput(text: "", diagnostics: uniqueDiagnostics(diagnostics))
                }
                mermaidSource = exportResult.source
            }

            let (text, renderDiagnostics) =
                try original_src_ascii_index.renderMermaidASCIIWithDiagnostics(
                    mermaidSource,
                    options: options
                )
            diagnostics.append(contentsOf: renderDiagnostics)
            return AsciiRenderOutput(text: text, diagnostics: uniqueDiagnostics(diagnostics))
        }
    }
}

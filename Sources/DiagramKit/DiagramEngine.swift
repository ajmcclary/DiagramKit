import Foundation
import DiagramKitCommon
import DiagramKitModel
#if canImport(CoreGraphics)
import DiagramKitRenderingCG
import CoreGraphics
#endif
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Main entry point for parsing, layout, and rendering Mermaid diagrams.
public struct DiagramEngine {
    /// Library version. Reads the `VERSION` resource bundled with
    /// `DiagramKitCommon` (Linux + Apple). To update the version, edit
    /// `Sources/DiagramKitCommon/Resources/VERSION` (or tag a release commit
    /// if a build-time script regenerates it).
    public static let version: String = DiagramKitVersion.current
    public static let supportedDiagramTypes: [DiagramType] = DiagramType.allCases

    #if canImport(CoreGraphics)
    /// Eagerly trigger the view-preparer bootstrap.
    ///
    /// Every public `DiagramEngine.*` API calls this implicitly before
    /// doing work, so end users normally never need to invoke it
    /// directly. Call it explicitly only when consuming
    /// `DiagramPreparation` / `DiagramViewPreparerEnvironment` /
    /// `DiagramKitViews` symbols without first going through a
    /// `DiagramEngine` entry point — for example, in test fixtures
    /// that exercise `DiagramPreparation.prepare(...)` directly.
    public static func bootstrap() {
        _ = _DiagramPreparerBootstrap.didInstall
    }
    #endif

    /// Parse a Mermaid diagram.
    public static func parse(_ source: String) async throws -> DiagramDocument {
        #if canImport(CoreGraphics)
        _ = _DiagramPreparerBootstrap.didInstall
        #endif
        return try await _runOnWorker {
            try DiagramPipeline.parse(source)
        }
    }

    /// Parse and layout a Mermaid diagram.
    public static func layout(
        _ source: String,
        config: LayoutConfig = LayoutConfig()
    ) async throws -> PositionedGraph {
        #if canImport(CoreGraphics)
        _ = _DiagramPreparerBootstrap.didInstall
        #endif
        return try await _runOnWorker {
            try DiagramPipeline.layout(source, config: config)
        }
    }

    #if canImport(CoreGraphics)
    /// Prepare a Mermaid diagram for direct CGContext rendering.
    public static func prepare(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) async throws -> PreparedDiagram {
        _ = _DiagramPreparerBootstrap.didInstall
        return try await _runOnWorker {
            try DiagramPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig
            )
        }
    }

    /// Render directly to a CGContext.
    @MainActor
    public static func render(
        source: String,
        in context: CGContext,
        bounds: CGRect,
        theme: DiagramTheme = .default
    ) async throws {
        let prepared = try await prepare(source: source, theme: theme)
        prepared.render(in: context, bounds: bounds)
    }

    /// Render a Mermaid diagram to a native image.
    @MainActor
    public static func renderImage(
        source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) async throws -> BMImage? {
        _ = _DiagramPreparerBootstrap.didInstall
        let renderer = DiagramImageRenderer(theme: theme)
        renderer.scale = scale
        return try await renderer.renderImage(from: source)
    }

    /// Render a Mermaid diagram to a native image with specific size.
    @MainActor
    public static func renderImage(
        source: String,
        size: CGSize,
        theme: DiagramTheme = .default
    ) async throws -> BMImage? {
        _ = _DiagramPreparerBootstrap.didInstall
        let renderer = DiagramImageRenderer(theme: theme)
        return try await renderer.renderImage(from: source, size: size)
    }
    #endif

    #if canImport(CoreGraphics)
    /// Render a Mermaid diagram to an SVG string.
    public static func renderSVG(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        idPolicy: SVGIDPolicy = .unique
    ) async throws -> String {
        _ = _DiagramPreparerBootstrap.didInstall
        return try await _runOnWorker {
            try DiagramPipeline.renderSVG(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig,
                idPolicy: idPolicy
            )
        }
    }

    /// Render a Mermaid diagram to an ASCII/Unicode string paired with any
    /// diagnostics emitted during parse / layout / ASCII rendering. Callers
    /// that only want the rendered text can access `.text`.
    public static func renderASCII(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> AsciiRenderOutput {
        _ = _DiagramPreparerBootstrap.didInstall
        return try await _runOnWorker {
            try DiagramPipeline.renderASCII(source: source, theme: theme)
        }
    }

    /// Parse `source` and return the full `DiagramImportResult`, including
    /// any diagnostics surfaced by the matched importer. Use this when you
    /// need the diagnostics without going through `prepare(...)`.
    public static func parseImportResult(
        source: String,
        registry: ImporterRegistry = DiagramPipeline.defaultRegistry
    ) async throws -> DiagramImportResult {
        _ = _DiagramPreparerBootstrap.didInstall
        return try await _runOnWorker {
            try DiagramLoader.parseImportResult(source, registry: registry)
        }
    }
    #endif

    /// Forwarding shim onto `DiagramWorkerThread.run` (defined in
    /// `DiagramKitRenderingCG`). The canonical worker now lives in the
    /// lower target so view code can dispatch through it without
    /// importing the umbrella; this shim preserves the existing
    /// internal call sites and the test surface
    /// (`Tests/DiagramKitTests/DiagramPreparationWorkerTests.swift`).
    #if canImport(CoreGraphics)
    static func _runOnWorker<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await DiagramWorkerThread.run(work)
    }
    #else
    static func _runOnWorker<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let thread = Thread {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            thread.name = "DiagramKit worker"
            thread.stackSize = DiagramWorkerConfig.stackSize
            thread.start()
        }
    }
    #endif
}

extension DiagramEngine {
    #if canImport(CoreGraphics)
    @available(*, deprecated, renamed: "renderImage(source:theme:scale:)", message: "Will be removed in the next major version.")
    @MainActor
    public static func renderImageAsync(
        source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) async throws -> BMImage? {
        try await renderImage(source: source, theme: theme, scale: scale)
    }
    #endif

    #if canImport(CoreGraphics)
    @available(*, deprecated, renamed: "renderSVG(source:theme:layoutConfig:)", message: "Will be removed in the next major version.")
    public static func renderSVGAsync(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await renderSVG(source: source, theme: theme)
    }

    @available(*, deprecated, renamed: "renderASCII(source:theme:)", message: "renderASCII now returns AsciiRenderOutput; access `.text` for the previous String shape. Will be removed in the next major version.")
    public static func renderASCIIAsync(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await renderASCII(source: source, theme: theme).text
    }
    #endif

    #if canImport(CoreGraphics)
    @available(*, deprecated, renamed: "prepare(source:theme:layoutConfig:)", message: "Will be removed in the next major version.")
    public static func prepareAsync(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> PreparedDiagram {
        try await prepare(source: source, theme: theme)
    }
    #endif
}

extension String {
    public func parseDiagram() async throws -> DiagramDocument {
        try await DiagramEngine.parse(self)
    }

    @available(*, deprecated, renamed: "parseDiagram()", message: "Will be removed in the next major version.")
    public func parseMermaid() async throws -> DiagramDocument {
        try await parseDiagram()
    }

    #if canImport(CoreGraphics)
    @MainActor
    public func renderDiagramImage(
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) async throws -> BMImage? {
        try await DiagramEngine.renderImage(source: self, theme: theme, scale: scale)
    }

    @available(*, deprecated, renamed: "renderDiagramImage(theme:scale:)", message: "Will be removed in the next major version.")
    @MainActor
    public func renderMermaidImage(
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) async throws -> BMImage? {
        try await renderDiagramImage(theme: theme, scale: scale)
    }
    #endif

    #if canImport(CoreGraphics)
    public func renderDiagramSVG(
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) async throws -> String {
        try await DiagramEngine.renderSVG(
            source: self,
            theme: theme,
            layoutConfig: layoutConfig
        )
    }

    @available(*, deprecated, renamed: "renderDiagramSVG(theme:layoutConfig:)", message: "Will be removed in the next major version.")
    public func renderMermaidSVG(
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) async throws -> String {
        try await renderDiagramSVG(theme: theme, layoutConfig: layoutConfig)
    }

    public func renderDiagramASCII(
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await DiagramEngine.renderASCII(source: self, theme: theme).text
    }

    @available(*, deprecated, renamed: "renderDiagramASCII(theme:)", message: "Will be removed in the next major version.")
    public func renderMermaidASCII(
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await renderDiagramASCII(theme: theme)
    }
    #endif
}

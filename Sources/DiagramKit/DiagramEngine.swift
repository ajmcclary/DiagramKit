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

/// Main entry point for parsing, layout, and rendering diagrams.
public struct DiagramEngine {
    /// Library version. Reads the `VERSION` resource bundled with
    /// `DiagramKitCommon` (Linux + Apple). To update the version, edit
    /// `Sources/DiagramKitCommon/Resources/VERSION` (or tag a release commit
    /// if a build-time script regenerates it).
    public static let version: String = DiagramKitVersion.current
    public static let supportedDiagramTypes: [DiagramType] = DiagramType.allCases

    /// Returns whether `family` is supported on Linux, and if not, the
    /// human-readable reason. On non-Linux platforms always returns
    /// `(true, nil)` — the contract is "would a renderSVG/renderASCII call
    /// for this family throw `DiagramError.unsupportedOnPlatform` on Linux?"
    public static func linuxSupport(for family: DiagramType) -> (supported: Bool, reason: String?) {
        guard let descriptor = DiagramRegistry.all.first(where: { $0.type == family }) else {
            return (true, nil)
        }
        return (descriptor.linuxSupport, descriptor.linuxUnsupportedReason)
    }

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

    /// Parse a diagram, auto-detecting its source format.
    public static func parse(_ source: String) async throws -> DiagramDocument {
        #if canImport(CoreGraphics)
        _ = _DiagramPreparerBootstrap.didInstall
        #endif
        return try await _runOnWorker {
            try DiagramPipeline.parse(source)
        }
    }

    /// Parse a diagram using an authoritative source format.
    public static func parse(
        _ source: String,
        as sourceFormat: DiagramFormatID
    ) async throws -> DiagramDocument {
        #if canImport(CoreGraphics)
        _ = _DiagramPreparerBootstrap.didInstall
        #endif
        return try await _runOnWorker {
            try DiagramPipeline.parse(source, as: sourceFormat)
        }
    }

    /// Parse and layout a diagram.
    public static func layout(
        _ source: String,
        config: LayoutConfig = LayoutConfig(),
        sourceFormat: DiagramFormatID? = nil
    ) async throws -> PositionedGraph {
        #if canImport(CoreGraphics)
        _ = _DiagramPreparerBootstrap.didInstall
        #endif
        return try await _runOnWorker {
            try DiagramPipeline.layout(source, config: config, sourceFormat: sourceFormat)
        }
    }

    #if canImport(CoreGraphics)
    /// Prepare a diagram for direct CGContext rendering.
    public static func prepare(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        sourceFormat: DiagramFormatID? = nil
    ) async throws -> PreparedDiagram {
        _ = _DiagramPreparerBootstrap.didInstall
        return try await _runOnWorker {
            try DiagramPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig,
                sourceFormat: sourceFormat
            )
        }
    }

    /// Render directly to a CGContext.
    @MainActor
    public static func render(
        source: String,
        in context: CGContext,
        bounds: CGRect,
        theme: DiagramTheme = .default,
        sourceFormat: DiagramFormatID? = nil
    ) async throws {
        let prepared = try await prepare(source: source, theme: theme, sourceFormat: sourceFormat)
        prepared.render(in: context, bounds: bounds)
    }

    /// Render a diagram to a native image.
    @MainActor
    public static func renderImage(
        source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0,
        sourceFormat: DiagramFormatID? = nil
    ) async throws -> BMImage? {
        _ = _DiagramPreparerBootstrap.didInstall
        let renderer = DiagramImageRenderer(theme: theme)
        renderer.sourceFormat = sourceFormat
        renderer.scale = scale
        return try await renderer.renderImage(from: source)
    }

    /// Render a diagram to a native image with specific size.
    @MainActor
    public static func renderImage(
        source: String,
        size: CGSize,
        theme: DiagramTheme = .default,
        sourceFormat: DiagramFormatID? = nil
    ) async throws -> BMImage? {
        _ = _DiagramPreparerBootstrap.didInstall
        let renderer = DiagramImageRenderer(theme: theme)
        renderer.sourceFormat = sourceFormat
        return try await renderer.renderImage(from: source, size: size)
    }
    #endif

    /// Render a diagram to an SVG string.
    public static func renderSVG(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        idPolicy: SVGIDPolicy = .unique,
        sourceFormat: DiagramFormatID? = nil
    ) async throws -> String {
        #if canImport(CoreGraphics)
        _ = _DiagramPreparerBootstrap.didInstall
        #endif
        return try await _runOnWorker {
            try DiagramPipeline.renderSVG(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig,
                idPolicy: idPolicy,
                sourceFormat: sourceFormat
            )
        }
    }

    /// Render a diagram to an ASCII/Unicode string paired with any
    /// diagnostics emitted during parse / layout / ASCII rendering. Callers
    /// that only want the rendered text can access `.text`.
    ///
    /// `registry` mirrors `renderSVG(source:…)` so non-Mermaid sources can
    /// be resolved by a custom `ImporterRegistry`. Closes the source-side
    /// half of audit P1; the structured document-aware path (audit A1) is
    /// still open.
    public static func renderASCII(
        source: String,
        theme: DiagramTheme = .default,
        sourceFormat: DiagramFormatID? = nil,
        registry: ImporterRegistry = DiagramPipeline.defaultRegistry
    ) async throws -> AsciiRenderOutput {
        #if canImport(CoreGraphics)
        _ = _DiagramPreparerBootstrap.didInstall
        #endif
        return try await _runOnWorker {
            try DiagramPipeline.renderASCII(
                source: source,
                theme: theme,
                sourceFormat: sourceFormat,
                registry: registry
            )
        }
    }

    /// Parse `source` and return the full `DiagramImportResult`, including
    /// any diagnostics surfaced by the matched importer. Use this when you
    /// need the diagnostics without going through `prepare(...)`.
    public static func parseImportResult(
        source: String,
        sourceFormat: DiagramFormatID? = nil,
        registry: ImporterRegistry = DiagramPipeline.defaultRegistry
    ) async throws -> DiagramImportResult {
        #if canImport(CoreGraphics)
        _ = _DiagramPreparerBootstrap.didInstall
        #endif
        return try await _runOnWorker {
            if let sourceFormat {
                return try DiagramLoader.parse(source, as: sourceFormat, registry: registry)
            }
            return try DiagramLoader.parseImportResult(source, registry: registry)
        }
    }

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

extension String {
    /// Parse this string as diagram source, optionally forcing a
    /// specific `sourceFormat`. Convenience wrapper over
    /// `DiagramEngine.parse(_:)` / `parse(_:as:)`.
    public func parseDiagram(sourceFormat: DiagramFormatID? = nil) async throws -> DiagramDocument {
        if let sourceFormat {
            return try await DiagramEngine.parse(self, as: sourceFormat)
        }
        return try await DiagramEngine.parse(self)
    }

    #if canImport(CoreGraphics)
    /// Parse + lay out + render this string to a `BMImage`. Apple-only.
    /// Convenience wrapper over `DiagramEngine.renderImage(source:…)`.
    @MainActor
    public func renderDiagramImage(
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0,
        sourceFormat: DiagramFormatID? = nil
    ) async throws -> BMImage? {
        try await DiagramEngine.renderImage(
            source: self,
            theme: theme,
            scale: scale,
            sourceFormat: sourceFormat
        )
    }
    #endif

    /// Parse + lay out + render this string to SVG markup. Convenience
    /// wrapper over `DiagramEngine.renderSVG(source:…)`. Available on
    /// Linux as well as Apple.
    public func renderDiagramSVG(
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        sourceFormat: DiagramFormatID? = nil
    ) async throws -> String {
        try await DiagramEngine.renderSVG(
            source: self,
            theme: theme,
            layoutConfig: layoutConfig,
            sourceFormat: sourceFormat
        )
    }

    /// Parse + lay out + render this string to ASCII art (just the
    /// text, no diagnostics). Use `DiagramEngine.renderASCII(source:…)`
    /// directly if you need the `AsciiRenderOutput` tuple with
    /// diagnostics.
    public func renderDiagramASCII(
        theme: DiagramTheme = .default,
        sourceFormat: DiagramFormatID? = nil
    ) async throws -> String {
        try await DiagramEngine.renderASCII(
            source: self,
            theme: theme,
            sourceFormat: sourceFormat
        ).text
    }
}

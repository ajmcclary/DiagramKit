import Foundation
import DiagramKitModel
import CoreGraphics
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Main entry point for parsing, layout, and rendering Mermaid diagrams.
public struct MermaidRenderer {
    /// Library version. Set via the `VERSION` file at the package root or `git describe --tags`.
    /// To update: edit the `VERSION` file or tag a release commit.
    public static let version: String = {
        if let url = Bundle.module.url(forResource: "VERSION", withExtension: nil),
           let v = try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !v.isEmpty {
            return v
        }
        return "0.1.1"
    }()
    public static let supportedDiagramTypes: [DiagramType] = DiagramType.allCases

    /// Parse a Mermaid diagram.
    public static func parse(_ source: String) async throws -> MermaidGraph {
        try await _runOnWorker {
            try MermaidPipeline.parse(source)
        }
    }

    /// Parse and layout a Mermaid diagram.
    public static func layout(
        _ source: String,
        config: LayoutConfig = LayoutConfig()
    ) async throws -> PositionedGraph {
        try await _runOnWorker {
            try MermaidPipeline.layout(source, config: config)
        }
    }

    /// Prepare a Mermaid diagram for direct CGContext rendering.
    public static func prepare(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) async throws -> PreparedDiagram {
        try await _runOnWorker {
            try MermaidPipeline.prepare(
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
        let renderer = MermaidImageRenderer(theme: theme)
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
        let renderer = MermaidImageRenderer(theme: theme)
        return try await renderer.renderImage(from: source, size: size)
    }

    /// Render a Mermaid diagram to an SVG string.
    public static func renderSVG(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await _runOnWorker {
            try MermaidPipeline.renderSVG(source: source, theme: theme)
        }
    }

    /// Render a Mermaid diagram to an ASCII/Unicode string.
    public static func renderASCII(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await _runOnWorker {
            try MermaidPipeline.renderASCII(source: source, theme: theme)
        }
    }

    /// Executes `work` on a fresh `Thread` with an 8 MB stack.
    ///
    /// Layout occasionally exceeds the cooperative thread pool's ~512 KB stack
    /// budget (this was empirically observed during the early port of
    /// flowchart layout, which recurses through nested subgraphs). A reusable
    /// worker pool was attempted in commit `ff2622b` and reverted shortly
    /// after — the per-call thread cost is on the order of microseconds and at
    /// the steady-state rate this library is used (well under 100 renders/min)
    /// the simpler "spawn-per-call" model is the right trade-off. Revisit only
    /// if profiling shows thread spawn dominates measured runtime.
    ///
    /// Both `MermaidRenderer.*` and `MermaidImageRenderer.*` route through
    /// this single helper, so all dispatch to the 8 MB stack happens here.
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
            thread.name = "BeautifulMermaid worker"
            thread.stackSize = 8 * 1024 * 1024
            thread.start()
        }
    }
}

extension MermaidRenderer {
    @available(*, deprecated, renamed: "renderImage(source:theme:scale:)")
    @MainActor
    public static func renderImageAsync(
        source: String,
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) async throws -> BMImage? {
        try await renderImage(source: source, theme: theme, scale: scale)
    }

    @available(*, deprecated, renamed: "renderSVG(source:theme:)")
    public static func renderSVGAsync(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await renderSVG(source: source, theme: theme)
    }

    @available(*, deprecated, renamed: "renderASCII(source:theme:)")
    public static func renderASCIIAsync(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await renderASCII(source: source, theme: theme)
    }

    @available(*, deprecated, renamed: "prepare(source:theme:layoutConfig:)")
    public static func prepareAsync(
        source: String,
        theme: DiagramTheme = .default
    ) async throws -> PreparedDiagram {
        try await prepare(source: source, theme: theme)
    }
}

extension String {
    public func parseMermaid() async throws -> MermaidGraph {
        try await MermaidRenderer.parse(self)
    }

    @MainActor
    public func renderMermaidImage(
        theme: DiagramTheme = .default,
        scale: CGFloat = 2.0
    ) async throws -> BMImage? {
        try await MermaidRenderer.renderImage(source: self, theme: theme, scale: scale)
    }

    public func renderMermaidSVG(
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await MermaidRenderer.renderSVG(source: self, theme: theme)
    }

    public func renderMermaidASCII(
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await MermaidRenderer.renderASCII(source: self, theme: theme)
    }
}

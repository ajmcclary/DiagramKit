// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
// Extracted from Views/DiagramLayer.swift during Stage 1 module split.
// PreparedDiagram is the bridge type between layout output and CGContext
// rendering; it lives in DiagramKitRenderingCG so both BeautifulMermaid
// (umbrella in Stage 1) and DiagramKitViews can consume it.

import Foundation
import DiagramKitCommon
import DiagramKitModel
import CoreGraphics

/// A prepared diagram ready for direct CGContext rendering
public struct PreparedDiagram: Sendable {
    /// The bounds of the diagram content
    public let bounds: CGRect
    public let positioned: PositionedGraph
    public let theme: DiagramTheme
    /// Aggregated `importDiagnostics + positioned.diagnostics` in that order.
    /// The ASCII path returns `AsciiRenderOutput` instead; see the design
    /// spec at docs/superpowers/specs/2026-05-14-parser-diagnostics-surfacing-design.md.
    public let diagnostics: [DiagramDiagnostic]

    public init(
        positioned: PositionedGraph,
        theme: DiagramTheme,
        importDiagnostics: [DiagramDiagnostic] = []
    ) {
        self.bounds = CGRect(
            x: 0,
            y: 0,
            width: max(1, positioned.width),
            height: max(1, positioned.height)
        )
        self.positioned = positioned
        self.theme = theme
        self.diagnostics = importDiagnostics + positioned.diagnostics
    }

    @MainActor
    public func render(in context: CGContext, bounds renderBounds: CGRect) {
        DiagramRenderer(theme: theme).render(positioned, in: context, bounds: renderBounds)
    }
}
#endif

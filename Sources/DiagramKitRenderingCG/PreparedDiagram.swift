// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
// Extracted from Views/MermaidLayer.swift during Stage 1 module split.
// PreparedDiagram is the bridge type between layout output and CGContext
// rendering; it lives in DiagramKitRenderingCG so both BeautifulMermaid
// (umbrella in Stage 1) and DiagramKitViews can consume it.

import Foundation
import DiagramKitModel
import CoreGraphics

/// A prepared diagram ready for direct CGContext rendering
public struct PreparedDiagram: Sendable {
    /// The bounds of the diagram content
    public let bounds: CGRect
    public let positioned: PositionedGraph
    public let theme: DiagramTheme

    public init(positioned: PositionedGraph, theme: DiagramTheme) {
        self.bounds = CGRect(
            x: 0,
            y: 0,
            width: max(1, positioned.width),
            height: max(1, positioned.height)
        )
        self.positioned = positioned
        self.theme = theme
    }

    @MainActor
    public func render(in context: CGContext, bounds renderBounds: CGRect) {
        DiagramRenderer(theme: theme).render(positioned, in: context, bounds: renderBounds)
    }
}
#endif

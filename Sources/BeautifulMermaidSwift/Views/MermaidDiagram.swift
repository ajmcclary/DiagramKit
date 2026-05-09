import SwiftUI
import CoreGraphics
import DiagramKitCommon

/// A value-type model that manages the Mermaid diagram pipeline.
@MainActor
public struct MermaidDiagram {
    public var source: String
    public var theme: DiagramTheme
    public var layoutConfig: LayoutConfig

    public private(set) var parseError: Error?
    public private(set) var diagramBounds: CGRect = .zero
    public private(set) var preparedDiagram: PreparedDiagram?

    public init(
        source: String = "",
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
    }

    /// Parse and layout the current source.
    public mutating func prepare() async {
        parseError = nil

        guard !source.isEmpty else {
            preparedDiagram = nil
            diagramBounds = .zero
            return
        }

        do {
            let prepared = try MermaidPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig
            )
            preparedDiagram = prepared
            diagramBounds = prepared.bounds
        } catch {
            _reportMermaidIssueIfNeeded(error, operation: "MermaidDiagram.prepare")
            parseError = error
        }
    }
}

// MARK: - MermaidDiagramView convenience init for the value-type model

#if canImport(UIKit)
import UIKit

@available(iOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
extension MermaidDiagramView {
    /// Create a diagram view driven by a ``MermaidDiagram`` value.
    public init(_ diagram: MermaidDiagram) {
        self.init(
            source: diagram.source,
            theme: diagram.theme,
            layoutConfig: diagram.layoutConfig
        )
    }
}

#elseif canImport(AppKit)
import AppKit

@available(macOS 26.0, *)
extension MermaidDiagramView {
    /// Create a diagram view driven by a ``MermaidDiagram`` value.
    public init(_ diagram: MermaidDiagram) {
        self.init(
            source: diagram.source,
            theme: diagram.theme,
            layoutConfig: diagram.layoutConfig
        )
    }
}

#endif

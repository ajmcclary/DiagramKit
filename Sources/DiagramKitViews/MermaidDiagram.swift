// Apple-only SwiftUI/UIView wrappers gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import SwiftUI
import CoreGraphics
import DiagramKitCommon
import DiagramKitModel
import DiagramKitRenderingCG

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
    ///
    /// Dispatches to `MermaidPreparation.prepare`, which routes onto the
    /// 8 MB-stack worker thread. The actual parse/layout therefore runs
    /// off the main actor; only the result publication happens on the
    /// main actor.
    public mutating func prepare() async {
        parseError = nil

        guard !source.isEmpty else {
            preparedDiagram = nil
            diagramBounds = .zero
            return
        }

        let snapshotSource = source
        let snapshotTheme = theme
        let snapshotConfig = layoutConfig

        // `MermaidViewPreparerEnvironment` is configured by the umbrella's
        // `_MermaidPreparerBootstrap` on the first call to any public
        // `MermaidRenderer.*` API. Hosts that bypass the umbrella public
        // API (e.g. construct `MermaidDiagram` before any `MermaidRenderer.*`
        // call) must call `MermaidRenderer.bootstrap()` once at startup,
        // or configure the environment directly.
        guard let preparer = MermaidViewPreparerEnvironment.current else {
            preconditionFailure("""
                MermaidDiagram: MermaidViewPreparerEnvironment is not configured. \
                Call `MermaidRenderer.bootstrap()` once at startup, or call \
                any `MermaidRenderer.*` API to install the default preparer \
                automatically.
                """)
        }

        do {
            let prepared = try await preparer.prepare(snapshotSource, snapshotTheme, snapshotConfig)
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
#endif

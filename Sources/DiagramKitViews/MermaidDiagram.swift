// Apple-only SwiftUI/UIView wrappers gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import SwiftUI
import CoreGraphics
import DiagramKitCommon
import DiagramKitModel
import DiagramKitRenderingCG

/// A value-type model that manages the Mermaid diagram pipeline.
@MainActor
public struct DiagramViewModel {
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
    /// Dispatches to `DiagramPreparation.prepare`, which routes onto the
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

        let preparer = DiagramViewPreparerEnvironment.current

        do {
            let prepared = if let preparer {
                try await preparer.prepare(snapshotSource, snapshotTheme, snapshotConfig)
            } else {
                try await DiagramPreparation.prepare(
                    source: snapshotSource,
                    theme: snapshotTheme,
                    layoutConfig: snapshotConfig
                )
            }
            preparedDiagram = prepared
            diagramBounds = prepared.bounds
        } catch {
            _reportDiagramIssueIfNeeded(error, operation: "DiagramViewModel.prepare")
            parseError = error
        }
    }
}

// MARK: - Phase 0 backward-compat deprecated alias

@available(*, deprecated, renamed: "DiagramViewModel")
public typealias MermaidDiagram = DiagramViewModel

// MARK: - DiagramView convenience init for the value-type model

#if canImport(UIKit)
import UIKit

@available(iOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
extension DiagramView {
    /// Create a diagram view driven by a ``DiagramViewModel`` value.
    public init(_ diagram: DiagramViewModel) {
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
extension DiagramView {
    /// Create a diagram view driven by a ``DiagramViewModel`` value.
    public init(_ diagram: DiagramViewModel) {
        self.init(
            source: diagram.source,
            theme: diagram.theme,
            layoutConfig: diagram.layoutConfig
        )
    }
}

#endif
#endif

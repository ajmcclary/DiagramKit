// Apple-only SwiftUI/UIView wrappers gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import SwiftUI
import CoreGraphics
import DiagramKitCommon
import DiagramKitModel
import DiagramKitRenderingCG

/// An observable model object that manages the diagram pipeline.
///
/// A reference type on purpose (M-CG-5): a `mutating` `prepare()` on the
/// former value type was an exclusivity trap — two overlapping `prepare()`
/// calls on copies of the struct could each mutate their own copy and lose
/// updates. `DiagramViewModel` is now a `@MainActor` class so `prepare()`
/// mutates one shared instance. This is a source-breaking change for
/// callers that relied on value semantics (copying, `let` vs `var` is now
/// irrelevant); the initializer and property surface are unchanged.
@MainActor
public final class DiagramViewModel {
    public var source: String
    public var theme: DiagramTheme
    public var layoutConfig: LayoutConfig
    public var sourceFormat: DiagramFormatID?

    public private(set) var parseError: Error?
    public private(set) var diagramBounds: CGRect = .zero
    public private(set) var preparedDiagram: PreparedDiagram?

    public init(
        source: String = "",
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        sourceFormat: DiagramFormatID? = nil
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
        self.sourceFormat = sourceFormat
    }

    /// Parse and layout the current source.
    ///
    /// Dispatches to `DiagramPreparation.prepare`, which routes onto the
    /// 8 MB-stack worker thread. The actual parse/layout therefore runs
    /// off the main actor; only the result publication happens on the
    /// main actor.
    public func prepare() async {
        parseError = nil

        guard !source.isEmpty else {
            preparedDiagram = nil
            diagramBounds = .zero
            return
        }

        let snapshotSource = source
        let snapshotTheme = theme
        let snapshotConfig = layoutConfig
        let snapshotSourceFormat = sourceFormat

        let preparer = DiagramViewPreparerEnvironment.current

        do {
            let prepared = if let preparer {
                try await preparer.prepare(
                    snapshotSource,
                    snapshotTheme,
                    snapshotConfig,
                    snapshotSourceFormat
                )
            } else {
                try await DiagramPreparation.prepare(
                    source: snapshotSource,
                    theme: snapshotTheme,
                    layoutConfig: snapshotConfig,
                    sourceFormat: snapshotSourceFormat
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

@available(*, deprecated, renamed: "DiagramViewModel", message: "Will be removed in the next major version.")
public typealias MermaidDiagram = DiagramViewModel

// MARK: - DiagramView convenience init for the model

#if canImport(UIKit)
import UIKit

@available(iOS 26.0, *)
extension DiagramView {
    /// Create a diagram view driven by a ``DiagramViewModel`` value.
    public init(_ diagram: DiagramViewModel) {
        self.init(
            source: diagram.source,
            theme: diagram.theme,
            layoutConfig: diagram.layoutConfig,
            sourceFormat: diagram.sourceFormat
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
            layoutConfig: diagram.layoutConfig,
            sourceFormat: diagram.sourceFormat
        )
    }
}

#endif
#endif

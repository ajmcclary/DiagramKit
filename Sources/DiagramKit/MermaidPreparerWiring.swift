#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import DiagramKitRenderingCG

/// Composition root that hands the canonical `MermaidViewPreparer` to
/// `DiagramKitRenderingCG` so view-layer code can prepare diagrams
/// without depending on umbrella-only `MermaidPreparation`.
///
/// The default preparer routes through `MermaidPreparation.prepare`,
/// which dispatches onto the 8 MB-stack worker thread defined by
/// `MermaidRenderer._runOnWorker`. Tests can override the environment
/// directly via `MermaidViewPreparerEnvironment.configure(_:)`.
@MainActor
enum _MermaidPreparerBootstrap {

    /// Lazy installer — referenced by the umbrella's public entry points
    /// so the default preparer is wired the first time any public API
    /// runs. Subsequent references are no-ops.
    static let didInstall: Void = {
        MermaidViewPreparerEnvironment.configure(
            MermaidViewPreparer { source, theme, config in
                try await MermaidPreparation.prepare(
                    source: source,
                    theme: theme,
                    layoutConfig: config
                )
            }
        )
    }()
}
#endif

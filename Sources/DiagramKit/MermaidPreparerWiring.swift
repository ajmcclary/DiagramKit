#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import DiagramKitRenderingCG

/// Composition root that registers the canonical synchronous prepare
/// implementation with `MermaidPreparation` (in RenderingCG) and hands
/// the matching async preparer to `MermaidViewPreparerEnvironment`.
///
/// Views in `DiagramKitViews` call `MermaidPreparation.prepare(...)` —
/// which dispatches onto the 8 MB-stack worker — but the actual
/// parse/layout/prepare implementation lives in the umbrella's
/// `MermaidPipeline`. This bootstrap is the seam: the umbrella supplies
/// the implementation closure on first access, so view code never
/// reaches back into the umbrella directly.
///
/// `didInstall` is a `static let`, so the first reference triggers the
/// registration exactly once. Every public `MermaidRenderer.*` entry
/// point references it before doing work, which guarantees the
/// installation has happened by the time any user-visible API runs.
/// Tests can override the environment directly via
/// `MermaidViewPreparerEnvironment.configure(_:)` after the bootstrap
/// has installed the default.
///
/// **Concurrency Contract**: this enum is non-isolated. The
/// `didInstall` initializer only touches two thread-safe registration
/// APIs (`MermaidPreparation.registerImplementation` and
/// `MermaidViewPreparerEnvironment.configure`), each of which guards
/// its state with a lock. The Swift runtime ensures the `static let`
/// initializer fires exactly once even under concurrent first-access.
enum _MermaidPreparerBootstrap {

    static let didInstall: Void = {
        // 1. Register the synchronous pipeline implementation. View code
        //    that calls `MermaidPreparation.prepare(...)` directly will
        //    find this closure here.
        MermaidPreparation.registerImplementation { source, theme, config in
            try MermaidPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: config
            )
        }

        // 2. Configure the view-preparer environment with the same
        //    async wrapper. Tests can override this without disturbing
        //    `MermaidPreparation` itself.
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

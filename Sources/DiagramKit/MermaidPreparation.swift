// Apple-only — depends on `MermaidPipeline.prepare`, which produces a
// `PreparedDiagram` (defined in `DiagramKitRenderingCG`).
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import DiagramKitRenderingCG

/// Canonical async wrapper around `MermaidPipeline.prepare` that dispatches
/// onto the 8 MB-stack worker thread defined in
/// `MermaidRenderer._runOnWorker`.
///
/// All UI-side preparation paths (`MermaidImageRenderer`, `MermaidLayer`,
/// `MermaidDiagram`) MUST go through this entry point — never call
/// `MermaidPipeline.prepare` synchronously from `@MainActor` code, since
/// flowchart layout's recursion can exceed the cooperative pool's ~512 KB
/// stack budget on nested-subgraph diagrams.
public enum MermaidPreparation {

    public static func prepare(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) async throws -> PreparedDiagram {
        try await MermaidRenderer._runOnWorker {
            try MermaidPipeline.prepare(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig
            )
        }
    }
}
#endif

// Apple-only — depends on Foundation only; lives in RenderingCG so the
// view target can dispatch onto the canonical 8 MB-stack worker without
// reaching back into the umbrella.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitCommon

/// Worker-thread helper that runs synchronous Mermaid work on a fresh
/// `Thread` with an 8 MB stack.
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
/// All public preparation entry points
/// (`DiagramEngine.*`, `DiagramImageRenderer.*`, `DiagramPreparation.prepare`)
/// route through this helper so the 8 MB stack is the only place where
/// layout runs.
public enum DiagramWorkerThread {

    /// Run `work` on a fresh `Thread` named `"DiagramKit worker"`
    /// with an 8 MB stack.
    public static func run<T: Sendable>(
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
            thread.name = "DiagramKit worker"
            thread.stackSize = DiagramWorkerConfig.stackSize
            thread.start()
        }
    }
}

#endif

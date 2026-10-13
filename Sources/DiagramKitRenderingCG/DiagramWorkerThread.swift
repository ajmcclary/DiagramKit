// Apple-only — depends on Foundation only; lives in RenderingCG so the
// view target can dispatch onto the canonical 8 MB-stack worker without
// reaching back into the umbrella.
#if canImport(CoreGraphics)
import Foundation
import Synchronization
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
    ///
    /// Cancellation (M-CG-1):
    /// - A task that is already cancelled never spawns a thread —
    ///   `run` throws `CancellationError` up front.
    /// - The task's cancellation is forwarded to the worker as a
    ///   cooperative flag that the thread body consults at its entry
    ///   point and at completion — the cheap dispatch-boundary check,
    ///   not an inside-the-loop poll. A render whose task was cancelled
    ///   while running still finishes its current pass (the 8 MB thread
    ///   must run to completion; there is no pool to return to), but its
    ///   result is discarded with `CancellationError` instead of being
    ///   published, so a keystroke-driven caller drops superseded
    ///   renders early.
    public static func run<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try Task.checkCancellation()

        // Cooperative cancellation flag shared with the worker thread.
        // `Mutex` is `Sendable` by construction, so it is safe to touch
        // from both the task and the fresh `Thread`.
        let cancelled = Mutex<Bool>(false)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
                let thread = Thread {
                    if cancelled.withLock({ $0 }) {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    do {
                        let value = try work()
                        if cancelled.withLock({ $0 }) {
                            // Cancelled mid-render: the work ran to
                            // completion (no pool, no reuse), but the
                            // result is stale — drop it.
                            continuation.resume(throwing: CancellationError())
                        } else {
                            continuation.resume(returning: value)
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                thread.name = "DiagramKit worker"
                thread.stackSize = DiagramWorkerConfig.stackSize
                thread.start()
            }
        } onCancel: {
            cancelled.withLock { $0 = true }
        }
    }
}

#endif

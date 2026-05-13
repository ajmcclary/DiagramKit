import Foundation

/// Shared configuration constants for the per-call worker `Thread` used by
/// every public preparation entry point.
///
/// The 8 MB stack is the empirically-validated floor for the deepest
/// flowchart subgraph nesting observed in the corpus; the cooperative
/// thread pool's ~512 KB budget is not enough. A reusable pool was tried
/// and reverted (commit `ff2622b`) — the spawn-per-call model is the
/// invariant. See `CLAUDE.md` "Critical Invariants".
public enum DiagramWorkerConfig {
    /// Stack size, in bytes, for the worker `Thread`.
    public static let stackSize: Int = 8 * 1024 * 1024
}

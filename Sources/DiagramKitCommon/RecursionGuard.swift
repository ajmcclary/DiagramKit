import Foundation

/// Default depth limit for recursive layout/render passes (TreeView's
/// `processNode`, the shared `appendNode` ASCII tree util, the ELK
/// compound `_collectAllChildren` traversal). Picked to bound stack use
/// on the worker thread's 8 MB stack — empirically each frame is well
/// under 8 KB, so 1024 frames leaves multiple MB of headroom.
public let _diagramDefaultRecursionLimit: Int = 1024

/// Returns `true` when the caller is still under the recursion limit and
/// may recurse. Returns `false` (and reports the issue once) when the
/// limit has been reached; callers must stop recursing in that case.
///
/// The intent is to bound the worker-thread stack so adversarial inputs
/// (e.g. a 50 k-deep mindmap) cannot SIGSEGV the process. Truncating with
/// a reported issue is strictly better UX than the previous crash, and
/// avoids forcing the entire layout pipeline to become `throws`.
///
/// `location` should be the recursion site (e.g. `"TreeView.processNode"`)
/// so the operator can identify which path hit the cap.
@discardableResult
public func _recursionGuard(
    depth: Int,
    limit: Int = _diagramDefaultRecursionLimit,
    location: @autoclosure () -> String
) -> Bool {
    if depth < limit {
        return true
    }
    _reportDiagramIssue(
        "\(location()): recursion depth limit \(limit) reached; truncating subtree"
    )
    return false
}

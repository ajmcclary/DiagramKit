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

// MARK: - Parser input limits

/// Maximum structural nesting a parser accepts (composite blocks, class
/// namespaces, ZenUML blocks, treemap sections, C4 boundaries,
/// architecture groups). Counted in nested containers, leaves excluded,
/// and inclusive: exactly this many levels parse, one more throws. Far
/// above anything a person writes, and far below what the recursive parse
/// passes and the layouts that follow them can survive on the worker
/// thread's 8 MB stack. A parser that meets
/// deeper nesting throws `DiagramInputLimitError` instead of recursing.
public let _maxParserNestingDepth: Int = 100

/// Thrown by a parser when the source exceeds a limit that a later stage
/// could not survive: nesting deeper than `_maxParserNestingDepth`, or a
/// number outside the range the family accepts. Recoverable: callers see a
/// typed parse failure instead of a trap, hang, or stack overflow.
public struct DiagramInputLimitError: Error, LocalizedError, Equatable, Sendable, _RecoverableDiagramError {
    public enum Limit: String, Sendable, Equatable {
        case nestingDepth
        case numericRange
        /// The diagram is within the parse limits but its layout would
        /// take more work than the layout is allowed (it used to hang).
        case layoutSize
        /// The diagram laid out, but drawing it as text (ASCII) would take
        /// more work than the text renderer is allowed. SVG and image
        /// rendering of the same diagram are unaffected.
        case textDrawingSize
    }

    public let limit: Limit
    public let detail: String

    public init(_ limit: Limit, _ detail: String) {
        self.limit = limit
        self.detail = detail
    }

    public var errorDescription: String? {
        switch limit {
        case .nestingDepth:
            return "Nesting is deeper than \(_maxParserNestingDepth) levels: \(detail)"
        case .numericRange:
            return "Number out of range: \(detail)"
        case .layoutSize:
            return "The diagram is too large to lay out: \(detail)"
        case .textDrawingSize:
            return "The diagram is too large to draw as text: \(detail)"
        }
    }
}

/// Throws `DiagramInputLimitError(.nestingDepth, …)` when `depth` exceeds
/// `_maxParserNestingDepth`. Call it wherever a parser pushes a nesting
/// level or recurses into one.
public func _checkParserNestingDepth(_ depth: Int, _ context: @autoclosure () -> String) throws {
    if depth > _maxParserNestingDepth {
        throw DiagramInputLimitError(.nestingDepth, context())
    }
}

// MARK: - Trees built from imported edge lists

/// Guards a recursive tree build over a parent → children edge list that
/// came from a source file (D2 / DOT tree-view and mindmap importers). The
/// edge list is not known to be a tree: `a -> b`, `b -> a` is a cycle, and
/// a shared child is duplicated under each parent (a diamond ladder doubles
/// per rung). Children that close a cycle are skipped, depth stops at
/// `_diagramDefaultRecursionLimit`, and the whole tree at `maxNodes`; each
/// cut is reported once as a diagnostic.
public struct _ImportedTreeWalkGuard {
    public static let maxNodes = 10_000

    public private(set) var diagnostics: [DiagramDiagnostic] = []
    private var built = 0
    private var reportedCycle = false
    private var reportedDepth = false
    private var reportedSize = false
    private let family: String

    public init(family: String) {
        self.family = family
    }

    /// The children of `id` the build may visit. `ancestors` is the path
    /// from the root down to `id` (exclusive of `id`).
    public mutating func admissibleChildren(
        _ children: [String],
        of id: String,
        ancestors: Set<String>,
        depth: Int
    ) -> [String] {
        guard !children.isEmpty else { return [] }
        if depth + 1 >= _diagramDefaultRecursionLimit {
            if !reportedDepth {
                reportedDepth = true
                diagnostics.append(.featureDropped(
                    .slotUnsupported,
                    message: "\(family) is nested deeper than \(_diagramDefaultRecursionLimit) levels; deeper nodes dropped"
                ))
            }
            return []
        }
        var admitted: [String] = []
        for child in children {
            if child == id || ancestors.contains(child) {
                if !reportedCycle {
                    reportedCycle = true
                    diagnostics.append(.featureDropped(
                        .slotUnsupported,
                        message: "\(family) edge \(id) -> \(child) closes a cycle; a tree has none, so it was dropped"
                    ))
                }
                continue
            }
            if built >= Self.maxNodes {
                if !reportedSize {
                    reportedSize = true
                    diagnostics.append(.featureDropped(
                        .slotUnsupported,
                        message: "\(family) expands to more than \(Self.maxNodes) nodes; the rest were dropped"
                    ))
                }
                break
            }
            built += 1
            admitted.append(child)
        }
        return admitted
    }
}

import Foundation

/// Conformance for types that carry a 1-based source line number so the
/// recovery-marker correlator can pair markers to preceding declarations.
public protocol HasLineNumber {
    var lineNumber: Int { get }
}

/// Return the declaration in `index` whose `lineNumber` is strictly less than
/// `line` and is the highest among such declarations. Returns `nil` when no
/// declaration precedes `line`. Matches Structurizr Wave 3 semantics: a
/// recovery marker at line N applies to the latest declaration on a line `< N`.
///
/// `index` does not need to be sorted; the helper walks every element.
public func latestDeclaration<D: HasLineNumber>(
    before line: Int,
    in index: [D]
) -> D? {
    var best: D? = nil
    for decl in index where decl.lineNumber < line {
        if best == nil || decl.lineNumber > best!.lineNumber {
            best = decl
        }
    }
    return best
}

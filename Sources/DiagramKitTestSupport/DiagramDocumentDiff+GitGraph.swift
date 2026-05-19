import DiagramKitModel

func diffGitGraphDiagram(_ a: GitGraphDiagram, _ b: GitGraphDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "gitGraph.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.direction != b.direction {
        deltas.append(.unexpected(
            path: "gitGraph.direction",
            detail: "lhs=\(a.direction) rhs=\(b.direction)"
        ))
    }

    // Compare commits by (id, branch, type, tags, parents). Resolved
    // commit ordering can differ between parses, so use a normalized
    // set. Mismatches surface concrete keys.
    func commitKey(_ c: GitGraphCommit) -> String {
        let tags = c.tags.sorted().joined(separator: ",")
        let parents = c.parents.sorted().joined(separator: ",")
        return "\(c.id)|\(c.branch)|\(c.type)|tags=\(tags)|parents=\(parents)"
    }
    let lhsCommits = Set(a.commits.map(commitKey))
    let rhsCommits = Set(b.commits.map(commitKey))
    if lhsCommits != rhsCommits {
        let onlyLhs = lhsCommits.subtracting(rhsCommits).sorted()
        let onlyRhs = rhsCommits.subtracting(lhsCommits).sorted()
        deltas.append(.unexpected(
            path: "gitGraph.commits",
            detail: "onlyLhs=\(onlyLhs.joined(separator: ";")) onlyRhs=\(onlyRhs.joined(separator: ";"))"
        ))
    }

    let lhsBranches = Set(a.branches)
    let rhsBranches = Set(b.branches)
    if lhsBranches != rhsBranches {
        let onlyL = lhsBranches.subtracting(rhsBranches).sorted()
        let onlyR = rhsBranches.subtracting(lhsBranches).sorted()
        deltas.append(.unexpected(
            path: "gitGraph.branches",
            detail: "onlyLhs=\(onlyL) onlyRhs=\(onlyR)"
        ))
    }
    return deltas
}

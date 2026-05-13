import Foundation

/// Render a `GitGraphDiagram` as an ASCII commit log. Commits are
/// emitted in chronological order (by `seq`) as `* <id> [<branch>]`
/// rows with `|` continuation between commits. Multi-branch graphs
/// get a `[branch]` annotation per commit to make lanes legible.
public func renderGitGraphAscii(_ model: GitGraphDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }
    let sorted = model.commits.sorted { $0.seq < $1.seq }
    for (idx, commit) in sorted.enumerated() {
        let tagsSuffix = commit.tags.isEmpty ? "" : " (\(commit.tags.joined(separator: ", ")))"
        let branchSuffix = model.branches.count > 1 ? " [\(commit.branch)]" : ""
        let label = commit.message.isEmpty ? commit.id : commit.message
        lines.append("* \(commit.id) \(label)\(branchSuffix)\(tagsSuffix)")
        if idx < sorted.count - 1 {
            lines.append("|")
        }
    }
    return lines.joined(separator: "\n")
}

import DiagramKitCommon
import Foundation

/// Render a `C4Diagram` as a tabular list of shapes grouped by
/// boundary plus a relationships block.
public func renderC4Ascii(_ model: C4Diagram) -> String {
    var lines: [String] = []
    if let title = model.title, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(terminalDisplayWidth(title), 1)))
    }

    let boundariesById = Dictionary(model.boundaries.map { ($0.alias, $0) }, uniquingKeysWith: { first, _ in first })
    let shapesByBoundary = Dictionary(grouping: model.shapes, by: \.parentBoundary)

    // A boundary whose parent chain loops back (`Boundary(global, …)` is
    // its own parent, since every top-level boundary's parent is `global`)
    // recursed until the stack overflowed. Each alias is emitted once.
    var visited: Set<String> = []

    func emit(boundaryAlias: String, depth: Int) {
        guard visited.insert(boundaryAlias).inserted, depth < _diagramDefaultRecursionLimit else { return }
        let indent = String(repeating: "  ", count: depth)
        if boundaryAlias != "global", let boundary = boundariesById[boundaryAlias] {
            lines.append("\(indent)[\(boundary.label)]")
        }
        for shape in shapesByBoundary[boundaryAlias] ?? [] {
            let detail = shape.technology.map { " (\($0))" } ?? ""
            lines.append("\(indent)  • \(shape.label) — \(shape.typeC4Shape.rawValue)\(detail)")
        }
        let children = model.boundaries.filter { $0.parentBoundary == boundaryAlias }
        for child in children {
            emit(boundaryAlias: child.alias, depth: depth + 1)
        }
    }

    emit(boundaryAlias: "global", depth: 0)

    if !model.relationships.isEmpty {
        lines.append("")
        for rel in model.relationships {
            let tech = rel.technology.map { " (\($0))" } ?? ""
            lines.append("\(rel.from) → \(rel.to) : \(rel.label)\(tech)")
        }
    }

    return lines.joined(separator: "\n")
}

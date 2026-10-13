// ASCII renderers for the specialty chart families:
// sankey, radar, treemap, venn, quadrantChart, packet, requirement, zenuml.
//
// Each renderer takes a typed payload and emits a tabular/list-style
// summary that captures the structural information of the diagram.
// Tabular form is intentional — canvas-based ASCII would require
// substantial layout code; the value here is unambiguous textual
// inspection of a parsed model.
import DiagramKitCommon
import Foundation

public func renderSankeyAscii(_ model: SankeyDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(terminalDisplayWidth(title), 1)))
    }
    for link in model.links {
        lines.append("\(link.source) → \(link.target) : \(String(format: "%g", link.value))")
    }
    return lines.joined(separator: "\n")
}

public func renderRadarAscii(_ model: RadarDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(terminalDisplayWidth(title), 1)))
    }
    if !model.axes.isEmpty {
        lines.append("Axes: " + model.axes.map(\.label).joined(separator: ", "))
    }
    for curve in model.curves {
        let entries = curve.entries.map { String(format: "%g", $0) }.joined(separator: ", ")
        lines.append("\(curve.label) [\(entries)]")
    }
    return lines.joined(separator: "\n")
}

public func renderTreemapAscii(_ model: TreemapDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(terminalDisplayWidth(title), 1)))
    }
    func emit(_ node: TreemapNode, depth: Int) {
        let indent = String(repeating: "  ", count: depth)
        let valueText = node.value.map { " : \(String(format: "%g", $0))" } ?? ""
        lines.append("\(indent)• \(node.name)\(valueText)")
        for child in node.children ?? [] {
            emit(child, depth: depth + 1)
        }
    }
    for node in model.nodes {
        emit(node, depth: 0)
    }
    return lines.joined(separator: "\n")
}

public func renderVennAscii(_ model: VennDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(terminalDisplayWidth(title), 1)))
    }
    for area in model.areas {
        let key = area.sets.joined(separator: " ∩ ")
        let label = area.label.map { " : \($0)" } ?? ""
        lines.append("\(key) [size=\(String(format: "%g", area.size))]\(label)")
    }
    return lines.joined(separator: "\n")
}

public func renderQuadrantAscii(_ model: QuadrantChart) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle ?? model.titleText, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(terminalDisplayWidth(title), 1)))
    }
    if let l = model.xAxisLeftText, let r = model.xAxisRightText {
        lines.append("x-axis: \(l) ↔ \(r)")
    }
    if let b = model.yAxisBottomText, let t = model.yAxisTopText {
        lines.append("y-axis: \(b) ↕ \(t)")
    }
    for point in model.points {
        lines.append("• \(point.text) [\(String(format: "%g", point.x)), \(String(format: "%g", point.y))]")
    }
    return lines.joined(separator: "\n")
}

public func renderPacketAscii(_ model: PacketDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(terminalDisplayWidth(title), 1)))
    }
    for row in model.rows {
        for block in row {
            lines.append("\(block.start)-\(block.end) (\(block.bits) bit) : \(block.label)")
        }
    }
    return lines.joined(separator: "\n")
}

public func renderRequirementAscii(_ model: RequirementDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(terminalDisplayWidth(title), 1)))
    }
    if !model.requirements.isEmpty {
        lines.append("Requirements:")
        for req in model.requirements {
            lines.append("  • \(req.name) (\(req.requirementId)) — \(req.text)")
        }
    }
    if !model.elements.isEmpty {
        lines.append("Elements:")
        for elem in model.elements {
            lines.append("  • \(elem.name) [\(elem.type)]")
        }
    }
    if !model.relationships.isEmpty {
        lines.append("Relationships:")
        for rel in model.relationships {
            lines.append("  • \(rel.sourceName) -\(rel.type)- \(rel.destinationName)")
        }
    }
    return lines.joined(separator: "\n")
}

public func renderZenUMLAscii(_ model: ZenUMLDiagram) -> String {
    var lines: [String] = []
    if let title = model.title, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(terminalDisplayWidth(title), 1)))
    }
    if !model.participants.isEmpty {
        lines.append("Participants: " + model.participants.map(\.name).joined(separator: ", "))
    }
    for stmt in model.statements {
        lines.append("• \(zenStatementSummary(stmt))")
    }
    return lines.joined(separator: "\n")
}

private func zenStatementSummary(_ stmt: ZenUMLStatement) -> String {
    switch stmt {
    case .message(let from, let to, let signature, let type, _, _):
        let arrow = (type == .async) ? "-->" : "->"
        return "\(from)\(arrow)\(to): \(signature)"
    case .asyncMessage(let from, let to, let content, _):
        return "\(from)-->\(to): \(content ?? "")"
    case .creation(let assignee, _, let construct, let to, let params, _, _):
        let paramsText = params.map { "(\($0.joined(separator: ", ")))" } ?? ""
        let actor = assignee.map { "\($0)= " } ?? ""
        return "\(actor)\(construct)\(paramsText) -> \(to)"
    case .return(let from, let to, let value, _):
        return "\(from)-->\(to): \(value ?? "")"
    case .fragment(let kind, let condition, _):
        return condition.map { "\(kind.rawValue) [\($0)]" } ?? kind.rawValue
    case .divider(let label):
        return "--- \(label) ---"
    case .comment(let text):
        return "note: \(text)"
    }
}

import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `architecture-beta` source from an `ArchitectureDiagram`.
///
/// Lossless: `architecture-beta` header → optional `title` →
/// accessibility metadata → groups (`group <id>(<icon>)[<title>] in
/// <parent>`) → services (`service <id>(<icon>|"<text>")[<title>]
/// in <parent>`) → junctions (`junction <id> in <parent>`) → edges
/// (`<lhs>[{group}]:<dir>[<-][-[<label>]-|--][>]<dir>:<rhs>[{group}]`).
///
/// Icons emit as `(<iconName>)`; iconText emits as `("<text>")` per
/// the architecture parser's icon-section grammar.
enum MermaidArchitectureExport {

    static func emit(_ model: ArchitectureDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["architecture-beta"]
        var diagnostics: [DiagramDiagnostic] = []

        // Cross-format shape-flattening: Mermaid architecture has no shape
        // vocabulary; any non-.service kind flattens to `service` with a
        // typed .shapeDowngrade diagnostic per affected entity.
        let nonServiceKinds: Set<ArchitectureServiceKind> = [
            .component, .interface,
            .node, .artifact, .database, .cloud, .frame, .folder,
            .package, .card, .queue, .stack, .storage, .agent,
            .actor, .boundary
        ]
        for service in model.services where nonServiceKinds.contains(service.kind) {
            diagnostics.append(.lossyTransform(
                .shapeDowngrade,
                message: "kind=\(service.kind.rawValue) downgraded to service for mermaid architecture"
            ))
        }

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        // Groups: any group used as a parentGroupId must be declared
        // before its child references it.
        for group in orderedByParentChain(model.groups) {
            var line = "    group \(group.id)"
            if let icon = group.icon, !icon.isEmpty {
                line += "(\(icon))"
            }
            if let title = group.title, !title.isEmpty {
                line += "[\(escapeBracketTitle(title))]"
            }
            if let parent = group.parentGroupId, !parent.isEmpty {
                line += " in \(parent)"
            }
            lines.append(line)
        }

        for service in model.services {
            var line = "    service \(service.id)"
            if let icon = service.icon, !icon.isEmpty {
                line += "(\(icon))"
            } else if let iconText = service.iconText, !iconText.isEmpty {
                line += "(\"\(escapeQuotedTitle(iconText))\")"
            }
            if let title = service.title, !title.isEmpty {
                line += "[\(escapeBracketTitle(title))]"
            }
            if let parent = service.parentGroupId, !parent.isEmpty {
                line += " in \(parent)"
            }
            lines.append(line)
        }

        for junction in model.junctions {
            var line = "    junction \(junction.id)"
            if let parent = junction.parentGroupId, !parent.isEmpty {
                line += " in \(parent)"
            }
            lines.append(line)
        }

        for edge in model.edges {
            let lhsPart = "\(edge.lhsId)\(edge.lhsGroupBoundary ? "{group}" : ""):\(edge.lhsDirection.rawValue)"
            let rhsPart = "\(edge.rhsDirection.rawValue):\(edge.rhsId)\(edge.rhsGroupBoundary ? "{group}" : "")"
            let arrow = arrowToken(
                sourceArrow: edge.sourceArrow,
                targetArrow: edge.targetArrow,
                label: edge.label
            )
            lines.append("    \(lhsPart) \(arrow) \(rhsPart)")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // Topological sort: groups whose parentGroupId references another
    // group must come after their parent.
    private static func orderedByParentChain(_ groups: [ArchitectureGroup]) -> [ArchitectureGroup] {
        var remaining = groups
        var emitted: Set<String> = []
        var result: [ArchitectureGroup] = []
        var safety = groups.count * 2
        while !remaining.isEmpty && safety > 0 {
            safety -= 1
            let readyIdx = remaining.firstIndex { g in
                guard let p = g.parentGroupId, !p.isEmpty else { return true }
                return emitted.contains(p)
            }
            if let idx = readyIdx {
                let g = remaining.remove(at: idx)
                emitted.insert(g.id)
                result.append(g)
            } else {
                result.append(contentsOf: remaining)
                break
            }
        }
        return result
    }

    private static func arrowToken(
        sourceArrow: Bool,
        targetArrow: Bool,
        label: String?
    ) -> String {
        var head = ""
        if sourceArrow { head = "<" }
        let body: String
        if let label, !label.isEmpty {
            body = "-[\(escapeBracketTitle(label))]-"
        } else {
            body = "--"
        }
        var tail = ""
        if targetArrow { tail = ">" }
        return "\(head)\(body)\(tail)"
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escapeBracketTitle(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escapeQuotedTitle(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}

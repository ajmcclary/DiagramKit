import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Line-oriented parser for PlantUML deployment-diagram bodies.
/// Produces a `PlantUMLDeploymentAST` via `parse(_:)`.
public struct PlantUMLDeploymentParser {

    public init() {}

    public enum Error: Swift.Error, Equatable {
        case malformedShape(line: String)
        case unmatchedBlockClose(line: String)
    }

    static let keywordToKind: [String: ArchitectureServiceKind] = [
        "node": .node, "artifact": .artifact, "database": .database,
        "cloud": .cloud, "frame": .frame, "folder": .folder,
        "package": .package, "card": .card, "queue": .queue,
        "stack": .stack, "storage": .storage, "agent": .agent,
        "actor": .actor, "boundary": .boundary,
        "component": .component, "interface": .interface
    ]

    private enum ParsedLine {
        case openGroup(PlantUMLDeploymentAST.Group)
        case shape(PlantUMLDeploymentAST.Shape)
    }

    public func parse(_ body: String) throws -> PlantUMLDeploymentAST {
        var rootContainer: [PlantUMLDeploymentAST.Node] = []
        var groupStack: [(group: PlantUMLDeploymentAST.Group, children: [PlantUMLDeploymentAST.Node])] = []
        var edges: [PlantUMLDeploymentAST.Edge] = []
        var notes: [PlantUMLDeploymentAST.NoteAttachment] = []
        var legend: String? = nil
        var pendingNote: (serviceId: String, position: String, lines: [String])? = nil
        var pendingLegendLines: [String]? = nil

        for rawLine in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("'") { continue }
            if line.hasPrefix("@") { continue }

            // Multi-line block accumulation (note, legend) takes priority
            if pendingNote != nil {
                if line == "end note" {
                    let p = pendingNote!
                    notes.append(.init(
                        serviceId: p.serviceId,
                        position: p.position,
                        body: p.lines.joined(separator: "\n")
                    ))
                    pendingNote = nil
                } else {
                    pendingNote!.lines.append(line)
                }
                continue
            }
            if pendingLegendLines != nil {
                if line == "endlegend" {
                    legend = pendingLegendLines!.joined(separator: "\n")
                    pendingLegendLines = nil
                } else {
                    pendingLegendLines!.append(line)
                }
                continue
            }
            if line == "legend" {
                pendingLegendLines = []
                continue
            }
            if line.hasPrefix("note ") {
                let tokens = line.split(separator: " ")
                if tokens.count >= 4, tokens[2] == "of" {
                    pendingNote = (
                        serviceId: String(tokens[3]),
                        position: String(tokens[1]),
                        lines: []
                    )
                    continue
                }
            }

            if line == "}" {
                guard let top = groupStack.popLast() else {
                    throw Error.unmatchedBlockClose(line: line)
                }
                let completed = PlantUMLDeploymentAST.Group(
                    id: top.group.id, label: top.group.label, kind: top.group.kind,
                    stereotype: top.group.stereotype, color: top.group.color,
                    children: top.children
                )
                if !groupStack.isEmpty {
                    groupStack[groupStack.count - 1].children.append(.group(completed))
                } else {
                    rootContainer.append(.group(completed))
                }
                continue
            }

            if let parsed = try parseShapeOrGroupLine(line) {
                switch parsed {
                case .openGroup(let group):
                    groupStack.append((group, []))
                case .shape(let shape):
                    if !groupStack.isEmpty {
                        groupStack[groupStack.count - 1].children.append(.shape(shape))
                    } else {
                        rootContainer.append(.shape(shape))
                    }
                }
                continue
            }

            if let edge = parseEdgeLine(line) {
                edges.append(edge)
                continue
            }
        }

        return PlantUMLDeploymentAST(
            roots: rootContainer, edges: edges,
            notes: notes, legend: legend
        )
    }

    private func parseEdgeLine(_ line: String) -> PlantUMLDeploymentAST.Edge? {
        // Longest-match-first arrow detection
        let arrowCandidates: [(token: String, direction: PlantUMLDeploymentAST.EdgeDirection, style: PlantUMLDeploymentAST.EdgeStyle)] = [
            ("<-->", .both, .solid),
            ("..>", .forward, .dashed),
            ("<..", .backward, .dashed),
            ("-->", .forward, .solid),
            ("<--", .backward, .solid)
        ]
        for candidate in arrowCandidates {
            if let arrowRange = line.range(of: candidate.token) {
                let lhs = line[..<arrowRange.lowerBound].trimmingCharacters(in: .whitespaces)
                let rhsAndExtra = line[arrowRange.upperBound...].trimmingCharacters(in: .whitespaces)
                var label: String? = nil
                var stereotype: String? = nil

                if let colonIdx = rhsAndExtra.firstIndex(of: ":") {
                    let rhsId = rhsAndExtra[..<colonIdx].trimmingCharacters(in: .whitespaces)
                    var afterColon = String(rhsAndExtra[rhsAndExtra.index(after: colonIdx)...])
                        .trimmingCharacters(in: .whitespaces)
                    if let stereoStart = afterColon.range(of: "<<"),
                       let stereoEnd = afterColon.range(of: ">>", range: stereoStart.upperBound..<afterColon.endIndex) {
                        stereotype = String(afterColon[stereoStart.upperBound..<stereoEnd.lowerBound])
                        afterColon = String(afterColon[..<stereoStart.lowerBound]).trimmingCharacters(in: .whitespaces)
                    }
                    label = afterColon.isEmpty ? nil : afterColon
                    return .init(
                        lhsId: lhs, rhsId: rhsId,
                        direction: candidate.direction, style: candidate.style,
                        label: label, stereotype: stereotype
                    )
                } else {
                    let rhsId = rhsAndExtra
                    return .init(
                        lhsId: lhs, rhsId: rhsId,
                        direction: candidate.direction, style: candidate.style,
                        label: nil, stereotype: nil
                    )
                }
            }
        }
        return nil
    }

    private func parseShapeOrGroupLine(_ line: String) throws -> ParsedLine? {
        guard let space = line.firstIndex(of: " ") else { return nil }
        let keyword = String(line[..<space])
        guard let kind = Self.keywordToKind[keyword] else { return nil }
        let rest = line[line.index(after: space)...].trimmingCharacters(in: .whitespaces)

        let opensBlock = rest.hasSuffix("{")
        let body = opensBlock
            ? String(rest.dropLast()).trimmingCharacters(in: .whitespaces)
            : rest

        var label: String? = nil
        var id: String = ""
        var cursor = Substring(body)

        if cursor.first == "\"" {
            let afterOpen = cursor.index(after: cursor.startIndex)
            guard let closeIdx = cursor[afterOpen...].firstIndex(of: "\"") else {
                throw Error.malformedShape(line: line)
            }
            label = String(cursor[afterOpen..<closeIdx])
            cursor = cursor[cursor.index(after: closeIdx)...].drop(while: { $0 == " " })
        }

        if cursor.hasPrefix("as ") {
            let aliasStart = cursor.index(cursor.startIndex, offsetBy: 3)
            let aliasEnd = cursor[aliasStart...].firstIndex(where: { $0 == " " }) ?? cursor.endIndex
            id = String(cursor[aliasStart..<aliasEnd])
            cursor = cursor[aliasEnd...].drop(while: { $0 == " " })
        } else if let lbl = label {
            id = lbl.lowercased()
                .map { $0.isLetter || $0.isNumber ? $0 : "_" }
                .reduce("") { $0 + String($1) }
        } else {
            return nil
        }

        // Trailing decorations: <<stereotype>> and #color, either order.
        var stereotype: String? = nil
        var color: String? = nil
        let remainder = String(cursor).trimmingCharacters(in: .whitespaces)
        if let stereoStart = remainder.range(of: "<<"),
           let stereoEnd = remainder.range(of: ">>", range: stereoStart.upperBound..<remainder.endIndex) {
            stereotype = String(remainder[stereoStart.upperBound..<stereoEnd.lowerBound])
        }
        if let hashIdx = remainder.firstIndex(of: "#") {
            let after = remainder[remainder.index(after: hashIdx)...]
            let runEnd = after.firstIndex(where: { !($0.isLetter || $0.isNumber) }) ?? after.endIndex
            let hex = remainder[hashIdx..<runEnd]
            if hex.count > 1 { color = String(hex) }
        }

        if opensBlock {
            return .openGroup(.init(
                id: id, label: label, kind: kind,
                stereotype: stereotype, color: color
            ))
        } else {
            return .shape(.init(
                id: id, label: label, kind: kind,
                stereotype: stereotype, color: color
            ))
        }
    }
}

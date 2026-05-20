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

    public func parse(_ body: String) throws -> PlantUMLDeploymentAST {
        var roots: [PlantUMLDeploymentAST.Node] = []
        for rawLine in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("'") { continue }
            if line.hasPrefix("@") { continue }
            if let shape = try parseShapeLine(line) {
                roots.append(.shape(shape))
                continue
            }
        }
        return PlantUMLDeploymentAST(roots: roots)
    }

    private func parseShapeLine(_ line: String) throws -> PlantUMLDeploymentAST.Shape? {
        guard let space = line.firstIndex(of: " ") else { return nil }
        let keyword = String(line[..<space])
        guard let kind = Self.keywordToKind[keyword] else { return nil }
        let rest = line[line.index(after: space)...].trimmingCharacters(in: .whitespaces)

        var label: String? = nil
        var id: String = ""
        var cursor = Substring(rest)

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
            let aliasEnd = cursor[aliasStart...].firstIndex(where: { $0 == " " || $0 == "{" }) ?? cursor.endIndex
            id = String(cursor[aliasStart..<aliasEnd])
        } else if let lbl = label {
            id = lbl.lowercased()
                .map { $0.isLetter || $0.isNumber ? $0 : "_" }
                .reduce("") { $0 + String($1) }
        } else {
            return nil
        }

        return .init(id: id, label: label, kind: kind)
    }
}

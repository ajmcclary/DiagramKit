import Foundation

struct PlantUMLActivityParser {

    func parse(_ body: String) -> PlantUMLActivityAST {
        var ast = PlantUMLActivityAST()
        var nodeIndex = 0
        var lastNodeID: String?
        var pendingEdgeLabel: String?
        var partitionStack: [String] = []
        var partitionMembers: [String: [String]] = [:]
        var partitionLabels: [String: String] = [:]
        var partitionIndex = 0

        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("'") { continue }
            if trimmed.hasPrefix("title ") {
                ast.title = String(trimmed.dropFirst("title ".count))
                continue
            }
            if trimmed.hasPrefix("partition ") {
                let label = parsePartitionLabel(trimmed)
                let id = "partition_\(partitionIndex)"
                partitionIndex += 1
                partitionLabels[id] = label
                partitionMembers[id] = []
                partitionStack.append(id)
                continue
            }
            if trimmed == "}" {
                if let closing = partitionStack.popLast() {
                    ast.partitions.append(.init(
                        id: closing,
                        label: partitionLabels[closing] ?? closing,
                        memberNodeIDs: partitionMembers[closing] ?? []
                    ))
                }
                continue
            }
            if trimmed == "start" || trimmed == "stop" {
                let id = "n_\(nodeIndex)"
                nodeIndex += 1
                let shape: PlantUMLActivityAST.Node.NodeShape =
                    (trimmed == "start") ? .startTerminator : .stopTerminator
                ast.nodes.append(.init(id: id, label: trimmed, shape: shape))
                if let parent = partitionStack.last {
                    partitionMembers[parent, default: []].append(id)
                }
                if let prev = lastNodeID {
                    ast.edges.append(.init(source: prev, target: id, label: pendingEdgeLabel))
                    pendingEdgeLabel = nil
                }
                lastNodeID = id
                continue
            }
            if trimmed.hasPrefix(":") && trimmed.hasSuffix(";") {
                let label = String(trimmed.dropFirst().dropLast())
                let id = "n_\(nodeIndex)"
                nodeIndex += 1
                ast.nodes.append(.init(id: id, label: label, shape: .action))
                if let parent = partitionStack.last {
                    partitionMembers[parent, default: []].append(id)
                }
                if let prev = lastNodeID {
                    ast.edges.append(.init(source: prev, target: id, label: pendingEdgeLabel))
                    pendingEdgeLabel = nil
                }
                lastNodeID = id
                continue
            }
            if trimmed.hasPrefix("->") && trimmed.hasSuffix("->") {
                let inner = trimmed.dropFirst(2).dropLast(2).trimmingCharacters(in: .whitespaces)
                pendingEdgeLabel = inner.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                continue
            }
        }
        return ast
    }

    private func parsePartitionLabel(_ line: String) -> String {
        let after = line.dropFirst("partition ".count)
        let stripped = after.trimmingCharacters(in: .whitespaces)
        if stripped.hasPrefix("\"") {
            let body = stripped.dropFirst()
            if let end = body.firstIndex(of: "\"") {
                return String(body[..<end])
            }
            return String(body)
        }
        let firstToken = stripped.split(separator: " ").first.map(String.init) ?? "partition"
        return firstToken.replacingOccurrences(of: "{", with: "")
    }
}

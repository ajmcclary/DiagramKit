import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML activity syntax from a `ParsedGraphModel` payload.
/// Default idiom for the `.flowchart` payload in `PlantUMLExporter`.
enum PlantUMLActivityExport {

    static func emit(_ model: ParsedGraphModel) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []
        lines.append("@startuml")
        if let title = model.accTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        // PlantUML activity parses every node into synthetic ids `n_<index>`
        // (start/stop/`:...;` all consume one index). To round-trip
        // non-synthetic ids the exporter emits an `activity-original-id`
        // marker line directly after the node it describes.
        //
        // Subgraphs surface as `partition "Label" { … }` blocks. Each
        // node's first containing subgraph in `model.subgraphs` (by
        // nodeIds membership) determines its partition. Nodes outside
        // any subgraph emit at the outer scope.
        let partitionByNode = buildPartitionByNode(model.subgraphs)
        var openPartition: String? = nil
        var nodeIndex = 0
        for entry in model.nodesInOrder {
            let node = entry.node
            let syntheticId = "n_\(nodeIndex)"
            nodeIndex += 1
            let nodePartition = partitionByNode[node.id]
            if nodePartition != openPartition {
                if openPartition != nil {
                    lines.append("}")
                }
                if let next = nodePartition,
                   let label = partitionLabel(forID: next, in: model.subgraphs) {
                    lines.append("partition \"\(escape(label))\" {")
                }
                openPartition = nodePartition
            }
            if node.shape == .stadium && node.label == "start" {
                lines.append("start")
            } else if node.shape == .stadium && node.label == "stop" {
                lines.append("stop")
            } else {
                lines.append(":\(escape(node.label));")
            }
            if node.id != syntheticId {
                lines.append(PlantUMLRecoveryMarker.emitActivityOriginalId(
                    syntheticId: syntheticId,
                    originalId: node.id
                ))
            }
        }
        if openPartition != nil {
            lines.append("}")
        }
        lines.append("@enduml")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: diagnostics)
    }

    private static func buildPartitionByNode(
        _ subgraphs: [original_src_types.MermaidSubgraph]
    ) -> [String: String] {
        var map: [String: String] = [:]
        for sub in subgraphs {
            for nid in sub.nodeIds where map[nid] == nil {
                map[nid] = sub.id
            }
            // Nested children: contained ids get attributed to the child;
            // outer subgraph membership stays for the parent only.
            for child in sub.children {
                for nid in child.nodeIds where map[nid] == nil {
                    map[nid] = child.id
                }
            }
        }
        return map
    }

    private static func partitionLabel(
        forID id: String,
        in subgraphs: [original_src_types.MermaidSubgraph]
    ) -> String? {
        for sub in subgraphs {
            if sub.id == id { return sub.label }
            for child in sub.children where child.id == id {
                return child.label
            }
        }
        return nil
    }

    private static func isSyntheticActivityID(_ id: String) -> Bool {
        guard id.hasPrefix("n_") else { return false }
        let tail = id.dropFirst(2)
        return !tail.isEmpty && tail.allSatisfy(\.isNumber)
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: ";", with: "\\;")
         .replacingOccurrences(of: "\n", with: " ")
    }
}

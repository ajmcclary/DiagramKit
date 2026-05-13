import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML mindmap source from a `MindmapDiagram` payload.
enum PlantUMLMindmapExport {

    static func emit(_ model: MindmapDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        lines.append("@startmindmap")

        if let root = model.root {
            appendNode(root, depth: 1, into: &lines)
        }

        lines.append("@endmindmap")

        return DiagramExportResult(
            source: lines.joined(separator: "\n"),
            diagnostics: diagnostics
        )
    }

    private static func appendNode(
        _ node: MindmapNode,
        depth: Int,
        into lines: inout [String]
    ) {
        let prefix = String(repeating: "*", count: depth)
        lines.append("\(prefix) \(node.descr)")
        for child in node.children {
            appendNode(child, depth: depth + 1, into: &lines)
        }
    }
}

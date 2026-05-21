import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits a `TreeViewDiagram` as PlantUML `@startwbs` source. WBS is the
/// canonical encoding for treeView in PlantUML; there is no per-call
/// encoding selector. JSON and YAML are import-only entry points that
/// converge to WBS on export.
///
/// Output shape:
///
/// ```
/// @startwbs
/// title <diagramTitle if set>
/// ' diagramkit:treeview-node-description=42,b64:NDI=
/// ' diagramkit:treeview-node-icon=3,folder
/// * root
/// ** child1
/// ** child2
/// @endwbs
/// ```
///
/// Markers emit in ascending nodeId order, grouped (descriptions first,
/// then icons, then cssClasses).
public struct PlantUMLTreeViewExporter {

    public init() {}

    public func export(_ diagram: TreeViewDiagram) throws -> DiagramExportResult {
        var diagnostics: [DiagramDiagnostic] = []
        var lines: [String] = ["@startwbs"]

        if let title = diagram.diagramTitle, !title.isEmpty {
            lines.append("title \(title.replacingOccurrences(of: "\n", with: " "))")
        }

        if diagram.accTitle != nil || diagram.accDescr != nil {
            diagnostics.append(.lossyTransform(
                .accessibilityDrop,
                message: "PlantUML WBS does not preserve accessibility metadata"
            ))
        }

        // Collect descriptions/icons/cssClasses in ascending id order.
        var descMarkers: [(id: Int, line: String)] = []
        var iconMarkers: [(id: Int, line: String)] = []
        var cssMarkers: [(id: Int, line: String)] = []
        walk(diagram.root) { node in
            if let d = node.description, !d.isEmpty {
                descMarkers.append((node.id,
                    PlantUMLRecoveryMarker.emitTreeViewNodeDescription(nodeId: node.id, body: d)))
            }
            if let icon = node.iconId, !icon.isEmpty {
                iconMarkers.append((node.id,
                    PlantUMLRecoveryMarker.emitTreeViewNodeIcon(nodeId: node.id, iconId: icon)))
            }
            if let css = node.cssClass, !css.isEmpty {
                cssMarkers.append((node.id,
                    PlantUMLRecoveryMarker.emitTreeViewNodeCssClass(nodeId: node.id, cssClass: css)))
            }
        }
        descMarkers.sort { $0.id < $1.id }
        iconMarkers.sort { $0.id < $1.id }
        cssMarkers.sort { $0.id < $1.id }
        lines.append(contentsOf: descMarkers.map { $0.line })
        lines.append(contentsOf: iconMarkers.map { $0.line })
        lines.append(contentsOf: cssMarkers.map { $0.line })

        emitNode(diagram.root, lines: &lines, diagnostics: &diagnostics)

        lines.append("@endwbs")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: diagnostics)
    }

    private func emitNode(
        _ node: TreeViewNode,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let depth = node.level + 1  // WBS depth is 1-based (`*` = root)
        var name = node.name
        if name.contains("\n") {
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "PlantUML WBS node names must be single-line; stripped newlines in '\(name.prefix(40))…'"
            ))
            name = name.replacingOccurrences(of: "\n", with: " ")
        }
        lines.append(String(repeating: "*", count: depth) + " " + name)
        for child in node.children {
            emitNode(child, lines: &lines, diagnostics: &diagnostics)
        }
    }

    private func walk(_ node: TreeViewNode, _ visit: (TreeViewNode) -> Void) {
        visit(node)
        for child in node.children {
            walk(child, visit)
        }
    }
}

extension PlantUMLTreeViewExporter {
    public static func emit(_ diagram: TreeViewDiagram) throws -> DiagramExportResult {
        try PlantUMLTreeViewExporter().export(diagram)
    }
}

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

        // Convention detection: pick the effective root (the user-visible
        // subtree the `*` root represents) and the dropped-siblings list.
        // PlantUML WBS supports exactly one `*` root per @startwbs block.
        let isSyntheticRoot = (diagram.root.name == "/" && diagram.root.level == -1)
        let effectiveRoot: TreeViewNode?
        let droppedSiblings: [TreeViewNode]
        if isSyntheticRoot {
            let children = diagram.root.children
            effectiveRoot = children.first
            droppedSiblings = Array(children.dropFirst())
        } else {
            effectiveRoot = diagram.root
            droppedSiblings = []
        }

        // Collect descriptions/icons/cssClasses in ascending id order
        // — walk only the effective root (markers for dropped siblings
        // would be orphaned).
        var descMarkers: [(id: Int, line: String)] = []
        var iconMarkers: [(id: Int, line: String)] = []
        var cssMarkers: [(id: Int, line: String)] = []
        if let root = effectiveRoot {
            walk(root) { node in
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
        }
        descMarkers.sort { $0.id < $1.id }
        iconMarkers.sort { $0.id < $1.id }
        cssMarkers.sort { $0.id < $1.id }
        lines.append(contentsOf: descMarkers.map { $0.line })
        lines.append(contentsOf: iconMarkers.map { $0.line })
        lines.append(contentsOf: cssMarkers.map { $0.line })

        // Emit the WBS root. If the synthetic container is empty we emit
        // a bare @startwbs/@endwbs (degenerate; matches "empty tree"
        // behavior on the parser side). The unchanged `node.level + 1`
        // mapping in `emitNode` yields the correct WBS depth: the
        // effective root is always at level 0 (whether that's a real
        // root or a synthetic-root child), giving depth 1 = `*`.
        if let root = effectiveRoot {
            emitNode(root, lines: &lines, diagnostics: &diagnostics)
        }

        // Emit one diagnostic per dropped sibling (in declaration order).
        for sibling in droppedSiblings {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "additional WBS root '\(sibling.name)' dropped " +
                         "(@startwbs supports a single root)"
            ))
        }

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

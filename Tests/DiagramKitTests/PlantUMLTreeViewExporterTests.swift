import Testing
import Foundation
import DiagramKitPlantUML
import DiagramKitModel
import DiagramKitCommon

@Suite struct PlantUMLTreeViewExporterTests {
    @Test func emitsSimpleTreeAsWBS() throws {
        let c1 = TreeViewNode(id: 1, level: 1, name: "child1", nodeType: .file)
        let c2 = TreeViewNode(id: 2, level: 1, name: "child2", nodeType: .file)
        let root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .directory, children: [c1, c2])
        let diagram = TreeViewDiagram(root: root, nodes: [root, c1, c2])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.source.hasPrefix("@startwbs"))
        #expect(result.source.contains("* root"))
        #expect(result.source.contains("** child1"))
        #expect(result.source.contains("** child2"))
        #expect(result.source.contains("@endwbs"))
    }

    @Test func emitsTitle() throws {
        let root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .file)
        let diagram = TreeViewDiagram(root: root, nodes: [root], diagramTitle: "My Tree")
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.source.contains("title My Tree"))
    }

    @Test func emitsDescriptionMarker() throws {
        let leaf = TreeViewNode(id: 1, level: 1, name: "a", nodeType: .file, description: "42")
        let root = TreeViewNode(id: 0, level: 0, name: "(root)", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        let expected = PlantUMLRecoveryMarker.emitTreeViewNodeDescription(nodeId: 1, body: "42")
        #expect(result.source.contains(expected))
    }

    @Test func emitsIconMarker() throws {
        let leaf = TreeViewNode(id: 1, level: 1, name: "a", nodeType: .file, iconId: "folder")
        let root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.source.contains(PlantUMLRecoveryMarker.emitTreeViewNodeIcon(nodeId: 1, iconId: "folder")))
    }

    @Test func emitsCssClassMarker() throws {
        let leaf = TreeViewNode(id: 1, level: 1, name: "a", nodeType: .file, cssClass: "highlighted")
        let root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.source.contains(PlantUMLRecoveryMarker.emitTreeViewNodeCssClass(nodeId: 1, cssClass: "highlighted")))
    }

    @Test func newlineInNameProducesIdSanitization() throws {
        let root = TreeViewNode(id: 0, level: 0, name: "line1\nline2", nodeType: .file)
        let diagram = TreeViewDiagram(root: root, nodes: [root])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.diagnostics.contains { $0.category == .idSanitization })
        #expect(!result.source.contains("\nline2"))  // stripped
    }

    @Test func accTitleDropsWithDiagnostic() throws {
        let root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .file)
        let diagram = TreeViewDiagram(
            root: root,
            nodes: [root],
            accTitle: "screen reader title"
        )
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.diagnostics.contains { $0.category == .accessibilityDrop })
    }
}

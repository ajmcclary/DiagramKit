import Testing
@testable import DiagramKitPlantUML
import DiagramKitModel

@Suite struct PlantUMLWBSMapperTests {
    @Test func mapsSingleRoot() {
        let tree = PlantUMLWBSTree(root: PlantUMLWBSNode(label: "root", depth: 1))
        let (diagram, diagnostics) = PlantUMLWBSMapper().map(tree)
        #expect(diagnostics.isEmpty)
        #expect(diagram.root.id == 0)
        #expect(diagram.root.name == "root")
        #expect(diagram.root.nodeType == .file) // leaf
        #expect(diagram.nodes.count == 1)
    }

    @Test func mapsHierarchyWithDFSPreOrderIds() {
        let inner = PlantUMLWBSNode(label: "grandchild", depth: 3)
        let mid = PlantUMLWBSNode(label: "child1", depth: 2, children: [inner])
        let sib = PlantUMLWBSNode(label: "child2", depth: 2)
        let root = PlantUMLWBSNode(label: "root", depth: 1, children: [mid, sib])
        let (diagram, diagnostics) = PlantUMLWBSMapper().map(PlantUMLWBSTree(root: root))

        #expect(diagnostics.isEmpty)
        #expect(diagram.root.id == 0)
        #expect(diagram.root.name == "root")
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.children.count == 2)

        let c1 = diagram.root.children[0]
        #expect(c1.id == 1)
        #expect(c1.name == "child1")
        #expect(c1.nodeType == .directory)
        #expect(c1.children.count == 1)

        let gc = c1.children[0]
        #expect(gc.id == 2)
        #expect(gc.name == "grandchild")
        #expect(gc.nodeType == .file)

        let c2 = diagram.root.children[1]
        #expect(c2.id == 3)
        #expect(c2.name == "child2")
    }

    @Test func surfacesShapeAndColorAsSlotUnsupported() {
        let root = PlantUMLWBSNode(label: "root", depth: 1, shape: "box", color: "LightBlue")
        let (diagram, diagnostics) = PlantUMLWBSMapper().map(PlantUMLWBSTree(root: root))
        #expect(diagram.root.name == "root")
        #expect(diagnostics.count == 2)
        for d in diagnostics {
            #expect(d.category == .slotUnsupported)
        }
    }

    @Test func surfacesTitle() {
        let tree = PlantUMLWBSTree(
            root: PlantUMLWBSNode(label: "root", depth: 1),
            title: "My Tree"
        )
        let (diagram, _) = PlantUMLWBSMapper().map(tree)
        #expect(diagram.diagramTitle == "My Tree")
    }

    @Test func mapsEmptyTreeToDefaultRoot() {
        let (diagram, diagnostics) = PlantUMLWBSMapper().map(PlantUMLWBSTree())
        #expect(diagnostics.isEmpty)
        #expect(diagram.root.name == "/") // matches TreeViewDiagram.empty
    }
}

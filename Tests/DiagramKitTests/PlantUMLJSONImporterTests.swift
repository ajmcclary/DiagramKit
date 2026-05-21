import Testing
import DiagramKitPlantUML
import DiagramKitModel

@Suite struct PlantUMLJSONImporterTests {
    @Test func parsesBasicJSON() throws {
        let src = """
        @startjson
        { "a": 1, "b": "hello" }
        @endjson
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView")
            return
        }
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "a")
        #expect(diagram.root.children[0].description == "1")
    }

    @Test func parsesPrimitiveRootJSON() throws {
        let src = """
        @startjson
        42
        @endjson
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView")
            return
        }
        #expect(diagram.root.name == "(root)")
        #expect(diagram.root.children.count == 1)
        #expect(diagram.root.children[0].description == "42")
    }

    @Test func appliesIncomingDescriptionMarker() throws {
        // Description marker overrides parser-supplied description for
        // node id 1 (which is the first child of the (root) container
        // synthesized for primitive documents). Here we have an object
        // root so id 0 is root, id 1 is the first child "a".
        let src = """
        ' diagramkit:treeview-node-description=1,b64:Zm9v
        @startjson
        { "a": 1 }
        @endjson
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView")
            return
        }
        #expect(diagram.root.children[0].id == 1)
        #expect(diagram.root.children[0].description == "foo")
    }
}

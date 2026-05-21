import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitPlantUML

@Suite struct PlantUMLMindmapImporterTests {

    @Test("Parses a simple mindmap with nested children")
    func basicMindmap() throws {
        let source = """
        @startmindmap
        * Root
        ** Child A
        *** Grandchild A1
        ** Child B
        @endmindmap
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .mindmap(let model) = result.document.payload else {
            Issue.record("Expected mindmap payload, got \(result.document.payload)")
            return
        }
        #expect(model.root?.descr == "Root")
        #expect(model.root?.children.count == 2)
        let childA = model.root?.children.first
        #expect(childA?.descr == "Child A")
        #expect(childA?.children.first?.descr == "Grandchild A1")
        let childB = model.root?.children.last
        #expect(childB?.descr == "Child B")
        #expect(childB?.children.isEmpty == true)
    }

    @Test("Mindmap accepts + and - markers in addition to *")
    func alternativeMarkers() throws {
        let source = """
        @startmindmap
        + Root
        ++ Child
        @endmindmap
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .mindmap(let model) = result.document.payload else {
            Issue.record("Expected mindmap payload"); return
        }
        #expect(model.root?.descr == "Root")
        #expect(model.root?.children.first?.descr == "Child")
    }
}

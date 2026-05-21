import Testing
import DiagramKitPlantUML
import DiagramKitModel
import DiagramKitCommon

@Suite struct PlantUMLYAMLImporterTests {
    @Test func parsesBasicYAML() throws {
        let src = """
        @startyaml
        a: 1
        b: hello
        @endyaml
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView")
            return
        }
        #expect(diagram.root.children.count == 2)
    }

    @Test func parsesNestedYAML() throws {
        let src = """
        @startyaml
        outer:
          inner: value
        @endyaml
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView")
            return
        }
        #expect(diagram.root.children[0].name == "outer")
        #expect(diagram.root.children[0].children[0].name == "inner")
    }

    @Test func unsupportedFeaturesProduceDiagnostics() throws {
        let src = """
        @startyaml
        a: &anchor 1
        b: *anchor
        @endyaml
        """
        let result = try PlantUMLImporter().parse(src)
        #expect(result.diagnostics.contains { $0.category == .slotUnsupported })
    }
}

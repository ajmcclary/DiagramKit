import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitPlantUML

/// Wave H retargets @startwbs from MindmapDiagram to TreeViewDiagram.
/// These cases used to live in PlantUMLMindmapImporterTests; they were
/// moved here when the spec retargeted WBS to TreeView.
///
/// Tests in this file fail until PlantUMLImporter.parse dispatches
/// @startwbs to PlantUMLWBSParser/Mapper in Task 11.
@Suite struct PlantUMLWBSImporterTests {

    @Test("Parses @startwbs into a treeView payload (was mindmap pre-Wave-H)")
    func parsesBasicWBS() throws {
        let source = """
        @startwbs
        * Project
        ** Phase 1
        ** Phase 2
        @endwbs
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("Expected treeView payload, got \(result.document.payload)")
            return
        }
        #expect(diagram.root.name == "Project")
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "Phase 1")
        #expect(diagram.root.children[1].name == "Phase 2")
    }
}

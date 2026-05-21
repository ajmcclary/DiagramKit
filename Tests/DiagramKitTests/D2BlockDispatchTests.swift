import Testing
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2 block dispatch")
struct D2BlockDispatchTests {

    @Test("Marker-forced family=block routes through D2BlockMapper")
    func markerForcedRoutes() throws {
        let source = """
        # diagramkit:family=block
        a: "A"
        """
        let result = try D2Importer().parse(source)
        guard case .block(let block) = result.document.payload else {
            Issue.record("expected .block payload, got \(result.document.payload)")
            return
        }
        #expect(block.rootChildren == ["a"])
    }

    @Test("Block-* marker triggers detection via probe")
    func probeDetectedRoutes() throws {
        let source = """
        a: "A"
        b: "B"
        # diagramkit:block-cols=root,2
        """
        let result = try D2Importer().parse(source)
        guard case .block = result.document.payload else {
            Issue.record("expected .block payload")
            return
        }
    }

    @Test("Exporter emits valid D2 for a block payload")
    func exporterEmits() throws {
        let document = DiagramDocument(payload: .block(BlockDiagram(
            rootChildren: ["a"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .square),
            ]
        )))
        let result = try D2Exporter().export(document)
        #expect(result.source.contains("# diagramkit:family=block"))
        #expect(result.source.contains("a: \"A\""))
    }
}

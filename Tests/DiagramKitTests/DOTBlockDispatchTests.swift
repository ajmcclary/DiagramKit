import Testing
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
@testable import DiagramKitGraphviz

@Suite("DOT block dispatch")
struct DOTBlockDispatchTests {

    @Test("Marker-forced family=block routes through DOTBlockMapper")
    func markerForcedRoutes() throws {
        let source = """
        # diagramkit:family=block
        digraph G {
          a [label="A"];
        }
        """
        let result = try GraphvizImporter().parse(source)
        guard case .block(let block) = result.document.payload else {
            Issue.record("expected .block payload, got \(result.document.payload)")
            return
        }
        #expect(block.rootChildren == ["a"])
    }

    @Test("Block-* marker triggers detection via probe")
    func probeDetectedRoutes() throws {
        let source = """
        digraph G {
          a; b;
          # diagramkit:block-cols=root,2
        }
        """
        let result = try GraphvizImporter().parse(source)
        guard case .block = result.document.payload else {
            Issue.record("expected .block payload")
            return
        }
    }

    @Test("Exporter emits valid DOT for a block payload")
    func exporterEmits() throws {
        let document = DiagramDocument(payload: .block(BlockDiagram(
            rootChildren: ["a"],
            blockDatabase: [
                "root": BlockNode(id: "root", type: .composite, children: ["a"], columns: -1),
                "a":    BlockNode(id: "a", label: "A", type: .square),
            ]
        )))
        let result = try DOTExporter().export(document)
        #expect(result.source.contains("digraph G {"))
        #expect(result.source.contains("# diagramkit:family=block"))
        #expect(result.source.contains("a [label=\"A\"];"))
    }
}

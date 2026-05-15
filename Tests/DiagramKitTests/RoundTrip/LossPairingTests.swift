import Testing
import DiagramKitTestSupport
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
import DiagramKit
import DiagramKitMermaid
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML

@Suite("Loss pairing")
struct LossPairingTests {

    @Test("Mermaid flowchart export emits a shape-downgrade warning for non-flowchart node shapes")
    func mermaidShapeDowngradePaired() throws {
        // Build a ParsedGraphModel with a state-family node shape inside the
        // .flowchart payload. MermaidFlowchartExport.shapeMarker returns
        // lossy: true for state shapes; the exporter loop appends one
        // .warning per lossy node.
        let stateNode = original_src_types.MermaidNode(
            id: "x",
            label: "X",
            shape: original_src_types.NodeShape.state
        )
        let model = ParsedGraphModel(
            direction: original_src_types.Direction.TD,
            nodesInOrder: [(id: "x", node: stateNode)],
            edges: []
        )
        let doc = DiagramDocument(payload: .flowchart(model))
        let result = try MermaidExporter().export(doc)
        let loss = RoundTripLoss.shapeDowngrade(
            nodeID: "x",
            from: original_src_types.NodeShape.state,
            to: original_src_types.NodeShape.rectangle
        )
        #expect(diagnosticsCover(loss: loss, in: result.diagnostics),
                "diagnostics did not cover shapeDowngrade loss: \(result.diagnostics)")
    }

    @Test("D2 flowchart export emits a subgraph-flatten warning when input has subgraphs")
    func d2SubgraphFlattenPaired() throws {
        let source = """
        graph TD
          subgraph s1[Group]
            A-->B
          end
        """
        let doc = try MermaidImporter().parse(source).document
        let result = try D2Exporter().export(doc)
        let loss = RoundTripLoss.subgraphFlatten(subgraphID: "s1", depth: 1)
        #expect(diagnosticsCover(loss: loss, in: result.diagnostics),
                "diagnostics did not cover subgraphFlatten loss: \(result.diagnostics)")
    }

    @Test("DOT flowchart export emits a subgraph-flatten warning when input has subgraphs")
    func dotSubgraphFlattenPaired() throws {
        let source = """
        graph TD
          subgraph s1[Group]
            A-->B
          end
        """
        let doc = try MermaidImporter().parse(source).document
        let result = try DOTExporter().export(doc)
        let loss = RoundTripLoss.subgraphFlatten(subgraphID: "s1", depth: 1)
        #expect(diagnosticsCover(loss: loss, in: result.diagnostics),
                "diagnostics did not cover subgraphFlatten loss: \(result.diagnostics)")
    }

    @Test("PlantUML exporter rejects unsupported types with a .unsupported diagnostic")
    func plantUMLUnsupportedTypePaired() throws {
        // PlantUML doesn't support flowchart; the export must emit a
        // .unsupported diagnostic rather than silently emit empty source.
        let model = ParsedGraphModel(
            direction: original_src_types.Direction.TD,
            nodesInOrder: [],
            edges: []
        )
        let doc = DiagramDocument(payload: .flowchart(model))
        let result = try PlantUMLExporter().export(doc)
        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }
}

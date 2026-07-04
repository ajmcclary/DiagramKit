// Visual editor plan 1 — @{ shape:/properties } metadata emission.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitMermaid
@testable import DiagramKit

private func doc(_ nodes: [(String, original_src_types.MermaidNode)]) -> DiagramDocument {
    DiagramDocument(payload: .flowchart(
        original_src_types.MermaidGraph(
            direction: .TD,
            nodesInOrder: nodes.map { (id: $0.0, node: $0.1) },
            edges: []
        )
    ))
}

@Suite
struct MermaidFlowchartMetadataExportTests {

    @Test("every NodeShape rawValue resolves to itself")
    func rawValuesResolve() {
        for shape in original_src_types.NodeShape.allCases {
            #expect(
                original_src_types.NodeShape.resolve(alias: shape.rawValue) == shape,
                "rawValue '\(shape.rawValue)' does not resolve to itself"
            )
        }
    }

    @Test("classic shapes keep bracket markers")
    func classicMarkers() throws {
        let node = original_src_types.MermaidNode(id: "A", label: "Start", shape: .rounded)
        let result = try MermaidExporter().export(doc([("A", node)]))
        #expect(result.source.contains("A(Start)"))
        #expect(!result.source.contains("@{"))
    }

    @Test("non-classic shape emits @{ shape: } metadata with no shapeDowngrade")
    func metadataShape() throws {
        let node = original_src_types.MermaidNode(id: "C", label: "Files", shape: .stackedDocument)
        let result = try MermaidExporter().export(doc([("C", node)]))
        #expect(result.source.contains("C[Files]@{ shape: stacked-document }"))
        #expect(!result.diagnostics.contains { $0.category == .shapeDowngrade })
    }

    @Test("non-classic shape with empty label emits bare id + metadata")
    func metadataShapeNoLabel() throws {
        let node = original_src_types.MermaidNode(id: "C", label: "C", shape: .cloud)
        let result = try MermaidExporter().export(doc([("C", node)]))
        #expect(result.source.contains("C@{ shape: cloud }"))
    }

    @Test("icon properties are emitted and parse back")
    func iconProperties() throws {
        let node = original_src_types.MermaidNode(
            id: "I", label: "User", shape: .iconCircle,
            properties: original_src_types.NodeProperties(icon: "fa:user", pos: "b", h: 48)
        )
        let result = try MermaidExporter().export(doc([("I", node)]))
        let reparsed = try MermaidImporter().parse(result.source)
        guard case .flowchart(let graph) = reparsed.document.payload else {
            #expect(Bool(false)); return
        }
        let round = graph.nodesById["I"]
        #expect(round?.shape == .iconCircle)
        #expect(round?.properties?.icon == "fa:user")
        #expect(round?.properties?.pos == "b")
        #expect(round?.properties?.h == 48)
    }

    @Test("full non-classic shape round-trip: export then re-parse preserves shape")
    func shapeRoundTrip() throws {
        for shape in [original_src_types.NodeShape.cloud, .document, .windowPane, .bowTieRectangle, .stateStart, .curvedTrapezoid] {
            let node = original_src_types.MermaidNode(id: "N", label: "Label", shape: shape)
            let result = try MermaidExporter().export(doc([("N", node)]))
            let reparsed = try MermaidImporter().parse(result.source)
            guard case .flowchart(let graph) = reparsed.document.payload else {
                #expect(Bool(false)); return
            }
            #expect(graph.nodesById["N"]?.shape == shape, "shape \(shape) did not round-trip")
        }
    }
}

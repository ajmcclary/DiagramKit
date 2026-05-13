import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitMermaid

@Suite struct MermaidEscapeTests {

    @Test("bracket label escaping handles special characters")
    func bracketLabelEscaping() throws {
        // Labels with special characters: [, ], ", \
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "Test [with] \"quotes\"", shape: .rectangle))
            ],
            edges: []
        )
        let doc = DiagramDocument(payload: .flowchart(graph))
        let result = try MermaidExporter().export(doc)

        // Should contain escaped characters
        #expect(result.source.contains("\\["))
        #expect(result.source.contains("\\]"))
        #expect(result.source.contains("\\\""))
    }

    @Test("edge label escaping handles pipe characters")
    func edgeLabelEscaping() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "A", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "B", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", label: "a|b", style: .solid)
            ]
        )
        let doc = DiagramDocument(payload: .flowchart(graph))
        let result = try MermaidExporter().export(doc)

        // Pipe in edge label should be escaped with #124;
        #expect(result.source.contains("#124;"))
    }

    @Test("identifier sanitization handles spaces and special chars")
    func identifierSanitization() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "My Node", node: original_src_types.MermaidNode(id: "My Node", label: "Label", shape: .rectangle))
            ],
            edges: []
        )
        let doc = DiagramDocument(payload: .flowchart(graph))
        let result = try MermaidExporter().export(doc)

        // Spaces should be converted to underscores in the identifier
        #expect(!result.source.contains("My Node["))
        #expect(result.source.contains("My_Node"))
    }
}

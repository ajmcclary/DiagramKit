import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitMermaid
import DiagramKit

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

        // The parser keeps `\[`, `\]` and `\"` literally, so backslash
        // escapes did not survive a round trip; the label must come back as
        // written.
        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .flowchart(let g) = reparsed.payload else { Issue.record("not a flowchart"); return }
        // A label holding both `"` and the closing `]` has no spelling the
        // parser reads back: the quote becomes `'` and a warning says so.
        #expect(g.nodesInOrder.first?.node.label == "Test [with] 'quotes'", "\(result.source)")
        #expect(result.diagnostics.contains { $0.severity == .warning })

        for label in ["Test [with] brackets", "say \"hi\" (twice)", "a|b; c", "100% done"] {
            let single = ParsedGraphModel(
                direction: .TD,
                nodesInOrder: [(id: "A", node: original_src_types.MermaidNode(id: "A", label: label, shape: .rectangle))],
                edges: []
            )
            let exported = try MermaidExporter().export(DiagramDocument(payload: .flowchart(single)))
            guard case .flowchart(let back) = try MermaidImporter().parse(exported.source).document.payload else {
                Issue.record("not a flowchart"); continue
            }
            #expect(back.nodesInOrder.first?.node.label == label, "\(exported.source)")
            #expect(exported.diagnostics.isEmpty)
        }
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

        // `#124;` was decoded before parsing and ended the pipe label early;
        // the label must come back as written.
        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .flowchart(let g) = reparsed.payload else { Issue.record("not a flowchart"); return }
        #expect(g.edges.first?.label == "a|b", "\(result.source)")
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

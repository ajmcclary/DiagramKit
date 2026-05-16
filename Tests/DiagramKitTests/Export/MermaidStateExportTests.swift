import Testing
import DiagramKitModel
import DiagramKitMermaid
import DiagramKit

@Suite struct MermaidStateExportTests {

    // MARK: - Supported types

    @Test("MermaidExporter declares stateDiagram supported")
    func stateDiagramIsSupported() {
        let exporter = MermaidExporter()
        #expect(exporter.supportedDiagramTypes.contains(.stateDiagram))
    }

    // MARK: - Empty diagram

    @Test("Empty state diagram emits stateDiagram-v2 header")
    func emptyStateDiagram() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [],
            edges: []
        )
        let doc = DiagramDocument(payload: .stateDiagram(graph))
        let result = try MermaidExporter().export(doc)
        #expect(result.source.contains("stateDiagram-v2"))
        #expect(result.diagnostics.isEmpty)
    }

    // MARK: - [*] pseudostate sentinels

    @Test("[*] start/end sentinels round-trip via shape")
    func pseudostateSentinelsRoundTrip() throws {
        // Build the shape the parser produces from `[*] --> Idle --> [*]`.
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "root_start", node: original_src_types.MermaidNode(id: "root_start", label: "", shape: .stateStart)),
                (id: "Idle", node: original_src_types.MermaidNode(id: "Idle", label: "Idle", shape: .rounded)),
                (id: "root_end", node: original_src_types.MermaidNode(id: "root_end", label: "", shape: .stateEnd))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "root_start", target: "Idle", style: .solid),
                original_src_types.MermaidEdge(source: "Idle", target: "root_end", style: .solid)
            ]
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .stateDiagram(graph)))
        #expect(result.source.contains("[*] --> Idle"))
        #expect(result.source.contains("Idle --> [*]"))

        // Reparse and verify shape preserved.
        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .stateDiagram(let reparsedGraph) = reparsed.payload else {
            Issue.record("Expected stateDiagram payload after reparse")
            return
        }
        // Reparsed shape must include the two pseudostates plus Idle.
        let shapes = Set(reparsedGraph.nodesInOrder.map { $0.node.shape })
        #expect(shapes.contains(.stateStart))
        #expect(shapes.contains(.stateEnd))
        #expect(reparsedGraph.edges.count == 2)
    }

    // MARK: - state "Name" as id alias

    @Test("state \"Name\" as id alias round-trips label")
    func stateAliasRoundTrip() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "Open", node: original_src_types.MermaidNode(id: "Open", label: "Connection Open", shape: .rounded)),
                (id: "Closed", node: original_src_types.MermaidNode(id: "Closed", label: "Connection Closed", shape: .rounded))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "Closed", target: "Open", label: "connect", style: .solid)
            ]
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .stateDiagram(graph)))
        #expect(result.source.contains("state \"Connection Open\" as Open"))
        #expect(result.source.contains("state \"Connection Closed\" as Closed"))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .stateDiagram(let reparsedGraph) = reparsed.payload else {
            Issue.record("Expected stateDiagram payload after reparse")
            return
        }
        let openLabel = reparsedGraph.nodesInOrder.first { $0.id == "Open" }?.node.label
        let closedLabel = reparsedGraph.nodesInOrder.first { $0.id == "Closed" }?.node.label
        #expect(openLabel == "Connection Open")
        #expect(closedLabel == "Connection Closed")
    }

    // MARK: - Labeled transitions

    @Test("Labeled transitions round-trip")
    func labeledTransitionsRoundTrip() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "A", shape: .rounded)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "B", shape: .rounded))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", label: "go", style: .solid)
            ]
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .stateDiagram(graph)))
        #expect(result.source.contains("A --> B : go"))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .stateDiagram(let reparsedGraph) = reparsed.payload else {
            Issue.record("Expected stateDiagram payload after reparse")
            return
        }
        #expect(reparsedGraph.edges.first?.label == "go")
    }

    // MARK: - Choice pseudo-state

    @Test("Choice pseudo-state emits <<choice>> marker")
    func choicePseudoState() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "Decide", node: original_src_types.MermaidNode(id: "Decide", label: "Decide", shape: .choice))
            ],
            edges: []
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .stateDiagram(graph)))
        #expect(result.source.contains("state Decide <<choice>>"))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .stateDiagram(let reparsedGraph) = reparsed.payload else {
            Issue.record("Expected stateDiagram payload after reparse")
            return
        }
        let reparsedShape = reparsedGraph.nodesInOrder.first { $0.id == "Decide" }?.node.shape
        #expect(reparsedShape == .choice)
    }

    // MARK: - Notes

    @Test("note left/right of state round-trips")
    func notesRoundTrip() throws {
        // Build shape the parser produces from:
        //   stateDiagram-v2
        //     Active
        //     note left of Active : Processing
        // Parser creates a `.stateNote` node with id `<target>----note`
        // and a dotted edge from note → target (position == .left).
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "Active", node: original_src_types.MermaidNode(id: "Active", label: "Active", shape: .rounded)),
                (id: "Active----note", node: original_src_types.MermaidNode(id: "Active----note", label: "Processing", shape: .stateNote))
            ],
            edges: [
                original_src_types.MermaidEdge(
                    source: "Active----note",
                    target: "Active",
                    label: nil,
                    style: .dotted,
                    arrowHeadStart: .none,
                    arrowHeadEnd: .none
                )
            ]
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .stateDiagram(graph)))
        #expect(result.source.contains("note left of Active : Processing"))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .stateDiagram(let reparsedGraph) = reparsed.payload else {
            Issue.record("Expected stateDiagram payload after reparse")
            return
        }
        let hasNoteNode = reparsedGraph.nodesInOrder.contains { $0.node.shape == .stateNote }
        #expect(hasNoteNode)
    }

    // MARK: - Deferred-feature diagnostics

    @Test("nodeStyles emit .styleDrop diagnostic")
    func nodeStylesEmitDiagnostic() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "A", shape: .rounded))
            ],
            edges: [],
            nodeStyles: ["A": ["fill": "#ffd"]]
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .stateDiagram(graph)))
        #expect(result.diagnostics.contains { $0.category == .styleDrop })
    }

    @Test("accTitle / accDescr emit .accessibilityDrop diagnostic")
    func accessibilityEmitsDiagnostic() throws {
        let graph = ParsedGraphModel(
            direction: .TD,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "A", shape: .rounded))
            ],
            edges: [],
            accTitle: "My State Machine"
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .stateDiagram(graph)))
        #expect(result.diagnostics.contains { $0.category == .accessibilityDrop })
    }
}

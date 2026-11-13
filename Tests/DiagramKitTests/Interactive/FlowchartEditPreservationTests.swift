// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// A canvas edit re-exports the whole flowchart and the app saves that text,
// so an edit must change only what it was asked to change.

import Testing
import DiagramKit
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

@MainActor
private func editor(for source: String) throws -> DiagramEditor {
    let document = try MermaidImporter().parse(source).document
    return DiagramEditor(
        document: document,
        preferredExportFormat: .mermaid,
        exportRegistry: DiagramPipeline.defaultExportRegistry,
        initialSource: source
    )
}

@MainActor
private func reparse(_ editor: DiagramEditor) throws -> DiagramDocument {
    try MermaidImporter().parse(#require(editor.source)).document
}

private func graph(_ document: DiagramDocument) -> original_src_types.MermaidGraph? {
    if case .flowchart(let g) = document.payload { return g }
    return nil
}

@Suite("Flowchart canvas edits preserve the rest of the source") @MainActor
struct FlowchartEditPreservationTests {

    @Test("changing one node's shape keeps every other feature of every fixture")
    func shapeEditKeepsEverythingElse() async throws {
        for fixture in flowchartFidelityFixtures {
            let original = try MermaidImporter().parse(fixture.source).document
            guard let firstNode = graph(original)?.nodesInOrder.first else { continue }
            let edit = try editor(for: fixture.source)
            try await edit.performFlowchart(.setNodeShape(
                of: DiagramSelection(diagramType: .flowchart, elementID: "node:\(firstNode.id)"),
                toShape: "hexagon"
            ))
            let after = try reparse(edit)

            var expected = original
            if case .flowchart(var g) = expected.payload {
                g.nodesInOrder[0].node.shape = .hexagon
                expected.payload = .flowchart(g)
            }
            #expect(flowchartFingerprint(after) == flowchartFingerprint(expected), "fixture \(fixture.name):\n\(edit.source ?? "")")
            #expect(edit.lastExportDiagnostics.isEmpty, "fixture \(fixture.name): \(edit.lastExportDiagnostics)")
        }
    }

    @Test("a shape edit keeps subgraph members inside their subgraph")
    func shapeEditKeepsMembership() async throws {
        let source = """
        flowchart TD
          subgraph S1 [Group one]
            A[Alpha] --> B[Beta]
          end
          subgraph S2
            C --o|lbl| D
          end
          B --> C
          linkStyle default stroke:red
          linkStyle 0 stroke:blue
        """
        let edit = try editor(for: source)
        try await edit.performFlowchart(.setNodeShape(
            of: DiagramSelection(diagramType: .flowchart, elementID: "node:A"), toShape: "rounded"
        ))
        let g = try #require(graph(try reparse(edit)))
        #expect(g.subgraphs.map(\.nodeIds) == [["A", "B"], ["C", "D"]])
        #expect(g.edges[1].arrowHeadEnd == .circle)
        #expect(g.edges[1].label == "lbl")
        #expect(g.linkStyles[-1] == ["stroke": "red"])
        #expect(g.linkStyles[0] == ["stroke": "blue"])
    }

    @Test("deleting a node moves linkStyle indices with the remaining edges")
    func deleteNodeReindexesLinkStyles() async throws {
        let source = "flowchart TD\n  A e1@--> B\n  B --> C\n  C --> D\n  linkStyle 1 stroke:red\n  linkStyle default stroke:gray\n"
        let edit = try editor(for: source)
        try await edit.perform(.deleteElement(DiagramSelection(diagramType: .flowchart, elementID: "node:A")))
        let g = try #require(graph(try reparse(edit)))
        #expect(g.edges.map { "\($0.source)->\($0.target)" } == ["B->C", "C->D"])
        #expect(g.linkStyles[0] == ["stroke": "red"], "the red style stays on B->C")
        #expect(g.linkStyles[1] == nil)
        #expect(g.linkStyles[-1] == ["stroke": "gray"])
    }

    @Test("deleting an edge drops its linkStyle and shifts the later ones")
    func deleteEdgeReindexesLinkStyles() async throws {
        let source = "flowchart TD\n  A --> B\n  B --> C\n  C --> D\n  linkStyle 0 stroke:red\n  linkStyle 2 stroke:blue\n"
        let edit = try editor(for: source)
        let model = try #require(graph(edit.document))
        let edgeID = edit._guaranteedEdgeID(for: model.edges[0])
        try await edit.perform(.deleteElement(DiagramSelection(diagramType: .flowchart, elementID: edgeID)))
        let g = try #require(graph(try reparse(edit)))
        #expect(g.edges.map { "\($0.source)->\($0.target)" } == ["B->C", "C->D"])
        #expect(g.linkStyles == [1: ["stroke": "blue"]])
    }

    @Test("deleting a node removes its styles, classes, click and membership")
    func deleteNodePurgesPerNodeState() async throws {
        let source = """
        flowchart TD
          subgraph S
            A --> B
          end
          classDef hot fill:#f00
          class B hot
          style B stroke:#00f
          click B href "https://example.com"
        """
        let edit = try editor(for: source)
        try await edit.perform(.deleteElement(DiagramSelection(diagramType: .flowchart, elementID: "node:B")))
        let g = try #require(graph(edit.document))
        #expect(g.classAssignments["B"] == nil)
        #expect(g.nodeStyles["B"] == nil)
        #expect(g.nodeInteractions["B"] == nil)
        #expect(g.subgraphs.first?.nodeIds == ["A"])
        #expect(g.classDefs["hot"] != nil, "class definitions are not per node")
        #expect(!(edit.source ?? "").contains(" B "), "\(edit.source ?? "")")
    }
}
#endif

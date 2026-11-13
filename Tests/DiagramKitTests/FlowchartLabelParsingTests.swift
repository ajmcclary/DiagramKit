import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitModel

/// Flowchart label and statement forms from the 2026-11-12 parser review
/// that used to parse to the wrong model without any error.
@Suite("Flowchart label parsing")
struct FlowchartLabelParsingTests {

    private struct Summary: Equatable {
        var nodes: [String: String] = [:]
        var shapes: [String: String] = [:]
        var edges: [String] = []
    }

    private static func summary(_ source: String) async throws -> Summary {
        let document = try await DiagramEngine.parse(source)
        guard case .flowchart(let graph) = document.payload else {
            Issue.record("expected a flowchart")
            return Summary()
        }
        var result = Summary()
        for (id, node) in graph.nodesInOrder {
            result.nodes[id] = node.label
            result.shapes[id] = "\(node.shape)"
        }
        result.edges = graph.edges.map { "\($0.source)->\($0.target)" + ($0.label.map { ":\($0)" } ?? "") }
        return result
    }

    @Test("a quoted label may contain its shape's closing bracket")
    func quotedLabelWithClosingBracket() async throws {
        let s = try await Self.summary("""
        flowchart LR
            B["array[0]"] --> B2
            C("Start (init)") --> C2
            D{"{x}"} --> D2
        """)
        #expect(s.nodes["B"] == "array[0]")
        #expect(s.nodes["C"] == "Start (init)")
        #expect(s.nodes["D"] == "{x}")
        #expect(s.shapes["B"] == "rectangle")
        #expect(s.shapes["C"] == "rounded")
        #expect(s.shapes["D"] == "diamond")
        #expect(s.edges == ["B->B2", "C->C2", "D->D2"])
    }

    @Test("a quoted label with a different bracket still parses")
    func quotedLabelWithOtherBracket() async throws {
        let s = try await Self.summary("flowchart LR\n    A[\"x (y)\"] --> B")
        #expect(s.nodes["A"] == "x (y)")
        #expect(s.edges == ["A->B"])
    }

    @Test("a text label written without spaces labels one edge")
    func unspacedTextLabel() async throws {
        let s = try await Self.summary("flowchart LR\n    Q--text-->Q2")
        #expect(s.nodes["text"] == nil)
        #expect(s.edges == ["Q->Q2:text"])
    }

    @Test("--> and --o after a node are still plain arrows")
    func unspacedArrowsUnchanged() async throws {
        let s = try await Self.summary("flowchart LR\n    A-->B\n    B--oC\n    C---D")
        #expect(s.edges == ["A->B", "B->C", "C->D"])
    }

    @Test("two slash-shaped nodes on one line stay two nodes")
    func slashShapesOnOneLine() async throws {
        let s = try await Self.summary("flowchart LR\n    W[/para/] --> X[\\alt\\]\n    A[\\x\\] --> B[/y/]")
        #expect(s.nodes["W"] == "para")
        #expect(s.nodes["X"] == "alt")
        #expect(s.nodes["A"] == "x")
        #expect(s.nodes["B"] == "y")
        #expect(s.shapes["W"] == "parallelogram")
        #expect(s.shapes["X"] == "parallelogramAlt")
        #expect(s.edges == ["W->X", "A->B"])
    }

    @Test("trapezoid shapes still parse")
    func trapezoidShapes() async throws {
        let s = try await Self.summary("flowchart LR\n    T[/top\\] --> U[\\bottom/]")
        #expect(s.shapes["T"] == "trapezoid")
        #expect(s.shapes["U"] == "trapezoidAlt")
        #expect(s.edges == ["T->U"])
    }
    @Test("%% inside a quoted label is label text, not a comment")
    func percentInsideQuotedLabel() async throws {
        let s = try await Self.summary("flowchart LR\n    E[\"100%% done\"] --> F %% trailing comment")
        #expect(s.nodes["E"] == "100%% done")
        #expect(s.edges == ["E->F"])
    }
}

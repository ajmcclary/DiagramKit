import XCTest
@testable import DiagramKit
@testable import DiagramKitModel

/// Labeled-edge regression coverage for the flowchart edge tokenizer
/// (`_scanEdgeOp`). Before the pipe-label fix, every `-->|text|`-style edge
/// was silently dropped by the parser — along with any target node referenced
/// only by that edge (corpus entry `flow-6-edge-styles` rendered a single
/// source node for years). These tests pin the token-level behavior of each
/// Mermaid labeled-edge form and the document-level invariant that the edge
/// AND its endpoints survive the parse.
final class LabeledEdgeParsingTests: XCTestCase {

    // MARK: - Tokenizer-level

    private func scan(_ text: String) -> _ParsedEdgeOp? {
        _scanEdgeOp(text)
    }

    func testPipeLabelAfterArrowOperator() throws {
        let op = try XCTUnwrap(scan("-->|solid| B"))
        XCTAssertEqual(op.label, "solid")
        XCTAssertEqual(op.arrowHeadEnd, .arrow)
        XCTAssertEqual(op.consumedLength, "-->|solid|".count)
    }

    func testPipeLabelBetweenSplitSolidOperator() throws {
        let op = try XCTUnwrap(scan("--|open|--> B"))
        XCTAssertEqual(op.label, "open")
        XCTAssertEqual(op.arrowHeadEnd, .arrow)
        XCTAssertEqual(op.consumedLength, "--|open|-->".count)
    }

    func testPipeLabelAfterOpenLinkOperator() throws {
        // `A ---|related| B` is Mermaid's labeled OPEN link: no arrowhead.
        let op = try XCTUnwrap(scan("---|related| B"))
        XCTAssertEqual(op.label, "related")
        XCTAssertEqual(op.arrowHeadEnd, .none)
        XCTAssertEqual(op.consumedLength, "---|related|".count)
    }

    func testPipeLabelAfterDottedOperator() throws {
        let op = try XCTUnwrap(scan("-.->|dotted| C"))
        XCTAssertEqual(op.label, "dotted")
        XCTAssertEqual(op.style, .dotted)
        XCTAssertEqual(op.arrowHeadEnd, .arrow)
    }

    func testPipeLabelBetweenSplitDottedOperator() throws {
        let op = try XCTUnwrap(scan("-.|dotted|.-> C"))
        XCTAssertEqual(op.label, "dotted")
        XCTAssertEqual(op.style, .dotted)
        XCTAssertEqual(op.arrowHeadEnd, .arrow)
        XCTAssertEqual(op.consumedLength, "-.|dotted|.->".count)
    }

    func testPipeLabelAfterThickOperator() throws {
        let op = try XCTUnwrap(scan("==>|thick| D"))
        XCTAssertEqual(op.label, "thick")
        XCTAssertEqual(op.style, .thick)
        XCTAssertEqual(op.arrowHeadEnd, .arrow)
    }

    func testPipeLabelBetweenSplitThickOperator() throws {
        let op = try XCTUnwrap(scan("==|thick|==> D"))
        XCTAssertEqual(op.label, "thick")
        XCTAssertEqual(op.style, .thick)
        XCTAssertEqual(op.arrowHeadEnd, .arrow)
        XCTAssertEqual(op.consumedLength, "==|thick|==>".count)
    }

    func testPipeLabelAfterBidirectionalOperator() throws {
        let op = try XCTUnwrap(scan("<-->|sync| B"))
        XCTAssertEqual(op.label, "sync")
        XCTAssertEqual(op.arrowHeadStart, .arrow)
        XCTAssertEqual(op.arrowHeadEnd, .arrow)
    }

    func testUnlabeledOperatorsKeepNilLabel() throws {
        for text in ["-->", "---", "-.->", "==>", "<-->", "~~~"] {
            let op = try XCTUnwrap(scan("\(text) B"), text)
            XCTAssertNil(op.label, text)
        }
    }

    func testUnterminatedPipeIsNotALabel() throws {
        // A stray `|` with no closing pipe must not swallow the operator:
        // the op keeps its original extent so downstream parsing is unchanged.
        let op = try XCTUnwrap(scan("-->|oops B"))
        XCTAssertNil(op.label)
        XCTAssertEqual(op.consumedLength, 3)
    }

    // MARK: - Document-level

    private func parseFlowchart(_ source: String) async throws -> (nodes: [String], edges: [(String, String, String?)]) {
        let document = try await DiagramEngine.parse(source)
        guard case .flowchart(let graph) = document.payload else {
            XCTFail("Expected flowchart payload, got \(document.payload)")
            return ([], [])
        }
        return (
            graph.nodesInOrder.map { $0.id },
            graph.edges.map { ($0.source, $0.target, $0.label) }
        )
    }

    func testLabeledEdgeTargetNodeExists() async throws {
        let (nodes, edges) = try await parseFlowchart("graph TD\n  A -->|label| B")
        XCTAssertEqual(nodes.sorted(), ["A", "B"], "target referenced only by a labeled edge must exist")
        XCTAssertEqual(edges.count, 1)
        XCTAssertEqual(edges.first?.0, "A")
        XCTAssertEqual(edges.first?.1, "B")
        XCTAssertEqual(edges.first?.2, "label")
    }

    func testChainedLabeledEdges() async throws {
        let (nodes, edges) = try await parseFlowchart("graph LR\n  A -->|x| B -->|y| C")
        XCTAssertEqual(nodes.sorted(), ["A", "B", "C"])
        XCTAssertEqual(edges.map { "\($0.0)->\($0.1):\($0.2 ?? "")" }.sorted(),
                       ["A->B:x", "B->C:y"])
    }

    func testAllLabeledFormsParseWithLabelsAndEndpoints() async throws {
        let source = """
        graph TD
          A -->|solid| B
          B --|open| C
          C ---|related| D
          D -.->|dotted| E
          E ==>|thick| F
          F <-->|both| A
        """
        let (nodes, edges) = try await parseFlowchart(source)
        XCTAssertEqual(nodes.sorted(), ["A", "B", "C", "D", "E", "F"])
        let labels = edges.map { "\($0.0)->\($0.1):\($0.2 ?? "nil")" }
        XCTAssertEqual(
            Set(labels),
            ["A->B:solid", "B->C:open", "C->D:related",
             "D->E:dotted", "E->F:thick", "F->A:both"]
        )
    }
}

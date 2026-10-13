#if canImport(UIKit) || canImport(AppKit)
import XCTest
import Foundation
import DiagramKitCommon
import DiagramKitTestSupport
@testable import DiagramKit

/// REVIEW.md §6.5 structural assertions for the flowchart/state layout
/// pipeline: every edge in the parsed document must reach the rendered SVG,
/// and every edge label string must appear in it. Pixel snapshots pin
/// geometry; they cannot catch a silently dropped edge (REVIEW.md C1 pinned
/// exactly that as "correct" for flow-16-subgraphs). This suite counts
/// `class="edge"` elements instead, so an edge can no longer disappear
/// without failing a test.
final class CorpusEdgeCountStructuralTests: XCTestCase {

    // MARK: - Loaders (same shape as SVGStructuralSweepTests)

    private static func loadCorpus() throws -> [CorpusEntry] {
        GanttTodayEnv.set()
        return try DiagramCorpus.load()
    }

    /// Count rendered edge elements. `_renderEdge` always emits
    /// `class="edge"` (plus ` edge-animated` / ` transition` variants);
    /// `edge-label` groups and `edge-animated`/`edge-*` substrings are
    /// excluded by requiring the quote or space right after `edge`.
    private static func renderedEdgeCount(in svg: String) -> Int {
        let pattern = #"class="edge("| )"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let ns = svg as NSString
        return regex.numberOfMatches(
            in: svg,
            range: NSRange(location: 0, length: ns.length)
        )
    }

    // MARK: - Targeted C1 reproductions

    func testFlow16SubgraphsRendersAllThreeEdges() async throws {
        let entry = try Self.loadCorpus().first(where: { $0.id == "flow-16-subgraphs" })
        let svg = try await DiagramEngine.renderSVG(source: XCTUnwrap(entry?.source))
        XCTAssertEqual(Self.renderedEdgeCount(in: svg), 3, "flow-16-subgraphs must render A-->B, C-->D, and the cross-subgraph B-->C")
    }

    /// Labeled-edge forms (pipe labels, split operators, text-embedded
    /// labels, chained labels) must reach the SVG at full count — the
    /// labeled `-->|text|` forms used to be dropped by the parser entirely
    /// (REVIEW C1's sibling defect; `flow-6-edge-styles` baselined only the
    /// source node). Structural, not pixel: parsed edge count == rendered
    /// edge count, and every label string survives.
    func testLabeledEdgeFormsRenderAtFullCount() async throws {
        let source = """
        graph TD
          A -->|solid| B
          B --|open| C
          C ---|related| D
          D -.->|dotted| E
          E -. embedded .-> F
          F ==>|thick| G
          G == embedded ==> H
          H <-->|both| A
          B -->|yes| I{Decision}
          I -->|no| J -->|retry| A
        """
        let document = try await DiagramEngine.parse(source)
        guard case .flowchart(let graph) = document.payload else {
            return XCTFail("Expected flowchart payload")
        }
        XCTAssertEqual(graph.edges.count, 11, "all ten labeled statements plus the chained hop must parse")
        XCTAssertEqual(
            Set(graph.nodesInOrder.map { $0.id }),
            Set(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]),
            "targets referenced only by labeled edges must exist")

        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertEqual(Self.renderedEdgeCount(in: svg), 11,
                       "every labeled edge must reach the SVG")
        for edge in graph.edges {
            guard let label = edge.label, !label.isEmpty else {
                XCTFail("edge \(edge.source)->\(edge.target) lost its label")
                continue
            }
            XCTAssertTrue(svg.contains(label) || svg.contains(SVG.escapeAttribute(label)),
                          "edge label \"\(label)\" missing from SVG")
        }
    }

    func testFlow18SubgraphDirectionRendersAllFiveEdges() async throws {
        let entry = try Self.loadCorpus().first(where: { $0.id == "flow-18-subgraph-direction" })
        let svg = try await DiagramEngine.renderSVG(source: XCTUnwrap(entry?.source))
        XCTAssertEqual(Self.renderedEdgeCount(in: svg), 5, "flow-18-subgraph-direction must render the 3 internal edges plus E-->A and D-->F")
    }

    /// Endpoints that legitimately exist in the layout: declared nodes plus
    /// subgraph/composite container ids (state composites like `Processing`
    /// are subgraphs, not `nodesInOrder` entries, yet participate in edges).
    private static func layoutEndpointIds(_ graph: original_src_types.MermaidGraph) -> Set<String> {
        var ids = Set(graph.nodesInOrder.map { $0.id })
        func walk(_ subs: [original_src_types.MermaidSubgraph]) {
            for sub in subs {
                ids.insert(sub.id)
                walk(sub.children)
            }
        }
        walk(graph.subgraphs)
        return ids
    }

    // MARK: - Corpus-wide structural sweep

    func testFlowchartEdgeCountAndLabelsMatchParsedDocument() async throws {
        let entries = try Self.loadCorpus().filter { $0.category == "flowchart" }
        XCTAssertGreaterThan(entries.count, 30)
        var failures: [String] = []
        for entry in entries {
            let document = try await DiagramEngine.parse(entry.source)
            guard case .flowchart(let graph) = document.payload else {
                failures.append("\(entry.id): corpus flowchart parsed as \(document.payload)")
                continue
            }
            let svg = try await DiagramEngine.renderSVG(source: entry.source)
            let endpoints = Self.layoutEndpointIds(graph)
            let parsed = graph.edges.filter { endpoints.contains($0.source) && endpoints.contains($0.target) }.count
            let rendered = Self.renderedEdgeCount(in: svg)
            if rendered != parsed {
                failures.append("\(entry.id): parsed \(parsed) edges, SVG renders \(rendered)")
                continue
            }
            // Label presence: every edge label string must survive to the
            // SVG (attribute-escaped, the form the renderer emits).
            for edge in graph.edges {
                guard let label = edge.label, !label.isEmpty else { continue }
                let escaped = SVG.escapeAttribute(label)
                if !svg.contains(escaped) && !svg.contains(label) {
                    failures.append("\(entry.id): edge label \"\(label)\" missing from SVG")
                }
            }
        }
        if !failures.isEmpty {
            XCTFail("\(failures.count) flowchart structural failure(s):\n  " + failures.joined(separator: "\n  "))
        }
    }

    func testStateEdgeCountsMatchParsedDocument() async throws {
        let entries = try Self.loadCorpus().filter { $0.category == "state" }
        XCTAssertGreaterThan(entries.count, 5)
        var failures: [String] = []
        for entry in entries {
            let document = try await DiagramEngine.parse(entry.source)
            guard case .stateDiagram(let graph) = document.payload else {
                failures.append("\(entry.id): corpus state entry parsed as \(document.payload)")
                continue
            }
            // Edges whose endpoints the parser dropped entirely (e.g. a
            // state literally named "End" in state-6-choice-fork never
            // becomes a node) are a separate parser defect from the
            // edge-routing drop C1 covers; only count routable edges.
            let endpoints = Self.layoutEndpointIds(graph)
            let parsed = graph.edges.filter { endpoints.contains($0.source) && endpoints.contains($0.target) }.count
            let svg = try await DiagramEngine.renderSVG(source: entry.source)
            let rendered = Self.renderedEdgeCount(in: svg)
            if rendered != parsed {
                failures.append("\(entry.id): parsed \(parsed) transitions, SVG renders \(rendered)")
            }
        }
        if !failures.isEmpty {
            XCTFail("\(failures.count) state structural failure(s):\n  " + failures.joined(separator: "\n  "))
        }
    }
}
#endif

import Testing
@testable import DiagramKit
import DiagramKitModel

/// REVIEW.md §4 (Tests, gates, concurrency): regression insurance for
/// the parser dispatch-order invariant that CLAUDE.md calls out
/// explicitly: "stateDiagram-v2 must not fall into state branch".
///
/// `DiagramRegistry.detect(from:)` walks `DiagramRegistry.all` and
/// returns the first descriptor whose `matches(header:)` returns true.
/// Narrower headers (stateDiagram-v2, flowchart-elk, gitGraph-v2, …)
/// must appear before broader ones; the fallback is `_flowchart`.
///
/// These tests pin specific header → descriptor.type pairs so a future
/// reorder of `DiagramRegistry.all` or a regression in a per-family
/// matcher surfaces here instead of as a corpus-snapshot mystery.
@Suite struct ParserDispatchOrderTests {

    private func detect(_ source: String) -> DiagramType {
        DiagramRegistry.detect(from: source).type
    }

    @Test("stateDiagram-v2 routes to stateDiagram (not falls through)")
    func stateDiagramV2() {
        #expect(detect("stateDiagram-v2\n[*] --> A") == .stateDiagram)
    }

    @Test("stateDiagram routes to stateDiagram")
    func stateDiagram() {
        #expect(detect("stateDiagram\n[*] --> A") == .stateDiagram)
    }

    @Test("flowchart-elk routes to flowchart (not falls through)")
    func flowchartElk() {
        #expect(detect("flowchart-elk LR\nA --> B") == .flowchart)
    }

    @Test("flowchart routes to flowchart")
    func flowchart() {
        #expect(detect("flowchart LR\nA --> B") == .flowchart)
    }

    @Test("graph routes to flowchart")
    func graph() {
        #expect(detect("graph TD\nA-->B") == .flowchart)
    }

    @Test("sequenceDiagram routes to sequenceDiagram")
    func sequenceDiagram() {
        #expect(detect("sequenceDiagram\nA->>B: hi") == .sequenceDiagram)
    }

    @Test("classDiagram routes to classDiagram")
    func classDiagram() {
        #expect(detect("classDiagram\nclass A") == .classDiagram)
    }

    @Test("classDiagram-v2 routes to classDiagram (not falls through)")
    func classDiagramV2() {
        #expect(detect("classDiagram-v2\nclass A") == .classDiagram)
    }

    @Test("gitGraph routes to gitGraph")
    func gitGraph() {
        #expect(detect("gitGraph\ncommit") == .gitGraph)
    }

    @Test("erDiagram routes to erDiagram")
    func erDiagram() {
        #expect(detect("erDiagram\nA ||--o{ B : x") == .erDiagram)
    }

    @Test("mindmap routes to mindmap")
    func mindmap() {
        #expect(detect("mindmap\nroot((R))") == .mindmap)
    }

    @Test("pie routes to pie")
    func pie() {
        #expect(detect("pie\n\"A\" : 50") == .pie)
    }

    @Test("gantt routes to gantt")
    func gantt() {
        #expect(detect("gantt\nsection A") == .gantt)
    }

    @Test("xychart-beta routes to xyChart")
    func xychart() {
        #expect(detect("xychart-beta\ntitle T") == .xyChart)
    }

    @Test("quadrantChart routes to quadrantChart")
    func quadrantChart() {
        #expect(detect("quadrantChart\ntitle T") == .quadrantChart)
    }

    @Test("Unknown header falls back to flowchart")
    func fallback() {
        #expect(detect("not a real header\nA-->B") == .flowchart)
    }
}

import Testing
import DiagramKitTestSupport
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
import DiagramKit
import DiagramKitMermaid
import Foundation

@Suite("RoundTripHarness")
struct RoundTripHarnessTests {

    @Test("Same-format harness surfaces unexpected delta from not-yet-implemented stub")
    func unexpectedDeltaThrows() {
        let cell = RoundTripCellRegistry.mermaidFlowchart
        let fixture = RoundTripFixture(path: "synthetic", source: "graph TD\nA-->B")
        // Mermaid flowchart comparator is currently a not-yet-implemented stub.
        // The harness should surface that as a failure rather than swallow it.
        do {
            try runSameFormatRoundTrip(cell: cell, fixture: fixture)
            Issue.record("expected the harness to throw on not-yet-implemented stub")
        } catch let error as RoundTripHarnessError {
            switch error {
            case .unexpectedDelta(let path, _, _):
                #expect(path == "flowchart")
            default:
                Issue.record("expected .unexpectedDelta, got \(error)")
            }
        } catch {
            Issue.record("expected RoundTripHarnessError, got \(error)")
        }
    }
}

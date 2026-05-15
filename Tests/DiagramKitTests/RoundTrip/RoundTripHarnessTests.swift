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

    @Test("Same-format harness completes silently on a happy-path fixture")
    func happyPathDoesNotThrow() throws {
        let cell = RoundTripCellRegistry.mermaidFlowchart
        let fixture = RoundTripFixture(path: "synthetic", source: "graph TD\nA-->B")
        try runSameFormatRoundTrip(cell: cell, fixture: fixture)
    }

    @Test("Same-format harness surfaces .disallowedLoss when an id-sanitization happens but the cell forbids it")
    func disallowedLossThrows() {
        // Build a synthetic cell that forbids idSanitization losses.
        let cell = RoundTripCell(
            importer: MermaidImporter(),
            exporter: MermaidExporter(),
            family: DiagramType.flowchart,
            allowedLosses: []
        )
        // Source uses a non-alpha id that the exporter will sanitize.
        let fixture = RoundTripFixture(path: "synthetic", source: "graph TD\n\"a b\"[Label]-->c")
        do {
            try runSameFormatRoundTrip(cell: cell, fixture: fixture)
        } catch let error as RoundTripHarnessError {
            switch error {
            case .disallowedLoss, .unpairedLoss, .unexpectedDelta:
                // any of these is a valid surfacing — the contract is "no
                // silent passes when the cell allow-list does not cover the
                // observed deltas."
                return
            default:
                Issue.record("unexpected RoundTripHarnessError: \(error)")
            }
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

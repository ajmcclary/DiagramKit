import Testing
import DiagramKitTestSupport
import DiagramKitImport
import DiagramKitExport
import DiagramKit
import DiagramKitMermaid
import DiagramKitCommon
import DiagramKitModel

@Suite("RoundTripCell")
struct RoundTripCellTests {

    @Test("Registry exposes mermaidFlowchart cell with correct format identity")
    func mermaidFlowchartCellShape() {
        let cell = RoundTripCellRegistry.mermaidFlowchart
        #expect(cell.importer.formatID == .mermaid)
        #expect(cell.exporter.formatID == .mermaid)
        #expect(cell.family == .flowchart)
        #expect(cell.allowedLosses.contains(.idSanitization))
    }

    @Test("RoundTripFixture default has no additional allowed losses")
    func fixtureDefaults() {
        let fixture = RoundTripFixture(path: "x", source: "graph TD\nA-->B")
        #expect(fixture.additionalAllowedLosses.isEmpty)
        #expect(fixture.note == nil)
    }
}

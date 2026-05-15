import Testing
import DiagramKitTestSupport
import Foundation

@Suite("Cross-format round-trip")
struct CrossFormatRoundTripTests {

    // MARK: Mermaid ↔ D2 (flowchart)

    @Test(
        "Mermaid → D2 → Mermaid (flowchart)",
        arguments: try fixtures(for: "cross-mermaid-d2-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func mermaidD2Flowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidFlowchart,
            legB: RoundTripCellRegistry.d2Flowchart,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2Flowchart,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Mermaid → D2 (flowchart)",
        arguments: try fixtures(for: "cross-d2-mermaid-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func d2MermaidFlowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Flowchart,
            legB: RoundTripCellRegistry.mermaidFlowchart,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidFlowchart,
            fixture: fixture
        )
    }
}

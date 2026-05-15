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

    // MARK: Mermaid ↔ DOT (flowchart)

    @Test(
        "Mermaid → DOT → Mermaid (flowchart)",
        arguments: try fixtures(for: "cross-mermaid-dot-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func mermaidDotFlowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidFlowchart,
            legB: RoundTripCellRegistry.dotFlowchart,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidDotFlowchart,
            fixture: fixture
        )
    }

    @Test(
        "DOT → Mermaid → DOT (flowchart)",
        arguments: try fixtures(for: "cross-dot-mermaid-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func dotMermaidFlowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotFlowchart,
            legB: RoundTripCellRegistry.mermaidFlowchart,
            additionalAllowedLosses: RoundTripCrossRegistry.dotMermaidFlowchart,
            fixture: fixture
        )
    }

    // MARK: D2 ↔ DOT (flowchart)

    @Test(
        "D2 → DOT → D2 (flowchart)",
        arguments: try fixtures(for: "cross-d2-dot-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func d2DotFlowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Flowchart,
            legB: RoundTripCellRegistry.dotFlowchart,
            additionalAllowedLosses: RoundTripCrossRegistry.d2DotFlowchart,
            fixture: fixture
        )
    }

    @Test(
        "DOT → D2 → DOT (flowchart)",
        arguments: try fixtures(for: "cross-dot-d2-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func dotD2Flowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotFlowchart,
            legB: RoundTripCellRegistry.d2Flowchart,
            additionalAllowedLosses: RoundTripCrossRegistry.dotD2Flowchart,
            fixture: fixture
        )
    }
}

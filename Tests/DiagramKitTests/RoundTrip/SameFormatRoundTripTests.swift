import Testing
import DiagramKitTestSupport
import Foundation

@Suite("Same-format round-trip")
struct SameFormatRoundTripTests {

    @Test(
        "Mermaid flowchart round-trip",
        arguments: try fixtures(for: "mermaid-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func mermaidFlowchart(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidFlowchart,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid sequence round-trip",
        arguments: try fixtures(for: "mermaid-sequence", fromRoot: roundTripResourcesRoot())
    )
    func mermaidSequence(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidSequence,
            fixture: fixture
        )
    }
}

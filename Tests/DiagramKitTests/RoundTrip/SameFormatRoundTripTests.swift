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

    @Test(
        "Mermaid class round-trip",
        arguments: try fixtures(for: "mermaid-class", fromRoot: roundTripResourcesRoot())
    )
    func mermaidClass(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidClass,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid ER round-trip",
        arguments: try fixtures(for: "mermaid-er", fromRoot: roundTripResourcesRoot())
    )
    func mermaidEr(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidEr,
            fixture: fixture
        )
    }
}

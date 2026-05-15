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

    @Test(
        "Mermaid C4 round-trip",
        arguments: try fixtures(for: "mermaid-c4", fromRoot: roundTripResourcesRoot())
    )
    func mermaidC4(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidC4,
            fixture: fixture
        )
    }

    @Test(
        "D2 flowchart round-trip",
        arguments: try fixtures(for: "d2-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func d2Flowchart(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.d2Flowchart,
            fixture: fixture
        )
    }

    @Test(
        "DOT flowchart round-trip",
        arguments: try fixtures(for: "dot-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func dotFlowchart(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.dotFlowchart,
            fixture: fixture
        )
    }

    @Test(
        "Structurizr C4 round-trip",
        arguments: try fixtures(for: "structurizr-c4", fromRoot: roundTripResourcesRoot())
    )
    func structurizrC4(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.structurizrC4,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML sequence round-trip",
        arguments: try fixtures(for: "plantuml-sequence", fromRoot: roundTripResourcesRoot())
    )
    func plantumlSequence(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlSequence,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML class round-trip",
        arguments: try fixtures(for: "plantuml-class", fromRoot: roundTripResourcesRoot())
    )
    func plantumlClass(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlClass,
            fixture: fixture
        )
    }
}

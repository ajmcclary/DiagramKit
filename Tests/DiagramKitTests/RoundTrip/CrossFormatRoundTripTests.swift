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

    // MARK: Mermaid ↔ Structurizr (C4)

    @Test(
        "Mermaid → Structurizr → Mermaid (C4)",
        arguments: try fixtures(for: "cross-mermaid-structurizr-c4", fromRoot: roundTripResourcesRoot())
    )
    func mermaidStructurizrC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidC4,
            legB: RoundTripCellRegistry.structurizrC4,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidStructurizrC4,
            fixture: fixture
        )
    }

    @Test(
        "Structurizr → Mermaid → Structurizr (C4)",
        arguments: try fixtures(for: "cross-structurizr-mermaid-c4", fromRoot: roundTripResourcesRoot())
    )
    func structurizrMermaidC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.structurizrC4,
            legB: RoundTripCellRegistry.mermaidC4,
            additionalAllowedLosses: RoundTripCrossRegistry.structurizrMermaidC4,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ PlantUML (C4)

    @Test(
        "Mermaid → PlantUML → Mermaid (C4)",
        arguments: try fixtures(for: "cross-mermaid-plantuml-c4", fromRoot: roundTripResourcesRoot())
    )
    func mermaidPlantumlC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidC4,
            legB: RoundTripCellRegistry.plantumlC4,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidPlantumlC4,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → Mermaid → PlantUML (C4)",
        arguments: try fixtures(for: "cross-plantuml-mermaid-c4", fromRoot: roundTripResourcesRoot())
    )
    func plantumlMermaidC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlC4,
            legB: RoundTripCellRegistry.mermaidC4,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlMermaidC4,
            fixture: fixture
        )
    }

    // MARK: PlantUML ↔ Structurizr (C4)

    @Test(
        "PlantUML → Structurizr → PlantUML (C4)",
        arguments: try fixtures(for: "cross-plantuml-structurizr-c4", fromRoot: roundTripResourcesRoot())
    )
    func plantumlStructurizrC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlC4,
            legB: RoundTripCellRegistry.structurizrC4,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlStructurizrC4,
            fixture: fixture
        )
    }

    @Test(
        "Structurizr → PlantUML → Structurizr (C4)",
        arguments: try fixtures(for: "cross-structurizr-plantuml-c4", fromRoot: roundTripResourcesRoot())
    )
    func structurizrPlantumlC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.structurizrC4,
            legB: RoundTripCellRegistry.plantumlC4,
            additionalAllowedLosses: RoundTripCrossRegistry.structurizrPlantumlC4,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ PlantUML (sequence)

    @Test(
        "Mermaid → PlantUML → Mermaid (sequence)",
        arguments: try fixtures(for: "cross-mermaid-plantuml-sequence", fromRoot: roundTripResourcesRoot())
    )
    func mermaidPlantumlSequence(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidSequence,
            legB: RoundTripCellRegistry.plantumlSequence,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidPlantumlSequence,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → Mermaid → PlantUML (sequence)",
        arguments: try fixtures(for: "cross-plantuml-mermaid-sequence", fromRoot: roundTripResourcesRoot())
    )
    func plantumlMermaidSequence(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlSequence,
            legB: RoundTripCellRegistry.mermaidSequence,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlMermaidSequence,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ PlantUML (class)

    @Test(
        "Mermaid → PlantUML → Mermaid (class)",
        arguments: try fixtures(for: "cross-mermaid-plantuml-class", fromRoot: roundTripResourcesRoot())
    )
    func mermaidPlantumlClass(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidClass,
            legB: RoundTripCellRegistry.plantumlClass,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidPlantumlClass,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → Mermaid → PlantUML (class)",
        arguments: try fixtures(for: "cross-plantuml-mermaid-class", fromRoot: roundTripResourcesRoot())
    )
    func plantumlMermaidClass(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlClass,
            legB: RoundTripCellRegistry.mermaidClass,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlMermaidClass,
            fixture: fixture
        )
    }
}


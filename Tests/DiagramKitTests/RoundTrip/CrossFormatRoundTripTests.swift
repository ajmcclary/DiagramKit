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

    // MARK: Mermaid ↔ PlantUML (ER) — Wave 1

    @Test(
        "Mermaid → PlantUML → Mermaid (ER)",
        arguments: try fixtures(for: "cross-mermaid-plantuml-er", fromRoot: roundTripResourcesRoot())
    )
    func mermaidPlantumlEr(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidEr,
            legB: RoundTripCellRegistry.plantumlEr,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidPlantumlEr,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → Mermaid → PlantUML (ER)",
        arguments: try fixtures(for: "cross-plantuml-mermaid-er", fromRoot: roundTripResourcesRoot())
    )
    func plantumlMermaidEr(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlEr,
            legB: RoundTripCellRegistry.mermaidEr,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlMermaidEr,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ PlantUML (flowchart, default→activity) — Wave 1

    @Test(
        "Mermaid → PlantUML → Mermaid (flowchart)",
        arguments: try fixtures(for: "cross-mermaid-plantuml-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func mermaidPlantumlFlowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidFlowchart,
            legB: RoundTripCellRegistry.plantumlActivity,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidPlantumlFlowchart,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → Mermaid → PlantUML (flowchart)",
        arguments: try fixtures(for: "cross-plantuml-mermaid-flowchart", fromRoot: roundTripResourcesRoot())
    )
    func plantumlMermaidFlowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlActivity,
            legB: RoundTripCellRegistry.mermaidFlowchart,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlMermaidFlowchart,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ D2 (class) — Wave 2

    @Test(
        "Mermaid → D2 → Mermaid (class)",
        arguments: try fixtures(for: "cross-mermaid-d2-class", fromRoot: roundTripResourcesRoot())
    )
    func mermaidD2Class(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidClass,
            legB: RoundTripCellRegistry.d2Class,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2Class,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Mermaid → D2 (class)",
        arguments: try fixtures(for: "cross-d2-mermaid-class", fromRoot: roundTripResourcesRoot())
    )
    func d2MermaidClass(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Class,
            legB: RoundTripCellRegistry.mermaidClass,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidClass,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ DOT (class) — Wave 2

    @Test(
        "Mermaid → DOT → Mermaid (class)",
        arguments: try fixtures(for: "cross-mermaid-dot-class", fromRoot: roundTripResourcesRoot())
    )
    func mermaidDotClass(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidClass,
            legB: RoundTripCellRegistry.dotClass,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidDotClass,
            fixture: fixture
        )
    }

    @Test(
        "DOT → Mermaid → DOT (class)",
        arguments: try fixtures(for: "cross-dot-mermaid-class", fromRoot: roundTripResourcesRoot())
    )
    func dotMermaidClass(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotClass,
            legB: RoundTripCellRegistry.mermaidClass,
            additionalAllowedLosses: RoundTripCrossRegistry.dotMermaidClass,
            fixture: fixture
        )
    }

    // MARK: D2 ↔ DOT (class) — Wave 2

    @Test(
        "D2 → DOT → D2 (class)",
        arguments: try fixtures(for: "cross-d2-dot-class", fromRoot: roundTripResourcesRoot())
    )
    func d2DotClass(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Class,
            legB: RoundTripCellRegistry.dotClass,
            additionalAllowedLosses: RoundTripCrossRegistry.d2DotClass,
            fixture: fixture
        )
    }

    @Test(
        "DOT → D2 → DOT (class)",
        arguments: try fixtures(for: "cross-dot-d2-class", fromRoot: roundTripResourcesRoot())
    )
    func dotD2Class(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotClass,
            legB: RoundTripCellRegistry.d2Class,
            additionalAllowedLosses: RoundTripCrossRegistry.dotD2Class,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ D2 (state) — Wave 2

    @Test(
        "Mermaid → D2 → Mermaid (state)",
        arguments: try fixtures(for: "cross-mermaid-d2-state", fromRoot: roundTripResourcesRoot())
    )
    func mermaidD2State(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidState,
            legB: RoundTripCellRegistry.d2State,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2State,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Mermaid → D2 (state)",
        arguments: try fixtures(for: "cross-d2-mermaid-state", fromRoot: roundTripResourcesRoot())
    )
    func d2MermaidState(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2State,
            legB: RoundTripCellRegistry.mermaidState,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidState,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ DOT (state) — Wave 2

    @Test(
        "Mermaid → DOT → Mermaid (state)",
        arguments: try fixtures(for: "cross-mermaid-dot-state", fromRoot: roundTripResourcesRoot())
    )
    func mermaidDotState(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidState,
            legB: RoundTripCellRegistry.dotState,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidDotState,
            fixture: fixture
        )
    }

    @Test(
        "DOT → Mermaid → DOT (state)",
        arguments: try fixtures(for: "cross-dot-mermaid-state", fromRoot: roundTripResourcesRoot())
    )
    func dotMermaidState(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotState,
            legB: RoundTripCellRegistry.mermaidState,
            additionalAllowedLosses: RoundTripCrossRegistry.dotMermaidState,
            fixture: fixture
        )
    }

    // MARK: D2 ↔ DOT (state) — Wave 2

    @Test(
        "D2 → DOT → D2 (state)",
        arguments: try fixtures(for: "cross-d2-dot-state", fromRoot: roundTripResourcesRoot())
    )
    func d2DotState(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2State,
            legB: RoundTripCellRegistry.dotState,
            additionalAllowedLosses: RoundTripCrossRegistry.d2DotState,
            fixture: fixture
        )
    }

    @Test(
        "DOT → D2 → DOT (state)",
        arguments: try fixtures(for: "cross-dot-d2-state", fromRoot: roundTripResourcesRoot())
    )
    func dotD2State(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotState,
            legB: RoundTripCellRegistry.d2State,
            additionalAllowedLosses: RoundTripCrossRegistry.dotD2State,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ D2 (ER) — Wave 2

    @Test(
        "Mermaid → D2 → Mermaid (ER)",
        arguments: try fixtures(for: "cross-mermaid-d2-er", fromRoot: roundTripResourcesRoot())
    )
    func mermaidD2Er(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidEr,
            legB: RoundTripCellRegistry.d2Er,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2Er,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Mermaid → D2 (ER)",
        arguments: try fixtures(for: "cross-d2-mermaid-er", fromRoot: roundTripResourcesRoot())
    )
    func d2MermaidEr(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Er,
            legB: RoundTripCellRegistry.mermaidEr,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidEr,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ DOT (ER) — Wave 2

    @Test(
        "Mermaid → DOT → Mermaid (ER)",
        arguments: try fixtures(for: "cross-mermaid-dot-er", fromRoot: roundTripResourcesRoot())
    )
    func mermaidDotEr(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidEr,
            legB: RoundTripCellRegistry.dotEr,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidDotEr,
            fixture: fixture
        )
    }

    @Test(
        "DOT → Mermaid → DOT (ER)",
        arguments: try fixtures(for: "cross-dot-mermaid-er", fromRoot: roundTripResourcesRoot())
    )
    func dotMermaidEr(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotEr,
            legB: RoundTripCellRegistry.mermaidEr,
            additionalAllowedLosses: RoundTripCrossRegistry.dotMermaidEr,
            fixture: fixture
        )
    }

    // MARK: D2 ↔ DOT (ER) — Wave 2

    @Test(
        "D2 → DOT → D2 (ER)",
        arguments: try fixtures(for: "cross-d2-dot-er", fromRoot: roundTripResourcesRoot())
    )
    func d2DotEr(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Er,
            legB: RoundTripCellRegistry.dotEr,
            additionalAllowedLosses: RoundTripCrossRegistry.d2DotEr,
            fixture: fixture
        )
    }

    @Test(
        "DOT → D2 → DOT (ER)",
        arguments: try fixtures(for: "cross-dot-d2-er", fromRoot: roundTripResourcesRoot())
    )
    func dotD2Er(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotEr,
            legB: RoundTripCellRegistry.d2Er,
            additionalAllowedLosses: RoundTripCrossRegistry.dotD2Er,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ D2 (architecture)

    @Test(
        "Mermaid → D2 → Mermaid (architecture)",
        arguments: try fixtures(for: "cross-mermaid-d2-architecture", fromRoot: roundTripResourcesRoot())
    )
    func mermaidD2Architecture(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidArchitecture,
            legB: RoundTripCellRegistry.d2Architecture,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2Architecture,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Mermaid → D2 (architecture)",
        arguments: try fixtures(for: "cross-d2-mermaid-architecture", fromRoot: roundTripResourcesRoot())
    )
    func d2MermaidArchitecture(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Architecture,
            legB: RoundTripCellRegistry.mermaidArchitecture,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidArchitecture,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ DOT (architecture)

    @Test(
        "Mermaid → DOT → Mermaid (architecture)",
        arguments: try fixtures(for: "cross-mermaid-dot-architecture", fromRoot: roundTripResourcesRoot())
    )
    func mermaidDotArchitecture(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidArchitecture,
            legB: RoundTripCellRegistry.dotArchitecture,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidDotArchitecture,
            fixture: fixture
        )
    }

    @Test(
        "DOT → Mermaid → DOT (architecture)",
        arguments: try fixtures(for: "cross-dot-mermaid-architecture", fromRoot: roundTripResourcesRoot())
    )
    func dotMermaidArchitecture(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotArchitecture,
            legB: RoundTripCellRegistry.mermaidArchitecture,
            additionalAllowedLosses: RoundTripCrossRegistry.dotMermaidArchitecture,
            fixture: fixture
        )
    }

    // MARK: D2 ↔ DOT (architecture)

    @Test(
        "D2 → DOT → D2 (architecture)",
        arguments: try fixtures(for: "cross-d2-dot-architecture", fromRoot: roundTripResourcesRoot())
    )
    func d2DotArchitecture(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Architecture,
            legB: RoundTripCellRegistry.dotArchitecture,
            additionalAllowedLosses: RoundTripCrossRegistry.d2DotArchitecture,
            fixture: fixture
        )
    }

    @Test(
        "DOT → D2 → DOT (architecture)",
        arguments: try fixtures(for: "cross-dot-d2-architecture", fromRoot: roundTripResourcesRoot())
    )
    func dotD2Architecture(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotArchitecture,
            legB: RoundTripCellRegistry.d2Architecture,
            additionalAllowedLosses: RoundTripCrossRegistry.dotD2Architecture,
            fixture: fixture
        )
    }
}


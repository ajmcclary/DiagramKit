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

    // MARK: Mermaid ↔ D2 (sequence) — Wave F

    @Test(
        "Mermaid → D2 → Mermaid (sequence)",
        arguments: try fixtures(for: "cross-mermaid-d2-sequence", fromRoot: roundTripResourcesRoot())
    )
    func mermaidD2Sequence(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidSequence,
            legB: RoundTripCellRegistry.d2Sequence,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2Sequence,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Mermaid → D2 (sequence)",
        arguments: try fixtures(for: "cross-d2-mermaid-sequence", fromRoot: roundTripResourcesRoot())
    )
    func d2MermaidSequence(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Sequence,
            legB: RoundTripCellRegistry.mermaidSequence,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidSequence,
            fixture: fixture
        )
    }

    // MARK: PlantUML ↔ D2 (sequence) — Wave F

    @Test(
        "PlantUML → D2 → PlantUML (sequence)",
        arguments: try fixtures(for: "cross-plantuml-d2-sequence", fromRoot: roundTripResourcesRoot())
    )
    func plantumlD2Sequence(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlSequence,
            legB: RoundTripCellRegistry.d2Sequence,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlD2Sequence,
            fixture: fixture
        )
    }

    @Test(
        "D2 → PlantUML → D2 (sequence)",
        arguments: try fixtures(for: "cross-d2-plantuml-sequence", fromRoot: roundTripResourcesRoot())
    )
    func d2PlantumlSequence(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Sequence,
            legB: RoundTripCellRegistry.plantumlSequence,
            additionalAllowedLosses: RoundTripCrossRegistry.d2PlantumlSequence,
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

    // MARK: Mermaid ↔ D2 (mindmap)

    @Test(
        "Mermaid → D2 → Mermaid (mindmap)",
        arguments: try fixtures(for: "cross-mermaid-d2-mindmap", fromRoot: roundTripResourcesRoot())
    )
    func mermaidD2Mindmap(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidMindmap,
            legB: RoundTripCellRegistry.d2Mindmap,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2Mindmap,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Mermaid → D2 (mindmap)",
        arguments: try fixtures(for: "cross-d2-mermaid-mindmap", fromRoot: roundTripResourcesRoot())
    )
    func d2MermaidMindmap(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Mindmap,
            legB: RoundTripCellRegistry.mermaidMindmap,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidMindmap,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ DOT (mindmap)

    @Test(
        "Mermaid → DOT → Mermaid (mindmap)",
        arguments: try fixtures(for: "cross-mermaid-dot-mindmap", fromRoot: roundTripResourcesRoot())
    )
    func mermaidDotMindmap(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidMindmap,
            legB: RoundTripCellRegistry.dotMindmap,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidDotMindmap,
            fixture: fixture
        )
    }

    @Test(
        "DOT → Mermaid → DOT (mindmap)",
        arguments: try fixtures(for: "cross-dot-mermaid-mindmap", fromRoot: roundTripResourcesRoot())
    )
    func dotMermaidMindmap(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotMindmap,
            legB: RoundTripCellRegistry.mermaidMindmap,
            additionalAllowedLosses: RoundTripCrossRegistry.dotMermaidMindmap,
            fixture: fixture
        )
    }

    // MARK: D2 ↔ DOT (mindmap)

    @Test(
        "D2 → DOT → D2 (mindmap)",
        arguments: try fixtures(for: "cross-d2-dot-mindmap", fromRoot: roundTripResourcesRoot())
    )
    func d2DotMindmap(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Mindmap,
            legB: RoundTripCellRegistry.dotMindmap,
            additionalAllowedLosses: RoundTripCrossRegistry.d2DotMindmap,
            fixture: fixture
        )
    }

    @Test(
        "DOT → D2 → DOT (mindmap)",
        arguments: try fixtures(for: "cross-dot-d2-mindmap", fromRoot: roundTripResourcesRoot())
    )
    func dotD2Mindmap(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotMindmap,
            legB: RoundTripCellRegistry.d2Mindmap,
            additionalAllowedLosses: RoundTripCrossRegistry.dotD2Mindmap,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ D2 (treeView)

    @Test(
        "Mermaid → D2 → Mermaid (treeView)",
        arguments: try fixtures(for: "cross-mermaid-d2-treeView", fromRoot: roundTripResourcesRoot())
    )
    func mermaidD2TreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidTreeView,
            legB: RoundTripCellRegistry.d2TreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2TreeView,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Mermaid → D2 (treeView)",
        arguments: try fixtures(for: "cross-d2-mermaid-treeView", fromRoot: roundTripResourcesRoot())
    )
    func d2MermaidTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2TreeView,
            legB: RoundTripCellRegistry.mermaidTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidTreeView,
            fixture: fixture
        )
    }

    // MARK: Mermaid ↔ DOT (treeView)

    @Test(
        "Mermaid → DOT → Mermaid (treeView)",
        arguments: try fixtures(for: "cross-mermaid-dot-treeView", fromRoot: roundTripResourcesRoot())
    )
    func mermaidDotTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidTreeView,
            legB: RoundTripCellRegistry.dotTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidDotTreeView,
            fixture: fixture
        )
    }

    @Test(
        "DOT → Mermaid → DOT (treeView)",
        arguments: try fixtures(for: "cross-dot-mermaid-treeView", fromRoot: roundTripResourcesRoot())
    )
    func dotMermaidTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotTreeView,
            legB: RoundTripCellRegistry.mermaidTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.dotMermaidTreeView,
            fixture: fixture
        )
    }

    // MARK: D2 ↔ DOT (treeView)

    @Test(
        "D2 → DOT → D2 (treeView)",
        arguments: try fixtures(for: "cross-d2-dot-treeView", fromRoot: roundTripResourcesRoot())
    )
    func d2DotTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2TreeView,
            legB: RoundTripCellRegistry.dotTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.d2DotTreeView,
            fixture: fixture
        )
    }

    // MARK: D2 ↔ PlantUML (treeView) — Wave H
    //
    // Mermaid ↔ PlantUML treeView is deliberately omitted: Mermaid uses a
    // synthetic "/" root convention (src_treeview_parser.swift:80) that
    // D2 / DOT / PlantUML don't share. The existing Mermaid ↔ D2 and
    // Mermaid ↔ DOT treeView fixtures have been silently skipping since
    // Wave E (`.mermaid` extension not in RoundTripFixtureLoader's set),
    // masking the same convention mismatch. Bridging that convention is
    // out of scope for Wave H.

    @Test(
        "D2 → PlantUML → D2 (treeView)",
        arguments: try fixtures(for: "cross-d2-plantuml-treeView", fromRoot: roundTripResourcesRoot())
    )
    func d2PlantumlTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2TreeView,
            legB: RoundTripCellRegistry.plantumlTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.d2PlantumlTreeView,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → D2 → PlantUML (treeView)",
        arguments: try fixtures(for: "cross-plantuml-d2-treeView", fromRoot: roundTripResourcesRoot())
    )
    func plantumlD2TreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlTreeView,
            legB: RoundTripCellRegistry.d2TreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlD2TreeView,
            fixture: fixture
        )
    }

    // MARK: DOT ↔ PlantUML (treeView) — Wave H

    @Test(
        "DOT → PlantUML → DOT (treeView)",
        arguments: try fixtures(for: "cross-dot-plantuml-treeView", fromRoot: roundTripResourcesRoot())
    )
    func dotPlantumlTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotTreeView,
            legB: RoundTripCellRegistry.plantumlTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.dotPlantumlTreeView,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → DOT → PlantUML (treeView)",
        arguments: try fixtures(for: "cross-plantuml-dot-treeView", fromRoot: roundTripResourcesRoot())
    )
    func plantumlDotTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlTreeView,
            legB: RoundTripCellRegistry.dotTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlDotTreeView,
            fixture: fixture
        )
    }

    @Test(
        "DOT → D2 → DOT (treeView)",
        arguments: try fixtures(for: "cross-dot-d2-treeView", fromRoot: roundTripResourcesRoot())
    )
    func dotD2TreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotTreeView,
            legB: RoundTripCellRegistry.d2TreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.dotD2TreeView,
            fixture: fixture
        )
    }

    // MARK: Wave G — Mermaid ↔ D2 (C4)

    @Test(
        "Mermaid → D2 → Mermaid (C4)",
        arguments: try fixtures(for: "cross-mermaid-d2-c4", fromRoot: roundTripResourcesRoot())
    )
    func mermaidD2C4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidC4,
            legB: RoundTripCellRegistry.d2C4,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2C4,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Mermaid → D2 (C4)",
        arguments: try fixtures(for: "cross-d2-mermaid-c4", fromRoot: roundTripResourcesRoot())
    )
    func d2MermaidC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2C4,
            legB: RoundTripCellRegistry.mermaidC4,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidC4,
            fixture: fixture
        )
    }

    // MARK: Wave G — Mermaid ↔ DOT (C4)

    @Test(
        "Mermaid → DOT → Mermaid (C4)",
        arguments: try fixtures(for: "cross-mermaid-dot-c4", fromRoot: roundTripResourcesRoot())
    )
    func mermaidDotC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidC4,
            legB: RoundTripCellRegistry.dotC4,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidDotC4,
            fixture: fixture
        )
    }

    @Test(
        "DOT → Mermaid → DOT (C4)",
        arguments: try fixtures(for: "cross-dot-mermaid-c4", fromRoot: roundTripResourcesRoot())
    )
    func dotMermaidC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotC4,
            legB: RoundTripCellRegistry.mermaidC4,
            additionalAllowedLosses: RoundTripCrossRegistry.dotMermaidC4,
            fixture: fixture
        )
    }

    // MARK: Wave G — PlantUML ↔ D2 (C4)

    @Test(
        "PlantUML → D2 → PlantUML (C4)",
        arguments: try fixtures(for: "cross-plantuml-d2-c4", fromRoot: roundTripResourcesRoot())
    )
    func plantumlD2C4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlC4,
            legB: RoundTripCellRegistry.d2C4,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlD2C4,
            fixture: fixture
        )
    }

    @Test(
        "D2 → PlantUML → D2 (C4)",
        arguments: try fixtures(for: "cross-d2-plantuml-c4", fromRoot: roundTripResourcesRoot())
    )
    func d2PlantumlC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2C4,
            legB: RoundTripCellRegistry.plantumlC4,
            additionalAllowedLosses: RoundTripCrossRegistry.d2PlantumlC4,
            fixture: fixture
        )
    }

    // MARK: Wave G — PlantUML ↔ DOT (C4)

    @Test(
        "PlantUML → DOT → PlantUML (C4)",
        arguments: try fixtures(for: "cross-plantuml-dot-c4", fromRoot: roundTripResourcesRoot())
    )
    func plantumlDotC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlC4,
            legB: RoundTripCellRegistry.dotC4,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlDotC4,
            fixture: fixture
        )
    }

    @Test(
        "DOT → PlantUML → DOT (C4)",
        arguments: try fixtures(for: "cross-dot-plantuml-c4", fromRoot: roundTripResourcesRoot())
    )
    func dotPlantumlC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotC4,
            legB: RoundTripCellRegistry.plantumlC4,
            additionalAllowedLosses: RoundTripCrossRegistry.dotPlantumlC4,
            fixture: fixture
        )
    }

    // MARK: Wave G — Structurizr ↔ D2 (C4)

    @Test(
        "Structurizr → D2 → Structurizr (C4)",
        arguments: try fixtures(for: "cross-structurizr-d2-c4", fromRoot: roundTripResourcesRoot())
    )
    func structurizrD2C4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.structurizrC4,
            legB: RoundTripCellRegistry.d2C4,
            additionalAllowedLosses: RoundTripCrossRegistry.structurizrD2C4,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Structurizr → D2 (C4)",
        arguments: try fixtures(for: "cross-d2-structurizr-c4", fromRoot: roundTripResourcesRoot())
    )
    func d2StructurizrC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2C4,
            legB: RoundTripCellRegistry.structurizrC4,
            additionalAllowedLosses: RoundTripCrossRegistry.d2StructurizrC4,
            fixture: fixture
        )
    }

    // MARK: Wave G — Structurizr ↔ DOT (C4)

    @Test(
        "Structurizr → DOT → Structurizr (C4)",
        arguments: try fixtures(for: "cross-structurizr-dot-c4", fromRoot: roundTripResourcesRoot())
    )
    func structurizrDotC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.structurizrC4,
            legB: RoundTripCellRegistry.dotC4,
            additionalAllowedLosses: RoundTripCrossRegistry.structurizrDotC4,
            fixture: fixture
        )
    }

    @Test(
        "DOT → Structurizr → DOT (C4)",
        arguments: try fixtures(for: "cross-dot-structurizr-c4", fromRoot: roundTripResourcesRoot())
    )
    func dotStructurizrC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotC4,
            legB: RoundTripCellRegistry.structurizrC4,
            additionalAllowedLosses: RoundTripCrossRegistry.dotStructurizrC4,
            fixture: fixture
        )
    }

    // MARK: Wave G — D2 ↔ DOT (C4)

    @Test(
        "D2 → DOT → D2 (C4)",
        arguments: try fixtures(for: "cross-d2-dot-c4", fromRoot: roundTripResourcesRoot())
    )
    func d2DotC4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2C4,
            legB: RoundTripCellRegistry.dotC4,
            additionalAllowedLosses: RoundTripCrossRegistry.d2DotC4,
            fixture: fixture
        )
    }

    @Test(
        "DOT → D2 → DOT (C4)",
        arguments: try fixtures(for: "cross-dot-d2-c4", fromRoot: roundTripResourcesRoot())
    )
    func dotD2C4(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotC4,
            legB: RoundTripCellRegistry.d2C4,
            additionalAllowedLosses: RoundTripCrossRegistry.dotD2C4,
            fixture: fixture
        )
    }
}


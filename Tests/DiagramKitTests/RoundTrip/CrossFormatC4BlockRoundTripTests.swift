// Split from CrossFormatRoundTripTests.swift (file-size gate: the
// original crossed the 1000-line hard limit in Wave J). Carries the
// Wave G C4 cross-format cells and the Wave J block cells; the
// fixture layout and harness usage are identical to the parent file.

import Testing
import DiagramKitTestSupport
import Foundation

@Suite("Cross-format round-trip (C4 + block)")
struct CrossFormatC4BlockRoundTripTests {

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

    // MARK: Wave J — Mermaid ↔ D2 (block)

    @Test(
        "Mermaid → D2 → Mermaid (block)",
        arguments: try fixtures(for: "cross-mermaid-d2-block", fromRoot: roundTripResourcesRoot())
    )
    func mermaidD2Block(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidBlock,
            legB: RoundTripCellRegistry.d2Block,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2Block,
            fixture: fixture
        )
    }

    @Test(
        "D2 → Mermaid → D2 (block)",
        arguments: try fixtures(for: "cross-d2-mermaid-block", fromRoot: roundTripResourcesRoot())
    )
    func d2MermaidBlock(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2Block,
            legB: RoundTripCellRegistry.mermaidBlock,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidBlock,
            fixture: fixture
        )
    }

    // MARK: Wave J — Mermaid ↔ DOT (block)

    @Test(
        "Mermaid → DOT → Mermaid (block)",
        arguments: try fixtures(for: "cross-mermaid-dot-block", fromRoot: roundTripResourcesRoot())
    )
    func mermaidDotBlock(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidBlock,
            legB: RoundTripCellRegistry.dotBlock,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidDotBlock,
            fixture: fixture
        )
    }

    @Test(
        "DOT → Mermaid → DOT (block)",
        arguments: try fixtures(for: "cross-dot-mermaid-block", fromRoot: roundTripResourcesRoot())
    )
    func dotMermaidBlock(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotBlock,
            legB: RoundTripCellRegistry.mermaidBlock,
            additionalAllowedLosses: RoundTripCrossRegistry.dotMermaidBlock,
            fixture: fixture
        )
    }
}

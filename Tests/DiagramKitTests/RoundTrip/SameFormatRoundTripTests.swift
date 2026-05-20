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
        "Mermaid gantt round-trip",
        arguments: try fixtures(for: "mermaid-gantt", fromRoot: roundTripResourcesRoot())
    )
    func mermaidGantt(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidGantt,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid state round-trip",
        arguments: try fixtures(for: "mermaid-state", fromRoot: roundTripResourcesRoot())
    )
    func mermaidState(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidState,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid pie round-trip",
        arguments: try fixtures(for: "mermaid-pie", fromRoot: roundTripResourcesRoot())
    )
    func mermaidPie(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidPie,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid sankey round-trip",
        arguments: try fixtures(for: "mermaid-sankey", fromRoot: roundTripResourcesRoot())
    )
    func mermaidSankey(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidSankey,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid packet round-trip",
        arguments: try fixtures(for: "mermaid-packet", fromRoot: roundTripResourcesRoot())
    )
    func mermaidPacket(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidPacket,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid journey round-trip",
        arguments: try fixtures(for: "mermaid-journey", fromRoot: roundTripResourcesRoot())
    )
    func mermaidJourney(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidJourney,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid timeline round-trip",
        arguments: try fixtures(for: "mermaid-timeline", fromRoot: roundTripResourcesRoot())
    )
    func mermaidTimeline(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidTimeline,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid kanban round-trip",
        arguments: try fixtures(for: "mermaid-kanban", fromRoot: roundTripResourcesRoot())
    )
    func mermaidKanban(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidKanban,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid mindmap round-trip",
        arguments: try fixtures(for: "mermaid-mindmap", fromRoot: roundTripResourcesRoot())
    )
    func mermaidMindmap(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidMindmap,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid treemap round-trip",
        arguments: try fixtures(for: "mermaid-treemap", fromRoot: roundTripResourcesRoot())
    )
    func mermaidTreemap(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidTreemap,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid gitGraph round-trip",
        arguments: try fixtures(for: "mermaid-gitgraph", fromRoot: roundTripResourcesRoot())
    )
    func mermaidGitGraph(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidGitGraph,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid xychart round-trip",
        arguments: try fixtures(for: "mermaid-xychart", fromRoot: roundTripResourcesRoot())
    )
    func mermaidXYChart(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidXYChart,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid quadrant round-trip",
        arguments: try fixtures(for: "mermaid-quadrant", fromRoot: roundTripResourcesRoot())
    )
    func mermaidQuadrant(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidQuadrant,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid requirement round-trip",
        arguments: try fixtures(for: "mermaid-requirement", fromRoot: roundTripResourcesRoot())
    )
    func mermaidRequirement(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidRequirement,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid radar round-trip",
        arguments: try fixtures(for: "mermaid-radar", fromRoot: roundTripResourcesRoot())
    )
    func mermaidRadar(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidRadar,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid venn round-trip",
        arguments: try fixtures(for: "mermaid-venn", fromRoot: roundTripResourcesRoot())
    )
    func mermaidVenn(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidVenn,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid ishikawa round-trip",
        arguments: try fixtures(for: "mermaid-ishikawa", fromRoot: roundTripResourcesRoot())
    )
    func mermaidIshikawa(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidIshikawa,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid treeView round-trip",
        arguments: try fixtures(for: "mermaid-treeview", fromRoot: roundTripResourcesRoot())
    )
    func mermaidTreeView(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidTreeView,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid zenuml round-trip",
        arguments: try fixtures(for: "mermaid-zenuml", fromRoot: roundTripResourcesRoot())
    )
    func mermaidZenUML(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidZenUML,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid eventmodeling round-trip",
        arguments: try fixtures(for: "mermaid-eventmodeling", fromRoot: roundTripResourcesRoot())
    )
    func mermaidEventModeling(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidEventModeling,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid block round-trip",
        arguments: try fixtures(for: "mermaid-block", fromRoot: roundTripResourcesRoot())
    )
    func mermaidBlock(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidBlock,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid architecture round-trip",
        arguments: try fixtures(for: "mermaid-architecture", fromRoot: roundTripResourcesRoot())
    )
    func mermaidArchitecture(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidArchitecture,
            fixture: fixture
        )
    }

    @Test(
        "Mermaid wardleyBeta round-trip",
        arguments: try fixtures(for: "mermaid-wardleybeta", fromRoot: roundTripResourcesRoot())
    )
    func mermaidWardleyBeta(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidWardley,
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
        "D2 class round-trip",
        arguments: try fixtures(for: "d2-class", fromRoot: roundTripResourcesRoot())
    )
    func d2Class(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.d2Class,
            fixture: fixture
        )
    }

    @Test(
        "D2 state round-trip",
        arguments: try fixtures(for: "d2-state", fromRoot: roundTripResourcesRoot())
    )
    func d2State(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.d2State,
            fixture: fixture
        )
    }

    @Test(
        "D2 ER round-trip",
        arguments: try fixtures(for: "d2-er", fromRoot: roundTripResourcesRoot())
    )
    func d2Er(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.d2Er,
            fixture: fixture
        )
    }

    @Test(
        "DOT class round-trip",
        arguments: try fixtures(for: "dot-class", fromRoot: roundTripResourcesRoot())
    )
    func dotClass(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.dotClass,
            fixture: fixture
        )
    }

    @Test(
        "DOT state round-trip",
        arguments: try fixtures(for: "dot-state", fromRoot: roundTripResourcesRoot())
    )
    func dotState(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.dotState,
            fixture: fixture
        )
    }

    @Test(
        "DOT ER round-trip",
        arguments: try fixtures(for: "dot-er", fromRoot: roundTripResourcesRoot())
    )
    func dotEr(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.dotEr,
            fixture: fixture
        )
    }

    @Test(
        "D2 architecture round-trip",
        arguments: try fixtures(for: "d2-architecture", fromRoot: roundTripResourcesRoot())
    )
    func d2Architecture(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.d2Architecture,
            fixture: fixture
        )
    }

    @Test(
        "DOT architecture round-trip",
        arguments: try fixtures(for: "dot-architecture", fromRoot: roundTripResourcesRoot())
    )
    func dotArchitecture(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.dotArchitecture,
            fixture: fixture
        )
    }

    @Test(
        "D2 mindmap round-trip",
        arguments: try fixtures(for: "d2-mindmap", fromRoot: roundTripResourcesRoot())
    )
    func d2Mindmap(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.d2Mindmap,
            fixture: fixture
        )
    }

    @Test(
        "DOT mindmap round-trip",
        arguments: try fixtures(for: "dot-mindmap", fromRoot: roundTripResourcesRoot())
    )
    func dotMindmap(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.dotMindmap,
            fixture: fixture
        )
    }

    @Test(
        "D2 treeView round-trip",
        arguments: try fixtures(for: "d2-treeView", fromRoot: roundTripResourcesRoot())
    )
    func d2TreeView(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.d2TreeView,
            fixture: fixture
        )
    }

    @Test(
        "DOT treeView round-trip",
        arguments: try fixtures(for: "dot-treeView", fromRoot: roundTripResourcesRoot())
    )
    func dotTreeView(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.dotTreeView,
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

    @Test(
        "PlantUML state round-trip",
        arguments: try fixtures(for: "plantuml-state", fromRoot: roundTripResourcesRoot())
    )
    func plantumlState(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlState,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML mindmap round-trip",
        arguments: try fixtures(for: "plantuml-mindmap", fromRoot: roundTripResourcesRoot())
    )
    func plantumlMindmap(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlMindmap,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML gantt round-trip",
        arguments: try fixtures(for: "plantuml-gantt", fromRoot: roundTripResourcesRoot())
    )
    func plantumlGantt(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlGantt,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML C4 round-trip",
        arguments: try fixtures(for: "plantuml-c4", fromRoot: roundTripResourcesRoot())
    )
    func plantumlC4(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlC4,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML activity round-trip",
        arguments: try fixtures(for: "plantuml-activity", fromRoot: roundTripResourcesRoot())
    )
    func plantumlActivity(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlActivity,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML ER round-trip",
        arguments: try fixtures(for: "plantuml-er", fromRoot: roundTripResourcesRoot())
    )
    func plantumlEr(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlEr,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML useCase round-trip",
        arguments: try fixtures(for: "plantuml-usecase", fromRoot: roundTripResourcesRoot())
    )
    func plantumlUseCase(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlUseCase,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML object round-trip",
        arguments: try fixtures(for: "plantuml-object", fromRoot: roundTripResourcesRoot())
    )
    func plantumlObject(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlObject,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML component round-trip",
        arguments: try fixtures(for: "plantuml-component", fromRoot: roundTripResourcesRoot())
    )
    func plantumlComponent(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlComponent,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML deployment round-trip",
        arguments: try fixtures(for: "plantuml-deployment", fromRoot: roundTripResourcesRoot())
    )
    func plantumlDeployment(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlDeployment,
            fixture: fixture
        )
    }
}

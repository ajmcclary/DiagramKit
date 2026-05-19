import DiagramKitTestSupport
import DiagramKitImport
import DiagramKitExport
import DiagramKit
import DiagramKitMermaid
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML
import DiagramKitModel

/// Static declarations for every same-format round-trip cell in the matrix.
/// Cells are added incrementally as the per-family comparator arms land.
///
/// Lives in the test target rather than DiagramKitTestSupport so the
/// test-support library does not accumulate transitive dependencies on every
/// format slice (DiagramKitMermaid / D2 / Graphviz / Structurizr / PlantUML).
enum RoundTripCellRegistry {
    static let mermaidFlowchart = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.flowchart,
        allowedLosses: [.idSanitization, .anonymousSubgraphRename]
    )

    static let mermaidSequence = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.sequenceDiagram,
        allowedLosses: [.idSanitization]
    )

    static let mermaidClass = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.classDiagram,
        allowedLosses: [.idSanitization]
    )

    static let mermaidEr = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.erDiagram,
        allowedLosses: [.idSanitization, .accessibilityDrop]
    )

    static let mermaidC4 = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.c4,
        allowedLosses: [.idSanitization, .boundaryFlatten, .c4SlotDrop]
    )

    static let mermaidGantt = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.gantt,
        allowedLosses: [.idSanitization, .configDrop]
    )

    static let mermaidState = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.stateDiagram,
        allowedLosses: [.idSanitization]
    )

    static let mermaidPie = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.pie,
        allowedLosses: []
    )

    static let mermaidSankey = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.sankey,
        allowedLosses: []
    )

    static let mermaidPacket = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.packet,
        allowedLosses: []
    )

    static let mermaidJourney = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.journey,
        allowedLosses: []
    )

    static let mermaidTimeline = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.timeline,
        allowedLosses: []
    )

    static let mermaidKanban = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.kanban,
        allowedLosses: []
    )

    static let mermaidMindmap = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.mindmap,
        allowedLosses: []
    )

    static let mermaidTreemap = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.treemap,
        allowedLosses: []
    )

    static let mermaidGitGraph = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.gitGraph,
        allowedLosses: []
    )

    static let mermaidXYChart = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.xyChart,
        allowedLosses: []
    )

    static let mermaidQuadrant = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.quadrantChart,
        allowedLosses: []
    )

    static let mermaidRequirement = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.requirement,
        allowedLosses: []
    )

    static let mermaidRadar = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.radar,
        allowedLosses: []
    )

    static let mermaidVenn = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.venn,
        allowedLosses: []
    )

    static let mermaidIshikawa = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.ishikawa,
        allowedLosses: []
    )

    static let mermaidTreeView = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.treeView,
        allowedLosses: []
    )

    static let mermaidZenUML = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.zenuml,
        allowedLosses: []
    )

    static let mermaidEventModeling = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.eventModeling,
        allowedLosses: []
    )

    static let mermaidBlock = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.block,
        allowedLosses: []
    )

    static let mermaidArchitecture = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.architecture,
        allowedLosses: []
    )

    static let mermaidWardley = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.wardleyBeta,
        allowedLosses: []
    )

    static let d2Flowchart = RoundTripCell(
        importer: D2Importer(),
        exporter: D2Exporter(),
        family: DiagramType.flowchart,
        allowedLosses: [.subgraphFlatten, .styleDrop, .shapeDowngrade, .d2DuplicateOverride, .idSanitization]
    )

    static let dotFlowchart = RoundTripCell(
        importer: GraphvizImporter(),
        exporter: DOTExporter(),
        family: DiagramType.flowchart,
        allowedLosses: [.subgraphFlatten, .styleDrop, .shapeDowngrade, .idSanitization]
    )

    static let d2Class = RoundTripCell(
        importer: D2Importer(),
        exporter: D2Exporter(),
        family: DiagramType.classDiagram,
        allowedLosses: [.classStereotypeDrop, .styleDrop]
    )

    static let d2State = RoundTripCell(
        importer: D2Importer(),
        exporter: D2Exporter(),
        family: DiagramType.stateDiagram,
        allowedLosses: [.stateActionDrop]
    )

    static let d2Er = RoundTripCell(
        importer: D2Importer(),
        exporter: D2Exporter(),
        family: DiagramType.erDiagram,
        allowedLosses: [.cardinalityDrop]
    )

    static let dotClass = RoundTripCell(
        importer: GraphvizImporter(),
        exporter: DOTExporter(),
        family: DiagramType.classDiagram,
        allowedLosses: [.classStereotypeDrop, .styleDrop]
    )

    static let dotState = RoundTripCell(
        importer: GraphvizImporter(),
        exporter: DOTExporter(),
        family: DiagramType.stateDiagram,
        allowedLosses: [.stateActionDrop]
    )

    static let dotEr = RoundTripCell(
        importer: GraphvizImporter(),
        exporter: DOTExporter(),
        family: DiagramType.erDiagram,
        allowedLosses: [.cardinalityDrop]
    )

    static let structurizrC4 = RoundTripCell(
        importer: StructurizrImporter(),
        exporter: StructurizrExporter(),
        family: DiagramType.c4,
        allowedLosses: [.idSanitization, .c4SlotDrop]
    )

    static let plantumlSequence = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLExporter(),
        family: DiagramType.sequenceDiagram,
        allowedLosses: [.idSanitization]
    )

    static let plantumlClass = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLExporter(),
        family: DiagramType.classDiagram,
        allowedLosses: [.idSanitization]
    )

    static let plantumlState = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLExporter(),
        family: DiagramType.stateDiagram,
        allowedLosses: [.idSanitization]
    )

    static let plantumlMindmap = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLExporter(),
        family: DiagramType.mindmap,
        allowedLosses: [.idSanitization]
    )

    static let plantumlGantt = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLExporter(),
        family: DiagramType.gantt,
        allowedLosses: [.idSanitization, .configDrop]
    )

    static let plantumlC4 = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLExporter(),
        family: DiagramType.c4,
        allowedLosses: [.idSanitization, .boundaryFlatten, .c4SlotDrop]
    )

    static let plantumlActivity = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLExporter(),
        family: DiagramType.flowchart,
        allowedLosses: [.idSanitization, .subgraphFlatten]
    )

    static let plantumlEr = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLExporter(),
        family: DiagramType.erDiagram,
        allowedLosses: [.idSanitization]
    )

    static let plantumlUseCase = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLUseCaseExporter(),
        family: DiagramType.flowchart,
        allowedLosses: [.idSanitization]
    )

    static let plantumlObject = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLObjectExporter(),
        family: DiagramType.classDiagram,
        allowedLosses: [.idSanitization]
    )

    static let plantumlComponent = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLExporter(),
        family: DiagramType.architecture,
        allowedLosses: [.idSanitization]
    )
}

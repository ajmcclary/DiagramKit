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

    static let structurizrC4 = RoundTripCell(
        importer: StructurizrImporter(),
        exporter: StructurizrExporter(),
        family: DiagramType.c4,
        allowedLosses: [.idSanitization, .boundaryFlatten, .c4SlotDrop]
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
}

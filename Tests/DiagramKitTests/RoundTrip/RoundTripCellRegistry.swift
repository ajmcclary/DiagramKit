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

    // Subsequent cells declared by later tasks:
    //   plantumlSequence, plantumlClass, plantumlState,
    //   plantumlMindmap, plantumlGantt, plantumlC4
}

import DiagramKitTestSupport
import DiagramKitImport
import DiagramKitExport
import DiagramKit
import DiagramKitMermaid
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

    // Subsequent cells declared by later tasks:
    //   mermaidC4,
    //   d2Flowchart, dotFlowchart, structurizrC4,
    //   plantumlSequence, plantumlClass, plantumlState,
    //   plantumlMindmap, plantumlGantt, plantumlC4
}

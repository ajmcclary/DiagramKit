import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

/// PlantUML source-format importer.
///
/// Detects `@startuml`/`@enduml` blocks, probes family-specific syntax
/// inside the body, and dispatches to the matching family parser.
///
/// Implements the two-level dispatch described in PHASE-6.md.
public struct PlantUMLImporter: DiagramSourceImporter {

    public let name = "PlantUML"
    public let formatID = DiagramFormatID.plantuml
    public let supportedDiagramTypes: Set<DiagramType> = [
        .sequenceDiagram,
        .classDiagram,
        .stateDiagram,
        .mindmap,
        .gantt,
        .c4,
    ]

    public init() {}

    public func supports(source: String) -> Bool {
        isPlantUMLSource(source)
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        guard let (body, startKind) = extractPlantUMLBody(source) else {
            // Source claimed to be PlantUML (probe accepted) but the
            // body could not be extracted from `@start…`/`@end…`.
            // That's a structural source failure, not an implementation
            // gap, so we throw `.malformedSource` rather than
            // `.notYetImplemented`.
            throw DiagramError.malformedSource(
                message: "PlantUML: could not extract body from @startuml/@enduml block"
            )
        }

        // Family routing probes (in PHASE-6.md order):
        // 1. C4    — deferred to 6E
        // 2. Gantt — deferred to 6D
        // 3. Mindmap — deferred to 6D
        // 4. State/Activity — deferred to 6C
        // 5. Class — deferred to 6B
        // 6. Sequence (fallback)

        // Slice 6A: only Sequence is implemented.
        // Explicit header families that aren't sequence are rejected early.
        if startKind == "gantt" {
            let ast = PlantUMLGanttParser().parse(body)
            let (model, diagnostics) = PlantUMLGanttMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .gantt(model)),
                diagnostics: diagnostics
            )
        }
        if startKind == "mindmap" || startKind == "wbs" {
            let tree = PlantUMLMindmapParser().parse(body)
            let (model, diagnostics) = PlantUMLMindmapMapper().map(tree)
            return DiagramImportResult(
                document: DiagramDocument(payload: .mindmap(model)),
                diagnostics: diagnostics
            )
        }

        // For @startuml bodies, probe family-specific content.
        // Slice 6A: all @startuml bodies with sequence content route to sequence.
        // Non-sequence bodies in @startuml throw notYetImplemented for now.

        // Check C4 first (narrowest)
        if isPlantUMLC4Body(body) {
            let ast = PlantUMLC4Parser().parse(body)
            let (model, diagnostics) = PlantUMLC4Mapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .c4(model)),
                diagnostics: diagnostics
            )
        }

        // Check State/Activity
        if isPlantUMLStateBody(body) {
            let ast = PlantUMLStateParser().parse(body)
            let (graph, diagnostics) = PlantUMLStateMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .stateDiagram(graph)),
                diagnostics: diagnostics
            )
        }

        // Check Class
        if isPlantUMLClassBody(body) {
            let ast = PlantUMLClassParser().parse(body)
            let (model, diagnostics) = PlantUMLClassMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .classDiagram(model)),
                diagnostics: diagnostics
            )
        }

        // Sequence: broadest fallback within PlantUML
        if isPlantUMLSequenceBody(body) {
            let parser = PlantUMLSequenceParser()
            let ast = parser.parse(body)

            let mapper = PlantUMLSequenceMapper()
            let (diagram, mapDiagnostics) = mapper.map(ast)

            let payload = DiagramPayload.sequenceDiagram(diagram)
            let document = DiagramDocument(payload: payload)

            return DiagramImportResult(document: document, diagnostics: mapDiagnostics)
        }

        // No family matched. All major PlantUML families are implemented
        // (sequence/class/state/mindmap/gantt/C4); a body that matches
        // none of them is malformed for our purposes — we cannot parse
        // it. (`.notYetImplemented` would be misleading here.)
        throw DiagramError.malformedSource(
            message: "PlantUML body did not match any supported family probe"
        )
    }
}

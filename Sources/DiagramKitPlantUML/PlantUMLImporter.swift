import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

/// PlantUML source-format importer.
///
/// Detects `@startuml` / `@startgantt` / `@startmindmap` blocks, probes
/// family-specific syntax inside the body, and dispatches to the matching
/// family parser. Covers Sequence, Class, State/Activity, Mindmap, Gantt,
/// and C4.
///
/// Family routing intentionally probes from narrow markers (`@startgantt`,
/// `@startmindmap`, C4 keywords, `state`/`activity` headers, class shapes)
/// to broad sequence syntax so families that share the generic `@startuml`
/// header resolve to the right parser.
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

        // Family routing order — narrow markers first so generic `@startuml`
        // sources only fall through to Sequence after explicit families have
        // had a chance to claim them:
        //   1. Gantt   (`@startgantt`)
        //   2. Mindmap (`@startmindmap`)
        //   3. C4      (C4-specific keywords inside `@startuml`)
        //   4. State / Activity (`state`/`activity` headers)
        //   5. Class   (class shape syntax)
        //   6. Sequence (fallback)
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

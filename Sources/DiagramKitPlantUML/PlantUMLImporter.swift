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
        .flowchart,
        .erDiagram,
        .architecture,
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
        //   1. Gantt    (`@startgantt`)
        //   2. Mindmap  (`@startmindmap` / `@startwbs`)
        //   3. C4       (C4-specific keywords inside `@startuml`)
        //   4. Activity (`start`/`stop`/`:text;`/`partition`)
        //   5. State    (`state` keyword / `[*]` pseudostate)
        //   6. ER       (`entity` keyword / IE arrows `||--o{`)
        //   7. UseCase  (`(usecase)` / `:actor:` / `usecase` / `actor` keywords)
        //   8. Object   (`object X` declaration)
        //   9. Component (`[component]` token / `interface` keyword)
        //  10. Class    (class shape syntax)
        //  11. Sequence (fallback)
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
        if isPlantUMLC4Body(body) {
            let ast = PlantUMLC4Parser().parse(body)
            let (model, diagnostics) = PlantUMLC4Mapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .c4(model)),
                diagnostics: diagnostics
            )
        }
        if isPlantUMLActivityBody(body) {
            fatalError("Wave 1 Task 2 implements PlantUMLActivityParser")
        }
        if isPlantUMLStateBody(body) {
            let ast = PlantUMLStateParser().parse(body)
            let (graph, diagnostics) = PlantUMLStateMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .stateDiagram(graph)),
                diagnostics: diagnostics
            )
        }
        if isPlantUMLERBody(body) {
            fatalError("Wave 1 Task 3 implements PlantUMLERParser")
        }
        if isPlantUMLUseCaseBody(body) {
            fatalError("Wave 1 Task 4 implements PlantUMLUseCaseParser")
        }
        if isPlantUMLObjectBody(body) {
            fatalError("Wave 1 Task 5 implements PlantUMLObjectParser")
        }
        if isPlantUMLComponentBody(body) {
            fatalError("Wave 1 Task 6 implements PlantUMLComponentParser")
        }
        if isPlantUMLClassBody(body) {
            let ast = PlantUMLClassParser().parse(body)
            let (model, diagnostics) = PlantUMLClassMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .classDiagram(model)),
                diagnostics: diagnostics
            )
        }
        if isPlantUMLSequenceBody(body) {
            let parser = PlantUMLSequenceParser()
            let ast = parser.parse(body)
            let mapper = PlantUMLSequenceMapper()
            let (diagram, mapDiagnostics) = mapper.map(ast)
            let payload = DiagramPayload.sequenceDiagram(diagram)
            let document = DiagramDocument(payload: payload)
            return DiagramImportResult(document: document, diagnostics: mapDiagnostics)
        }
        throw DiagramError.malformedSource(
            message: "PlantUML body did not match any supported family probe"
        )
    }
}

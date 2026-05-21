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
        .treeView,
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

        // Family routing order — narrow start-kind matches first so
        // generic `@startuml` sources only fall through to Sequence after
        // explicit families have had a chance to claim them:
        //   1. JSON     (`@startjson`)         — Wave H
        //   2. YAML     (`@startyaml`)         — Wave H
        //   3. WBS      (`@startwbs`)          — Wave H (split from Mindmap)
        //   4. Gantt    (`@startgantt`)
        //   5. Mindmap  (`@startmindmap`)
        //   6. C4       (C4-specific keywords)
        //   7. Activity (`start`/`stop`/`:text;`/`partition`)
        //   8. State    (`state` keyword / `[*]` pseudostate)
        //   9. ER       (`entity` keyword / IE arrows `||--o{`)
        //  10. UseCase  (`(usecase)` / `:actor:`)
        //  11. Object   (`object X` declaration)
        //  12. Component (`[component]` / `interface` keyword)
        //  13. Class    (class shape syntax)
        //  14. Deployment (`node`, `artifact`, ... declarations)
        //  15. Sequence (fallback)
        if startKind == "json" {
            let value = try PlantUMLJSONParser().parse(body)
            var (diagram, diagnostics) = PlantUMLJSONMapper().map(value)
            Self.applyTreeViewMarkers(&diagram, source: source)
            return DiagramImportResult(
                document: DiagramDocument(payload: .treeView(diagram)),
                diagnostics: diagnostics
            )
        }
        if startKind == "yaml" {
            let parsed = try PlantUMLYAMLParser().parse(body)
            var (diagram, diagnostics) = PlantUMLYAMLMapper().map(parsed)
            Self.applyTreeViewMarkers(&diagram, source: source)
            return DiagramImportResult(
                document: DiagramDocument(payload: .treeView(diagram)),
                diagnostics: diagnostics
            )
        }
        if startKind == "wbs" {
            let tree = PlantUMLWBSParser().parse(body)
            var (diagram, diagnostics) = PlantUMLWBSMapper().map(tree)
            Self.applyTreeViewMarkers(&diagram, source: source)
            return DiagramImportResult(
                document: DiagramDocument(payload: .treeView(diagram)),
                diagnostics: diagnostics
            )
        }
        if startKind == "gantt" {
            let ast = PlantUMLGanttParser().parse(body)
            let (model, diagnostics) = PlantUMLGanttMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .gantt(model)),
                diagnostics: diagnostics
            )
        }
        if startKind == "mindmap" {
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
            let ast = PlantUMLActivityParser().parse(body)
            var (model, diagnostics) = PlantUMLActivityMapper().map(ast)
            // Apply activity-original-id recovery markers from the source.
            let markerScan = PlantUMLRecoveryMarker.scanner.scan(source: source)
            Self.applyActivityOriginalIdMarkers(&model, markers: markerScan.markers)
            return DiagramImportResult(
                document: DiagramDocument(payload: .flowchart(model)),
                diagnostics: diagnostics
            )
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
            let ast = PlantUMLERParser().parse(body)
            let (model, diagnostics) = PlantUMLERMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .erDiagram(model)),
                diagnostics: diagnostics
            )
        }
        if isPlantUMLUseCaseBody(body) {
            let ast = PlantUMLUseCaseParser().parse(body)
            let (model, diagnostics) = PlantUMLUseCaseMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .flowchart(model)),
                diagnostics: diagnostics
            )
        }
        if isPlantUMLObjectBody(body) {
            let ast = PlantUMLObjectParser().parse(body)
            let (model, diagnostics) = PlantUMLObjectMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .classDiagram(model)),
                diagnostics: diagnostics
            )
        }
        if isPlantUMLComponentBody(body) {
            let ast = PlantUMLComponentParser().parse(body)
            let (model, diagnostics) = PlantUMLComponentMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .architecture(model)),
                diagnostics: diagnostics
            )
        }
        if isPlantUMLClassBody(body) {
            let ast = PlantUMLClassParser().parse(body)
            let (model, diagnostics) = PlantUMLClassMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .classDiagram(model)),
                diagnostics: diagnostics
            )
        }
        if isPlantUMLDeploymentBody(body) {
            let (ast, parseDiagnostics) = try PlantUMLDeploymentParser().parse(body)
            let (model, mapDiagnostics) = PlantUMLDeploymentMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .architecture(model)),
                diagnostics: parseDiagnostics + mapDiagnostics
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

    /// Apply treeView recovery markers to nodes by DFS-pre-order id.
    /// Markers referencing unknown ids are silently dropped (matches
    /// existing activity-marker behavior).
    private static func applyTreeViewMarkers(
        _ diagram: inout TreeViewDiagram,
        source: String
    ) {
        let markers = PlantUMLRecoveryMarker.scanner.scan(source: source).markers
        guard !markers.isEmpty else { return }

        var descriptions: [Int: String] = [:]
        var icons: [Int: String] = [:]
        var cssClasses: [Int: String] = [:]
        for marker in markers {
            switch marker.kind {
            case .treeViewNodeDescription(let nodeId, let base64):
                if let data = Data(base64Encoded: base64),
                   let text = String(data: data, encoding: .utf8) {
                    descriptions[nodeId] = text
                }
            case .treeViewNodeIcon(let nodeId, let iconId):
                icons[nodeId] = iconId
            case .treeViewNodeCssClass(let nodeId, let cssClass):
                cssClasses[nodeId] = cssClass
            default:
                continue
            }
        }
        guard !descriptions.isEmpty || !icons.isEmpty || !cssClasses.isEmpty else { return }

        diagram.root = applyMarkersTo(diagram.root,
                                      descriptions: descriptions,
                                      icons: icons,
                                      cssClasses: cssClasses)
        for i in diagram.nodes.indices {
            let id = diagram.nodes[i].id
            if let d = descriptions[id] { diagram.nodes[i].description = d }
            if let icon = icons[id]      { diagram.nodes[i].iconId = icon }
            if let css = cssClasses[id]  { diagram.nodes[i].cssClass = css }
        }
    }

    private static func applyMarkersTo(
        _ node: TreeViewNode,
        descriptions: [Int: String],
        icons: [Int: String],
        cssClasses: [Int: String]
    ) -> TreeViewNode {
        var copy = node
        if let d = descriptions[copy.id] { copy.description = d }
        if let icon = icons[copy.id]      { copy.iconId = icon }
        if let css = cssClasses[copy.id]  { copy.cssClass = css }
        copy.children = copy.children.map {
            applyMarkersTo($0, descriptions: descriptions, icons: icons, cssClasses: cssClasses)
        }
        return copy
    }

    /// Apply activity-original-id markers to recover non-synthetic node ids
    /// that were sanitized through the activity export. Rewrites
    /// `nodesInOrder[i].id` and any edge endpoints referencing the synthetic
    /// id. Silent drop when no node matches the marker's syntheticId.
    private static func applyActivityOriginalIdMarkers(
        _ model: inout ParsedGraphModel,
        markers: [RecoveryMarker<PlantUMLRecoveryMarker.Kind>]
    ) {
        // Build rename map first so edge endpoints stay consistent.
        var renames: [String: String] = [:]
        for marker in markers {
            guard case .activityOriginalId(let syntheticId, let originalId) = marker.kind else { continue }
            renames[syntheticId] = originalId
        }
        guard !renames.isEmpty else { return }

        for i in model.nodesInOrder.indices {
            if let original = renames[model.nodesInOrder[i].id] {
                model.nodesInOrder[i].id = original
                model.nodesInOrder[i].node.id = original
            }
        }
        for i in model.edges.indices {
            if let original = renames[model.edges[i].source] {
                model.edges[i].source = original
            }
            if let original = renames[model.edges[i].target] {
                model.edges[i].target = original
            }
        }
    }
}

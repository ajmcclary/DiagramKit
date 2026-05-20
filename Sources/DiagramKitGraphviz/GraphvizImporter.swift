import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Graphviz DOT source-format importer.
///
/// Parses DOT source into a `DiagramDocument` with `DiagramPayload.flowchart`
/// by mapping DOT constructs to `ParsedGraphModel`. Unsupported DOT features
/// emit `.unsupported` diagnostics.
public struct GraphvizImporter: DiagramSourceImporter {

    public let name = "Graphviz"
    public let formatID = DiagramFormatID.graphviz
    public let supportedDiagramTypes: Set<DiagramType> = [
        .flowchart,
        .classDiagram,
        .stateDiagram,
        .erDiagram,
        .architecture,
    ]

    public init() {}

    public func supports(source: String) -> Bool {
        isDOTSource(source)
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)

        let parser = DOTParser()
        let (dotDoc, parseDiagnostics) = try parser.parse(tokens)
        let markerScan = DOTRecoveryMarker.scanner.scan(source: source)

        if DOTClassProbe.detectsClassDiagram(dotDoc) {
            var (cd, classDiagnostics) = DOTClassMapper().map(dotDoc)
            Self.applyClassStereotypeMarkers(&cd, markers: markerScan.markers)
            let document = DiagramDocument(payload: .classDiagram(cd))
            return DiagramImportResult(
                document: document,
                diagnostics: parseDiagnostics + classDiagnostics
            )
        }

        if DOTStateProbe.detectsStateDiagram(dotDoc) {
            let (graph, stateDiagnostics) = DOTStateMapper().map(dotDoc)
            let document = DiagramDocument(payload: .stateDiagram(graph))
            return DiagramImportResult(
                document: document,
                diagnostics: parseDiagnostics + stateDiagnostics
            )
        }

        if DOTERProbe.detectsERDiagram(dotDoc) {
            var (er, erDiagnostics) = DOTERMapper().map(dotDoc)
            Self.applyERCardinalityMarkers(&er, markers: markerScan.markers)
            let document = DiagramDocument(payload: .erDiagram(er))
            return DiagramImportResult(
                document: document,
                diagnostics: parseDiagnostics + erDiagnostics
            )
        }

        // Marker-forced family takes precedence over structural probes.
        let markerFamily = markerScan.markers.compactMap { marker -> String? in
            if case .family(let name) = marker.kind { return name } else { return nil }
        }.first

        if markerFamily == "architecture" || DOTArchitectureProbe.detectsArchitecture(dotDoc) {
            let (arch, archDiagnostics) = DOTArchitectureMapper().map(dotDoc, markers: markerScan.markers)
            let document = DiagramDocument(payload: .architecture(arch))
            return DiagramImportResult(
                document: document,
                diagnostics: parseDiagnostics + archDiagnostics
            )
        }

        let mapper = DOTMapper()
        let (graph, mapDiagnostics) = mapper.map(dotDoc)

        let allDiagnostics = parseDiagnostics + mapDiagnostics
        let payload = DiagramPayload.flowchart(graph)
        let document = DiagramDocument(payload: payload)

        return DiagramImportResult(document: document, diagnostics: allDiagnostics)
    }

    /// Apply class-stereotype recovery markers to a built `ClassDiagram`.
    private static func applyClassStereotypeMarkers(
        _ cd: inout ClassDiagram,
        markers: [RecoveryMarker<DOTRecoveryMarker.Kind>]
    ) {
        for marker in markers {
            guard case .classStereotype(let className, let stereotype) = marker.kind else { continue }
            guard let idx = cd.classes.firstIndex(where: { $0.id == className }) else { continue }
            if !cd.classes[idx].annotations.contains(stereotype) {
                cd.classes[idx].annotations.append(stereotype)
            }
        }
        cd.classMap = Dictionary(uniqueKeysWithValues: cd.classes.map { ($0.id, $0) })
    }

    /// Apply er-cardinality recovery markers to a built `ErDiagram`.
    private static func applyERCardinalityMarkers(
        _ ed: inout ErDiagram,
        markers: [RecoveryMarker<DOTRecoveryMarker.Kind>]
    ) {
        for marker in markers {
            guard case .erCardinality(let relationshipId, let sourceCard, let targetCard) = marker.kind else { continue }
            guard let idx = ed.relationships.firstIndex(where: {
                "\($0.entity1)_\($0.entity2)" == relationshipId
            }) else { continue }
            guard let cardA = ErCardinality(rawValue: sourceCard),
                  let cardB = ErCardinality(rawValue: targetCard) else { continue }
            ed.relationships[idx].relSpec = ErRelSpec(
                cardA: cardA,
                cardB: cardB,
                relType: ed.relationships[idx].relSpec.relType
            )
        }
    }
}

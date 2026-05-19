import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

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

        if DOTClassProbe.detectsClassDiagram(dotDoc) {
            let (cd, classDiagnostics) = DOTClassMapper().map(dotDoc)
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

        let mapper = DOTMapper()
        let (graph, mapDiagnostics) = mapper.map(dotDoc)

        let allDiagnostics = parseDiagnostics + mapDiagnostics
        let payload = DiagramPayload.flowchart(graph)
        let document = DiagramDocument(payload: payload)

        return DiagramImportResult(document: document, diagnostics: allDiagnostics)
    }
}

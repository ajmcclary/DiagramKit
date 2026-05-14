import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

/// Structurizr DSL source-format importer.
///
/// Parses Structurizr workspace source into a `DiagramDocument` with
/// `DiagramPayload.c4` by mapping workspace model elements and the first
/// view to `C4Diagram`. Unsupported DSL features emit `.unsupported`
/// diagnostics.
public struct StructurizrImporter: DiagramSourceImporter {

    public let name = "Structurizr"
    public let formatID = DiagramFormatID.structurizr
    public let supportedDiagramTypes: Set<DiagramType> = [.c4]

    public init() {}

    public func supports(source: String) -> Bool {
        isStructurizrSource(source)
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        let lexer = StructurizrLexer()
        let tokens = lexer.tokenize(source)

        let parser = StructurizrParser()
        let (workspace, parseDiagnostics) = try parser.parse(tokens)

        let mapper = StructurizrMapper()
        let (c4Diagram, mapDiagnostics) = mapper.map(workspace)

        let allDiagnostics = parseDiagnostics + mapDiagnostics
        let payload = DiagramPayload.c4(c4Diagram)
        let document = DiagramDocument(payload: payload)

        return DiagramImportResult(document: document, diagnostics: allDiagnostics)
    }
}

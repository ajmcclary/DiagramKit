import Foundation
import DiagramKitModel
import DiagramKitImport

/// d2 source-format importer.
///
/// Parses d2 source into a `DiagramDocument` with `DiagramPayload.flowchart`
/// by mapping d2 constructs to `ParsedGraphModel`. Unsupported d2 features
/// emit `.unsupported` diagnostics.
public struct D2Importer: DiagramSourceImporter {

    public let name = "D2"
    public let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    public init() {}

    public func supports(source: String) -> Bool {
        isD2Source(source)
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        let parser = D2Parser()
        let (d2Doc, parseDiagnostics) = try parser.parse(source)

        let mapper = D2Mapper()
        let (graph, mapDiagnostics) = mapper.map(d2Doc)

        let allDiagnostics = parseDiagnostics + mapDiagnostics
        let payload = DiagramPayload.flowchart(graph)
        var document = DiagramDocument(payload: payload)
        document.title = Self.documentTitleMetadata(in: source)

        return DiagramImportResult(document: document, diagnostics: allDiagnostics)
    }

    private static func documentTitleMetadata(in source: String) -> String? {
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            guard trimmed.hasPrefix("#") || trimmed.hasPrefix("//") else {
                return nil
            }

            let comment: String
            if trimmed.hasPrefix("#") {
                comment = String(trimmed.dropFirst())
            } else {
                comment = String(trimmed.dropFirst(2))
            }

            let body = comment.trimmingCharacters(in: .whitespaces)
            guard body.lowercased().hasPrefix("title:") else { continue }

            let value = String(body.dropFirst("title:".count))
                .trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }
}

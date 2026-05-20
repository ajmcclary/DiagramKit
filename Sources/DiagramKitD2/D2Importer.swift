import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

/// d2 source-format importer.
///
/// Parses d2 source into a `DiagramDocument` with `DiagramPayload.flowchart`
/// by mapping d2 constructs to `ParsedGraphModel`. Unsupported d2 features
/// emit `.unsupported` diagnostics.
public struct D2Importer: DiagramSourceImporter {

    public let name = "D2"
    public let formatID = DiagramFormatID.d2
    public let supportedDiagramTypes: Set<DiagramType> = [
        .flowchart,
        .classDiagram,
        .stateDiagram,
        .erDiagram,
    ]

    public init() {}

    public func supports(source: String) -> Bool {
        isD2Source(source)
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        let parser = D2Parser()
        let (d2Doc, parseDiagnostics) = try parser.parse(source)
        let markerScan = D2RecoveryMarker.scanner.scan(source: source)

        if D2ClassProbe.detectsClassDiagram(d2Doc) {
            var (cd, classDiagnostics) = D2ClassMapper().map(d2Doc)
            applyClassStereotypeMarkers(&cd, markers: markerScan.markers)
            var document = DiagramDocument(payload: .classDiagram(cd))
            document.title = Self.documentTitleMetadata(in: source)
            return DiagramImportResult(
                document: document,
                diagnostics: parseDiagnostics + classDiagnostics
            )
        }

        if D2ERProbe.detectsERDiagram(d2Doc) {
            let (er, erDiagnostics) = D2ERMapper().map(d2Doc)
            var document = DiagramDocument(payload: .erDiagram(er))
            document.title = Self.documentTitleMetadata(in: source)
            return DiagramImportResult(
                document: document,
                diagnostics: parseDiagnostics + erDiagnostics
            )
        }

        if D2StateProbe.detectsStateDiagram(d2Doc) {
            let (graph, stateDiagnostics) = D2StateMapper().map(d2Doc)
            var document = DiagramDocument(payload: .stateDiagram(graph))
            document.title = Self.documentTitleMetadata(in: source)
            return DiagramImportResult(
                document: document,
                diagnostics: parseDiagnostics + stateDiagnostics
            )
        }

        let mapper = D2Mapper()
        let (graph, mapDiagnostics) = mapper.map(d2Doc)

        let allDiagnostics = parseDiagnostics + mapDiagnostics
        let payload = DiagramPayload.flowchart(graph)
        var document = DiagramDocument(payload: payload)
        document.title = Self.documentTitleMetadata(in: source)

        return DiagramImportResult(document: document, diagnostics: allDiagnostics)
    }

    /// Apply class-stereotype recovery markers to the built `ClassDiagram`.
    /// Each marker appends its stereotype to the matching `ClassNode.annotations`.
    /// Mirrors Structurizr Wave 3 semantics: silent drop when the named class
    /// is not present in the document.
    private func applyClassStereotypeMarkers(
        _ cd: inout ClassDiagram,
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
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

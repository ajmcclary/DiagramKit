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
        .sequenceDiagram,
        .architecture,
        .mindmap,
        .treeView,
        .c4,
    ]

    public init() {}

    public func supports(source: String) -> Bool {
        isD2Source(source)
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        // c4 detection runs first because the c4 mapper walks the source
        // text directly and does not need the D2 AST. Putting it before the
        // D2Parser call also avoids structural probes matching on c4-shaped
        // input that happens to satisfy other family heuristics.
        if D2C4Probe.detectsC4(source) {
            var result = D2C4Mapper.map(source: source)
            if let title = Self.documentTitleMetadata(in: source) {
                var doc = result.document
                doc.title = title
                result = DiagramImportResult(document: doc, diagnostics: result.diagnostics)
            }
            return result
        }

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
            var (er, erDiagnostics) = D2ERMapper().map(d2Doc)
            applyERCardinalityMarkers(&er, markers: markerScan.markers)
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

        if D2SequenceProbe.detectsSequence(d2Doc) {
            let (seq, seqDiagnostics) = D2SequenceMapper().map(d2Doc, markers: markerScan.markers)
            var document = DiagramDocument(payload: .sequenceDiagram(seq))
            document.title = Self.documentTitleMetadata(in: source)
            return DiagramImportResult(
                document: document,
                diagnostics: parseDiagnostics + seqDiagnostics
            )
        }

        // Marker-forced family takes precedence over structural probes.
        let markerFamily = markerScan.markers.compactMap { marker -> String? in
            if case .family(let name) = marker.kind { return name } else { return nil }
        }.first

        if markerFamily == "sequence" {
            let (seq, seqDiagnostics) = D2SequenceMapper().map(d2Doc, markers: markerScan.markers)
            var document = DiagramDocument(payload: .sequenceDiagram(seq))
            document.title = Self.documentTitleMetadata(in: source)
            return DiagramImportResult(
                document: document,
                diagnostics: parseDiagnostics + seqDiagnostics
            )
        }

        if markerFamily == "architecture" || D2ArchitectureProbe.detectsArchitecture(d2Doc) {
            let (arch, archDiagnostics) = D2ArchitectureMapper().map(d2Doc, markers: markerScan.markers)
            var document = DiagramDocument(payload: .architecture(arch))
            document.title = Self.documentTitleMetadata(in: source)
            return DiagramImportResult(
                document: document,
                diagnostics: parseDiagnostics + archDiagnostics
            )
        }

        if markerFamily == "mindmap" {
            let (maybeMindmap, mmDiagnostics) = D2MindmapMapper().map(d2Doc, markers: markerScan.markers)
            if let mindmap = maybeMindmap {
                var document = DiagramDocument(payload: .mindmap(mindmap))
                document.title = Self.documentTitleMetadata(in: source)
                return DiagramImportResult(
                    document: document,
                    diagnostics: parseDiagnostics + mmDiagnostics
                )
            }
            // Fall through to flowchart on multi-root mindmap input.
        }

        if markerFamily == "treeView" {
            let (maybeTree, tvDiagnostics) = D2TreeViewMapper().map(d2Doc, markers: markerScan.markers)
            if let tree = maybeTree {
                var document = DiagramDocument(payload: .treeView(tree))
                document.title = Self.documentTitleMetadata(in: source)
                return DiagramImportResult(
                    document: document,
                    diagnostics: parseDiagnostics + tvDiagnostics
                )
            }
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

    /// Apply er-cardinality recovery markers to the built `ErDiagram`. Each
    /// marker overwrites the `relSpec.cardA` / `cardB` of the relationship
    /// whose synthesized id `"\(entity1)_\(entity2)"` matches the marker's
    /// `relationshipId`. Silent drop when no relationship matches.
    private func applyERCardinalityMarkers(
        _ ed: inout ErDiagram,
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
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

import Foundation
import DiagramKitModel
import DiagramKitCommon
import DiagramKitImport

/// Mermaid source-format importer.
///
/// Wraps the existing per-family `DiagramRegistry` dispatch behind the
/// `DiagramSourceImporter` protocol. All 28 diagram families supported
/// by the Mermaid parser are available through this importer.
///
/// This importer's `supports(source:)` probe is intentionally broad —
/// it always returns `true`. Mermaid acts as the fallback importer and
/// MUST be ordered LAST in any `ImporterRegistry` that includes narrower
/// format importers.
public struct MermaidImporter: DiagramSourceImporter {

    public let name = "Mermaid"
    public let supportedDiagramTypes: Set<DiagramType> = Set(DiagramType.allCases)

    public init() {}

    public func supports(source: String) -> Bool {
        // Mermaid's flowchart fallback descriptor matches `{ _ in true }`,
        // so any non-empty source is potentially Mermaid. This is the
        // explicit fallback — narrower importers (d2, DOT, PlantUML,
        // Structurizr) are probed BEFORE this importer in the registry.
        return true
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        // Replicate existing MermaidParser.parse() logic.
        let decoded = _HTMLEntities.decode(source)
        let (processed, frontmatter) = _parseFrontMatterAndStripped(decoded)

        let header = DiagramHeader.detect(from: processed)
        let descriptor = DiagramRegistry.detect(header)
        let document = try descriptor.parse(processed, frontmatter)

        return DiagramImportResult(document: document, diagnostics: [])
    }
}

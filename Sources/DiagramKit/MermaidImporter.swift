import Foundation
import DiagramKitCommon
import DiagramKitModel
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
    public let formatID = DiagramFormatID.mermaid
    public let supportedDiagramTypes: Set<DiagramType> = Set(DiagramType.allCases)
    public let isFallback: Bool = true

    public init() {}

    public func supports(source: String) -> Bool {
        // Mermaid's flowchart fallback descriptor matches `{ _ in true }`,
        // so any non-empty source is potentially Mermaid. This is the
        // explicit fallback — narrower importers (d2, DOT, PlantUML,
        // Structurizr) are probed BEFORE this importer in the registry.
        //
        // Empty / whitespace-only input is excluded: nothing claims that
        // input, and `DiagramLoader.parse` surfaces the rejection as a
        // `DiagramError.unrecognizedFormat` diagnostic rather than
        // dispatching to a parser.
        return !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        let decoded = _HTMLEntities.decode(source)
        let (processed, frontmatter) = _parseFrontMatterAndStripped(decoded)

        let header = DiagramHeader.detect(from: processed)
        let descriptor = DiagramRegistry.detect(header)
        var (document, diagnostics) = try descriptor.parse(processed, frontmatter)
        if let title = frontmatter?.shared.diagramTitle ?? frontmatter?.shared.title, !title.isEmpty {
            document.title = title
        }
        let fmTheme = frontmatter?.shared.theme
        let fmLayout = frontmatter?.shared.layout
        if fmTheme != nil || fmLayout != nil {
            document.frontmatter = DiagramDocumentFrontmatter(theme: fmTheme, layout: fmLayout)
        }

        return DiagramImportResult(document: document, diagnostics: diagnostics)
    }
}

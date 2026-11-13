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
        let normalized = DiagramSourceNormalizer.normalizedLineEndings(source)
        let terminated = _HTMLEntities.stripStyleStatementTerminators(normalized)
        let decoded = _HTMLEntities.decode(terminated)
        let (decodedBody, frontmatter) = _parseFrontMatterAndStripped(decoded)
        var processed = decodedBody

        let header = DiagramHeader.detect(from: processed)
        let descriptor = DiagramRegistry.detect(header)
        if Self.decodesEntitiesAfterScanning.contains(descriptor.type) {
            // Upstream decodes entity codes in label text, after parsing.
            // Decoding first turns `#quot;` into a `"` the kanban and block
            // scanners read as a quote, so a label could not hold one.
            // These parsers decode their text themselves.
            processed = Self.undecodedBody(terminated)
        }
        // Upstream shields entity codes before lexing, so `#59;` is a `;`
        // in the text, never a statement end, and `#35;` never starts a
        // comment. The sequence parser reads text with the codes held as
        // placeholders, and the decoded characters go back in afterwards.
        var shieldedEntities: [String] = []
        if descriptor.type == .sequenceDiagram {
            (processed, shieldedEntities) = _HTMLEntities.shieldingEntities(Self.undecodedBody(terminated))
        }
        var (document, diagnostics) = try descriptor.parse(processed, frontmatter)
        if !shieldedEntities.isEmpty, case .sequenceDiagram(let model) = document.payload {
            document.payload = .sequenceDiagram(model._mappingText {
                _HTMLEntities.restoringShieldedEntities($0, shieldedEntities)
            })
        }
        if let title = frontmatter?.shared.diagramTitle ?? frontmatter?.shared.title, !title.isEmpty {
            document.title = title
        }
        let fmTheme = frontmatter?.shared.theme
        let fmLayout = frontmatter?.shared.layout
        if fmTheme != nil || fmLayout != nil {
            document.frontmatter = DiagramDocumentFrontmatter(theme: fmTheme, layout: fmLayout)
        }
        document.sourceAnnotations = _collectMermaidSourceAnnotations(
            normalized, title: document.title, theme: fmTheme, layout: fmLayout
        )

        if let fmDiagnostics = frontmatter?.diagnostics, !fmDiagnostics.isEmpty {
            diagnostics.append(contentsOf: fmDiagnostics)
        }

        return DiagramImportResult(document: document, diagnostics: diagnostics)
    }

    /// The diagram body of `source` with frontmatter and init directives
    /// removed and entity codes left as written. Out of line: the
    /// `DiagramFrontmatter` it discards is large, and `parse` runs on
    /// callers' stacks (swift-testing's cooperative threads among them).
    @inline(never)
    static func undecodedBody(_ source: String) -> String {
        _parseFrontMatterAndStripped(source).0
    }

    /// Families whose parsers decode entity codes in their text after
    /// scanning it.
    static let decodesEntitiesAfterScanning: Set<DiagramType> = [.kanban, .block]

}

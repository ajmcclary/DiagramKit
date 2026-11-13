import Foundation
import DiagramKitCommon

// MARK: - DiagramFrontmatter
//
// Parsed YAML frontmatter values for any diagram family.
//
// Storage is split into two nested structs:
//
//   - `shared`     — diagram-agnostic config (title, theme name, font size,
//                    layout, look, htmlLabels, securityLevel). See
//                    `SharedFrontmatter`.
//   - `perDiagram` — 27 typed family sections. Each family lives in one
//                    `DiagramFamilyFrontmatter<Config, Theme>` slot;
//                    config-only families parameterize on `Theme = Never`.
//                    See `PerDiagramFrontmatter`.
//
// Audit A4 removed the legacy 49-arg flat init and the 49 flat-name
// compatibility shims. Callers write directly to typed sections, e.g.
// `fm.perDiagram.block.config = cfg` or `fm.shared.title = "X"`.

public struct DiagramFrontmatter: Sendable {

    public var shared: SharedFrontmatter
    public var perDiagram: PerDiagramFrontmatter
    /// Diagnostics collected while binding frontmatter values (e.g. rejected
    /// unsafe colors or style values). Merged into `DiagramImportResult` by
    /// the importer.
    public var diagnostics: [DiagramDiagnostic]

    public init(
        shared: SharedFrontmatter = SharedFrontmatter(),
        perDiagram: PerDiagramFrontmatter = PerDiagramFrontmatter(),
        diagnostics: [DiagramDiagnostic] = []
    ) {
        self.shared = shared
        self.perDiagram = perDiagram
        self.diagnostics = diagnostics
    }
}

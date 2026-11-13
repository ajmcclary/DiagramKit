// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Owner ruling (2026-11-12 review, round 4): an edit that does not concern
// the diagram's body (title, theme, layout preset) changes only the lines
// of those settings, on every diagram type, and an edit that would change a
// line it is not about is refused.

import Foundation
import Testing
import DiagramKit
import DiagramKitCommon
import DiagramKitExport
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitInteractive

/// The real Mermaid exporter, with one body line rewritten.
private struct BodyRewritingExporter: DiagramExporter {
    let name = "Rewriting Mermaid"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = MermaidExporter().supportedDiagramTypes
    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        let source = try MermaidExporter().export(document).source
        return DiagramExportResult(source: source.replacingOccurrences(of: "A --> B", with: "A-->B"))
    }
}

@Suite("Settings edits keep the diagram's lines") @MainActor
struct SettingsEditPreservationTests {

    @Test("title, theme and layout changes on every corpus Mermaid document leave every body line as written")
    func everyTypeKeepsItsBody() async throws {
        var failures: [String] = []
        var checked = 0
        for entry in try DiagramCorpus.load() {
            guard let document = try? MermaidImporter().parse(entry.source).document else { continue }
            for mutation in [DiagramMutation.setTitle("Renamed"), .setTheme("nord"), .setLayoutPreset(.adaptive)] {
                let editor = DiagramEditor(
                    document: document, preferredExportFormat: .mermaid,
                    exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: entry.source
                )
                do {
                    try await editor.perform(mutation)
                } catch {
                    failures.append("[\(entry.id)] \(mutation) refused: \(error)")
                    continue
                }
                checked += 1
                let saved = editor.source ?? ""
                let preamble = _collectMermaidSourceAnnotations(
                    entry.source, title: document.title, theme: document.frontmatter?.theme, layout: document.frontmatter?.layout
                )?.preamble ?? ""
                let body = entry.source.dropFirst(preamble.count)
                if !saved.hasSuffix(body) {
                    failures.append("[\(entry.id)] \(mutation) changed the body")
                }
            }
        }
        #expect(checked > 1000)
        #expect(failures.isEmpty, "\(failures.prefix(20).joined(separator: "\n"))")
    }

    @Test("a settings edit whose saved text would rewrite a body line is refused, and nothing changes")
    func bodyRewriteRefused() async throws {
        let source = "flowchart TD\n  A --> B\n"
        let editor = DiagramEditor(
            document: try MermaidImporter().parse(source).document,
            preferredExportFormat: .mermaid,
            exportRegistry: ExporterRegistry.empty.registering(BodyRewritingExporter()),
            initialSource: source
        )
        do {
            try await editor.perform(.setTitle("New"))
            Issue.record("applied")
        } catch DiagramEditorError.exportWouldLoseContent(let details) {
            #expect(details.contains("not only its settings"), "\(details)")
        }
        #expect(editor.source == source)
        #expect(!editor.canUndo)
    }
}
#endif

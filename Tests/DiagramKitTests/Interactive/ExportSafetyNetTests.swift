// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Owner ruling 5 (2026-11-12 review): a canvas edit whose saved text would
// lose content fails with a typed error and leaves the document alone.

import Foundation
import Testing
import DiagramKit
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
import DiagramKitTestSupport
@testable import DiagramKitInteractive

/// The real Mermaid exporter with a deliberate loss applied to its output.
private struct LossyExporter: DiagramExporter {
    let name = "Lossy Mermaid"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = MermaidExporter().supportedDiagramTypes
    let dropping: @Sendable (String) -> Bool

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        let result = try MermaidExporter().export(document)
        let kept = result.source.split(separator: "\n", omittingEmptySubsequences: false).filter { !dropping(String($0)) }
        return DiagramExportResult(source: kept.joined(separator: "\n"), diagnostics: result.diagnostics)
    }
}

private func registry(dropping: @escaping @Sendable (String) -> Bool) -> ExporterRegistry {
    ExporterRegistry.empty
        .registering(LossyExporter(dropping: dropping))
        .readingBack { source, format in
            try DiagramLoader.parseDocument(source, as: format, registry: DiagramPipeline.defaultRegistry)
        }
}

@MainActor
private func editor(_ source: String, registry: ExporterRegistry = DiagramPipeline.defaultExportRegistry) throws -> DiagramEditor {
    DiagramEditor(
        document: try MermaidImporter().parse(source).document,
        preferredExportFormat: .mermaid,
        exportRegistry: registry,
        initialSource: source
    )
}

private let flowSource = """
flowchart TD
  %% the ingest side
  A[Ingest] --> B[Parse]
  B --> C[Store]
  click C href "obsidian://open?vault=notes" "Open"
"""

private func isLossRefusal(_ error: any Error) -> Bool {
    if case DiagramEditorError.exportWouldLoseContent = error { return true }
    return false
}

@Suite("A canvas edit that would lose content is refused") @MainActor
struct ExportSafetyNetTests {

    @Test("an export that drops a statement the model holds fails the mutation and changes nothing")
    func lossyModelExportRefused() async throws {
        let edit = try editor(flowSource, registry: registry(dropping: { $0.contains("B --> C") }))
        let before = _modelFingerprint(edit.document)
        do {
            try await edit.perform(.setLabel(of: DiagramSelection(diagramType: .flowchart, elementID: "node:A"), to: "Read"))
            Issue.record("mutation was applied")
        } catch {
            #expect(isLossRefusal(error), "\(error)")
        }
        #expect(edit.source == flowSource)
        #expect(_modelFingerprint(edit.document) == before)
        #expect(!edit.canUndo)
    }

    @Test("an export that drops a comment the model does not hold fails the mutation")
    func lostCommentRefused() async throws {
        let edit = try editor(flowSource, registry: registry(dropping: { $0.contains("%% the ingest side") }))
        do {
            try await edit.perform(.setLabel(of: DiagramSelection(diagramType: .flowchart, elementID: "node:A"), to: "Read"))
            Issue.record("mutation was applied")
        } catch {
            #expect(isLossRefusal(error), "\(error)")
        }
        #expect(edit.source == flowSource)
    }

    @Test("an export that drops a click line fails the mutation")
    func lostClickRefused() async throws {
        let edit = try editor(flowSource, registry: registry(dropping: { $0.contains("click C") }))
        do {
            try await edit.perform(.setLabel(of: DiagramSelection(diagramType: .flowchart, elementID: "node:A"), to: "Read"))
            Issue.record("mutation was applied")
        } catch {
            #expect(isLossRefusal(error), "\(error)")
        }
        #expect(edit.source == flowSource)
    }

    @Test("an export that rewrites the frontmatter fails a mutation that does not change configuration")
    func lostFrontmatterRefused() async throws {
        let source = "---\ntitle: Plan\nconfig:\n  look: handDrawn\n---\n" + flowSource
        let edit = try editor(source, registry: registry(dropping: { $0.contains("look: handDrawn") }))
        do {
            try await edit.perform(.setLabel(of: DiagramSelection(diagramType: .flowchart, elementID: "node:A"), to: "Read"))
            Issue.record("mutation was applied")
        } catch {
            #expect(isLossRefusal(error), "\(error)")
        }
        #expect(edit.source == source)
    }

    @Test("with the real exporter the same edits go through and keep every protected line")
    func faithfulEditsPass() async throws {
        let edit = try editor(flowSource)
        try await edit.perform(.setLabel(of: DiagramSelection(diagramType: .flowchart, elementID: "node:A"), to: "Read"))
        let saved = try #require(edit.source)
        #expect(saved.contains("%% the ingest side"))
        #expect(saved.contains("click C href \"obsidian://open?vault=notes\" \"Open\""))
        try await edit.perform(.deleteElement(DiagramSelection(diagramType: .flowchart, elementID: "node:C")))
        #expect(edit.source?.contains("click C") == false, "the click line goes with its node")
    }

    @Test("a sequence edit that would reverse a half arrow or drop a link line is refused")
    func sequenceLossRefused() async throws {
        let source = "sequenceDiagram\n  participant A\n  link A: Docs @ https://example.com\n  A-|\\B: one\n  B->>A: two\n"
        let reversing = ExporterRegistry.empty
            .registering(LossyExporter(dropping: { $0.contains("link A") }))
            .readingBack { source, format in
                try DiagramLoader.parseDocument(source, as: format, registry: DiagramPipeline.defaultRegistry)
            }
        let edit = try editor(source, registry: reversing)
        do {
            try await edit.performSequence(.moveMessage(at: 0, to: 1))
            Issue.record("mutation was applied")
        } catch {
            #expect(isLossRefusal(error), "\(error)")
        }
        #expect(edit.source == source)
    }
}
#endif

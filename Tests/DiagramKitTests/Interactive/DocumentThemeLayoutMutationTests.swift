// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Visual editor plan 6 — setTheme / setLayoutPreset document mutations.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

private struct MockExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart, .stateDiagram]
    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        DiagramExportResult(source: "mock")
    }
}

private func flowDoc() -> DiagramDocument {
    DiagramDocument(payload: .flowchart(original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: [(id: "A", node: original_src_types.MermaidNode(id: "A", label: "A", shape: .rectangle))],
        edges: []
    )))
}

@MainActor
private func makeEditor() -> DiagramEditor {
    DiagramEditor(
        document: flowDoc(),
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(MockExporter())
    )
}

@Suite @MainActor
struct DocumentThemeLayoutMutationTests {

    @Test("setTheme writes the frontmatter theme")
    func setTheme() async throws {
        let editor = makeEditor()
        try await editor.perform(.setTheme("nord"))
        #expect(editor.document.frontmatter?.theme == "nord")
    }

    @Test("setTheme nil clears the theme and drops an empty frontmatter")
    func clearTheme() async throws {
        let editor = makeEditor()
        try await editor.perform(.setTheme("nord"))
        try await editor.perform(.setTheme(nil))
        #expect(editor.document.frontmatter?.theme == nil)
        #expect(editor.document.frontmatter == nil || editor.document.frontmatter?.isEmpty == true)
    }

    @Test("unknown theme name throws unknownThemeName")
    func unknownTheme() async {
        let editor = makeEditor()
        await #expect(throws: DiagramEditorError.self) {
            try await editor.perform(.setTheme("not-a-theme-xyz"))
        }
    }

    @Test("setLayoutPreset adaptive writes layout; hierarchical clears it")
    func layoutPreset() async throws {
        let editor = makeEditor()
        try await editor.perform(.setLayoutPreset(.adaptive))
        #expect(editor.document.frontmatter?.layout == "adaptive")
        try await editor.perform(.setLayoutPreset(.hierarchical))
        #expect(editor.document.frontmatter?.layout == nil)
    }

    @Test("theme survives alongside layout")
    func combined() async throws {
        let editor = makeEditor()
        try await editor.perform(.setTheme("dracula"))
        try await editor.perform(.setLayoutPreset(.adaptive))
        #expect(editor.document.frontmatter?.theme == "dracula")
        #expect(editor.document.frontmatter?.layout == "adaptive")
    }

    @Test("undo restores the previous frontmatter")
    func undoRestores() async throws {
        let editor = makeEditor()
        try await editor.perform(.setTheme("nord"))
        editor.undoManager.undo()
        #expect(editor.document.frontmatter?.theme == nil)
    }
}
#endif

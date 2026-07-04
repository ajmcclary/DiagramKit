import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitModel
@testable import DiagramKitSample

/// Regression: `store.editor` (the source of truth for the Organize/Search
/// panels and the inspector) must re-seed from the committed source in every
/// workspace mode — the visual canvas paints from `previewSource` and does not
/// route through `didCompleteRender`, so `setSource` must trigger the re-seed.
@MainActor @Suite struct EditorReseedSyncTests {
    @Test func editorReseedsAfterSetSource() async throws {
        let store = LiveEditorStore()
        // Initial doc.
        store.setSource("flowchart TB\n A[Start] --> B[Process] --> C[End]", origin: .system)
        // Let the async parse/seed settle.
        for _ in 0..<20 where OutlineTree.from(store).roots.isEmpty { try await Task.sleep(nanoseconds: 100_000_000) }
        let first = OutlineTree.from(store)
        #expect(first.roots.map(\.id) == ["A", "B", "C"])

        // Load a different, more complex doc with a subgraph.
        store.setSource("""
        flowchart TB
          C[C] --> DS[Deploy Staging]
          subgraph CI[CI Pipeline]
            D[D] --> P[Push Code] --> T{Tests Pass?}
          end
        """, origin: .system)

        // Poll until the editor re-seeds to the new document (id set changes).
        var reseeded = OutlineTree.from(store)
        for _ in 0..<30 {
            reseeded = OutlineTree.from(store)
            if reseeded.roots.contains(where: { $0.kind == .subgraph }) { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let allIDs = flatIDs(reseeded.roots)
        // The Organize source (editor.document) must reflect the NEW doc, not the old one.
        #expect(reseeded.roots.contains { $0.kind == .subgraph }, "editor.document did not re-seed to the new subgraph doc; ids=\(allIDs)")
        #expect(allIDs.contains("DS"), "expected new node DS; got \(allIDs)")
        #expect(!allIDs.contains("A"), "stale node A still present; got \(allIDs)")
    }

    private func flatIDs(_ nodes: [OutlineNode]) -> [String] {
        nodes.flatMap { [$0.id] + flatIDs($0.children) }
    }

    /// Search (via OutlineElements) and the inspector (via graph.nodesById) read
    /// the same editor.document, so they track a reseeded document too.
    @Test func searchAndInspectorSeeReseededDocument() async throws {
        let store = LiveEditorStore()
        store.setSource("flowchart TB\n A[Start] --> B[Process]", origin: .system)
        for _ in 0..<20 where OutlineElements.from(store).nodes.isEmpty { try await Task.sleep(nanoseconds: 100_000_000) }

        store.setSource("flowchart TB\n X[Deploy] --> Y[Verify]", origin: .system)
        var els = OutlineElements.from(store)
        for _ in 0..<30 {
            els = OutlineElements.from(store)
            if els.nodes.contains(where: { $0.id == "X" }) { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        // Search panel data reflects the new document.
        let ids = Set(els.nodes.map(\.id))
        #expect(ids.contains("X"))
        #expect(ids.contains("Y"))
        #expect(!ids.contains("A"), "stale node A still present in Search data: \(ids)")

        // Inspector resolves the selected node against the reseeded document
        // (mirrors InspectorView.currentNode: strip "node:" prefix, look up in graph).
        store.setSelection(DiagramSelection(diagramType: .flowchart, elementID: "node:X"))
        guard case .flowchart(let model) = store.editor?.document.payload else {
            Issue.record("expected flowchart payload")
            return
        }
        #expect(model.nodesById["X"]?.label == "Deploy")
    }
}

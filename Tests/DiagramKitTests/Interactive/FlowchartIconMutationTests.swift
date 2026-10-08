// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Visual editor plan 4 — setNodeIcon mutation.

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

private func flowDoc(_ nodes: [String]) -> DiagramDocument {
    let mNodes = nodes.map {
        (id: $0, node: original_src_types.MermaidNode(id: $0, label: "Node \($0)", shape: .rectangle))
    }
    return DiagramDocument(payload: .flowchart(
        original_src_types.MermaidGraph(direction: .TD, nodesInOrder: mNodes, edges: [])
    ))
}

@MainActor
private func makeEditor(_ doc: DiagramDocument) -> DiagramEditor {
    DiagramEditor(
        document: doc,
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(MockExporter())
    )
}

@MainActor
private func nodeA(_ editor: DiagramEditor) -> original_src_types.MermaidNode? {
    guard case .flowchart(let model) = editor.document.payload else { return nil }
    return model.nodesInOrder.first { $0.id == "A" }?.node
}

private let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")

@Suite @MainActor
struct FlowchartIconMutationTests {

    @Test("setNodeIcon applies shape, icon, size, and label position")
    func setIcon() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let spec = IconSpec(name: "user", background: .circle, size: .large, labelPosition: .bottom)
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: spec))

        let node = nodeA(editor)
        #expect(node?.shape == .iconCircle)
        #expect(node?.properties?.icon == "fa:user")
        #expect(node?.properties?.h == 64)
        #expect(node?.properties?.pos == "b")
        #expect(node?.label == "Node A")  // label untouched
    }

    @Test("setNodeIcon defaults: circle, medium, centered label")
    func defaults() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: IconSpec(name: "check")))
        let node = nodeA(editor)
        #expect(node?.shape == .iconCircle)
        #expect(node?.properties?.h == 48)
        #expect(node?.properties?.pos == nil)
    }

    @Test("nil spec clears icon state back to rectangle")
    func clearIcon() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: IconSpec(name: "user")))
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: nil))
        let node = nodeA(editor)
        #expect(node?.shape == .rectangle)
        #expect(node?.properties?.icon == nil)
        #expect(node?.properties?.h == nil)
        #expect(node?.properties?.pos == nil)
    }

    @Test("unknown FA name throws unknownIconName")
    func unknownName() async {
        let editor = makeEditor(flowDoc(["A"]))
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.setNodeIcon(of: sel, to: IconSpec(name: "not-a-real-icon-xyz")))
        }
    }

    @Test("fa: prefix in the spec name is tolerated and normalized")
    func prefixNormalized() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: IconSpec(name: "fa:user")))
        #expect(nodeA(editor)?.properties?.icon == "fa:user")
    }

    @Test("undo restores the pre-icon node")
    func undoRestores() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: IconSpec(name: "user")))
        editor.undoManager.undo()
        let node = nodeA(editor)
        #expect(node?.shape == .rectangle)
        #expect(node?.properties?.icon == nil)
    }
}
#endif

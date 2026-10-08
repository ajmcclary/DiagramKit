// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Visual editor plan 5 — setNodeImage mutation.

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
struct FlowchartImageMutationTests {

    @Test("setNodeImage applies shape, url, size, and title")
    func setImage() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let spec = ImageSpec(urlString: "https://example.com/x.png", width: 200, height: 150, title: "Diagram")
        try await editor.performFlowchart(.setNodeImage(of: sel, to: spec))
        let node = nodeA(editor)
        #expect(node?.shape == .imageSquare)
        #expect(node?.properties?.img == "https://example.com/x.png")
        #expect(node?.properties?.w == 200)
        #expect(node?.properties?.h == 150)
        #expect(node?.label == "Diagram")
    }

    @Test("nil title leaves the label untouched")
    func nilTitle() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeImage(of: sel, to: ImageSpec(urlString: "https://example.com/x.png")))
        #expect(nodeA(editor)?.label == "Node A")
        #expect(nodeA(editor)?.properties?.w == 120)
        #expect(nodeA(editor)?.properties?.h == 90)
    }

    @Test("nil spec clears image state back to rectangle")
    func clearImage() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeImage(of: sel, to: ImageSpec(urlString: "https://example.com/x.png")))
        try await editor.performFlowchart(.setNodeImage(of: sel, to: nil))
        let node = nodeA(editor)
        #expect(node?.shape == .rectangle)
        #expect(node?.properties?.img == nil)
        #expect(node?.properties?.w == nil)
        #expect(node?.properties?.h == nil)
    }

    @Test("non-http(s) URLs throw invalidImageURL and never mutate")
    func badURLs() async {
        let editor = makeEditor(flowDoc(["A"]))
        for bad in ["javascript:alert(1)", "file:///etc/passwd", "data:image/png;base64,AAAA", "not a url", ""] {
            await #expect(throws: DiagramEditorError.self) {
                try await editor.performFlowchart(.setNodeImage(of: sel, to: ImageSpec(urlString: bad)))
            }
        }
        #expect(nodeA(editor)?.shape == .rectangle)
    }

    @Test("validateURL accepts http/https with host, rejects the rest")
    func validate() {
        #expect(ImageSpec.validateURL("https://example.com/a.png"))
        #expect(ImageSpec.validateURL("http://example.com/a.png"))
        #expect(!ImageSpec.validateURL("ftp://example.com/a.png"))
        #expect(!ImageSpec.validateURL("https://"))
        #expect(!ImageSpec.validateURL(""))
    }

    @Test("undo restores the pre-image node")
    func undoRestores() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeImage(of: sel, to: ImageSpec(urlString: "https://example.com/x.png", title: "T")))
        editor.undoManager.undo()
        let node = nodeA(editor)
        #expect(node?.shape == .rectangle)
        #expect(node?.label == "Node A")
    }
}
#endif

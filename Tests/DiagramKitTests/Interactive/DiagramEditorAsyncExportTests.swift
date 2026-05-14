// Async export behavior: serialization, isExporting transitions,
// cancellation isolation, off-MainActor worker hop, atomicity
// under exporter throw.

import Testing
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
@testable import DiagramKitInteractive

// MARK: - Test exporter that emits the current node count

private struct CountingExporter: DiagramExporter {
    let name: String = "Counting"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        let n: Int
        switch document.payload {
        case .flowchart(let m): n = m.nodesInOrder.count
        default: n = -1
        }
        return DiagramExportResult(source: "n=\(n)")
    }
}

private func flowDoc(_ nodes: [String]) -> DiagramDocument {
    let mNodes = nodes.map { id in
        (id: id, node: original_src_types.MermaidNode(
            id: id, label: id, shape: .rectangle
        ))
    }
    let model = original_src_types.MermaidGraph(
        direction: .TD, nodesInOrder: mNodes, edges: []
    )
    return DiagramDocument(payload: .flowchart(model))
}

@MainActor
private func makeEditor(_ nodes: [String] = ["A"]) -> DiagramEditor {
    DiagramEditor(
        document: flowDoc(nodes),
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(CountingExporter())
    )
}

@Suite @MainActor
struct DiagramEditorAsyncExportTests {

    @Test("Two perform calls fired without intermediate awaits commit in order")
    func serializesOverlappingPerforms() async throws {
        let editor = makeEditor(["A"])

        let t1 = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        let t2 = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "C", label: "C"))
        }
        try await t1.value
        try await t2.value

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false), "expected flowchart")
            return
        }
        #expect(model.nodesInOrder.map(\.id) == ["A", "B", "C"])
        #expect(editor.undoManager.canUndo == true)
        editor.undoManager.undo()
        editor.undoManager.undo()
        if case .flowchart(let m0) = editor.document.payload {
            #expect(m0.nodesInOrder.map(\.id) == ["A"])
        } else {
            #expect(Bool(false), "expected flowchart after two undos")
        }
    }

    @Test("isExporting is false at rest, true during a mutation, false after")
    func isExportingTransitions() async throws {
        actor Gate {
            private var continuation: CheckedContinuation<Void, Never>?
            func wait() async {
                await withCheckedContinuation { self.continuation = $0 }
            }
            func release() { continuation?.resume(); continuation = nil }
        }
        let gate = Gate()

        struct GatedExporter: DiagramExporter {
            let name: String = "Gated"
            let formatID: DiagramFormatID = .mermaid
            let supportedDiagramTypes: Set<DiagramType> = [.flowchart]
            let gate: Gate
            func export(_ document: DiagramDocument) throws -> DiagramExportResult {
                let sema = DispatchSemaphore(value: 0)
                Task { await gate.wait(); sema.signal() }
                sema.wait()
                return DiagramExportResult(source: "gated")
            }
        }

        let editor = DiagramEditor(
            document: flowDoc(["A"]),
            preferredExportFormat: .mermaid,
            exportRegistry: ExporterRegistry.empty.registering(GatedExporter(gate: gate))
        )
        #expect(editor.isExporting == false)

        let task = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        try await Task.sleep(for: .milliseconds(50))
        #expect(editor.isExporting == true)
        await gate.release()
        try await task.value
        #expect(editor.isExporting == false)
    }
}

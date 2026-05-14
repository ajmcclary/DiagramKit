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

    @Test("Export runs off MainActor")
    func exportRunsOffMainActor() async throws {
        actor ThreadObserver {
            private(set) var sawOffMainActor: Bool = false
            func record(isMain: Bool) { if !isMain { sawOffMainActor = true } }
        }
        let observer = ThreadObserver()

        struct ObservingExporter: DiagramExporter {
            let name: String = "Observing"
            let formatID: DiagramFormatID = .mermaid
            let supportedDiagramTypes: Set<DiagramType> = [.flowchart]
            let observer: ThreadObserver
            func export(_ document: DiagramDocument) throws -> DiagramExportResult {
                let isMain = Thread.isMainThread
                let sema = DispatchSemaphore(value: 0)
                Task { await observer.record(isMain: isMain); sema.signal() }
                sema.wait()
                return DiagramExportResult(source: "observed")
            }
        }

        let editor = DiagramEditor(
            document: flowDoc(["A"]),
            preferredExportFormat: .mermaid,
            exportRegistry: ExporterRegistry.empty.registering(ObservingExporter(observer: observer))
        )

        try await editor.performFlowchart(.insertNode(id: "B", label: "B"))

        let sawOff = await observer.sawOffMainActor
        #expect(sawOff == true, "exporter must run off MainActor (DiagramWorkerThread)")
    }

    @Test("Cancelling the outer Task does not abort the in-flight commit")
    func cancellationIsolation() async throws {
        let editor = makeEditor(["A"])

        let task = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        // Let the inner Task start the worker hop, then cancel the outer.
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()
        _ = try? await task.value

        // Drain any continuation work.
        try await Task.sleep(for: .milliseconds(50))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false), "expected flowchart")
            return
        }
        #expect(model.nodesInOrder.map(\.id).contains("B"))
        #expect(editor.isExporting == false)
    }

    @Test("A throwing exporter leaves document, source, and undo stack untouched")
    func atomicityUnderExporterThrow() async throws {
        struct FailingExporter: DiagramExporter {
            let name: String = "Failing"
            let formatID: DiagramFormatID = .mermaid
            let supportedDiagramTypes: Set<DiagramType> = [.flowchart]
            func export(_ document: DiagramDocument) throws -> DiagramExportResult {
                throw DiagramExportError(message: "boom")
            }
        }
        let editor = DiagramEditor(
            document: flowDoc(["A"]),
            preferredExportFormat: .mermaid,
            exportRegistry: ExporterRegistry.empty.registering(FailingExporter())
        )
        let preCanUndo = editor.undoManager.canUndo

        do {
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
            #expect(Bool(false), "expected throw")
        } catch {
            // pass — expecting sourceSyncFailed
        }

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false), "expected flowchart")
            return
        }
        #expect(model.nodesInOrder.map(\.id) == ["A"])
        #expect(editor.source == nil)
        #expect(editor.undoManager.canUndo == preCanUndo)
        #expect(editor.isExporting == false)
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

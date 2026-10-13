// Apple-only test (UndoManager-based interactive editor). On Linux this
// file is empty.
#if canImport(UIKit) || canImport(AppKit)
// REVIEW H2: mutation-chain serialization under concurrent `perform`,
// queued undo during an in-flight export, cancellation mid-chain, and
// `syncSource` chain routing. All coordination is via continuations —
// no wall-clock timing.

import Testing
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
@testable import DiagramKitInteractive

// MARK: - Fixtures

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

/// Deterministic coordination point for exporters that must hold the
/// worker thread at a known point. Replaces load-sensitive `Task.sleep`
/// observations: `waitUntilStarted(count:)` waits until `count` exports
/// have entered the exporter, and each `release()` resumes the exports
/// currently blocked in `awaitRelease()`. There is no release latch —
/// a later export blocks again until the next `release()`, so tests
/// drive each chained export round explicitly.
private actor ExportGate {
    private var startedCount = 0
    private var startedWaiters: [(target: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilStarted(count: Int = 1) async {
        while startedCount < count {
            await withCheckedContinuation { startedWaiters.append((count, $0)) }
        }
    }

    func signalStarted() {
        startedCount += 1
        startedWaiters.removeAll { waiter in
            if startedCount >= waiter.target {
                waiter.continuation.resume()
                return true
            }
            return false
        }
    }

    func awaitRelease() async {
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func release() {
        for continuation in releaseWaiters { continuation.resume() }
        releaseWaiters.removeAll()
    }
}

/// Exporter that signals `gate` on entry and blocks its worker thread
/// until `gate.release()` (or immediately if already released).
private struct GatedExporter: DiagramExporter {
    let name: String = "Gated"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart]
    let gate: ExportGate

    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        let sema = DispatchSemaphore(value: 0)
        Task {
            await gate.signalStarted()
            await gate.awaitRelease()
            sema.signal()
        }
        sema.wait()
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
private func makeEditor(
    _ nodes: [String] = ["A"],
    gate: ExportGate? = nil
) -> DiagramEditor {
    let registry: ExporterRegistry
    if let gate {
        registry = ExporterRegistry.empty.registering(GatedExporter(gate: gate))
    } else {
        registry = ExporterRegistry.empty.registering(CountingExporter())
    }
    return DiagramEditor(
        document: flowDoc(nodes),
        preferredExportFormat: .mermaid,
        exportRegistry: registry
    )
}

@MainActor
private func nodeIDs(_ editor: DiagramEditor) -> [String] {
    if case .flowchart(let model) = editor.document.payload {
        return model.nodesInOrder.map(\.id)
    }
    return []
}

// MARK: - Tests

@Suite @MainActor
struct DiagramEditorChainConcurrencyTests {

    @Test("Three rapid perform calls all land in order with a coherent undo stack")
    func threeRapidPerformsAllLand() async throws {
        let editor = makeEditor(["A"])

        let t1 = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        let t2 = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "C", label: "C"))
        }
        let t3 = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "D", label: "D"))
        }
        try await t1.value
        try await t2.value
        try await t3.value

        #expect(nodeIDs(editor) == ["A", "B", "C", "D"])
        #expect(editor.source == "n=4")
        #expect(editor.isExporting == false)

        // Three undos restore the original document; three redos
        // restore the mutated one. Each mutation got its own entry.
        await editor.undo()
        await editor.undo()
        await editor.undo()
        #expect(nodeIDs(editor) == ["A"])
        #expect(editor.undoManager.canUndo == false)

        await editor.redo()
        await editor.redo()
        await editor.redo()
        #expect(nodeIDs(editor) == ["A", "B", "C", "D"])
    }

    @Test("Undo issued while an export is in flight applies after the commit")
    func undoDuringInFlightExportIsConsistent() async throws {
        let gate = ExportGate()
        let editor = makeEditor(["A"], gate: gate)

        let performTask = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        await gate.waitUntilStarted()
        #expect(editor.isExporting == true)
        #expect(editor.canUndo == false, "canUndo gated while exporting")

        // Queue the undo while the commit is mid-flight.
        let undoTask = Task { @MainActor in
            await editor.undo()
        }
        await gate.release()
        try await performTask.value
        await undoTask.value

        // The mutation committed, then the queued undo reversed it:
        // no lost mutation, no stale commit (a stale commit would have
        // left source at "n=2" over the undone document).
        #expect(nodeIDs(editor) == ["A"])
        #expect(editor.source == nil)
        #expect(editor.canRedo == true)
        #expect(editor.isExporting == false)
    }

    @Test("canUndo gates to false only while the export is in flight")
    func canUndoGatedDuringExport() async throws {
        let gate = ExportGate()
        let editor = makeEditor(["A"], gate: gate)

        let setup = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        await gate.waitUntilStarted()
        await gate.release()
        try await setup.value
        #expect(editor.canUndo == true)

        let task = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "C", label: "C"))
        }
        await gate.waitUntilStarted(count: 2)
        #expect(editor.isExporting == true)
        #expect(editor.undoManager.canUndo == true, "stack still holds the entry")
        #expect(editor.canUndo == false, "editor gate hides it mid-export")
        await gate.release()
        try await task.value
        #expect(editor.isExporting == false)
        #expect(editor.canUndo == true)
    }

    @Test("syncSource issued during an in-flight mutation reflects the committed document")
    func syncSourceWaitsForInFlightMutation() async throws {
        let gate = ExportGate()
        let editor = makeEditor(["A"], gate: gate)

        let performTask = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        await gate.waitUntilStarted()

        let syncTask = Task { @MainActor in
            try await editor.syncSource()
        }
        // The sync is chained behind the in-flight mutation: round 1
        // completes the mutation, round 2 starts and completes the
        // sync's own export.
        await gate.release()
        await gate.waitUntilStarted(count: 2)
        #expect(editor.isExporting == true)
        await gate.release()
        try await performTask.value
        try await syncTask.value

        // A non-chained sync would have read the pre-mutation document
        // and committed "n=1".
        #expect(nodeIDs(editor) == ["A", "B"])
        #expect(editor.source == "n=2")
        #expect(editor.isExporting == false)
    }

    @Test("Cancelling callers mid-chain drops nothing; a later perform still works")
    func cancelMidChainThenPerformStillWorks() async throws {
        let gate = ExportGate()
        let editor = makeEditor(["A"], gate: gate)

        let t1 = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        }
        let t2 = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "C", label: "C"))
        }
        // t1's export is in flight; t2 is chained behind it.
        await gate.waitUntilStarted(count: 1)
        t1.cancel()
        t2.cancel()
        // Round 1 completes t1's export; t2's export then starts.
        await gate.release()
        await gate.waitUntilStarted(count: 2)
        await gate.release()
        try await t1.value
        try await t2.value

        #expect(nodeIDs(editor) == ["A", "B", "C"])
        #expect(editor.isExporting == false)

        // A fresh perform after the cancelled callers still lands.
        let t3 = Task { @MainActor in
            try await editor.performFlowchart(.insertNode(id: "D", label: "D"))
        }
        await gate.waitUntilStarted(count: 3)
        await gate.release()
        try await t3.value
        #expect(nodeIDs(editor) == ["A", "B", "C", "D"])
        #expect(editor.isExporting == false)
    }

    @Test("A failed mutation does not break the chain for later mutations")
    func failedMutationDoesNotBreakChain() async throws {
        let editor = makeEditor(["A"])

        // Duplicate id: derivation throws before any state changes.
        do {
            try await editor.performFlowchart(.insertNode(id: "A", label: "dup"))
            #expect(Bool(false), "expected duplicateNodeID throw")
        } catch {
            // expected
        }
        #expect(editor.isExporting == false)

        try await editor.performFlowchart(.insertNode(id: "B", label: "B"))
        #expect(nodeIDs(editor) == ["A", "B"])
        #expect(editor.source == "n=2")
    }
}
#endif

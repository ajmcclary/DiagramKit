// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Phase 9: Interactive Model Tests — DiagramMutation value-type semantics

import Testing
import DiagramKitModel
@testable import DiagramKitInteractive

@Suite
struct DiagramMutationTests {

    @Test("DiagramMutation is Equatable")
    func equatable() {
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        #expect(DiagramMutation.deleteElement(sel) == DiagramMutation.deleteElement(sel))
        #expect(DiagramMutation.setLabel(of: sel, to: "hi") == DiagramMutation.setLabel(of: sel, to: "hi"))
        #expect(DiagramMutation.setTitle("T") == DiagramMutation.setTitle("T"))
        #expect(DiagramMutation.noop == DiagramMutation.noop)

        #expect(DiagramMutation.deleteElement(sel) != DiagramMutation.noop)
        #expect(DiagramMutation.setTitle("A") != DiagramMutation.setTitle("B"))
    }

    @Test("DiagramMutation is Hashable")
    func hashable() {
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        let set: Set<DiagramMutation> = [
            .deleteElement(sel),
            .setLabel(of: sel, to: "X"),
            .setTitle("Y"),
            .noop
        ]
        #expect(set.count == 4)
    }

    @Test("DiagramMutation is Sendable")
    func sendable() {
        // Verified by compilation — all associated values are Sendable
        let m: DiagramMutation = .setTitle("Hello")
        #expect(m.undoActionName == "Set Title")
    }

    @Test("undoActionName is human-readable")
    func undoActionNames() {
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        #expect(DiagramMutation.deleteElement(sel).undoActionName == "Delete Element")
        #expect(DiagramMutation.setLabel(of: sel, to: "X").undoActionName == "Set Label")
        #expect(DiagramMutation.setTitle("T").undoActionName == "Set Title")
        #expect(DiagramMutation.noop.undoActionName == "")
    }

    @Test("FlowchartMutation undoActionName")
    func flowchartUndoActionNames() {
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        #expect(FlowchartMutation.insertNode(id: "N", label: "L").undoActionName == "Insert Node")
        #expect(FlowchartMutation.insertEdge(id: "E", from: sel, to: sel).undoActionName == "Insert Edge")
    }

    @Test("FlowchartMutation is Equatable and Hashable")
    func flowchartEquatableHashable() {
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        let m1 = FlowchartMutation.insertNode(id: "N", label: "L")
        let m2 = FlowchartMutation.insertNode(id: "N", label: "L")
        #expect(m1 == m2)

        let set: Set<FlowchartMutation> = [m1, .insertEdge(id: "E", from: sel, to: sel)]
        #expect(set.count == 2)
    }
}
#endif

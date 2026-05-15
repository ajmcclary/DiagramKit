import Testing
import DiagramKitTestSupport
import DiagramKitModel

@Suite("DiagramDocumentDiff dispatcher")
struct DiagramDocumentDiffTests {

    @Test("Dispatcher routes flowchart payloads to the flowchart arm")
    func dispatchesToFlowchartArm() {
        let model = ParsedGraphModel(direction: original_src_types.Direction.TD, nodesInOrder: [], edges: [])
        let a = DiagramDocument(payload: .flowchart(model))
        let b = DiagramDocument(payload: .flowchart(model))
        let deltas = compare(a, b)
        #expect(deltas.isEmpty)
    }

    @Test("Mismatched payload types report unexpected delta")
    func mismatchedPayloadTypes() {
        let a = DiagramDocument(payload: .flowchart(
            ParsedGraphModel(direction: original_src_types.Direction.TD, nodesInOrder: [], edges: [])
        ))
        let b = DiagramDocument(payload: .pie(PieChart()))
        let deltas = compare(a, b)
        #expect(deltas.count == 1)
        if case .unexpected(let path, _) = deltas[0] {
            #expect(path == "payload.type")
        } else {
            Issue.record("expected .unexpected; got \(deltas[0])")
        }
    }

    @Test("Title drop is categorised as .loss(.titleDrop), not .unexpected")
    func titleDrop() {
        var a = DiagramDocument(payload: .pie(PieChart()))
        a.title = "Sales"
        let b = DiagramDocument(payload: .pie(PieChart()))
        // Note: pie comparator is not implemented, but the dispatcher emits
        // .loss(.titleDrop) BEFORE descending into the payload arm. The
        // unexpected delta from the pie default-case will land after.
        let deltas = compare(a, b)
        #expect(deltas.contains { delta in
            if case .loss(.titleDrop) = delta { return true }
            return false
        })
    }
}

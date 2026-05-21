import Testing
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2SequenceExporter")
struct D2SequenceExporterTests {

    @Test("Emits dispatch header and actors with labels")
    func emitsHeaderAndActors() throws {
        let doc = DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: [
            .actor(SequenceActor(id: "alice", label: "Alice", type: .actor, isExplicit: true)),
            .actor(SequenceActor(id: "bob", label: "Bob", type: .participant, isExplicit: true)),
        ])))
        let out = try D2Exporter().export(doc)
        #expect(out.source.contains("shape: sequence_diagram"))
        #expect(out.source.contains("alice: \"Alice\""))
        #expect(out.source.contains("bob: \"Bob\""))
        #expect(out.source.contains("# diagramkit:seq-actor-kind=alice,actor"))
        #expect(out.source.contains("alice.shape: person"))
    }

    @Test("Emits messages with -> / --> / <-> arrows + seq-arrow-type markers")
    func emitsMessages() throws {
        let doc = DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: [
            .actor(SequenceActor(id: "alice", label: "Alice")),
            .actor(SequenceActor(id: "bob", label: "Bob")),
            .message(SequenceMessage(from: "alice", to: "bob", label: "Hello", arrowType: .solid)),
            .message(SequenceMessage(from: "bob", to: "alice", label: "Hi", arrowType: .dotted)),
            .message(SequenceMessage(from: "alice", to: "bob", label: "Sync", arrowType: .bidirectionalSolid)),
        ])))
        let out = try D2Exporter().export(doc)
        #expect(out.source.contains("alice -> bob: \"Hello\""))
        #expect(out.source.contains("bob --> alice: \"Hi\""))
        #expect(out.source.contains("alice <-> bob: \"Sync\""))
        #expect(out.source.contains("# diagramkit:seq-arrow-type=0,0"))
        #expect(out.source.contains("# diagramkit:seq-arrow-type=1,1"))
        #expect(out.source.contains("# diagramkit:seq-arrow-type=2,33"))
    }

    @Test("Round-trip through D2Importer reproduces actors + messages")
    func minimalRoundTrip() throws {
        let original = DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: [
            .actor(SequenceActor(id: "alice", label: "Alice", type: .actor)),
            .actor(SequenceActor(id: "bob", label: "Bob", type: .participant)),
            .message(SequenceMessage(from: "alice", to: "bob", label: "Hello", arrowType: .solid)),
        ])))
        let exported = try D2Exporter().export(original)
        let reimported = try D2Importer().parse(exported.source)
        guard case .sequenceDiagram(let seq) = reimported.document.payload else {
            Issue.record("re-imported is not sequence"); return
        }
        #expect(seq.actors.map(\.id) == ["alice", "bob"])
        #expect(seq.actors.first?.type == .actor)
        #expect(seq.messages.first?.label == "Hello")
    }

    @Test("D2Exporter.supportedDiagramTypes now contains .sequenceDiagram")
    func exporterAdvertisesSequence() {
        #expect(D2Exporter().supportedDiagramTypes.contains(.sequenceDiagram))
    }
}

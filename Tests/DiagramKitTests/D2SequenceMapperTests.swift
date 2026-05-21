import Testing
import DiagramKitImport
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2SequenceMapper")
struct D2SequenceMapperTests {

    @Test("Parses participants from top-level node definitions")
    func parsesParticipants() throws {
        let source = """
        shape: sequence_diagram
        alice: Alice
        bob: Bob
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("expected .sequenceDiagram, got \(result.document.payload)"); return
        }
        #expect(seq.actors.map(\.id) == ["alice", "bob"])
        #expect(seq.actors.map(\.label) == ["Alice", "Bob"])
        #expect(seq.actors.allSatisfy { $0.type == .participant })
    }

    @Test("Parses messages from top-level edges")
    func parsesMessages() throws {
        let source = """
        shape: sequence_diagram
        alice -> bob: Hello
        bob -> alice: Hi back
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not a sequence diagram"); return
        }
        #expect(seq.messages.count == 2)
        #expect(seq.messages[0].from == "alice")
        #expect(seq.messages[0].to == "bob")
        #expect(seq.messages[0].label == "Hello")
        #expect(seq.messages[0].arrowType == .solid)
        #expect(seq.messages[1].from == "bob")
        #expect(seq.messages[1].to == "alice")
    }

    @Test("Bidirectional edges map to .bidirectionalSolid")
    func parsesBidirectional() throws {
        let source = """
        shape: sequence_diagram
        alice <-> bob: Sync
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        #expect(seq.messages.first?.arrowType == .bidirectionalSolid)
    }

    @Test("D2Importer.supportedDiagramTypes now contains .sequenceDiagram")
    func importerAdvertisesSequence() {
        #expect(D2Importer().supportedDiagramTypes.contains(.sequenceDiagram))
    }

    @Test("Self-message preserved")
    func selfMessage() throws {
        let source = """
        shape: sequence_diagram
        alice -> alice: thinking
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        #expect(seq.messages.first?.from == "alice")
        #expect(seq.messages.first?.to == "alice")
    }
}

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

    @Test("Container with alt_<n> label produces a SequenceBlock of type 'alt'")
    func altBlockInferredFromLabel() throws {
        let source = """
        shape: sequence_diagram
        alice -> bob: ask
        alt_1: {
          bob -> alice: yes
        }
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        let block = try #require(seq.blocks.first)
        #expect(block.type == "alt")
        #expect(block.startItemIndex < block.endItemIndex)
    }

    @Test("Container without recognizable prefix defaults to 'opt' with styleDrop diagnostic")
    func unrecognizedBlockDefaultsToOpt() throws {
        let source = """
        shape: sequence_diagram
        alice -> bob: ask
        fancy_thing: {
          bob -> alice: yes
        }
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        let block = try #require(seq.blocks.first)
        #expect(block.type == "opt")
        let downgraded = result.diagnostics.contains {
            $0.severity == .warning && $0.category == .styleDrop
        }
        #expect(downgraded)
    }

    @Test("seq-block-type marker overrides label-prefix inference")
    func blockTypeMarkerWins() throws {
        let source = """
        # diagramkit:seq-block-type=fancy_thing,critical
        shape: sequence_diagram
        alice -> bob: ask
        fancy_thing: {
          bob -> alice: yes
        }
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        #expect(seq.blocks.first?.type == "critical")
    }

    @Test("Container with shape: sequence_diagram becomes a SequenceBox")
    func nestedSequenceDiagramBecomesBox() throws {
        let source = """
        # diagramkit:seq-box=customerBox,#ECECFF,true,Customer side
        shape: sequence_diagram
        customerBox: Customer side {
          shape: sequence_diagram
          alice: Alice
        }
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        let box = try #require(seq.boxes.first)
        #expect(box.name == "Customer side")
        #expect(box.fill == "#ECECFF")
        #expect(box.wrap == true)
        #expect(box.actorIds == ["alice"])
    }

    @Test("Block divider recovered from marker")
    func blockDividerRecovered() throws {
        let source = """
        # diagramkit:seq-block-divider=alt_1,1,no path
        shape: sequence_diagram
        alice -> bob: ask
        alt_1: {
          bob -> alice: yes
          bob -> alice: no
        }
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        let block = try #require(seq.blocks.first)
        #expect(block.dividers.first?.label == "no path")
    }

    @Test("seq-note marker creates a SequenceNote at the right position")
    func noteFromMarker() throws {
        let source = """
        # diagramkit:seq-note=0,right of,bob,Thinking...
        shape: sequence_diagram
        alice -> bob: ping
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        let note = try #require(seq.notes.first)
        #expect(note.position == "right of")
        #expect(note.actorIds == ["bob"])
        #expect(note.text == "Thinking...")
    }

    @Test("seq-message-attr=<n>,activate sets activate flag")
    func activateFromMarker() throws {
        let source = """
        # diagramkit:seq-message-attr=0,activate
        shape: sequence_diagram
        alice -> bob: ping
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        #expect(seq.messages.first?.activate == true)
    }

    @Test("seq-autonumber recovers (start, step, visible)")
    func autonumberMarker() throws {
        let source = """
        # diagramkit:seq-autonumber=5.0,10.0,true
        shape: sequence_diagram
        alice -> bob: ping
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        #expect(seq.autonumberEnabled == true)
        #expect(seq.autonumberStart == 5.0)
        #expect(seq.autonumberStep == 10.0)
    }

    @Test("seq-title / seq-acc-title / seq-acc-descr recovered onto SequenceDiagram")
    func titleMarkers() throws {
        let source = """
        # diagramkit:seq-title=Login flow
        # diagramkit:seq-acc-title=Login
        # diagramkit:seq-acc-descr=Validates OAuth
        shape: sequence_diagram
        alice -> bob: auth
        """
        let result = try D2Importer().parse(source)
        guard case .sequenceDiagram(let seq) = result.document.payload else {
            Issue.record("not sequence"); return
        }
        #expect(seq.title == "Login flow")
        #expect(seq.accTitle == "Login")
        #expect(seq.accDescr == "Validates OAuth")
    }
}

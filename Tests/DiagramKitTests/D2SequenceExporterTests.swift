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
        // Dotted arrow uses `->` token (D2 has no `-->`); seq-arrow-type marker carries the truth.
        #expect(out.source.contains("bob -> alice: \"Hi\""))
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

    @Test("Block start/end emits container with seq-block-type marker")
    func emitsBlockContainer() throws {
        let doc = DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: [
            .actor(SequenceActor(id: "alice", label: "Alice")),
            .actor(SequenceActor(id: "bob", label: "Bob")),
            .message(SequenceMessage(from: "alice", to: "bob", label: "ask")),
            .blockStart(type: "alt", label: "alt_1"),
            .message(SequenceMessage(from: "bob", to: "alice", label: "yes")),
            .blockDivider(type: "alt", label: "no path"),
            .message(SequenceMessage(from: "bob", to: "alice", label: "no")),
            .blockEnd(type: "alt"),
        ])))
        let out = try D2Exporter().export(doc)
        #expect(out.source.contains("alt_1: {"))
        #expect(out.source.contains("# diagramkit:seq-block-type=alt_1,alt"))
        #expect(out.source.contains("# diagramkit:seq-block-divider=alt_1,1,no path"))
    }

    @Test("Box start/end emits nested shape: sequence_diagram container with seq-box marker")
    func emitsBoxContainer() throws {
        let doc = DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: [
            .boxStart(fill: "#ECECFF", title: "Customer side", wrap: true),
            .actor(SequenceActor(id: "alice", label: "Alice")),
            .boxEnd,
        ])))
        let out = try D2Exporter().export(doc)
        #expect(out.source.contains("# diagramkit:seq-box="))
        // Outer dispatch + inner box marker both emit "shape: sequence_diagram"
        let occurrences = out.source.components(separatedBy: "shape: sequence_diagram").count - 1
        #expect(occurrences >= 2)
    }

    @Test("activation/deactivation lifted into seq-message-attr on adjacent message")
    func liftsActivations() throws {
        let doc = DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: [
            .actor(SequenceActor(id: "alice", label: "Alice")),
            .actor(SequenceActor(id: "bob", label: "Bob")),
            .activationStart(actorId: "bob"),
            .message(SequenceMessage(from: "alice", to: "bob", label: "ping")),
            .activationEnd(actorId: "bob"),
        ])))
        let out = try D2Exporter().export(doc)
        #expect(out.source.contains("# diagramkit:seq-message-attr=0,activate"))
        #expect(out.source.contains("# diagramkit:seq-message-attr=0,deactivate"))
    }

    @Test("Note emitted as comment + seq-note marker referencing afterMessageIndex")
    func notesEmitted() throws {
        let doc = DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: [
            .actor(SequenceActor(id: "alice", label: "Alice")),
            .actor(SequenceActor(id: "bob", label: "Bob")),
            .message(SequenceMessage(from: "alice", to: "bob", label: "ping")),
            .note(SequenceNote(actorIds: ["bob"], text: "Thinking...", position: "right of")),
        ])))
        let out = try D2Exporter().export(doc)
        #expect(out.source.contains("# diagramkit:seq-note=0,right of,bob,Thinking..."))
        #expect(out.source.contains("# Note (right of bob): Thinking..."))
    }

    @Test("Note round-trips through importer")
    func noteRoundTrip() throws {
        let original = DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: [
            .actor(SequenceActor(id: "alice", label: "Alice")),
            .actor(SequenceActor(id: "bob", label: "Bob")),
            .message(SequenceMessage(from: "alice", to: "bob", label: "ping")),
            .note(SequenceNote(actorIds: ["bob"], text: "Thinking...", position: "right of")),
        ])))
        let exported = try D2Exporter().export(original)
        let reimported = try D2Importer().parse(exported.source)
        guard case .sequenceDiagram(let seq) = reimported.document.payload else {
            Issue.record("not sequence"); return
        }
        let note = try #require(seq.notes.first)
        #expect(note.actorIds == ["bob"])
        #expect(note.position == "right of")
        #expect(note.text == "Thinking...")
    }

    @Test(".link / .properties / .details items dropped with featureDropped diagnostic")
    func metadataDropped() throws {
        let doc = DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: [
            .actor(SequenceActor(id: "alice", label: "Alice")),
            .link("alice", label: "docs", url: "https://example.com"),
            .properties("alice", json: "{\"role\":\"admin\"}"),
            .details("alice", elementId: "elem1"),
        ])))
        let out = try D2Exporter().export(doc)
        let dropped = out.diagnostics.filter {
            $0.severity == .unsupported && $0.category == .slotUnsupported
        }
        #expect(dropped.count == 3)
    }

    @Test("Full block/divider round-trip preserves type, label, and divider")
    func blockBoxRoundTrip() throws {
        let original = DiagramDocument(payload: .sequenceDiagram(SequenceDiagram(items: [
            .actor(SequenceActor(id: "alice", label: "Alice")),
            .actor(SequenceActor(id: "bob", label: "Bob")),
            .message(SequenceMessage(from: "alice", to: "bob", label: "ask")),
            .blockStart(type: "alt", label: "alt_1"),
            .message(SequenceMessage(from: "bob", to: "alice", label: "yes")),
            .blockDivider(type: "alt", label: "no path"),
            .message(SequenceMessage(from: "bob", to: "alice", label: "no")),
            .blockEnd(type: "alt"),
        ])))
        let exported = try D2Exporter().export(original)
        let reimported = try D2Importer().parse(exported.source)
        guard case .sequenceDiagram(let seq) = reimported.document.payload else {
            Issue.record("not sequence"); return
        }
        let block = try #require(seq.blocks.first)
        #expect(block.type == "alt")
        #expect(block.label == "alt_1")
        #expect(block.dividers.first?.label == "no path")
    }
}

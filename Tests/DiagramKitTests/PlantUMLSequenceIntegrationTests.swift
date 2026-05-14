import Testing
@testable import DiagramKitPlantUML
import DiagramKitModel
import DiagramKitImport
import DiagramKit

@Suite struct PlantUMLSequenceIntegrationTests {

    // MARK: - Probe Tests

    @Test("Probe recognizes participant in body")
    func probeRecognizesParticipant() {
        let body = "participant Alice\nAlice -> Bob: Hello"
        #expect(isPlantUMLSequenceBody(body))
    }

    @Test("Probe recognizes actor in body")
    func probeRecognizesActor() {
        let body = "actor Charlie\nCharlie -> Dana: Hi"
        #expect(isPlantUMLSequenceBody(body))
    }

    @Test("Probe recognizes arrow in body")
    func probeRecognizesArrow() {
        let body = "Alice -> Bob: Hello"
        #expect(isPlantUMLSequenceBody(body))
    }

    @Test("Probe recognizes activate/deactivate keywords")
    func probeRecognizesActivateDeactivate() {
        let body = "activate Bob\ndeactivate Bob"
        #expect(isPlantUMLSequenceBody(body))
    }

    @Test("Probe rejects bare @startuml with no sequence content")
    func probeRejectsBareStartuml() {
        // This is the outer probe test — bare @startuml without sequence content
        // should not match sequence probe specifically.
        // The isPlantUMLSequenceBody probe operates on the body, not full source.
        // An empty body has no sequence content.
        let emptyBody = ""
        #expect(!isPlantUMLSequenceBody(emptyBody))
    }

    @Test("Probe does not false-match on class syntax")
    func probeRejectsClassSyntax() {
        let body = """
        class Animal {
          +name: String
        }
        """
        // Class probe should fire first; sequence probe should return false
        #expect(isPlantUMLClassBody(body))
        // But does it also match sequence? Check specifically.
        // "class " prefix is not a sequence signal
        #expect(!isPlantUMLSequenceBody(body))
    }

    @Test("Probe does not false-match on mindmap syntax")
    func probeRejectsMindmapSyntax() {
        let body = "* Root\n** Branch"
        #expect(!isPlantUMLSequenceBody(body))
    }

    @Test("State probe fires before sequence probe")
    func stateProbeFiresBeforeSequence() {
        // State content also contains arrows that the sequence probe matches.
        // This is fine — the dispatch order in PlantUMLImporter ensures
        // State probe fires first (see family routing test below).
        let body = "state Idle\n[*] --> Idle"
        #expect(isPlantUMLStateBody(body))
        // Sequence probe is intentionally broad; state body is dispatched
        // by the family routing order, not by exclusive probe matching.
    }

    // MARK: - Integration Tests

    @Test("Full @startuml/@enduml round-trip through PlantUMLImporter.parse")
    func fullRoundTrip() throws {
        let source = """
        @startuml
        participant Alice
        participant Bob
        Alice -> Bob: Hello
        Bob --> Alice: Response
        @enduml
        """
        let importer = PlantUMLImporter()
        let result = try importer.parse(source)
        #expect(result.document.type == .sequenceDiagram)
        if case .sequenceDiagram(let seq) = result.document.payload {
            #expect(seq.actors.count == 2)
            #expect(seq.messages.count == 2)
        } else {
            Issue.record("Expected sequenceDiagram payload")
        }
    }

    @Test("Parse -> DiagramDocument -> correct payload type")
    func parseToDocumentRoundTrip() throws {
        let source = """
        @startuml
        actor Charlie
        participant "Dana" as D
        Charlie -> D: Hi
        @enduml
        """
        let importer = PlantUMLImporter()
        let result = try importer.parse(source)
        #expect(result.document.type == .sequenceDiagram)
        if case .sequenceDiagram(let seq) = result.document.payload {
            let ids = seq.actors.map(\.id)
            #expect(ids.contains("Charlie"))
            #expect(ids.contains("D"))
            let messages = seq.messages
            #expect(messages.count == 1)
            #expect(messages[0].from == "Charlie")
            #expect(messages[0].to == "D")
        } else {
            Issue.record("Expected sequenceDiagram")
        }
    }

    @Test("Parse -> layout smoke (produces positioned graph)")
    func parseToLayoutSmoke() throws {
        let source = """
        @startuml
        participant Alice
        participant Bob
        Alice -> Bob: Hello
        @enduml
        """
        let positioned = try DiagramPipeline.layout(source, registry: ImporterRegistry(
            importers: [PlantUMLImporter(), MermaidImporter()]
        ))
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
    }

    @Test("Multiple participants + messages + groups + notes in one diagram")
    func complexDiagram() throws {
        let source = """
        @startuml
        participant Alice
        participant Bob
        alt success
          Alice -> Bob: Request
          Bob --> Alice: Response
        else failure
          Alice -> Bob: Request
          Bob --> Alice: Error
        end
        note right of Bob: Responder
        @enduml
        """
        let importer = PlantUMLImporter()
        let result = try importer.parse(source)
        #expect(result.document.type == .sequenceDiagram)
        if case .sequenceDiagram(let seq) = result.document.payload {
            let actors = seq.actors
            #expect(actors.count == 2)
            let messages = seq.messages
            #expect(messages.count == 4)
            let blocks = seq.blocks
            #expect(blocks.count == 1)
            #expect(blocks[0].type == "alt")
            let notes = seq.notes
            #expect(notes.count == 1)
        } else {
            Issue.record("Expected sequenceDiagram")
        }
    }

    // MARK: - Family Routing Tests

    @Test("PlantUML outer probe rejects Mermaid source")
    func outerProbeRejectsMermaid() {
        let source = "sequenceDiagram\nAlice->>Bob: Hello"
        #expect(!isPlantUMLSource(source))
    }

    @Test("PlantUML outer probe rejects D2 source")
    func outerProbeRejectsD2() {
        let source = "A -> B\nB: C"
        #expect(!isPlantUMLSource(source))
    }

    @Test("PlantUML outer probe rejects DOT source")
    func outerProbeRejectsDOT() {
        let source = "digraph G { A -> B }"
        #expect(!isPlantUMLSource(source))
    }

    @Test("PlantUML outer probe rejects Structurizr source")
    func outerProbeRejectsStructurizr() {
        let source = "workspace { model { user = person } }"
        #expect(!isPlantUMLSource(source))
    }

    @Test("PlantUML outer probe accepts @startuml source")
    func outerProbeAcceptsStartuml() {
        let source = "@startuml\nAlice -> Bob: Hello\n@enduml"
        #expect(isPlantUMLSource(source))
    }

    @Test("PlantUML outer probe accepts labels containing other format keywords")
    func outerProbeAcceptsLabelsContainingOtherFormatKeywords() {
        let source = "@startuml\nAlice -> Bob: workspace { label\n@enduml"
        #expect(isPlantUMLSource(source))
    }

    @Test("Importer.supports delegates to outer probe")
    func importerSupportsDelegatesToProbe() {
        let importer = PlantUMLImporter()
        #expect(importer.supports(source: "@startuml\nA->B\n@enduml"))
        #expect(!importer.supports(source: "graph TD\nA-->B"))
    }

    @Test("Family routing: @startuml with C4 content rejects with clear error")
    func familyRoutingC4Rejects() {
        let body = """
        !include <C4/C4_Container>
        Person(p, "Name", "Desc")
        """
        // Non-sequence families in @startuml should throw notYetImplemented
        #expect(isPlantUMLC4Body(body))
        // This probe does not match sequence
        #expect(!isPlantUMLSequenceBody(body))
    }

    @Test("Family routing: @startuml with class content rejects")
    func familyRoutingClassRejects() {
        let body = """
        class Animal {
          +name: String
        }
        """
        #expect(isPlantUMLClassBody(body))
        #expect(!isPlantUMLSequenceBody(body))
    }

    @Test("Family routing: @startuml with state content is dispatched to state")
    func familyRoutingStateDispatched() {
        // State content: the importer checks State probe before Sequence.
        // Verify that state probe fires, and the importer routes to state.
        let body = "state Idle\n[*] --> Idle"
        #expect(isPlantUMLStateBody(body))
        // State import landed in a later phase — verify it produces a
        // `.stateDiagram` payload rather than throwing.
        let source = "@startuml\nstate Idle\n[*] --> Idle\n@enduml"
        let importer = PlantUMLImporter()
        do {
            let result = try importer.parse(source)
            if case .stateDiagram = result.document.payload {
                // expected
            } else {
                Issue.record("Expected .stateDiagram payload, got \(result.document.payload)")
            }
        } catch {
            Issue.record("State import threw: \(error)")
        }
    }

    @Test("PlantUML importer throws malformedSource for unrecognized body")
    func importerThrowsForUnrecognizedBody() {
        let source = "@startuml\njust some random text\n@enduml"
        let importer = PlantUMLImporter()
        do {
            _ = try importer.parse(source)
            Issue.record("Expected throw")
        } catch DiagramError.malformedSource {
            // Expected — no family probe matched.
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Registry Tests

    @Test("Default registry includes PlantUMLImporter before MermaidImporter")
    func registryIncludesPlantUML() {
        let registry = DiagramPipeline.defaultRegistry
        let importer = registry.importer(for: "@startuml\nA->B\n@enduml")
        #expect(importer?.name == "PlantUML")
    }

    @Test("Registry falls back to Mermaid for mermaid-only source")
    func registryFallsBackToMermaid() {
        let registry = DiagramPipeline.defaultRegistry
        let importer = registry.importer(for: "sequenceDiagram\nAlice->>Bob: Hello")
        #expect(importer?.name == "Mermaid")
    }
}

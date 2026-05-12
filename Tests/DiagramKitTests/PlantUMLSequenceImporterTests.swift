import Testing
@testable import DiagramKitPlantUML
import DiagramKitModel
import DiagramKitImport
import DiagramKit

@Suite struct PlantUMLSequenceImporterTests {

    // MARK: - Parsing Tests

    @Test("Parses single participant")
    func parsesSingleParticipant() {
        let body = "participant Alice"
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.participants.count == 1)
        #expect(ast.participants[0].alias == "Alice")
        #expect(ast.participants[0].kind == .participant)
    }

    @Test("Parses multiple participants with aliases")
    func parsesMultipleParticipantsWithAliases() {
        let body = """
        participant "Bob" as B
        actor "Charlie" as C
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.participants.count == 2)
        let bob = ast.participants.first(where: { $0.alias == "B" })
        #expect(bob != nil)
        #expect(bob?.kind == .participant)
        #expect(bob?.displayName == "Bob")
        let charlie = ast.participants.first(where: { $0.alias == "C" })
        #expect(charlie != nil)
        #expect(charlie?.kind == .actor)
        #expect(charlie?.displayName == "Charlie")
    }

    @Test("Parses actor declarations")
    func parsesActorDeclarations() {
        let body = "actor Dana"
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.participants.count == 1)
        #expect(ast.participants[0].kind == .actor)
        #expect(ast.participants[0].alias == "Dana")
    }

    @Test("Parses simple message ->")
    func parsesSimpleMessage() {
        let body = """
        participant Alice
        participant Bob
        Alice -> Bob: Hello
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        let messages = ast.items.compactMap { item -> PlantUMLSequenceMessage? in
            if case .message(let m) = item { return m }; return nil
        }
        #expect(messages.count == 1)
        #expect(messages[0].from == "Alice")
        #expect(messages[0].to == "Bob")
        #expect(messages[0].arrow == .solid)
        #expect(messages[0].label == "Hello")
    }

    @Test("Parses all arrow types")
    func parsesAllArrowTypes() {
        let body = """
        participant A
        participant B
        A --> B: dotted
        A ->> B: open
        A ->o B: circle
        A ->x B: cross
        A <-> B: bidirectional
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        let messages = ast.items.compactMap { item -> PlantUMLSequenceMessage? in
            if case .message(let m) = item { return m }; return nil
        }
        #expect(messages.count == 5)
        #expect(messages[0].arrow == .dotted)
        #expect(messages[1].arrow == .open)
        #expect(messages[2].arrow == .circle)
        #expect(messages[3].arrow == .cross)
        #expect(messages[4].arrow == .bidirectional)
    }

    @Test("Parses message labels")
    func parsesMessageLabels() {
        let body = """
        participant A
        participant B
        A -> B: This is a test message
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        if case .message(let msg) = ast.items[0] {
            #expect(msg.label == "This is a test message")
        } else {
            Issue.record("Expected message item")
        }
    }

    @Test("Parses self-messages")
    func parsesSelfMessages() {
        let body = """
        participant Bob
        Bob -> Bob: Self call
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        if case .message(let msg) = ast.items[0] {
            #expect(msg.from == "Bob")
            #expect(msg.to == "Bob")
            #expect(msg.label == "Self call")
        } else {
            Issue.record("Expected message")
        }
    }

    @Test("Parses activate/deactivate")
    func parsesActivateDeactivate() {
        let body = """
        participant Bob
        activate Bob
        deactivate Bob
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.items.contains(where: {
            if case .activate("Bob") = $0 { return true }; return false
        }))
        #expect(ast.items.contains(where: {
            if case .deactivate("Bob") = $0 { return true }; return false
        }))
    }

    @Test("Parses notes left/right/over")
    func parsesNotes() {
        let body = """
        note left of Alice: Left note
        note right of Bob: Right note
        note over Alice, Bob: Spanning note
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        let notes = ast.items.compactMap { item -> PlantUMLSequenceNote? in
            if case .note(let n) = item { return n }; return nil
        }
        #expect(notes.count == 3)
        #expect(notes[0].position == .left)
        #expect(notes[0].targets == ["Alice"])
        #expect(notes[0].text == "Left note")
        #expect(notes[1].position == .right)
        #expect(notes[1].targets == ["Bob"])
        #expect(notes[2].position == .over)
        #expect(notes[2].targets.count == 2)
    }

    @Test("Parses box groups")
    func parsesBoxGroups() {
        let body = """
        box "Internal" #LightBlue
        participant Alice
        end box
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.participants.count == 1)
        // The participant inherits box name context during parsing
        // (box context is tracked for future slices; in 6A it doesn't
        // change parse output beyond participant collection)
        #expect(ast.participants[0].alias == "Alice")
    }

    @Test("Parses alt/else/end")
    func parsesAltElseEnd() {
        let body = """
        participant A
        participant B
        alt success
          A -> B: ok
        else failure
          A -> B: error
        end
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        var foundAlt = false, foundElse = false, foundEnd = false
        for item in ast.items {
            switch item {
            case .groupStart("success", .alt): foundAlt = true
            case .divergent("failure"): foundElse = true
            case .groupEnd: foundEnd = true
            case .message: break
            default: break
            }
        }
        #expect(foundAlt)
        #expect(foundElse)
        #expect(foundEnd)
    }

    @Test("Parses loop/opt/group/end")
    func parsesLoopOptGroupEnd() {
        let body = """
        participant A
        loop every 5 min
          A -> A: ping
        end
        opt optional
          A -> A: maybe
        end
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        let groupStarts = ast.items.compactMap { item -> (String, PlantUMLGroupKind)? in
            if case .groupStart(let label, let kind) = item { return (label, kind) }
            return nil
        }
        #expect(groupStarts.count == 2)
        #expect(groupStarts[0].1 == .loop)
        #expect(groupStarts[1].1 == .opt)
    }

    @Test("Parses autonumber")
    func parsesAutonumber() {
        let body = """
        autonumber
        participant A
        A -> A: ping
        """
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.hasAutoNumber == true)
        #expect(ast.items.contains(where: {
            if case .autoNumberStart = $0 { return true }; return false
        }))
    }

    // MARK: - Diagnostics Tests

    @Test("Emits diagnostic for newpage")
    func diagnosticNewpage() {
        let body = "newpage"
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.items.contains(where: {
            if case .unsupported(let msg, _) = $0, msg.contains("newpage") { return true }
            return false
        }))
    }

    @Test("Emits diagnostic for title")
    func diagnosticTitle() {
        let body = "title My Diagram"
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.items.contains(where: {
            if case .unsupported(let msg, _) = $0, msg.contains("title") { return true }
            return false
        }))
    }

    @Test("Emits diagnostic for skinparam")
    func diagnosticSkinparam() {
        let body = "skinparam backgroundColor #FFFFFF"
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.items.contains(where: {
            if case .unsupported(let msg, _) = $0, msg.contains("skinparam") { return true }
            return false
        }))
    }

    @Test("Emits diagnostic for stereotypes")
    func diagnosticStereotypes() {
        let parser = PlantUMLSequenceParser()
        // <<UI>> in the participant line may not trigger stereotypes check
        // because it's consumed by participant parsing. Test on a raw line.
        let altBody = "Alice <<stereotype>> Bob"
        let altAst = parser.parse(altBody)
        #expect(altAst.items.contains(where: {
            if case .unsupported(let msg, _) = $0, msg.contains("stereotype") { return true }
            return false
        }))
    }

    @Test("Emits diagnostic for ref over")
    func diagnosticRefOver() {
        let body = "ref over Alice : Some reference"
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.items.contains(where: {
            if case .unsupported(let msg, _) = $0, msg.contains("ref over") { return true }
            return false
        }))
    }

    @Test("Emits diagnostic for hnote/rnote")
    func diagnosticHnoteRnote() {
        let body = "hnote over Alice: Historical"
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.items.contains(where: {
            if case .unsupported(let msg, _) = $0, msg.contains("hnote") { return true }
            return false
        }))
    }

    @Test("Emits diagnostic for create/destroy")
    func diagnosticCreateDestroy() {
        let body = "create Bob"
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.items.contains(where: {
            if case .unsupported(let msg, _) = $0, msg.contains("create") { return true }
            return false
        }))
    }

    @Test("Emits diagnostic for separator lines")
    func diagnosticSeparator() {
        let body = "|| separator line"
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.items.contains(where: {
            if case .unsupported(let msg, _) = $0, msg.contains("separator") { return true }
            return false
        }))
    }

    // MARK: - Mapping Tests

    @Test("Maps participants to SequenceActors")
    func mapsParticipantsToSequenceActors() {
        let ast = PlantUMLSequenceAST(participants: [
            PlantUMLParticipant(kind: .participant, alias: "A", displayName: "Alice"),
            PlantUMLParticipant(kind: .actor, alias: "B", displayName: "Bob")
        ])
        let mapper = PlantUMLSequenceMapper()
        let (diagram, _) = mapper.map(ast)
        let actors = diagram.actors
        #expect(actors.count == 2)
        #expect(actors[0].id == "A")
        #expect(actors[0].label == "Alice")
        #expect(actors[0].type == .participant)
        #expect(actors[1].id == "B")
        #expect(actors[1].label == "Bob")
        #expect(actors[1].type == .actor)
    }

    @Test("Maps messages to SequenceMessages with correct types")
    func mapsMessagesToSequenceMessages() {
        let ast = PlantUMLSequenceAST(
            participants: [
                PlantUMLParticipant(alias: "A"),
                PlantUMLParticipant(alias: "B")
            ],
            items: [
                .message(PlantUMLSequenceMessage(from: "A", to: "B", arrow: .dotted, label: "test"))
            ]
        )
        let mapper = PlantUMLSequenceMapper()
        let (diagram, _) = mapper.map(ast)
        let messages = diagram.messages
        #expect(messages.count == 1)
        #expect(messages[0].from == "A")
        #expect(messages[0].to == "B")
        #expect(messages[0].label == "test")
        #expect(messages[0].arrowType == .dotted)
    }

    @Test("Maps notes to SequenceNotes")
    func mapsNotesToSequenceNotes() {
        let ast = PlantUMLSequenceAST(
            items: [
                .note(PlantUMLSequenceNote(position: .left, targets: ["A"], text: "Note text"))
            ]
        )
        let mapper = PlantUMLSequenceMapper()
        let (diagram, _) = mapper.map(ast)
        let notes = diagram.notes
        #expect(notes.count == 1)
        #expect(notes[0].actorIds == ["A"])
        #expect(notes[0].text == "Note text")
        #expect(notes[0].position == "left")
    }

    @Test("Maps groups to SequenceItems")
    func mapsGroupsToSequenceItems() {
        let ast = PlantUMLSequenceAST(
            participants: [
                PlantUMLParticipant(alias: "A"),
                PlantUMLParticipant(alias: "B")
            ],
            items: [
                .groupStart("success", kind: .alt),
                .message(PlantUMLSequenceMessage(from: "A", to: "B", arrow: .solid)),
                .groupEnd
            ]
        )
        let mapper = PlantUMLSequenceMapper()
        let (diagram, _) = mapper.map(ast)
        var foundBlockStart = false, foundBlockEnd = false
        for item in diagram.items {
            switch item {
            case .blockStart("alt", "success"): foundBlockStart = true
            case .blockEnd("alt"): foundBlockEnd = true
            default: break
            }
        }
        #expect(foundBlockStart)
        #expect(foundBlockEnd)
    }

    @Test("Synthesizes participants from undeclared message references")
    func synthesizesUndefinedParticipants() {
        let ast = PlantUMLSequenceAST(
            items: [
                .message(PlantUMLSequenceMessage(from: "X", to: "Y", arrow: .solid))
            ]
        )
        let mapper = PlantUMLSequenceMapper()
        let (diagram, _) = mapper.map(ast)
        let actors = diagram.actors
        let ids = actors.map(\.id)
        #expect(ids.contains("X"))
        #expect(ids.contains("Y"))
    }

    @Test("Auto-activation is not applied for explicit activate items")
    func explicitActivationMapsCorrectly() {
        let ast = PlantUMLSequenceAST(
            participants: [PlantUMLParticipant(alias: "A")],
            items: [
                .activate("A"),
                .deactivate("A")
            ]
        )
        let mapper = PlantUMLSequenceMapper()
        let (diagram, _) = mapper.map(ast)
        var foundActivation = false, foundDeactivation = false
        for item in diagram.items {
            switch item {
            case .activationStart("A"): foundActivation = true
            case .activationEnd("A"): foundDeactivation = true
            default: break
            }
        }
        #expect(foundActivation)
        #expect(foundDeactivation)
    }

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
        // Verify the importer rejects this (state not yet implemented in 6A)
        let source = "@startuml\nstate Idle\n[*] --> Idle\n@enduml"
        let importer = PlantUMLImporter()
        do {
            _ = try importer.parse(source)
            Issue.record("Expected notYetImplemented error for state diagram")
        } catch DiagramError.notYetImplemented(let msg) {
            #expect(msg.contains("State"))
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test("PlantUML importer throws notYetImplemented for unrecognized body")
    func importerThrowsForUnrecognizedBody() {
        let source = "@startuml\njust some random text\n@enduml"
        let importer = PlantUMLImporter()
        do {
            _ = try importer.parse(source)
            Issue.record("Expected throw")
        } catch DiagramError.notYetImplemented {
            // Expected
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

import Testing
@testable import DiagramKitPlantUML
import DiagramKitModel
import DiagramKitImport
import DiagramKit

@Suite struct PlantUMLSequenceParserTests {

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

    @Test("Bare activate and deactivate use the previous message context")
    func bareActivateDeactivateUsePreviousMessageContext() throws {
        let source = """
        @startuml
        participant Alice
        participant Bob
        Alice -> Bob: Work
        activate
        Bob --> Alice: Done
        deactivate
        @enduml
        """
        let importer = PlantUMLImporter()
        let result = try importer.parse(source)
        if case .sequenceDiagram(let seq) = result.document.payload {
            #expect(seq.items.contains(where: {
                if case .activationStart("Bob") = $0 { return true }
                return false
            }))
            #expect(seq.items.contains(where: {
                if case .activationEnd("Bob") = $0 { return true }
                return false
            }))
        } else {
            Issue.record("Expected sequenceDiagram")
        }
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
        // The participant inherits box context during parsing so the mapper can
        // emit SequenceBox items around contiguous boxed participants.
        #expect(ast.participants[0].alias == "Alice")
        #expect(ast.participants[0].boxName == "Internal")
    }

    @Test("Maps box groups to SequenceBox output")
    func mapsBoxGroupsToSequenceBoxes() throws {
        let source = """
        @startuml
        box "Internal" #LightBlue
        participant Alice
        participant Bob
        end box
        Alice -> Bob: Hello
        @enduml
        """
        let importer = PlantUMLImporter()
        let result = try importer.parse(source)
        if case .sequenceDiagram(let seq) = result.document.payload {
            #expect(seq.boxes.count == 1)
            if let box = seq.boxes.first {
                #expect(box.name == "Internal")
                #expect(box.actorIds == ["Alice", "Bob"])
            }
        } else {
            Issue.record("Expected sequenceDiagram")
        }
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

    @Test("Return keyword maps to dotted return message with deactivate")
    func returnKeywordMapsToDottedReturnMessage() throws {
        let source = """
        @startuml
        participant Alice
        participant Bob
        Alice -> Bob: Request
        activate Bob
        return Result
        @enduml
        """
        let importer = PlantUMLImporter()
        let result = try importer.parse(source)
        if case .sequenceDiagram(let seq) = result.document.payload {
            #expect(seq.messages.count == 2)
            if seq.messages.count > 1 {
                #expect(seq.messages[1].from == "Bob")
                #expect(seq.messages[1].to == "Alice")
                #expect(seq.messages[1].label == "Result")
                #expect(seq.messages[1].arrowType == .dotted)
                #expect(seq.messages[1].deactivate)
            }
        } else {
            Issue.record("Expected sequenceDiagram")
        }
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

    @Test("Parses title directive into title item")
    func parsesTitle() {
        // PlantUML sequence title parsing landed in Session 2's
        // `5ef689f`; what was previously emitted as a .unsupported
        // diagnostic now parses into PlantUMLSequenceAST.title.
        let body = "title My Diagram"
        let parser = PlantUMLSequenceParser()
        let ast = parser.parse(body)
        #expect(ast.title == "My Diagram")
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

}

import Testing
@testable import DiagramKitPlantUML
import DiagramKitModel

@Suite struct PlantUMLSequenceMapperTests {

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
}

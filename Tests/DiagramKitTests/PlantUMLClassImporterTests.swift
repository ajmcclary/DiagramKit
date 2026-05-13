import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitPlantUML

@Suite struct PlantUMLClassImporterTests {

    @Test("Parses simple class with fields and methods")
    func simpleClass() throws {
        let source = """
        @startuml
        class Person {
          +name: String
          +age: Int
          +greet(): Void
        }
        @enduml
        """

        let result = try PlantUMLImporter().parse(source)
        guard case .classDiagram(let model) = result.document.payload else {
            Issue.record("Expected classDiagram payload, got \(result.document.payload)")
            return
        }
        let person = model.classes.first(where: { $0.id == "Person" })
        #expect(person != nil)
        #expect(person?.attributes.count == 2)
        #expect(person?.methods.count == 1)
    }

    @Test("Parses interface declaration")
    func interfaceDeclaration() throws {
        let source = """
        @startuml
        interface Drawable {
          +draw(): Void
        }
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .classDiagram(let model) = result.document.payload else {
            Issue.record("Expected classDiagram payload"); return
        }
        let drawable = model.classes.first(where: { $0.id == "Drawable" })
        #expect(drawable != nil)
        #expect(drawable?.annotations.contains("Interface") == true)
    }

    @Test("Maps inheritance and composition relationships")
    func inheritanceAndComposition() throws {
        let source = """
        @startuml
        class Animal
        class Dog
        class Tail
        Animal <|-- Dog
        Dog *-- Tail
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .classDiagram(let model) = result.document.payload else {
            Issue.record("Expected classDiagram payload"); return
        }

        let inheritance = model.relationships.first { $0.id1 == "Animal" && $0.id2 == "Dog" }
        #expect(inheritance != nil)
        #expect(inheritance?.relation.type1 == ClassRelationType.inheritance.rawValue)
        #expect(inheritance?.relation.lineType == ClassLineType.solid.rawValue)

        let composition = model.relationships.first { $0.id1 == "Dog" && $0.id2 == "Tail" }
        #expect(composition != nil)
        #expect(composition?.relation.type1 == ClassRelationType.composition.rawValue)
        #expect(composition?.relation.lineType == ClassLineType.solid.rawValue)
    }

    @Test("Maps realization and dependency (dotted lines)")
    func realizationAndDependency() throws {
        let source = """
        @startuml
        interface I
        class A
        class B
        I <|.. A
        A ..> B
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .classDiagram(let model) = result.document.payload else {
            Issue.record("Expected classDiagram payload"); return
        }

        let realization = model.relationships.first { $0.id1 == "I" && $0.id2 == "A" }
        #expect(realization?.relation.type1 == ClassRelationType.inheritance.rawValue)
        #expect(realization?.relation.lineType == ClassLineType.dotted.rawValue)

        let dependency = model.relationships.first { $0.id1 == "A" && $0.id2 == "B" }
        #expect(dependency?.relation.type2 == ClassRelationType.dependency.rawValue)
        #expect(dependency?.relation.lineType == ClassLineType.dotted.rawValue)
    }

    @Test("Note attached to class")
    func noteAttached() throws {
        let source = """
        @startuml
        class A
        note right of A : This is a note
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .classDiagram(let model) = result.document.payload else {
            Issue.record("Expected classDiagram payload"); return
        }
        #expect(model.notes.contains(where: { $0.text.contains("This is a note") }))
    }
}

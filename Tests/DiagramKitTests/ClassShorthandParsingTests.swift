import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitModel

/// Class-diagram statement forms from the 2026-11-12 parser review that
/// were silently dropped or turned into a bogus class.
@Suite("Class diagram shorthand parsing")
struct ClassShorthandParsingTests {

    private static func classDiagram(_ source: String) async throws -> ClassDiagram {
        let document = try await DiagramEngine.parse(source)
        guard case .classDiagram(let diagram) = document.payload else {
            Issue.record("expected a class diagram")
            throw CancellationError()
        }
        return diagram
    }

    @Test("colon-form methods with no arguments are kept")
    func colonFormMethodsWithoutArguments() async throws {
        let diagram = try await Self.classDiagram("""
        classDiagram
            Animal <|-- Duck
            Animal : +int age
            Animal: +isMammal()
            Animal: +mate()
            Animal: +eat(food)
        """)
        let animal = try #require(diagram.classMap["Animal"])
        #expect(animal.attributes.map(\.id) == ["int age"])
        #expect(animal.methods.map(\.id) == ["isMammal", "mate", "eat"])
        #expect(diagram.relationships.count == 1)
    }

    @Test("relationships written without spaces are relationships")
    func unspacedRelationships() async throws {
        let diagram = try await Self.classDiagram("""
        classDiagram
            Customer-->Order : places
            Animal<|--Duck
            A-->B: uses
        """)
        #expect(diagram.classMap["Customer-->Order"] == nil)
        #expect(diagram.classMap["A-->B"] == nil)
        let pairs = diagram.relationships.map { "\($0.id1)->\($0.id2):\($0.title)" }
        #expect(pairs == ["Customer->Order:places", "Animal->Duck:", "A->B:uses"])
        #expect(Set(diagram.classes.map(\.id)) == ["Customer", "Order", "Animal", "Duck", "A", "B"])
        let inheritance = try #require(diagram.relationships.first { $0.id1 == "Animal" })
        #expect(inheritance.relation.type1 == ClassRelationType.inheritance.rawValue)
    }

    @Test("an unspaced relationship keeps its cardinalities and line style")
    func unspacedCardinalityAndDotted() async throws {
        let diagram = try await Self.classDiagram("""
        classDiagram
            C "1"-->"*" D
            Foo..>Bar
        """)
        let card = try #require(diagram.relationships.first { $0.id1 == "C" })
        #expect(card.id2 == "D")
        #expect(card.relationTitle1 == "1")
        #expect(card.relationTitle2 == "*")
        let dotted = try #require(diagram.relationships.first { $0.id1 == "Foo" })
        #expect(dotted.id2 == "Bar")
        #expect(dotted.relation.lineType == ClassLineType.dotted.rawValue)
    }

    @Test("a lollipop relationship is still a relationship")
    func lollipopStillParses() async throws {
        let diagram = try await Self.classDiagram("classDiagram\n    bar ()-- foo")
        #expect(diagram.relationships.count == 1)
        #expect(diagram.relationships.first?.relation.type1 == ClassRelationType.lollipop.rawValue)
    }
}

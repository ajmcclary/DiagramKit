import Testing
@testable import DiagramKitPlantUML
import DiagramKitModel

@Suite struct PlantUMLJSONMapperTests {
    @Test func mapsObjectToDirectoryWithStringKeys() throws {
        let value = PlantUMLJSONValue.object([
            .init(key: "a", value: .number("1")),
            .init(key: "b", value: .string("hello"))
        ])
        let (diagram, diagnostics) = PlantUMLJSONMapper().map(value)
        #expect(diagnostics.isEmpty)
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.id == 0)
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "a")
        #expect(diagram.root.children[0].id == 1)
        #expect(diagram.root.children[0].nodeType == .file)
        #expect(diagram.root.children[0].description == "1")
        #expect(diagram.root.children[1].name == "b")
        #expect(diagram.root.children[1].id == 2)
        #expect(diagram.root.children[1].description == "\"hello\"")
    }

    @Test func mapsArrayWithIndexedNames() {
        let value = PlantUMLJSONValue.array([.number("10"), .number("20")])
        let (diagram, _) = PlantUMLJSONMapper().map(value)
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "[0]")
        #expect(diagram.root.children[1].name == "[1]")
    }

    @Test func synthesizesRootForPrimitiveDocument() {
        let value = PlantUMLJSONValue.number("42")
        let (diagram, _) = PlantUMLJSONMapper().map(value)
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.name == "(root)")
        #expect(diagram.root.children.count == 1)
        #expect(diagram.root.children[0].description == "42")
    }

    @Test func encodesNullAndBoolLiterals() {
        let value = PlantUMLJSONValue.object([
            .init(key: "n", value: .null),
            .init(key: "b", value: .bool(true))
        ])
        let (diagram, _) = PlantUMLJSONMapper().map(value)
        #expect(diagram.root.children[0].description == "null")
        #expect(diagram.root.children[1].description == "true")
    }

    @Test func assignsDFSPreOrderIds() {
        let value = PlantUMLJSONValue.object([
            .init(key: "outer", value: .object([
                .init(key: "inner", value: .number("1"))
            ])),
            .init(key: "sibling", value: .number("2"))
        ])
        let (diagram, _) = PlantUMLJSONMapper().map(value)
        #expect(diagram.root.id == 0)
        #expect(diagram.root.children[0].id == 1)         // outer
        #expect(diagram.root.children[0].children[0].id == 2) // inner
        #expect(diagram.root.children[1].id == 3)         // sibling
    }
}

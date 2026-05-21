import Testing
@testable import DiagramKitPlantUML
import DiagramKitCommon
import DiagramKitModel

@Suite struct PlantUMLYAMLMapperTests {
    @Test func mapsMappingToDirectoryWithStringKeys() {
        let value = PlantUMLYAMLValue.mapping([
            .init(key: "a", value: .scalar("1")),
            .init(key: "b", value: .scalar("hello"))
        ])
        let (diagram, diagnostics) = PlantUMLYAMLMapper().map(
            PlantUMLYAMLParseResult(value: value, unsupportedFeatures: [])
        )
        #expect(diagnostics.isEmpty)
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "a")
        #expect(diagram.root.children[0].description == "1")
    }

    @Test func mapsSequenceWithIndexedNames() {
        let value = PlantUMLYAMLValue.sequence([.scalar("x"), .scalar("y")])
        let (diagram, _) = PlantUMLYAMLMapper().map(
            PlantUMLYAMLParseResult(value: value, unsupportedFeatures: [])
        )
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "[0]")
        #expect(diagram.root.children[1].name == "[1]")
    }

    @Test func synthesizesRootForScalarDocument() {
        let value = PlantUMLYAMLValue.scalar("just-a-scalar")
        let (diagram, _) = PlantUMLYAMLMapper().map(
            PlantUMLYAMLParseResult(value: value, unsupportedFeatures: [])
        )
        #expect(diagram.root.name == "(root)")
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.children.count == 1)
        #expect(diagram.root.children[0].description == "just-a-scalar")
    }

    @Test func surfacesUnsupportedFeaturesAsDiagnostics() {
        let value = PlantUMLYAMLValue.mapping([
            .init(key: "a", value: .scalar("1"))
        ])
        let (_, diagnostics) = PlantUMLYAMLMapper().map(
            PlantUMLYAMLParseResult(
                value: value,
                unsupportedFeatures: [
                    "YAML feature: anchor (&name)",
                    "YAML feature: flow style ({…}, […])"
                ]
            )
        )
        #expect(diagnostics.count == 2)
        for d in diagnostics {
            #expect(d.category == .slotUnsupported)
        }
    }

    @Test func assignsDFSPreOrderIds() {
        let value = PlantUMLYAMLValue.mapping([
            .init(key: "outer", value: .mapping([
                .init(key: "inner", value: .scalar("1"))
            ])),
            .init(key: "sibling", value: .scalar("2"))
        ])
        let (diagram, _) = PlantUMLYAMLMapper().map(
            PlantUMLYAMLParseResult(value: value, unsupportedFeatures: [])
        )
        #expect(diagram.root.id == 0)
        #expect(diagram.root.children[0].id == 1)
        #expect(diagram.root.children[0].children[0].id == 2)
        #expect(diagram.root.children[1].id == 3)
    }
}

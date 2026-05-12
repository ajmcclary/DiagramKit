import Testing
import DiagramKitStructurizr

@Suite struct StructurizrModelRegistryTests {

    @Test("lookup element by alias")
    func lookupElementByAlias() {
        let elements = [
            StructurizrModelElement(alias: "user", kind: .person, name: "User"),
            StructurizrModelElement(alias: "app", kind: .softwareSystem, name: "App")
        ]
        let registry = StructurizrModelRegistry(elements: elements)

        #expect(registry.element(for: "user")?.name == "User")
        #expect(registry.element(for: "app")?.name == "App")
    }

    @Test("lookup missing alias returns nil")
    func lookupMissingAliasReturnsNil() {
        let elements = [StructurizrModelElement(alias: "user", kind: .person, name: "User")]
        let registry = StructurizrModelRegistry(elements: elements)

        #expect(registry.element(for: "nonexistent") == nil)
    }

    @Test("collects nested children")
    func collectsNestedChildren() {
        let child = StructurizrModelElement(alias: "web", kind: .container, name: "Web", parentAlias: "app")
        let parent = StructurizrModelElement(
            alias: "app", kind: .softwareSystem, name: "App",
            children: [child]
        )
        let registry = StructurizrModelRegistry(elements: [parent])

        #expect(registry.element(for: "app") != nil)
        #expect(registry.element(for: "web") != nil)
    }

    @Test("topLevelElements excludes children")
    func topLevelElementsExcludesChildren() {
        let child = StructurizrModelElement(alias: "web", kind: .container, name: "Web", parentAlias: "app")
        let parent = StructurizrModelElement(
            alias: "app", kind: .softwareSystem, name: "App",
            children: [child]
        )
        let registry = StructurizrModelRegistry(elements: [parent])

        let topLevel = registry.topLevelElements
        #expect(topLevel.count == 1)
        #expect(topLevel[0].alias == "app")
    }

    @Test("connectedAliases finds both directions")
    func connectedAliasesFindsBothDirections() {
        let elements = [
            StructurizrModelElement(alias: "A", kind: .person, name: "A"),
            StructurizrModelElement(alias: "B", kind: .person, name: "B")
        ]
        let rels = [StructurizrRelationshipDef(source: "A", target: "B")]
        let registry = StructurizrModelRegistry(elements: elements, relationships: rels)

        #expect(registry.connectedAliases(to: "A").contains("B"))
        #expect(registry.connectedAliases(to: "B").contains("A"))
    }

    @Test("connectedAliases empty for isolated element")
    func connectedAliasesEmptyForIsolatedElement() {
        let elements = [
            StructurizrModelElement(alias: "A", kind: .person, name: "A"),
            StructurizrModelElement(alias: "B", kind: .person, name: "B")
        ]
        let registry = StructurizrModelRegistry(elements: elements)

        #expect(registry.connectedAliases(to: "A").isEmpty)
    }
}

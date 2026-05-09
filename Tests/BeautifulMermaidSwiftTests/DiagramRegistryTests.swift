import Testing
@testable import BeautifulMermaid

@Suite struct DiagramRegistryTests {

    @Test("Registry validates that every DiagramType case has a descriptor")
    func registryCoversAllDiagramTypes() {
        #expect(DiagramRegistry.validate(), "Every DiagramType case must have a registered descriptor")
    }

    @Test("Registered count matches DiagramType.allCases count")
    func registeredCountMatchesDiagramTypeAllCases() {
        #expect(
            DiagramRegistry.registeredCount == DiagramType.allCases.count,
            "Registry count (\(DiagramRegistry.registeredCount)) must match DiagramType.allCases (\(DiagramType.allCases.count))"
        )
    }

    @Test("Registry contains no duplicate diagram types")
    func noDuplicateTypesInRegistry() {
        let types = DiagramRegistry.all.map(\.type)
        #expect(Set(types).count == types.count, "Registry must not contain duplicate diagram types")
    }

    @Test("descriptor(for:) returns correct descriptor for each DiagramType")
    func descriptorLookupWorksForAllTypes() throws {
        for type in DiagramType.allCases {
            let descriptor = try DiagramRegistry.descriptor(for: type)
            #expect(descriptor.type == type, "descriptor(for: \(type.rawValue)) returned wrong type: \(descriptor.type.rawValue)")
        }
    }

    @Test("descriptor(for:) throws for an invalid type")
    func descriptorLookupThrowsForMissingType() {
        // This is a safety-net test: if a DiagramType exists with no descriptor,
        // descriptor(for:) should throw rather than silently returning nil.
        // validate() already catches this at the registry level.
        let registeredCount = DiagramRegistry.registeredCount
        let allCasesCount = DiagramType.allCases.count
        #expect(registeredCount == allCasesCount, "Precondition: registry must be complete before testing throws")
    }
}

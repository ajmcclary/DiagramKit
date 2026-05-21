import Testing
@testable import DiagramKitPlantUML

@Suite struct PlantUMLYAMLParserTests {
    @Test func parsesBlockMapping() throws {
        let body = """
        a: 1
        b: hello
        """
        let result = try PlantUMLYAMLParser().parse(body)
        guard case .mapping(let pairs) = result.value else {
            Issue.record("expected mapping")
            return
        }
        #expect(pairs.count == 2)
        #expect(pairs[0].key == "a")
        #expect(pairs[1].key == "b")
        #expect(result.unsupportedFeatures.isEmpty)
    }

    @Test func parsesBlockSequence() throws {
        let body = """
        - one
        - two
        - three
        """
        let result = try PlantUMLYAMLParser().parse(body)
        guard case .sequence(let elements) = result.value else {
            Issue.record("expected sequence")
            return
        }
        #expect(elements.count == 3)
    }

    @Test func parsesNestedStructure() throws {
        let body = """
        outer:
          inner:
            leaf: value
          list:
            - a
            - b
        """
        let result = try PlantUMLYAMLParser().parse(body)
        guard case .mapping(let topPairs) = result.value else {
            Issue.record("expected mapping")
            return
        }
        #expect(topPairs.count == 1)
        #expect(topPairs[0].key == "outer")
        guard case .mapping(let outerPairs) = topPairs[0].value else {
            Issue.record("expected nested mapping")
            return
        }
        #expect(outerPairs.count == 2)
    }

    @Test func parsesQuotedScalar() throws {
        let body = #"key: "hello world""#
        let result = try PlantUMLYAMLParser().parse(body)
        guard case .mapping(let pairs) = result.value,
              case .scalar(let raw) = pairs[0].value else {
            Issue.record("expected mapping → scalar")
            return
        }
        #expect(raw == "\"hello world\"")
    }

    @Test func skipsLineComments() throws {
        let body = """
        # a header comment
        a: 1
        # mid comment
        b: 2
        """
        let result = try PlantUMLYAMLParser().parse(body)
        guard case .mapping(let pairs) = result.value else {
            Issue.record("expected mapping")
            return
        }
        #expect(pairs.count == 2)
    }

    @Test func reportsAnchorAsUnsupported() throws {
        let body = """
        a: &anchor 1
        b: *anchor
        """
        let result = try PlantUMLYAMLParser().parse(body)
        #expect(result.unsupportedFeatures.contains { $0.contains("anchor") })
    }

    @Test func reportsTagAsUnsupported() throws {
        let body = """
        a: !!str 1
        """
        let result = try PlantUMLYAMLParser().parse(body)
        #expect(result.unsupportedFeatures.contains { $0.contains("tag") })
    }

    @Test func reportsFlowStyleAsUnsupported() throws {
        let body = #"a: {b: 1}"#
        let result = try PlantUMLYAMLParser().parse(body)
        #expect(result.unsupportedFeatures.contains { $0.contains("flow") })
    }

    @Test func reportsMultiDocAsUnsupported() throws {
        let body = """
        a: 1
        ---
        b: 2
        """
        let result = try PlantUMLYAMLParser().parse(body)
        #expect(result.unsupportedFeatures.contains { $0.contains("multi-document") })
    }
}

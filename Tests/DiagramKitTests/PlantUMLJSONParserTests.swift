import Testing
import Foundation
@testable import DiagramKitPlantUML

@Suite struct PlantUMLJSONParserTests {
    @Test func parsesObject() throws {
        let body = #"{ "a": 1, "b": "x" }"#
        let value = try PlantUMLJSONParser().parse(body)
        guard case .object(let pairs) = value else {
            Issue.record("expected object, got \(value)")
            return
        }
        #expect(pairs.count == 2)
        #expect(pairs[0].key == "a")
    }

    @Test func parsesArray() throws {
        let body = #"[1, 2, "three"]"#
        let value = try PlantUMLJSONParser().parse(body)
        guard case .array(let elements) = value else {
            Issue.record("expected array")
            return
        }
        #expect(elements.count == 3)
    }

    @Test func parsesPrimitive() throws {
        let value = try PlantUMLJSONParser().parse("42")
        if case .number(let n) = value {
            #expect(n.contains("42"))
        } else {
            Issue.record("expected number")
        }
    }

    @Test func parsesNull() throws {
        let value = try PlantUMLJSONParser().parse("null")
        #expect(value == .null)
    }

    @Test func parsesBool() throws {
        let value = try PlantUMLJSONParser().parse("true")
        #expect(value == .bool(true))
    }

    @Test func throwsOnMalformed() {
        #expect(throws: Error.self) {
            try PlantUMLJSONParser().parse("{ malformed")
        }
    }
}

import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// Inputs from the review of the parser remediation (round 1): lines that
/// made a parse-side regex backtrack super-linearly. Each must parse (or
/// throw a typed error) within a second.
extension EngineHostileInputTests {

    fileprivate static func parseTime(_ source: String) async -> TimeInterval {
        let start = Date()
        _ = try? await DiagramEngine.parseImportResult(source: source)
        return Date().timeIntervalSince(start)
    }

    static let stylePrePassInputs: [String] = {
        let a: String = "graph TD\n;#" + String(repeating: "style:", count: 800)
        let b: String = "graph TD\n;#" + String(repeating: "style: ", count: 3_000)
        let c: String = "sequenceDiagram\nA->>B: ;#" + String(repeating: "classDef:", count: 3_000)
        let d: String = "graph TD\n;#" + String(repeating: "linkStyle:", count: 800)
        return [a, b, c, d]
    }()

    static let oneLineBodyInputs: [String] = {
        let spaces = String(repeating: " ", count: 8_000)
        let a: String = "stateDiagram-v2\nstate A" + spaces + "}"
        let b: String = "stateDiagram-v2\nstate A {" + spaces + "x"
        let c: String = "classDiagram\nclass A" + spaces + "}"
        return [a, b, c]
    }()

    /// Lines found by the round-1 regex sweep (5 KB of a pattern's own
    /// alphabet, one-second bound).
    static let sweepInputs: [String] = {
        let n = 5_000
        let er1: String = "erDiagram\nA" + String(repeating: " ", count: n) + "B"
        let er2: String = "erDiagram\nA" + String(repeating: "[", count: n)
        let er3: String = "erDiagram\n" + String(repeating: ":", count: n) + "{}"
        let er4: String = "erDiagram\nA:::x" + String(repeating: " ", count: n) + "y"
        let wardley: String = "wardley-beta\ncomponent P [0.5, 0.5]\npipeline P {\n  component X [" + String(repeating: "1", count: n) + "\n}"
        let classOpen: String = "classDiagram\nclass A" + String(repeating: " ", count: n) + "~"
        return [er1, er2, er3, er4, wardley, classOpen]
    }()

    @Test("style-colour pre-pass is linear on repeated style/classDef tokens", arguments: stylePrePassInputs)
    func stylePrePassLinear(_ source: String) async {
        #expect(await Self.parseTime(source) < 1)
    }

}

import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// CPU time consumed by the calling thread. Shared by the hostile-input
/// suites that bound a parse's cost: wall time also counts time spent
/// waiting for a core, which a loaded CI runner can stretch past any bound.
func _threadCPUSeconds() -> TimeInterval {
    var ts = timespec()
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts)
    return TimeInterval(ts.tv_sec) + TimeInterval(ts.tv_nsec) / 1_000_000_000
}

/// Inputs from the review of the parser remediation (round 1): lines that
/// made a parse-side regex backtrack super-linearly. Each must parse (or
/// throw a typed error) within a second.
extension EngineHostileInputTests {

    /// CPU seconds the parse takes on its worker thread. Wall time also
    /// counts time spent waiting for a core, and with the rest of the
    /// suite running in parallel that alone passed a second (seen in the
    /// 2026-11-12 remediation, on macOS and in the Linux container); a
    /// super-linear pattern still costs seconds of CPU.
    fileprivate static func parseTime(_ source: String) async -> TimeInterval {
        (try? await DiagramEngine._runOnWorker { () -> TimeInterval in
            let start = _threadCPUSeconds()
            _ = try? DiagramPipeline.parseImportResult(source)
            return _threadCPUSeconds() - start
        }) ?? .infinity
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

    /// Round-2 review: two patterns that stay under a second at 5 KB but
    /// were quadratic (4 s at 20 KB), so the sweep runs at 20 KB.
    static let round2SweepInputs: [String] = {
        let n = 20_000
        let note: String = "sequenceDiagram\nnote over" + String(repeating: " ", count: n) + "A"
        let member: String = "classDiagram\nA : +m" + String(repeating: "(", count: n)
        let bodyMember: String = "classDiagram\nclass A {\n+m" + String(repeating: "(", count: n) + "\n}"
        return [note, member, bodyMember]
    }()

    @Test("sequence note and class member patterns are linear at 20 KB", arguments: round2SweepInputs)
    func round2SweepLinear(_ source: String) async {
        #expect(await Self.parseTime(source) < 1)
    }

    @Test("parse-side regexes found by the sweep are linear", arguments: sweepInputs)
    func sweepFoundRegexesLinear(_ source: String) async {
        #expect(await Self.parseTime(source) < 1)
    }

    @Test("style-colour pre-pass is linear on repeated style/classDef tokens", arguments: stylePrePassInputs)
    func stylePrePassLinear(_ source: String) async {
        #expect(await Self.parseTime(source) < 1)
    }

    @Test("one-line state and class bodies are linear on long space runs", arguments: oneLineBodyInputs)
    func oneLineBodyLinear(_ source: String) async {
        #expect(await Self.parseTime(source) < 1)
    }
}

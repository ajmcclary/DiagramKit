import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitModel

/// Frontmatter and init-directive numbers are finite and bounded before any
/// binding sees them, and JSON 0/1 are numbers, not booleans.
@Suite("Frontmatter numeric bounds")
struct FrontmatterNumericBoundsTests {

    @Test("FrontmatterValue.double rejects non-finite values and clamps huge ones")
    func doubleBounds() {
        #expect(FrontmatterValue(raw: "inf").double == nil)
        #expect(FrontmatterValue(raw: "-inf").double == nil)
        #expect(FrontmatterValue(raw: "nan").double == nil)
        #expect(FrontmatterValue(raw: "1e999").double == nil)
        #expect(FrontmatterValue(raw: "1e300").double == FrontmatterValue.maxNumericMagnitude)
        #expect(FrontmatterValue(raw: "-1e300").double == -FrontmatterValue.maxNumericMagnitude)
        #expect(FrontmatterValue(raw: "12.5").double == 12.5)
    }

    @Test("FrontmatterValue.int clamps huge values")
    func intBounds() {
        #expect(FrontmatterValue(raw: "9223372036854775807").int == Int(FrontmatterValue.maxNumericMagnitude))
        #expect(FrontmatterValue(raw: "-9223372036854775808").int == -Int(FrontmatterValue.maxNumericMagnitude))
        #expect(FrontmatterValue(raw: "32").int == 32)
    }

    @Test("huge or non-finite frontmatter numbers render instead of trapping", arguments: [
        "---\nconfig:\n  journey:\n    leftMargin: 1e300\n---\njourney\nsection S\nA: 5: Me",
        "%%{init: {\"journey\": {\"leftMargin\": 1e300}}}%%\njourney\nsection S\nA: 5: Me",
        "---\nconfig:\n  gantt:\n    useWidth: 1e300\n---\ngantt\nsection A\ntask : 2024-01-01, 1d",
        "---\nconfig:\n  packet:\n    bitWidth: 1e300\n---\npacket-beta\n0-15: \"a\"",
        "---\nconfig:\n  packet:\n    bitsPerRow: 9223372036854775807\n---\npacket-beta\n0-15: \"a\"",
        "---\nconfig:\n  radar:\n    width: inf\n---\nradar-beta\n  axis A,B\n  curve c{1,2}",
        "---\nconfig:\n  journey:\n    taskMargin: nan\n---\njourney\nsection S\nA: 5: Me",
    ])
    func hugeFrontmatterRenders(_ source: String) async throws {
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(!svg.isEmpty)
        _ = try await DiagramEngine.renderASCII(source: source)
    }

    @Test("init-directive 0 and 1 are numbers")
    func initDirectiveZeroAndOne() async throws {
        let document = try await DiagramEngine.parse("""
        %%{init: {"gantt": {"barHeight": 1, "barGap": 7, "topPadding": 0}}}%%
        gantt
        section A
        task : 2024-01-01, 1d
        """)
        guard case .gantt(let diagram) = document.payload else {
            Issue.record("expected gantt")
            return
        }
        #expect(diagram.config?.barHeight == 1)
        #expect(diagram.config?.barGap == 7)
        #expect(diagram.config?.topPadding == 0)
    }

    @Test("init-directive booleans are still booleans")
    func initDirectiveBooleans() {
        let pairs = InitDirectiveParser.flatten(["a": true, "b": false, "c": 1, "d": 0])
        let values = Dictionary(uniqueKeysWithValues: pairs.map { ($0.path, $0.value.raw) })
        #expect(values == ["a": "true", "b": "false", "c": "1", "d": "0"])
    }
}

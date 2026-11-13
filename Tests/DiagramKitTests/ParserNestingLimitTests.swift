import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// Deep nesting and long tokens stay bounded on the parse side
/// (2026-11-12 parser review).
@Suite("Nesting and length limits on the parse side")
struct ParserNestingLimitTests {

    @Test("ZenUML nesting past the limit throws instead of overflowing the stack")
    func zenumlDeepNesting() async throws {
        let depth = 1_500
        let source = "zenuml\n" + String(repeating: "A.m(){", count: depth) + String(repeating: "}", count: depth)
        await #expect(throws: DiagramInputLimitError.self) {
            _ = try await DiagramEngine.parse(source)
        }
    }

    @Test("ZenUML nesting within the limit parses")
    func zenumlModerateNesting() async throws {
        let depth = 20
        let source = "zenuml\n" + String(repeating: "A.m(){", count: depth) + String(repeating: "}", count: depth)
        _ = try await DiagramEngine.parse(source)
    }

    @Test("class namespace nesting past the limit throws quickly")
    func classNamespaceDeepNesting() async throws {
        let depth = 1_500
        let source = "classDiagram\n" + (0..<depth).map { "namespace n\($0) {\n" }.joined()
            + "class A\n" + String(repeating: "}\n", count: depth)
        let start = Date()
        await #expect(throws: DiagramInputLimitError.self) {
            _ = try await DiagramEngine.parse(source)
        }
        #expect(Date().timeIntervalSince(start) < 5)
    }

    @Test("a 200 KB quoted wardley name parses in linear time")
    func wardleyLongQuotedName() async throws {
        let name = String(repeating: "x", count: 200_000)
        let start = Date()
        _ = try? await DiagramEngine.parse("wardley-beta\ncomponent \"\(name)\" [0.5, 0.5]\nevolve \"\(name)\" 0.8")
        #expect(Date().timeIntervalSince(start) < 5)
    }

    @Test("a quote in a wardley evolution line terminates")
    func wardleyQuotedEvolution() async throws {
        let document = try await DiagramEngine.parse("wardley-beta\nevolution Genesis / Concept -> \"Custom\" -> Product -> Commodity")
        guard case .wardleyBeta(let diagram) = document.payload else {
            Issue.record("expected wardley")
            return
        }
        #expect(diagram.axes.stages?.count == 4)
        _ = try? await DiagramEngine.parse("wardley-beta\nevolution Genesis / Concept -> Custom\"")
    }

    @Test("xychart with an unterminated accDescr block terminates")
    func xychartUnterminatedAccDescr() async throws {
        // The review's exact input has no data, so it now ends in a typed
        // error instead of hanging; with data the description is kept.
        await #expect(throws: XYChartParserError.self) {
            _ = try await DiagramEngine.parse("xychart\n    accDescr {\n      This chart")
        }
        let document = try await DiagramEngine.parse("xychart\n    bar [1, 2]\n    accDescr {\n      This chart")
        guard case .xyChart(let chart) = document.payload else {
            Issue.record("expected xychart")
            return
        }
        let closed = try await DiagramEngine.parse("xychart\n    bar [1, 2]\n    accDescr {\n      This chart\n    }")
        guard case .xyChart(let closedChart) = closed.payload else {
            Issue.record("expected xychart")
            return
        }
        #expect(chart.accDescr?.isEmpty == false)
        #expect(chart.accDescr == closedChart.accDescr)
    }
}

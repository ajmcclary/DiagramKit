import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// Hostile inputs from the 2026-11-12 parser review. Each one used to trap,
/// overflow the stack, or never return; each must now terminate through
/// every public stage, either with output or with a typed parse error.
extension EngineHostileInputTests {

    /// Runs `source` through parse, layout, SVG and ASCII. Returns the parse
    /// result, or the error the parse stage threw.
    fileprivate static func runAllStages(_ source: String) async -> Result<DiagramImportResult, any Error> {
        let parsed: Result<DiagramImportResult, any Error>
        do {
            parsed = .success(try await DiagramEngine.parseImportResult(source: source))
        } catch {
            parsed = .failure(error)
        }
        _ = try? await DiagramEngine.layout(source)
        _ = try? await DiagramEngine.renderSVG(source: source)
        _ = try? await DiagramEngine.renderASCII(source: source)
        return parsed
    }

    /// Parse stage only. Used for deep-nesting inputs: the parser bounds the
    /// depth, but block layout is still exponential in nesting depth (a
    /// layout-side finding), so these tests must not lay the input out.
    fileprivate static func parseOnly(_ source: String) async -> Result<DiagramImportResult, any Error> {
        do {
            return .success(try await DiagramEngine.parseImportResult(source: source))
        } catch {
            return .failure(error)
        }
    }

    fileprivate static func block(_ result: Result<DiagramImportResult, any Error>) throws -> (BlockDiagram, [DiagramDiagnostic]) {
        let imported = try result.get()
        guard case .block(let diagram) = imported.document.payload else {
            Issue.record("expected a block diagram")
            throw CancellationError()
        }
        return (diagram, imported.diagnostics)
    }

    /// Walks the block database from the root and fails if any block is
    /// reached twice (a cycle or a node with two parents).
    fileprivate static func expectBlockTree(_ diagram: BlockDiagram) {
        var seen: Set<String> = []
        var stack = ["root"]
        while let id = stack.popLast() {
            #expect(!seen.contains(id), "block \(id) reached twice")
            if seen.contains(id) { return }
            seen.insert(id)
            stack.append(contentsOf: diagram.blockDatabase[id]?.children ?? [])
        }
    }

    // MARK: - Block: self-containment and nesting

    @Test("block containing its own id terminates and drops the self reference")
    func blockContainingItself() async throws {
        let (diagram, diagnostics) = try Self.block(await Self.runAllStages("block-beta\nblock:g\n  g\nend"))
        Self.expectBlockTree(diagram)
        #expect(diagram.blockDatabase["g"]?.type == .composite)
        #expect(diagram.blockDatabase["g"]?.children.contains("g") == false)
        #expect(diagnostics.contains { $0.message.contains("cannot be nested inside itself") })
    }

    @Test("edge naming its enclosing block keeps the edge and the child")
    func blockEdgeToEnclosingBlock() async throws {
        let source = "block-beta\n  block:group1\n    a b\n    group1 --> a\n  end"
        let (diagram, _) = try Self.block(await Self.runAllStages(source))
        Self.expectBlockTree(diagram)
        #expect(diagram.blockDatabase["group1"]?.children == ["a", "b"])
        #expect(diagram.edges.contains { $0.start == "group1" && $0.end == "a" })
    }

    @Test("mutually containing blocks terminate")
    func blockMutualContainment() async throws {
        let (diagram, _) = try Self.block(await Self.runAllStages("block-beta\nblock:a\nblock:b\na\nend\nend"))
        Self.expectBlockTree(diagram)
        #expect(diagram.blockDatabase["a"]?.children == ["b"])
    }

    @Test("composites defined separately that list each other terminate")
    func blockCycleAcrossDefinitions() async throws {
        let source = "block-beta\nblock:a\n  b\nend\nblock:b\n  a\nend"
        let (diagram, diagnostics) = try Self.block(await Self.runAllStages(source))
        Self.expectBlockTree(diagram)
        #expect(diagnostics.contains { $0.message.contains("already placed elsewhere") })
    }

    @Test("nested block:g inside block:g keeps the inner children")
    func blockNestedSameId() async throws {
        let source = "block\n  block:g\n    block:g\n      a\n    end\n  end"
        let (diagram, _) = try Self.block(await Self.runAllStages(source))
        Self.expectBlockTree(diagram)
        #expect(diagram.blockDatabase["g"]?.children == ["a"])
    }

    @Test("block nesting deeper than the parser limit throws a typed error")
    func blockNestingLimit() async throws {
        let depth = _maxParserNestingDepth + 1
        let source = "block-beta\n"
            + (0..<depth).map { "block:b\($0)\n" }.joined()
            + "a\n" + String(repeating: "end\n", count: depth)
        let result = await Self.parseOnly(source)
        #expect(throws: DiagramInputLimitError.self) { try result.get() }
    }

    @Test("block chain built from separate definitions past the limit throws")
    func blockChainAcrossDefinitionsLimit() async throws {
        let depth = _maxParserNestingDepth + 5
        let source = "block-beta\n"
            + (0..<depth).map { "block:b\($0)\n  b\($0 + 1)\nend\n" }.joined()
        let result = await Self.parseOnly(source)
        #expect(throws: DiagramInputLimitError.self) { try result.get() }
    }

    @Test("block nesting at the limit still parses")
    func blockNestingAtLimit() async throws {
        let depth = _maxParserNestingDepth
        let source = "block-beta\n"
            + (0..<depth).map { "block:b\($0)\n" }.joined()
            + "a\n" + String(repeating: "end\n", count: depth)
        _ = try Self.block(await Self.parseOnly(source))
    }

    // MARK: - Block: column spans

    @Test("block width spans above the cap are clamped with a diagnostic", arguments: [
        "block-beta\na:9223372036854775807 b",
        "block-beta\na:4611686018427387904 b:4611686018427387904",
        "block-beta\na:99999999999999999999999 b",
        "block-beta\nblock:g:9223372036854775807\n  a\nend",
        "block-beta\nspace:9223372036854775807\na",
    ])
    func blockHugeSpan(_ source: String) async throws {
        let (diagram, diagnostics) = try Self.block(await Self.runAllStages(source))
        let spans = diagram.blockDatabase.values.compactMap(\.widthInColumns)
        #expect(spans.contains(1000))
        #expect(spans.allSatisfy { $0 <= 1000 })
        #expect(diagnostics.contains { $0.message.contains("clamped to 1000") })
    }

    @Test("block width span within the cap is kept as written")
    func blockOrdinarySpan() async throws {
        let (diagram, diagnostics) = try Self.block(await Self.runAllStages("block-beta\ncolumns 3\na:2 b"))
        #expect(diagram.blockDatabase["a"]?.widthInColumns == 2)
        #expect(diagnostics.isEmpty)
    }

    // MARK: - Packet: bit ranges at the Int limit

    @Test("packet ranges reaching Int.max throw instead of trapping", arguments: [
        "packet-beta\n0-9223372036854775807: \"a\"",
        "packet-beta\n0-15: \"a\"\n16-9223372036854775807: \"b\"",
        "packet-beta\n+1: \"b\"\n+9223372036854775807: \"a\"",
        "packet-beta\n0-320000: \"a\"",
    ])
    func packetHugeRange(_ source: String) async throws {
        let result = await Self.runAllStages(source)
        #expect {
            try result.get()
        } throws: { error in
            if case PacketParserError.maxPacketSizeExceeded = error { return true }
            return false
        }
    }

    @Test("packet range filling exactly the row limit still parses")
    func packetRangeAtLimit() async throws {
        let result = await Self.runAllStages("packet-beta\n0-319999: \"a\"")
        _ = try result.get()
    }
}

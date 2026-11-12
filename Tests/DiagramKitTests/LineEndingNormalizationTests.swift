import Foundation
import Testing
import DiagramKitTestSupport
@testable import DiagramKit
@testable import DiagramKitModel

/// A document must mean the same thing whatever its line endings are.
/// CRLF and lone-CR sources used to fail to parse, or parse to an empty
/// diagram, in fifteen families because only some parsers normalised
/// line endings.
@Suite("Line-ending normalization")
struct LineEndingNormalizationTests {

    /// SVG and ASCII output. Stable SVG ids are hashes of the source bytes,
    /// so they differ by construction when only the line endings differ;
    /// they are replaced with a placeholder before comparing.
    private static func outcome(_ source: String) async -> String {
        do {
            let svg = try await DiagramEngine.renderSVG(source: source, idPolicy: .stable)
                .replacingOccurrences(of: SVGIDGenerator.id(for: source, policy: .stable), with: "ID")
            let ascii = try await DiagramEngine.renderASCII(source: source).text
            return svg + "\n" + ascii
        } catch {
            return "threw \(error)"
        }
    }

    static func mermaidEntries() throws -> [CorpusEntry] {
        GanttTodayEnv.set()
        return try DiagramCorpus.load()
    }

    @Test("every corpus entry parses and renders ASCII the same with CRLF and CR line endings", arguments: try mermaidEntries())
    func corpusEntryLineEndings(_ entry: CorpusEntry) async throws {
        let lf = entry.source.replacingOccurrences(of: "\r\n", with: "\n")
        let expected = await Self.outcome(lf)
        #expect(await Self.outcome(lf.replacingOccurrences(of: "\n", with: "\r\n")) == expected, "CRLF")
        #expect(await Self.outcome(lf.replacingOccurrences(of: "\n", with: "\r")) == expected, "CR")
    }

    @Test("a CRLF sequence diagram parses its messages")
    func crlfSequence() async throws {
        let document = try await DiagramEngine.parse("sequenceDiagram\r\nAlice->>Bob: Hi\r\n")
        guard case .sequenceDiagram(let diagram) = document.payload else {
            Issue.record("expected a sequence diagram")
            return
        }
        #expect(diagram.messages.count == 1)
    }

    @Test("CRLF gantt, gitGraph and radar are not silently empty")
    func crlfFamiliesThatParsedEmpty() async throws {
        let gantt = try await DiagramEngine.parse("gantt\r\ndateFormat YYYY-MM-DD\r\nsection S\r\nTask : t1, 2024-01-01, 1d\r\n")
        if case .gantt(let diagram) = gantt.payload {
            #expect(diagram.tasks.count == 1)
        } else {
            Issue.record("expected gantt")
        }
        let git = try await DiagramEngine.parse("gitGraph\r\ncommit\r\ncommit\r\n")
        if case .gitGraph(let diagram) = git.payload {
            #expect(diagram.statements.count == 2)
        } else {
            Issue.record("expected gitGraph")
        }
        let radar = try await DiagramEngine.parse("radar-beta\r\naxis a,b,c\r\ncurve x{1,2,3}\r\n")
        if case .radar(let diagram) = radar.payload {
            #expect(diagram.axes.count == 3)
            #expect(diagram.curves.count == 1)
        } else {
            Issue.record("expected radar")
        }
    }

    @Test("statement splitting treats CRLF and CR as line breaks")
    func splitterLineBreaks() {
        #expect(DiagramSourceNormalizer.statements("a\r\nb\rc") == ["a", "b", "c"])
        #expect(DiagramSourceNormalizer.normalizedLineEndings("a\r\nb\rc\n") == "a\nb\nc\n")
    }
}

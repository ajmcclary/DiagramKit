import Testing
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
import Foundation

@Suite struct MermaidSourceNormalizerTests {

    // MARK: - rawLines

    @Test("rawLines normalizes CRLF and CR to LF")
    func rawLinesNormalizesCRLF() {
        let source = "line1\r\nline2\rline3\nline4"
        let lines = MermaidSourceNormalizer.rawLines(source)
        #expect(lines.count == 4)
        #expect(lines[0] == "line1")
        #expect(lines[1] == "line2")
        #expect(lines[2] == "line3")
        #expect(lines[3] == "line4")
    }

    @Test("rawLines preserves empty lines")
    func rawLinesPreservesEmptyLines() {
        let source = "a\n\nb\n"
        let lines = MermaidSourceNormalizer.rawLines(source)
        #expect(lines.count == 4)
        #expect(lines[0] == "a")
        #expect(lines[1] == "")
        #expect(lines[2] == "b")
        #expect(lines[3] == "")
    }

    // MARK: - diagramLines

    @Test("diagramLines filters comments and empty lines")
    func diagramLinesFiltersComments() {
        let source = "statement1\n%% comment\n\nstatement2"
        let lines = MermaidSourceNormalizer.diagramLines(source)
        #expect(lines.count == 2)
        #expect(lines[0] == "statement1")
        #expect(lines[1] == "statement2")
    }

    // MARK: - statements

    @Test("statements splits on newlines by default")
    func statementsSplitsOnNewlines() {
        let source = "stmt1\nstmt2\nstmt3"
        let lines = MermaidSourceNormalizer.statements(source, separators: CharacterSet(charactersIn: "\n"))
        #expect(lines.count == 3)
        #expect(lines[0] == "stmt1")
        #expect(lines[1] == "stmt2")
        #expect(lines[2] == "stmt3")
    }

    @Test("statements splits on semicolons")
    func statementsSplitsOnSemicolons() {
        let source = "a;b;c"
        let lines = MermaidSourceNormalizer.statements(source)
        #expect(lines.count == 3)
        #expect(lines[0] == "a")
        #expect(lines[1] == "b")
        #expect(lines[2] == "c")
    }

    @Test("statements is quote-aware — semicolons inside quotes are preserved")
    func statementsPreservesQuotedSemicolons() {
        let source = "label \"hello; world\"; next"
        let lines = MermaidSourceNormalizer.statements(source)
        #expect(lines.count == 2)
        #expect(lines[0] == "label \"hello; world\"")
        #expect(lines[1] == "next")
    }

    @Test("statements is quote-aware — newlines inside quotes are preserved")
    func statementsPreservesQuotedNewlines() {
        let source = "label \"line1\nline2\"; next"
        let lines = MermaidSourceNormalizer.statements(source, separators: CharacterSet(charactersIn: "\n;"))
        #expect(lines.count == 2)
        #expect(lines[0].contains("line1"))
        #expect(lines[0].contains("line2"))
        #expect(lines[1] == "next")
    }

    @Test("statements handles escaped quotes inside strings")
    func statementsHandlesEscapedQuotes() {
        let source = "label \"hello \\\"world\\\"\"; next"
        let lines = MermaidSourceNormalizer.statements(source)
        #expect(lines.count == 2)
        #expect(lines[0] == "label \"hello \\\"world\\\"\"")
        #expect(lines[1] == "next")
    }

    @Test("statements filters %% comment lines")
    func statementsFiltersComments() {
        let source = "%% this is a comment\nactual statement\n%% another comment"
        let lines = MermaidSourceNormalizer.statements(source, separators: CharacterSet(charactersIn: "\n"))
        #expect(lines.count == 1)
        #expect(lines[0] == "actual statement")
    }

    @Test("statements trims whitespace from results")
    func statementsTrimsWhitespace() {
        let source = "  stmt1  ;  stmt2  "
        let lines = MermaidSourceNormalizer.statements(source)
        #expect(lines.count == 2)
        #expect(lines[0] == "stmt1")
        #expect(lines[1] == "stmt2")
    }

    // MARK: - joinedStatements

    @Test("joinedStatements joins multiline @{ } blocks")
    func joinedStatementsJoinsMetadataBlocks() {
        let source = "A@{ shape: cloud,\n    label: \"Data\" }\nB-->C"
        let lines = MermaidSourceNormalizer.joinedStatements(source, separators: CharacterSet(charactersIn: "\n"))
        #expect(lines.count >= 2)
        let joined = lines.joined(separator: "|")
        // _joinMultiLineBlocks replaces newlines with spaces; indentation is preserved
        #expect(joined.contains("A@{"))
        #expect(joined.contains("label:"))
        #expect(joined.contains("Data"))
        #expect(joined.contains("B-->C"))
    }

    // MARK: - Edge cases

    @Test("empty input produces empty output")
    func emptyInputProducesEmptyOutput() {
        #expect(MermaidSourceNormalizer.statements("").isEmpty)
        #expect(MermaidSourceNormalizer.diagramLines("").isEmpty)
        // rawLines preserves empty lines by design — empty source → [""]
        #expect(MermaidSourceNormalizer.rawLines("") == [""])
    }

    @Test("input with only comments produces empty output")
    func onlyCommentsProducesEmptyOutput() {
        let source = "%% comment1\n%% comment2"
        #expect(MermaidSourceNormalizer.statements(source, separators: CharacterSet(charactersIn: "\n")).isEmpty)
    }
}

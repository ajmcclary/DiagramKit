import Testing
@testable import DiagramKitModel

/// Pins the YAML-quirk handling added to `FrontmatterDocumentParser`
/// after the original review flagged silent failures on tab indent,
/// escaped quotes, and mid-line `#` comments.
@Suite("Frontmatter Document Parser")
struct FrontmatterDocumentParserTests {

    // MARK: - Tab indent

    @Test("Tab-indented nested keys produce the same path as space-indented")
    func tabIndentEquivalentToSpaces() {
        let spaceLines = [
            "config:",
            "  sequence:",
            "    diagramMarginX: 10",
        ]
        let tabLines = [
            "config:",
            "\tsequence:",
            "\t\tdiagramMarginX: 10",
        ]
        let space = FrontmatterDocumentParser.flatten(spaceLines)
        let tab = FrontmatterDocumentParser.flatten(tabLines)
        #expect(space.map(\.path) == tab.map(\.path))
        #expect(space.first?.path == "config.sequence.diagramMarginX")
        #expect(tab.first?.path == "config.sequence.diagramMarginX")
    }

    @Test("Mixed space/tab indent still nests correctly")
    func mixedIndent() {
        let lines = [
            "config:",
            "\t sequence:",       // tab + space
            "  \tdiagramMarginX: 10", // 2 spaces + tab
        ]
        let pairs = FrontmatterDocumentParser.flatten(lines)
        #expect(pairs.first?.path == "config.sequence.diagramMarginX")
    }

    // MARK: - Escaped quotes

    @Test("Escaped \\\" inside double-quoted value is unescaped")
    func escapedDoubleQuote() {
        let lines = [#"title: "Hello \"World\"""#]
        let pairs = FrontmatterDocumentParser.flatten(lines)
        #expect(pairs.first?.value.raw == #"Hello "World""#)
    }

    @Test("Escaped \\\\ inside double-quoted value is unescaped to single backslash")
    func escapedBackslash() {
        let lines = [#"title: "C:\\path\\to\\file""#]
        let pairs = FrontmatterDocumentParser.flatten(lines)
        #expect(pairs.first?.value.raw == #"C:\path\to\file"#)
    }

    @Test("Single-quoted values are taken literally (no escape processing)")
    func singleQuotedLiteral() {
        let lines = [#"title: 'Hello \"World\"'"#]
        let pairs = FrontmatterDocumentParser.flatten(lines)
        // YAML single-quote semantics: backslashes are not escape chars.
        #expect(pairs.first?.value.raw == #"Hello \"World\""#)
    }

    // MARK: - Mid-line `#` comments

    @Test("Trailing whitespace-prefixed # comment is stripped from unquoted value")
    func trailingCommentStripped() {
        let lines = ["theme: forest # the default light theme"]
        let pairs = FrontmatterDocumentParser.flatten(lines)
        #expect(pairs.first?.value.raw == "forest")
    }

    @Test("Hex color literal (#abc) is preserved (no whitespace before #)")
    func hexLiteralPreserved() {
        let lines = ["color: #abc123"]
        let pairs = FrontmatterDocumentParser.flatten(lines)
        #expect(pairs.first?.value.raw == "#abc123")
    }

    @Test("# inside a quoted value is preserved")
    func hashInsideQuotePreserved() {
        let lines = [#"label: "tag #1""#]
        let pairs = FrontmatterDocumentParser.flatten(lines)
        #expect(pairs.first?.value.raw == "tag #1")
    }
}

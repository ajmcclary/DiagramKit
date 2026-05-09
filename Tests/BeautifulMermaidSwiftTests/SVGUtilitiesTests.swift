import Testing
@testable import BeautifulMermaidSwift

@Suite struct SVGUtilitiesTests {

    // MARK: - escapeText

    @Test func escapeText_ampersand() {
        #expect(SVG.escapeText("&") == "&amp;")
    }

    @Test func escapeText_lessThan() {
        #expect(SVG.escapeText("<") == "&lt;")
    }

    @Test func escapeText_greaterThan() {
        #expect(SVG.escapeText(">") == "&gt;")
    }

    @Test func escapeText_plainText_isIdentity() {
        #expect(SVG.escapeText("hello world") == "hello world")
    }

    @Test func escapeText_apostrophe_isIdentity() {
        // Text content must NOT escape apostrophes (byte-stability requirement).
        #expect(SVG.escapeText("customer's") == "customer's")
    }

    @Test func escapeText_quote_isIdentity() {
        // Text content must NOT escape double quotes.
        #expect(SVG.escapeText(#"say "hello""#) == #"say "hello""#)
    }

    @Test func escapeText_combined() {
        #expect(SVG.escapeText("a < b & c > d") == "a &lt; b &amp; c &gt; d")
    }

    @Test func escapeText_empty() {
        #expect(SVG.escapeText("") == "")
    }

    // MARK: - escapeAttribute

    @Test func escapeAttribute_ampersand() {
        #expect(SVG.escapeAttribute("&") == "&amp;")
    }

    @Test func escapeAttribute_lessThan() {
        #expect(SVG.escapeAttribute("<") == "&lt;")
    }

    @Test func escapeAttribute_greaterThan() {
        #expect(SVG.escapeAttribute(">") == "&gt;")
    }

    @Test func escapeAttribute_doubleQuote() {
        #expect(SVG.escapeAttribute("\"") == "&quot;")
    }

    @Test func escapeAttribute_apostrophe_isNumericEntity() {
        // Standardized to &#39; not &apos; (parser compatibility).
        #expect(SVG.escapeAttribute("'") == "&#39;")
    }

    @Test func escapeAttribute_plainText_isIdentity() {
        #expect(SVG.escapeAttribute("hello world") == "hello world")
    }

    @Test func escapeAttribute_combined() {
        #expect(SVG.escapeAttribute(#"a < b & c > "d" 'e'"#) == "a &lt; b &amp; c &gt; &quot;d&quot; &#39;e&#39;")
    }

    @Test func escapeAttribute_empty() {
        #expect(SVG.escapeAttribute("") == "")
    }

    // MARK: - Round-trip sanity

    @Test func escapeText_doesNotEscapeQuote() {
        // Double quotes in text content stay as-is (not escaped).
        #expect(SVG.escapeText("\"test\"") == "\"test\"")
    }

    @Test func escapeAttribute_escapesAllFive() {
        // &, <, >, ", ' must all be escaped in attribute context.
        let result = SVG.escapeAttribute("&<>\"'")
        #expect(result.contains("&amp;"))
        #expect(result.contains("&lt;"))
        #expect(result.contains("&gt;"))
        #expect(result.contains("&quot;"))
        #expect(result.contains("&#39;"))
    }
}

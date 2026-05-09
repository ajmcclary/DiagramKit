import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class MarkdownLabelRendererTests: XCTestCase {

    func testBoldTextHasBoldTrait() {
        let config = MarkdownLabelRenderer.Config(fontSize: 14, textColor: .black)
        let result = MarkdownLabelRenderer.render("hello **world**!", config: config)
        XCTAssertGreaterThan(result.length, 0)
        var foundBold = false
        result.enumerateAttributes(in: NSRange(location: 0, length: result.length)) { attrs, range, _ in
            if (result.string as NSString).substring(with: range).contains("world"),
               let font = attrs[.font] as? BMFont {
                #if os(macOS)
                let isBold = font.fontDescriptor.symbolicTraits.contains(.bold)
                #else
                let isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                #endif
                if isBold { foundBold = true }
            }
        }
        XCTAssertTrue(foundBold, "Text inside ** should have bold trait")
    }

    func testItalicTextHasItalicTrait() {
        let config = MarkdownLabelRenderer.Config(fontSize: 14, textColor: .black)
        let result = MarkdownLabelRenderer.render("a *slanted* word", config: config)
        var foundItalic = false
        result.enumerateAttributes(in: NSRange(location: 0, length: result.length)) { attrs, range, _ in
            if (result.string as NSString).substring(with: range).contains("slanted"),
               let font = attrs[.font] as? BMFont {
                #if os(macOS)
                let isItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
                #else
                let isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                #endif
                if isItalic { foundItalic = true }
            }
        }
        XCTAssertTrue(foundItalic, "Text inside * should have italic trait")
    }

    func testCodeTextHasMonoFont() {
        let config = MarkdownLabelRenderer.Config(fontSize: 14, textColor: .black)
        let result = MarkdownLabelRenderer.render("use `foo()` here", config: config)
        var foundMono = false
        result.enumerateAttributes(in: NSRange(location: 0, length: result.length)) { attrs, range, _ in
            if (result.string as NSString).substring(with: range).contains("foo()"),
               let font = attrs[.font] as? BMFont {
                #if os(macOS)
                let isMono = font.fontDescriptor.symbolicTraits.contains(.monoSpace)
                #else
                let isMono = font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace)
                #endif
                if isMono { foundMono = true }
            }
        }
        XCTAssertTrue(foundMono, "Text inside backticks should have monospace trait")
    }

    func testNestedBoldAndItalic() {
        let config = MarkdownLabelRenderer.Config(fontSize: 14, textColor: .black)
        let result = MarkdownLabelRenderer.render("**bold *nested***", config: config)
        let fullText = result.string
        XCTAssertTrue(fullText.contains("bold"))
        XCTAssertTrue(fullText.contains("nested"))
    }

    func testBRTagProducesNewline() {
        let config = MarkdownLabelRenderer.Config(fontSize: 14, textColor: .black)
        let result = MarkdownLabelRenderer.render("hello<br>world", config: config)
        XCTAssertTrue(result.string.contains("\n"), "br tag should produce newline")
    }

    func testBRSelfClosingTagProducesNewline() {
        let config = MarkdownLabelRenderer.Config(fontSize: 14, textColor: .black)
        let result = MarkdownLabelRenderer.render("a<br/>b", config: config)
        XCTAssertTrue(result.string.contains("\n"))
    }

    func testPlainTextNoTraits() {
        let config = MarkdownLabelRenderer.Config(fontSize: 14, textColor: .black)
        let result = MarkdownLabelRenderer.render("plain text", config: config)
        XCTAssertEqual(result.string, "plain text")
    }

    func testEmptyString() {
        let config = MarkdownLabelRenderer.Config(fontSize: 14, textColor: .black)
        let result = MarkdownLabelRenderer.render("", config: config)
        XCTAssertEqual(result.length, 0)
    }
}

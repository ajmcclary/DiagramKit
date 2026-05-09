import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
@testable import DiagramKitCommon

final class HTMLEntityDecoderTests: XCTestCase {

    func testNamedEntityAmp() {
        let result = _HTMLEntities.decode("m &amp; cheese")
        XCTAssertEqual(result, "m & cheese")
    }

    func testNamedEntityLtGt() {
        let result = _HTMLEntities.decode("&lt;tag&gt;")
        XCTAssertEqual(result, "<tag>")
    }

    func testNamedEntityQuot() {
        let result = _HTMLEntities.decode(#"say &quot;hello&quot;"#)
        XCTAssertEqual(result, "say \"hello\"")
    }

    func testNamedEntityApos() {
        let result = _HTMLEntities.decode("it&apos;s")
        XCTAssertEqual(result, "it's")
    }

    func testNamedEntityNum39() {
        let result = _HTMLEntities.decode("it&#39;s")
        XCTAssertEqual(result, "it's")
    }

    func testPoundQuot() {
        let result = _HTMLEntities.decode("a #quot;b#quot; c")
        XCTAssertEqual(result, "a \"b\" c")
    }

    func testPoundAmp() {
        let result = _HTMLEntities.decode("a #amp; b")
        XCTAssertEqual(result, "a & b")
    }

    func testPoundNumDecimal() {
        let result = _HTMLEntities.decode("#65;#66;")
        XCTAssertEqual(result, "AB")
    }

    func testDecimalEntity() {
        let result = _HTMLEntities.decode("&#65;&#66;&#67;")
        XCTAssertEqual(result, "ABC")
    }

    func testHexEntity() {
        let result = _HTMLEntities.decode("&#x48;&#x69;")
        XCTAssertEqual(result, "Hi")
    }

    func testHexEntityUppercase() {
        let result = _HTMLEntities.decode("&#X41;")
        XCTAssertEqual(result, "A")
    }

    func testIncompleteEntityPassthrough() {
        let result = _HTMLEntities.decode("a &amp b")
        // Missing semicolon, so "&amp" is not a complete entity
        XCTAssertEqual(result, "a &amp b")
    }

    func testUnknownEntityPassthrough() {
        let result = _HTMLEntities.decode("&bogus;")
        XCTAssertEqual(result, "&bogus;")
    }

    func testMultipleEntitiesInOneString() {
        let result = _HTMLEntities.decode("&lt;b&gt;bold&amp;safe&lt;/b&gt;")
        XCTAssertEqual(result, "<b>bold&safe</b>")
    }

    func testEmptyString() {
        let result = _HTMLEntities.decode("")
        XCTAssertEqual(result, "")
    }

    func testNoEntities() {
        let result = _HTMLEntities.decode("plain text")
        XCTAssertEqual(result, "plain text")
    }
}

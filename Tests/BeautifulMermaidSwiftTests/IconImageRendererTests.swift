import XCTest
@testable import BeautifulMermaid
import DiagramKitCommon

final class IconImageRendererTests: XCTestCase {

    // MARK: - Font Awesome mapping

    func testSFSymbolForKnownFAName() {
        let sfName = FontAwesomeMap.sfSymbolName(for: "fa-user")
        XCTAssertEqual(sfName, "person.fill")
    }

    func testSFSymbolForFAWithoutPrefix() {
        let sfName = FontAwesomeMap.sfSymbolName(for: "check")
        XCTAssertEqual(sfName, "checkmark")
    }

    func testSFSymbolForUnknownFAName() {
        let sfName = FontAwesomeMap.sfSymbolName(for: "bogus-icon")
        XCTAssertNil(sfName)
    }

    // MARK: - Icon node SVG output

    func testIconNodeRendersWithFATextFallback() async throws {
        let source = """
        graph LR
          A@{ icon: "fa:user", shape: icon-square, label: "User" }
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<svg"), "Should produce valid SVG")
        XCTAssertTrue(svg.contains("icon-label"), "Should contain icon label text")
    }

    func testImageNodeWithSafeURLRendersImageTag() async throws {
        let source = """
        graph LR
          A@{ img: "https://example.com/img.png", shape: image-square, label: "Image" }
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<image"), "Should contain image tag")
    }

    func testIconNodeWithPOSLabelAbove() async throws {
        let source = """
        graph LR
          A@{ icon: "fa:check", form: "square", label: "OK", pos: "t" }
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<svg"))
    }

    func testIconNodeWithPOSLabelBelow() async throws {
        let source = """
        graph LR
          A@{ icon: "fa:check", form: "square", label: "OK", pos: "b" }
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<svg"))
    }

    // MARK: - CG rendering (CG context not compatible with NSImage draw in test runner)

}

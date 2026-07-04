import XCTest
@testable import DiagramKit
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
@testable import DiagramKitCommon

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
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<svg"), "Should produce valid SVG")
        XCTAssertTrue(svg.contains("icon-label"), "Should contain icon label text")
    }

    func testImageNodeWithSafeURLRendersImageTag() async throws {
        let source = """
        graph LR
          A@{ img: "https://example.com/img.png", shape: image-square, label: "Image" }
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<image"), "Should contain image tag")
    }

    func testIconNodeWithPOSLabelAbove() async throws {
        // pos:"t" must place the label above the centered position
        // (visual editor plan 4 — SVG parity with the CG renderer).
        let topY = try await labelY(pos: "t")
        let centeredY = try await labelY(pos: nil)
        XCTAssertLessThan(topY, centeredY, "pos:t label must sit above the centered label")
    }

    func testIconNodeWithPOSLabelBelow() async throws {
        let bottomY = try await labelY(pos: "b")
        let centeredY = try await labelY(pos: nil)
        XCTAssertGreaterThan(bottomY, centeredY, "pos:b label must sit below the centered label")
    }

    /// Render a one-icon-node diagram and extract the y coordinate of
    /// its "Me" label text element.
    private func labelY(pos: String?) async throws -> Double {
        let posPart = pos.map { ", pos: \"\($0)\"" } ?? ""
        let source = "graph LR\n  A[\"Me\"]@{ icon: \"fa:user\", shape: icon-square, h: 48\(posPart) }\n"
        let svg = try await DiagramEngine.renderSVG(source: source)
        let pattern = #"y="([0-9.\-]+)"[^>]*>(?:<tspan[^>]*>)?Me"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(svg.startIndex..., in: svg)
        guard let match = regex.firstMatch(in: svg, range: range),
              let yRange = Range(match.range(at: 1), in: svg),
              let y = Double(svg[yRange]) else {
            XCTFail("label y not found in SVG output for pos=\(pos ?? "nil")")
            return .nan
        }
        return y
    }

    // MARK: - CG rendering (CG context not compatible with NSImage draw in test runner)

}

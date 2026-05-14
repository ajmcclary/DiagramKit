#if canImport(CoreGraphics)
import XCTest
import DiagramKitModel
@testable import DiagramKitRenderingCG

final class LabelRendererMultilineTests: XCTestCase {
    private var renderer: LabelRenderer!
    private var font: BMFont!

    override func setUp() {
        super.setUp()
        renderer = LabelRenderer()
        font = BMFont.systemFont(ofSize: 14)
    }

    override func tearDown() {
        renderer = nil
        font = nil
        super.tearDown()
    }

    // MARK: - Single-line parity

    func test_singleLine_widthMatchesMeasureText() {
        let extent = renderer.measureMultilineExtent("hi", font: font)
        let baseline = renderer.measureText("hi", font: font)
        XCTAssertEqual(extent.width, baseline.width, accuracy: 0.0001)
    }

    func test_singleLine_heightIsOneLineHeight() {
        let extent = renderer.measureMultilineExtent("hi", font: font)
        let expected = font.pointSize * 1.3
        XCTAssertEqual(extent.height, expected, accuracy: 0.0001)
    }

    // MARK: - Blank-line height

    func test_blankLineCountsTowardHeight() {
        let extent = renderer.measureMultilineExtent("A\n\nB", font: font)
        let expected = 3 * (font.pointSize * 1.3)
        XCTAssertEqual(extent.height, expected, accuracy: 0.0001)
    }

    func test_blankLineContributesZeroWidth() {
        let extent = renderer.measureMultilineExtent("A\n\nB", font: font)
        let aWidth = renderer.measureText("A", font: font).width
        let bWidth = renderer.measureText("B", font: font).width
        XCTAssertEqual(extent.width, max(aWidth, bWidth), accuracy: 0.0001)
    }

    // MARK: - Longest-line-wins

    func test_longestLineDeterminesWidth() {
        let extent = renderer.measureMultilineExtent("x\nlongest line here\ny", font: font)
        let middle = renderer.measureText("longest line here", font: font).width
        XCTAssertEqual(extent.width, middle, accuracy: 0.0001)
    }
}
#endif

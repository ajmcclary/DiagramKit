import XCTest
import Foundation
import CoreGraphics
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class JourneyCGRendererTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    private func makeContext(size: CGSize) -> CGContext? {
        CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private func makeImage(from context: CGContext) -> CGImage? {
        context.makeImage()
    }

    // MARK: - CG Smoke Tests

    func test_cssExTitleFontSizeResolvesAboveTinyNumericValue() {
        let resolved = _journeyResolvedCGFontSize("4ex", baseFontSize: 14, fallback: 18)
        XCTAssertEqual(resolved, 28, accuracy: 0.1)
    }

    func test_cgRendersBasicDiagramWithoutCrashing() throws {
        let source = """
        journey
            title Test
            section Go
            Do thing: 5: Me
        """
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(max(1, positioned.width)), height: CGFloat(max(1, positioned.height)))
        guard let context = makeContext(size: size) else {
            XCTFail("Could not create CGContext")
            return
        }
        let bounds = CGRect(origin: .zero, size: size)
        renderer.render(positioned, in: context, bounds: bounds)
        XCTAssertTrue(true)
    }

    func test_cgProducesNonNilImage() throws {
        let source = """
        journey
            title Test
            section Go
            Do thing: 5: Me
        """
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(max(1, positioned.width)), height: CGFloat(max(1, positioned.height)))
        guard let context = makeContext(size: size) else {
            XCTFail("Could not create CGContext")
            return
        }
        let bounds = CGRect(origin: .zero, size: size)
        renderer.render(positioned, in: context, bounds: bounds)
        let image = makeImage(from: context)
        XCTAssertNotNil(image)
    }

    func test_cgRendersWithMultipleTasks() throws {
        let source = """
        journey
            title My Day
            section Morning
            Wake up: 5: Me
            Shower: 3: Me
            section Afternoon
            Work: 1: Me, Boss
            Lunch: 5: Me
        """
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(max(1, positioned.width)), height: CGFloat(max(1, positioned.height)))
        guard let context = makeContext(size: size) else {
            XCTFail("Could not create CGContext")
            return
        }
        let bounds = CGRect(origin: .zero, size: size)
        renderer.render(positioned, in: context, bounds: bounds)
        let image = makeImage(from: context)
        XCTAssertNotNil(image)
    }

    func test_cgImageDimensionsMatchLayout() throws {
        let source = """
        journey
            title Test
            section Go
            Do thing: 5: Me
        """
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(max(1, positioned.width)), height: CGFloat(max(1, positioned.height)))
        guard let context = makeContext(size: size) else {
            XCTFail("Could not create CGContext")
            return
        }
        let bounds = CGRect(origin: .zero, size: size)
        renderer.render(positioned, in: context, bounds: bounds)
        let image = makeImage(from: context)
        guard let img = image else {
            XCTFail("Image is nil")
            return
        }
        XCTAssertEqual(CGFloat(img.width), size.width * 1.0, accuracy: 1.0)
        XCTAssertEqual(CGFloat(img.height), size.height * 1.0, accuracy: 1.0)
    }

    func test_cgRendersFullPipelineParseLayoutRender() throws {
        let source = """
        journey
            title Full Day
            section Morning
            Wake up: 5: Alice
            section Evening
            Sleep: 3: Bob
        """
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)
        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(max(1, positioned.width)), height: CGFloat(max(1, positioned.height)))
        guard let context = makeContext(size: size) else {
            XCTFail("Could not create CGContext")
            return
        }
        let bounds = CGRect(origin: .zero, size: size)
        renderer.render(positioned, in: context, bounds: bounds)
        let image = makeImage(from: context)
        XCTAssertNotNil(image)
    }
}

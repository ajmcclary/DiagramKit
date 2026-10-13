// Apple-only test (CoreGraphics renderer + AppKit/UIKit). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import XCTest
import Foundation
import CoreGraphics
import DiagramKitTestSupport
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

/// Regression tests for the review findings that the CG renderer silently
/// drew nothing (or background only) while image baselines pinned the
/// blank output.
///
/// - H1: requirement diagrams (and markdown flowchart labels) drew
///   `NSAttributedString` straight into a raw CGContext with no
///   `NSGraphicsContext` installed — a silent no-op on the bitmap path.
/// - H9: parser-authored icon/image nodes (`@{ icon: … }` / `@{ img: … }`)
///   keep `shape == "rectangle"`, so the CG renderer's shape-keyed branch
///   skipped them and drew plain empty boxes.
///
/// These tests render through `DiagramBitmapRenderer` (the same path the
/// image snapshots use), so the pixel buffer is canonical top-down and
/// node rectangles map exactly — no orientation ambiguity.
final class CGRendererInkTests: XCTestCase {

    /// The bitmap renderer rasterizes at `renderScale` pixels per point.
    private let renderScale: CGFloat = 2.0

    private func corpusSource(_ id: String) throws -> String {
        let entries = try DiagramCorpus.load()
        guard let entry = entries.first(where: { $0.id == id }) else {
            XCTFail("corpus entry \(id) not found")
            throw NSError(domain: "CGRendererInkTests", code: 1)
        }
        return entry.source
    }

    private func scaledPixelRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX * renderScale,
            y: rect.minY * renderScale,
            width: rect.width * renderScale,
            height: rect.height * renderScale
        )
    }

    // MARK: - H1: requirement diagrams draw text

    func test_requirementDiagramTextInkInsideBoxes() throws {
        let source = try corpusSource("req-2-all-requirement-types")
        let graph = try DiagramPipeline.parse(source)
        let positioned = try _GraphLayout().layout(graph)
        let buffer = try XCTUnwrap(
            CGInkAssertions.readRenderedPixels(positioned),
            "could not render positioned diagram to pixels"
        )

        // Whole-image presence: shapes + labels (1% of pixels).
        let fraction = CGInkAssertions.inkFraction(
            in: try XCTUnwrap(CGInkAssertions.makeRenderedContext(positioned))
        )
        XCTAssertGreaterThanOrEqual(fraction, 0.01)

        // Targeted: the name row of the first requirement node must carry
        // ink. The band sits strictly between the `<<Requirement>>`
        // stereotype (top of the box) and the body divider, so only the
        // node's markdown-rendered name text can produce ink there.
        guard case let .requirement(diagram) = positioned.content,
              let node = diagram.nodes.first else {
            XCTFail("expected positioned requirement content")
            return
        }
        let nameBand = scaledPixelRect(CGRect(
            x: node.x + 6,
            y: node.y + 22,
            width: max(1, node.width - 12),
            height: 22
        ))
        let ink = CGInkAssertions.darkPixelCount(pixels: buffer, within: nameBand)
        XCTAssertGreaterThanOrEqual(
            ink,
            25,
            "expected dark text ink inside the requirement box name band, found \(ink) dark pixels — H1 regression (text drawn with no NSGraphicsContext is a no-op)"
        )
    }

    // MARK: - H9: parser-authored icon/image nodes draw content

    func test_parserAuthoredIconNodeDrawsIconInk() throws {
        let source = try corpusSource("flow-29-icon-nodes")
        let graph = try DiagramPipeline.parse(source)
        let positioned = try _GraphLayout().layout(graph)
        let buffer = try XCTUnwrap(
            CGInkAssertions.readRenderedPixels(positioned),
            "could not render positioned diagram to pixels"
        )

        // Node `U` carries `pos: "b"`, so its label renders BELOW the box —
        // the box interior can only contain ink from the icon itself. The
        // box border is excluded by the inset.
        guard let nodes = positioned.flowchartNodes,
              let iconNode = nodes.first(where: { $0.id == "U" }) else {
            XCTFail("expected flowchart node U")
            return
        }
        let interior = scaledPixelRect(CGRect(
            x: iconNode.x + 5,
            y: iconNode.y + 5,
            width: max(1, iconNode.width - 10),
            height: max(1, iconNode.height - 10)
        ))
        let ink = CGInkAssertions.darkPixelCount(pixels: buffer, within: interior)
        XCTAssertGreaterThanOrEqual(
            ink,
            25,
            "expected dark icon ink inside node U's box, found \(ink) dark pixels — H9 regression (icon branch keyed on shape, not properties)"
        )
    }

    func test_parserAuthoredImageNodeRenders() throws {
        let source = try corpusSource("flow-30-image-node")
        let graph = try DiagramPipeline.parse(source)
        let positioned = try _GraphLayout().layout(graph)
        let context = try XCTUnwrap(
            CGInkAssertions.makeRenderedContext(positioned),
            "could not create render context"
        )
        // The image placeholder is a dashed frame + photo glyph drawn
        // inside the node; assert the render carries ink at all.
        CGInkAssertions.assertInk(in: context, minFraction: 0.01)
    }
}
#endif

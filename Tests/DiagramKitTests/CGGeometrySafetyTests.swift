// Apple-only test (CoreGraphics renderer). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import CoreGraphics
import Testing
import DiagramKit
@testable import DiagramKitRenderingCG

@Suite("CG rounded rects from unchecked geometry")
struct CGGeometrySafetyTests {

    @Test("non-finite rects draw nothing instead of raising", arguments: [
        CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10),
        CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 10),
        CGRect(x: 0, y: CGFloat.nan, width: CGFloat.nan, height: 10),
    ])
    func nonFinite(rect: CGRect) {
        #expect(_safeBezierRoundedRect(rect, cornerRadius: 3).isEmpty)
        #expect(_safeCGRoundedRect(rect, cornerWidth: 3, cornerHeight: 3).isEmpty)
    }

    @Test("an oversize corner radius is clamped")
    func oversizeRadius() {
        let path = _safeCGRoundedRect(CGRect(x: 0, y: 0, width: 10, height: 4), cornerWidth: 50, cornerHeight: .nan)
        #expect(!path.isEmpty)
    }

    @Test("a sequence diagram with a huge autonumber start draws", arguments: [
        "sequenceDiagram\n  autonumber 99999999999999999999\n  A->>B: hi\n",
        "sankey-beta\nA,B,99999999999999999999\n",
    ])
    func hugeNumbersDraw(source: String) async throws {
        let prepared = try await DiagramEngine.prepare(source: source)
        let image = DiagramBitmapRenderer.render(size: prepared.bounds.size, scale: 1, theme: prepared.theme) { ctx in
            prepared.render(in: ctx, bounds: prepared.bounds)
        }
        #expect(image != nil)
    }
}
#endif

// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Visual editor plan 1 — NodeStyleSpec value semantics.

import Testing
@testable import DiagramKitInteractive

@Suite
struct NodeStyleSpecTests {

    @Test("classDefProperties maps colors and normalizes hex to lowercase")
    func propertiesMapping() {
        let spec = NodeStyleSpec(
            fill: "#E8F5E9", stroke: "#2E7D32", textColor: "#1B5E20", borderStyle: .dashed
        )
        #expect(spec.classDefProperties == [
            "fill": "#e8f5e9",
            "stroke": "#2e7d32",
            "color": "#1b5e20",
            "stroke-dasharray": "5 5",
        ])
    }

    @Test("thick border maps to stroke-width, solid adds nothing")
    func borderMapping() {
        #expect(NodeStyleSpec(borderStyle: .thick).classDefProperties == ["stroke-width": "3px"])
        #expect(NodeStyleSpec(borderStyle: .solid).classDefProperties.isEmpty)
    }

    @Test("empty spec has no properties and reports isEmpty")
    func emptySpec() {
        let spec = NodeStyleSpec()
        #expect(spec.isEmpty)
        #expect(spec.classDefProperties.isEmpty)
    }

    @Test("init(classDefProperties:) round-trips a generated map")
    func roundTripFromProperties() {
        let original = NodeStyleSpec(fill: "#fff3e0", stroke: "#ef6c00", borderStyle: .dashed)
        let rebuilt = NodeStyleSpec(classDefProperties: original.classDefProperties)
        #expect(rebuilt == original)
    }

    @Test("init(classDefProperties:) reads thick from stroke-width")
    func thickFromProperties() {
        let spec = NodeStyleSpec(classDefProperties: ["stroke-width": "3px"])
        #expect(spec.borderStyle == .thick)
    }

    @Test("equal styles written differently normalize equal")
    func normalization() {
        let a = NodeStyleSpec(fill: "#AABBCC")
        let b = NodeStyleSpec(fill: "#aabbcc")
        #expect(a.classDefProperties == b.classDefProperties)
    }
}
#endif

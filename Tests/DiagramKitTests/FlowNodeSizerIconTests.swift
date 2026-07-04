// Visual editor plan 4 — icon-shape node sizing.

import Testing
@testable import DiagramKitModel

private func iconNode(
    shape: original_src_types.NodeShape,
    label: String = "User",
    h: Double? = nil
) -> original_src_types.MermaidNode {
    original_src_types.MermaidNode(
        id: "i", label: label, shape: shape,
        properties: original_src_types.NodeProperties(icon: "fa:user", h: h)
    )
}

@Suite
struct FlowNodeSizerIconTests {

    @Test("icon shapes size to the default 48pt box, not the label")
    func defaultBox() {
        for shape in [original_src_types.NodeShape.icon, .iconCircle, .iconRounded, .iconSquare] {
            let size = _nodeSize(iconNode(shape: shape, label: "A very long label that would stretch a rectangle"))
            #expect(size.height == 64)  // 48 + 16 padding
            #expect(size.width >= 64)   // at least the box; label may widen it
        }
    }

    @Test("properties.h overrides the icon box size")
    func hOverride() {
        let size = _nodeSize(iconNode(shape: .iconCircle, label: "U", h: 64))
        #expect(size.height == 80)  // 64 + 16
        #expect(size.width == 80)   // square when the label fits
    }

    @Test("wide labels widen the node so pos-t/b labels don't clip")
    func wideLabel() {
        let narrow = _nodeSize(iconNode(shape: .iconSquare, label: "U"))
        let wide = _nodeSize(iconNode(shape: .iconSquare, label: "Authentication Gateway Service"))
        #expect(wide.width > narrow.width)
        #expect(wide.height == narrow.height)
    }

    @Test("non-icon shapes are unaffected")
    func rectangleUnchanged() {
        let node = original_src_types.MermaidNode(id: "r", label: "Label", shape: .rectangle)
        let size = _nodeSize(node)
        #expect(size.height == 36 || size.height > 36)  // classic floor path
        #expect(size.height != 64)
    }
}

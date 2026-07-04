// Visual editor plan 4 — typed icon configuration for setNodeIcon.
// The icon vocabulary is FontAwesomeMap (bundled, ~110 names) so every
// browsable icon renders as a real SF Symbol glyph in the CG renderer
// and serializes portably as `fa:<name>` in Mermaid source.

import DiagramKitCommon
import DiagramKitModel

public struct IconSpec: Sendable, Equatable, Hashable {

    public enum BackgroundShape: String, Sendable, CaseIterable, Hashable {
        case plain = "icon"
        case circle = "icon-circle"
        case rounded = "icon-rounded"
        case square = "icon-square"

        public var nodeShape: original_src_types.NodeShape {
            switch self {
            case .plain: return .icon
            case .circle: return .iconCircle
            case .rounded: return .iconRounded
            case .square: return .iconSquare
            }
        }
    }

    public enum Size: String, Sendable, CaseIterable, Hashable {
        case small
        case medium
        case large

        public var height: Double {
            switch self {
            case .small: return 32
            case .medium: return 48
            case .large: return 64
            }
        }
    }

    public enum LabelPosition: String, Sendable, CaseIterable, Hashable {
        case top = "t"
        case bottom = "b"
    }

    /// Font Awesome icon name. A `fa:` prefix is tolerated and
    /// stripped on init so call sites can pass either form.
    public var name: String
    public var background: BackgroundShape
    public var size: Size
    public var labelPosition: LabelPosition?

    public init(
        name: String,
        background: BackgroundShape = .circle,
        size: Size = .medium,
        labelPosition: LabelPosition? = nil
    ) {
        self.name = name.hasPrefix("fa:") ? String(name.dropFirst(3)) : name
        self.background = background
        self.size = size
        self.labelPosition = labelPosition
    }
}

extension DiagramEditor {

    func _setNodeIcon(
        of selection: DiagramSelection,
        to spec: IconSpec?,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        try _validateSelection(selection, matches: document)
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        guard selection.elementID.hasPrefix("node:") else {
            throw DiagramEditorError.unknownElementKind(id: selection.elementID)
        }
        let nodeID = String(selection.elementID.dropFirst(5))
        guard model.nodesInOrder.contains(where: { $0.id == nodeID }) else {
            throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
        }
        if let spec, FontAwesomeMap.sfSymbolName(for: spec.name) == nil {
            throw DiagramEditorError.unknownIconName(name: spec.name)
        }

        model.nodesInOrder = model.nodesInOrder.map { entry in
            guard entry.id == nodeID else { return entry }
            var node = entry.node
            var props = node.properties ?? original_src_types.NodeProperties()
            if let spec {
                node.shape = spec.background.nodeShape
                props.icon = "fa:\(spec.name)"
                props.h = spec.size.height
                props.pos = spec.labelPosition?.rawValue
            } else {
                node.shape = .rectangle
                props.icon = nil
                props.h = nil
                props.pos = nil
            }
            node.properties = props
            return (id: entry.id, node: node)
        }
        doc.payload = .flowchart(model)
        return doc
    }
}

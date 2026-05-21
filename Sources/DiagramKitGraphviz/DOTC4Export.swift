import Foundation
import DiagramKitCommon
import DiagramKitModel

public enum DOTC4Export {

    public static func export(_ diagram: C4Diagram) -> String {
        var lines: [String] = []
        lines.append("digraph G {")
        lines.append("    " + DOTRecoveryMarker.emitFamily("c4"))
        lines.append("    " + DOTRecoveryMarker.emitC4DiagramKind(diagram.kind.rawValue))
        if let title = diagram.title, !title.isEmpty {
            lines.append("    label = \"\(escape(title))\";")
        }
        lines.append("")

        let authoredBoundaries = diagram.boundaries.filter { $0.origin != .viewScopeSynthesized }
        let rootBoundaries = authoredBoundaries.filter { isRoot($0.parentBoundary) }
        let childrenByParent = Dictionary(grouping: authoredBoundaries.filter { !isRoot($0.parentBoundary) }, by: \.parentBoundary)
        let shapesByBoundary = Dictionary(grouping: diagram.shapes, by: \.parentBoundary)

        for boundary in rootBoundaries {
            emitBoundary(
                boundary,
                childrenByParent: childrenByParent,
                shapesByBoundary: shapesByBoundary,
                indent: "    ",
                into: &lines
            )
        }
        for shape in diagram.shapes where isRoot(shape.parentBoundary) {
            emitShape(shape, indent: "    ", into: &lines)
        }

        for (index, rel) in diagram.relationships.enumerated() {
            let labelAttr = rel.label.isEmpty ? "" : " [label=\"\(escape(rel.label))\"]"
            lines.append("    \(rel.from) -> \(rel.to)\(labelAttr);")
            let edgeID = "\(index)"
            if rel.kind != .rel {
                lines.append("    " + DOTRecoveryMarker.emitC4RelKind(
                    edgeIndex: index,
                    rawValue: rel.kind.rawValue
                ))
            }
            if let tech = rel.technology, !tech.isEmpty {
                lines.append("    " + DOTRecoveryMarker.emitC4Technology(targetID: edgeID, value: tech))
            }
            if let descr = rel.description, !descr.isEmpty {
                lines.append("    " + DOTRecoveryMarker.emitC4Description(targetID: edgeID, value: descr))
            }
            if let sprite = rel.sprite, !sprite.isEmpty {
                lines.append("    " + DOTRecoveryMarker.emitC4Sprite(targetID: edgeID, value: sprite))
            }
            if let tags = rel.tags, !tags.isEmpty {
                lines.append("    " + DOTRecoveryMarker.emitC4Tag(targetID: edgeID, value: tags))
            }
            if let link = rel.link, !link.isEmpty {
                lines.append("    " + DOTRecoveryMarker.emitC4Link(targetID: edgeID, value: link))
            }
            if let packed = packRelColors(rel) {
                lines.append("    " + DOTRecoveryMarker.emitC4Color(targetID: edgeID, packed: packed))
            }
        }

        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func emitShape(_ shape: C4Shape, indent: String, into lines: inout [String]) {
        let (nativeShape, needsKindMarker) = nativeDOTShape(for: shape.typeC4Shape)
        lines.append("\(indent)\(shape.alias) [shape=\(nativeShape), label=\"\(escape(shape.label))\"];")
        if needsKindMarker {
            lines.append(indent + DOTRecoveryMarker.emitC4ShapeKind(
                targetID: shape.alias,
                rawValue: shape.typeC4Shape.rawValue
            ))
        }
        if shape.typeC4Shape.isExternal {
            lines.append(indent + DOTRecoveryMarker.emitC4External(targetID: shape.alias))
        }
        if let tech = shape.technology, !tech.isEmpty {
            lines.append(indent + DOTRecoveryMarker.emitC4Technology(targetID: shape.alias, value: tech))
        }
        if let descr = shape.description, !descr.isEmpty {
            lines.append(indent + DOTRecoveryMarker.emitC4Description(targetID: shape.alias, value: descr))
        }
        if let sprite = shape.sprite, !sprite.isEmpty {
            lines.append(indent + DOTRecoveryMarker.emitC4Sprite(targetID: shape.alias, value: sprite))
        }
        if let tags = shape.tags, !tags.isEmpty {
            lines.append(indent + DOTRecoveryMarker.emitC4Tag(targetID: shape.alias, value: tags))
        }
        if let link = shape.link, !link.isEmpty {
            lines.append(indent + DOTRecoveryMarker.emitC4Link(targetID: shape.alias, value: link))
        }
        if let packed = packShapeColors(shape) {
            lines.append(indent + DOTRecoveryMarker.emitC4Color(targetID: shape.alias, packed: packed))
        }
    }

    private static func emitBoundary(
        _ boundary: C4Boundary,
        childrenByParent: [String: [C4Boundary]],
        shapesByBoundary: [String: [C4Shape]],
        indent: String,
        into lines: inout [String]
    ) {
        lines.append("\(indent)subgraph cluster_\(boundary.alias) {")
        lines.append("\(indent)    label = \"\(escape(boundary.label))\";")
        for child in childrenByParent[boundary.alias] ?? [] {
            emitBoundary(
                child,
                childrenByParent: childrenByParent,
                shapesByBoundary: shapesByBoundary,
                indent: indent + "    ",
                into: &lines
            )
        }
        for shape in shapesByBoundary[boundary.alias] ?? [] {
            emitShape(shape, indent: indent + "    ", into: &lines)
        }
        lines.append("\(indent)}")
        if let kind = boundary.type, !kind.isEmpty {
            lines.append(indent + DOTRecoveryMarker.emitC4BoundaryKind(targetID: boundary.alias, rawValue: kind))
        }
        if let descr = boundary.description, !descr.isEmpty {
            lines.append(indent + DOTRecoveryMarker.emitC4Description(targetID: boundary.alias, value: descr))
        }
        if let tags = boundary.tags, !tags.isEmpty {
            lines.append(indent + DOTRecoveryMarker.emitC4Tag(targetID: boundary.alias, value: tags))
        }
        if let link = boundary.link, !link.isEmpty {
            lines.append(indent + DOTRecoveryMarker.emitC4Link(targetID: boundary.alias, value: link))
        }
        if let packed = packBoundaryColors(boundary) {
            lines.append(indent + DOTRecoveryMarker.emitC4Color(targetID: boundary.alias, packed: packed))
        }
    }

    /// Returns (native DOT shape name, whether c4-shape-kind marker is required
    /// to recover the original C4ShapeType on import). DOT lacks D2's `person`
    /// and `queue` shapes, so more variants require the marker than on D2.
    private static func nativeDOTShape(for type: C4ShapeType) -> (String, Bool) {
        switch type {
        case .person, .external_person:
            return ("oval", true)
        case .system, .external_system:
            return ("box", false)
        case .system_db, .external_system_db:
            return ("cylinder", false)
        case .system_queue, .external_system_queue:
            return ("box", true)
        case .container, .external_container:
            return ("box", true)
        case .container_db, .external_container_db:
            return ("cylinder", true)
        case .container_queue, .external_container_queue:
            return ("box", true)
        case .component, .external_component:
            return ("component", false)
        case .component_db, .external_component_db:
            return ("cylinder", true)
        case .component_queue, .external_component_queue:
            return ("box", true)
        }
    }

    private static func isRoot(_ parentBoundary: String) -> Bool {
        parentBoundary.isEmpty || parentBoundary == "global"
    }

    private static func packShapeColors(_ shape: C4Shape) -> String? {
        var parts: [String] = []
        if let bg = shape.bgColor, !bg.isEmpty { parts.append("bg=\(bg)") }
        if let font = shape.fontColor, !font.isEmpty { parts.append("font=\(font)") }
        if let border = shape.borderColor, !border.isEmpty { parts.append("border=\(border)") }
        return parts.isEmpty ? nil : parts.joined(separator: ";")
    }

    private static func packBoundaryColors(_ boundary: C4Boundary) -> String? {
        var parts: [String] = []
        if let bg = boundary.bgColor, !bg.isEmpty { parts.append("bg=\(bg)") }
        if let font = boundary.fontColor, !font.isEmpty { parts.append("font=\(font)") }
        if let border = boundary.borderColor, !border.isEmpty { parts.append("border=\(border)") }
        return parts.isEmpty ? nil : parts.joined(separator: ";")
    }

    private static func packRelColors(_ rel: C4Relationship) -> String? {
        var parts: [String] = []
        if let text = rel.textColor, !text.isEmpty { parts.append("text=\(text)") }
        if let line = rel.lineColor, !line.isEmpty { parts.append("line=\(line)") }
        return parts.isEmpty ? nil : parts.joined(separator: ";")
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private extension C4ShapeType {
    var isExternal: Bool {
        switch self {
        case .external_person, .external_system, .external_system_db, .external_system_queue,
             .external_container, .external_container_db, .external_container_queue,
             .external_component, .external_component_db, .external_component_queue:
            return true
        default:
            return false
        }
    }
}

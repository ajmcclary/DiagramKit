import Foundation
import DiagramKitCommon
import DiagramKitModel

public enum D2C4Export {

    public static func export(_ diagram: C4Diagram) -> String {
        var lines: [String] = []
        lines.append(D2RecoveryMarker.emitFamily("c4"))
        lines.append(D2RecoveryMarker.emitC4DiagramKind(diagram.kind.rawValue))
        if let title = diagram.title, !title.isEmpty {
            lines.append("title: \"\(escape(title))\"")
        }
        lines.append("")

        // Skip the implicit `global` boundary — D2/DOT importers synthesize
        // one on parse to match Mermaid's c4 importer.
        let authoredBoundaries = diagram.boundaries.filter {
            $0.origin != .viewScopeSynthesized && $0.alias != "global"
        }
        let rootBoundaries = authoredBoundaries.filter { isRoot($0.parentBoundary) }
        let childrenByParent = Dictionary(grouping: authoredBoundaries.filter { !isRoot($0.parentBoundary) }, by: \.parentBoundary)
        let shapesByBoundary = Dictionary(grouping: diagram.shapes, by: \.parentBoundary)
        let authoredBoundaryAliases = Set(authoredBoundaries.map(\.alias))

        for boundary in rootBoundaries {
            emitBoundary(
                boundary,
                childrenByParent: childrenByParent,
                shapesByBoundary: shapesByBoundary,
                indent: "",
                into: &lines
            )
        }
        // Emit shapes whose parentBoundary doesn't reference an authored
        // boundary alias — i.e., truly top-level shapes. Shapes with
        // parentBoundary matching an authored boundary alias were already
        // emitted nested inside that boundary above.
        for shape in diagram.shapes
            where isRoot(shape.parentBoundary) && !authoredBoundaryAliases.contains(shape.parentBoundary) {
            emitShape(shape, indent: "", into: &lines)
        }

        for (index, rel) in diagram.relationships.enumerated() {
            let arrow = (rel.kind == .birel) ? "<->" : "->"
            let labelSuffix = rel.label.isEmpty ? "" : ": \"\(escape(rel.label))\""
            lines.append("\(rel.from) \(arrow) \(rel.to)\(labelSuffix)")
            let edgeID = "\(index)"
            if rel.kind != .rel {
                lines.append(D2RecoveryMarker.emitC4RelKind(
                    edgeIndex: index,
                    rawValue: rel.kind.rawValue
                ))
            }
            if let tech = rel.technology, !tech.isEmpty {
                lines.append(D2RecoveryMarker.emitC4Technology(targetID: edgeID, value: tech))
            }
            if let descr = rel.description, !descr.isEmpty {
                lines.append(D2RecoveryMarker.emitC4Description(targetID: edgeID, value: descr))
            }
            if let sprite = rel.sprite, !sprite.isEmpty {
                lines.append(D2RecoveryMarker.emitC4Sprite(targetID: edgeID, value: sprite))
            }
            if let tags = rel.tags, !tags.isEmpty {
                lines.append(D2RecoveryMarker.emitC4Tag(targetID: edgeID, value: tags))
            }
            if let link = rel.link, !link.isEmpty {
                lines.append(D2RecoveryMarker.emitC4Link(targetID: edgeID, value: link))
            }
            if let packed = packRelColors(rel) {
                lines.append(D2RecoveryMarker.emitC4Color(targetID: edgeID, packed: packed))
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func emitBoundary(
        _ boundary: C4Boundary,
        childrenByParent: [String: [C4Boundary]],
        shapesByBoundary: [String: [C4Shape]],
        indent: String,
        into lines: inout [String]
    ) {
        lines.append("\(indent)\(boundary.alias): \"\(escape(boundary.label))\" {")
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
            lines.append(D2RecoveryMarker.emitC4BoundaryKind(targetID: boundary.alias, rawValue: kind))
        }
        if let descr = boundary.description, !descr.isEmpty {
            lines.append(D2RecoveryMarker.emitC4Description(targetID: boundary.alias, value: descr))
        }
        if let tags = boundary.tags, !tags.isEmpty {
            lines.append(D2RecoveryMarker.emitC4Tag(targetID: boundary.alias, value: tags))
        }
        if let link = boundary.link, !link.isEmpty {
            lines.append(D2RecoveryMarker.emitC4Link(targetID: boundary.alias, value: link))
        }
        if let packed = packBoundaryColors(boundary) {
            lines.append(D2RecoveryMarker.emitC4Color(targetID: boundary.alias, packed: packed))
        }
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

    static func emitShape(_ shape: C4Shape, indent: String, into lines: inout [String]) {
        let (nativeShape, needsKindMarker) = nativeD2Shape(for: shape.typeC4Shape)
        lines.append("\(indent)\(shape.alias): \"\(escape(shape.label))\" {")
        lines.append("\(indent)    shape: \(nativeShape)")
        lines.append("\(indent)}")
        if needsKindMarker {
            lines.append(D2RecoveryMarker.emitC4ShapeKind(
                targetID: shape.alias,
                rawValue: shape.typeC4Shape.rawValue
            ))
        }
        if shape.typeC4Shape.isExternal {
            lines.append(D2RecoveryMarker.emitC4External(targetID: shape.alias))
        }
        if let tech = shape.technology, !tech.isEmpty {
            lines.append(D2RecoveryMarker.emitC4Technology(targetID: shape.alias, value: tech))
        }
        if let descr = shape.description, !descr.isEmpty {
            lines.append(D2RecoveryMarker.emitC4Description(targetID: shape.alias, value: descr))
        }
        if let sprite = shape.sprite, !sprite.isEmpty {
            lines.append(D2RecoveryMarker.emitC4Sprite(targetID: shape.alias, value: sprite))
        }
        if let tags = shape.tags, !tags.isEmpty {
            lines.append(D2RecoveryMarker.emitC4Tag(targetID: shape.alias, value: tags))
        }
        if let link = shape.link, !link.isEmpty {
            lines.append(D2RecoveryMarker.emitC4Link(targetID: shape.alias, value: link))
        }
        if let packed = packShapeColors(shape) {
            lines.append(D2RecoveryMarker.emitC4Color(targetID: shape.alias, packed: packed))
        }
    }

    /// Returns (native D2 shape name, whether c4-shape-kind marker is required
    /// to recover the original C4ShapeType on import).
    static func nativeD2Shape(for type: C4ShapeType) -> (String, Bool) {
        switch type {
        case .person, .external_person:
            return ("person", false)
        case .system, .external_system:
            return ("rectangle", false)
        case .system_db, .external_system_db:
            return ("cylinder", false)
        case .system_queue, .external_system_queue:
            return ("queue", false)
        case .container, .external_container:
            return ("rectangle", true)
        case .container_db, .external_container_db:
            return ("cylinder", true)
        case .container_queue, .external_container_queue:
            return ("queue", true)
        case .component, .external_component:
            return ("hexagon", false)
        case .component_db, .external_component_db:
            return ("cylinder", true)
        case .component_queue, .external_component_queue:
            return ("queue", true)
        }
    }

    static func isRoot(_ parentBoundary: String) -> Bool {
        parentBoundary.isEmpty || parentBoundary == "global"
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\"", with: "\\\"")
    }
}

extension C4ShapeType {
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

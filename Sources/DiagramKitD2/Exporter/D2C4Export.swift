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

        for shape in diagram.shapes where isRoot(shape.parentBoundary) {
            emitShape(shape, indent: "", into: &lines)
        }

        return lines.joined(separator: "\n") + "\n"
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

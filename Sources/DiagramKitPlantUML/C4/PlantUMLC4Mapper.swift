import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

/// Converts a `PlantUMLC4AST` into a `C4Diagram` payload by mapping
/// the macro invocations onto C4Shape / C4Relationship.
public struct PlantUMLC4Mapper {

    public init() {}

    public func map(_ ast: PlantUMLC4AST) -> (model: C4Diagram, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var shapes: [C4Shape] = []
        var relationships: [C4Relationship] = []

        for decl in ast.declarations {
            guard let shapeType = c4ShapeType(for: decl.macro) else {
                diagnostics.append(DiagramDiagnostic(
                    severity: .unsupported,
                    message: "PlantUML C4 macro '\(decl.macro)' is not recognized"
                ))
                continue
            }
            shapes.append(C4Shape(
                alias: decl.alias,
                label: decl.label,
                typeC4Shape: shapeType,
                technology: decl.technology,
                description: decl.description
            ))
        }

        for rel in ast.relationships {
            let kind = c4RelationshipKind(for: rel.macro)
            relationships.append(C4Relationship(
                kind: kind,
                from: rel.from,
                to: rel.to,
                label: rel.label,
                technology: rel.technology
            ))
        }

        for line in ast.unsupportedLines {
            diagnostics.append(DiagramDiagnostic(
                severity: .unsupported,
                message: "PlantUML C4 line not yet supported: \(line)"
            ))
        }

        // Choose diagram kind from the first shape macro family (simple heuristic).
        let kind = inferDiagramKind(from: ast.declarations)
        let model = C4Diagram(kind: kind, shapes: shapes, relationships: relationships)
        return (model, diagnostics)
    }

    private func c4ShapeType(for macro: String) -> C4ShapeType? {
        switch macro {
        case "Person":               return .person
        case "Person_Ext":            return .external_person
        case "System":                return .system
        case "SystemDb":              return .system_db
        case "SystemQueue":           return .system_queue
        case "System_Ext":            return .external_system
        case "SystemDb_Ext":          return .external_system_db
        case "SystemQueue_Ext":       return .external_system_queue
        case "Container":             return .container
        case "ContainerDb":           return .container_db
        case "ContainerQueue":        return .container_queue
        case "Container_Ext":         return .external_container
        case "ContainerDb_Ext":       return .external_container_db
        case "ContainerQueue_Ext":    return .external_container_queue
        case "Component":             return .component
        case "ComponentDb":           return .component_db
        case "ComponentQueue":        return .component_queue
        case "Component_Ext":         return .external_component
        case "ComponentDb_Ext":       return .external_component_db
        case "ComponentQueue_Ext":    return .external_component_queue
        default: return nil
        }
    }

    private func c4RelationshipKind(for macro: String) -> C4RelationshipKind {
        switch macro {
        case "BiRel":                  return .birel
        case "Rel_Up", "Rel_U":         return .rel_u
        case "Rel_Down", "Rel_D":       return .rel_d
        case "Rel_Left", "Rel_L":       return .rel_l
        case "Rel_Right", "Rel_R":      return .rel_r
        case "Rel_Back":                return .rel_b
        default:                        return .rel
        }
    }

    private func inferDiagramKind(from declarations: [PlantUMLC4Declaration]) -> C4DiagramKind {
        for decl in declarations {
            if decl.macro.hasPrefix("Component") { return .component }
            if decl.macro.hasPrefix("Container") { return .container }
        }
        return .context
    }
}

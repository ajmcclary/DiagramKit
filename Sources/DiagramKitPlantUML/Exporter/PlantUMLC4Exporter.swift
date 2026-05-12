import Foundation
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML C4 diagram source from a `C4Diagram`.
enum PlantUMLC4Export {

    static func emit(_ model: C4Diagram) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        lines.append("@startuml")

        // C4 inclusion
        lines.append("!include <C4/C4_\(plantUMLKind(model.kind))>")

        // Title
        if let title = model.title {
            lines.append("title \(escape(title))")
        }

        // Shapes as PlantUML C4 elements
        for shape in model.shapes {
            let funcName = plantUMLShapeFunction(shape.typeC4Shape)
            let alias = escape(shape.alias)
            let label = escape(shape.label)
            let desc = shape.description.map { escape($0) } ?? ""
            let tech = shape.technology.map { escape($0) } ?? ""

            var shapeLine: String
            if !desc.isEmpty && !tech.isEmpty {
                shapeLine = "\(funcName)(\(alias), \"\(label)\", \"\(desc)\", \"\(tech)\")"
            } else if !desc.isEmpty {
                shapeLine = "\(funcName)(\(alias), \"\(label)\", \"\(desc)\")"
            } else if !tech.isEmpty {
                shapeLine = "\(funcName)(\(alias), \"\(label)\", \"\(tech)\")"
            } else {
                shapeLine = "\(funcName)(\(alias), \"\(label)\")"
            }

            // Tags
            if let tags = shape.tags, !tags.isEmpty {
                shapeLine += " $tags=\"\(escape(tags))\""
            }

            lines.append(shapeLine)
        }

        // Boundaries
        for boundary in model.boundaries {
            let alias = escape(boundary.alias)
            let label = escape(boundary.label)
            if let desc = boundary.description, !desc.isEmpty {
                lines.append("Boundary(\(alias), \"\(label)\", \"\(escape(desc))\")")
            } else {
                lines.append("Boundary(\(alias), \"\(label)\")")
            }
        }

        // Relationships
        for rel in model.relationships {
            let from = escape(rel.from)
            let to = escape(rel.to)
            let label = escape(rel.label)
            let tech = rel.technology.map { escape($0) } ?? ""

            let relFunc = plantUMLRelFunction(rel.kind)
            var relLine: String
            if !tech.isEmpty {
                relLine = "\(relFunc)(\(from), \(to), \"\(label)\", \"\(tech)\")"
            } else {
                relLine = "\(relFunc)(\(from), \(to), \"\(label)\")"
            }

            lines.append(relLine)
        }

        lines.append("@enduml")

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // MARK: - PlantUML C4 function mappings

    private static func plantUMLKind(_ kind: C4DiagramKind) -> String {
        switch kind {
        case .context: return "Context"
        case .container: return "Container"
        case .component: return "Component"
        case .dynamic: return "Dynamic"
        case .deployment: return "Deployment"
        }
    }

    private static func plantUMLShapeFunction(_ type: C4ShapeType) -> String {
        switch type {
        case .person: return "Person"
        case .external_person: return "Person_Ext"
        case .system: return "System"
        case .system_db: return "SystemDb"
        case .system_queue: return "SystemQueue"
        case .external_system: return "System_Ext"
        case .external_system_db: return "SystemDb_Ext"
        case .external_system_queue: return "SystemQueue_Ext"
        case .container: return "Container"
        case .container_db: return "ContainerDb"
        case .container_queue: return "ContainerQueue"
        case .external_container: return "Container_Ext"
        case .external_container_db: return "ContainerDb_Ext"
        case .external_container_queue: return "ContainerQueue_Ext"
        case .component: return "Component"
        case .component_db: return "ComponentDb"
        case .component_queue: return "ComponentQueue"
        case .external_component: return "Component_Ext"
        case .external_component_db: return "ComponentDb_Ext"
        case .external_component_queue: return "ComponentQueue_Ext"
        }
    }

    private static func plantUMLRelFunction(_ kind: C4RelationshipKind) -> String {
        switch kind {
        case .rel: return "Rel"
        case .birel: return "BiRel"
        case .rel_u: return "Rel_U"
        case .rel_d: return "Rel_D"
        case .rel_l: return "Rel_L"
        case .rel_r: return "Rel_R"
        case .rel_b: return "Rel_Back"
        }
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }
}

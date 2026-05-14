import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML C4 source from a `C4Diagram`.
enum PlantUMLC4Export {

    static func emit(_ model: C4Diagram) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        lines.append("@startuml")
        lines.append(includeDirective(for: model.kind))

        if let title = model.title, !title.isEmpty {
            lines.append("title \(escape(title))")
        }

        for shape in model.shapes {
            lines.append(shapeLine(shape))
        }

        for rel in model.relationships {
            lines.append(relationshipLine(rel))
        }

        lines.append("@enduml")

        return DiagramExportResult(
            source: lines.joined(separator: "\n"),
            diagnostics: diagnostics
        )
    }

    private static func includeDirective(for kind: C4DiagramKind) -> String {
        switch kind {
        case .context:    return "!include <C4/C4_Context>"
        case .container:  return "!include <C4/C4_Container>"
        case .component:  return "!include <C4/C4_Component>"
        case .dynamic:    return "!include <C4/C4_Dynamic>"
        case .deployment: return "!include <C4/C4_Deployment>"
        }
    }

    private static func shapeLine(_ shape: C4Shape) -> String {
        let macro = macroName(for: shape.typeC4Shape)
        var args = [shape.alias, quoted(shape.label)]
        // PlantUML's C4 standard library macros mirror the Mermaid grammar:
        //   Person/System:     (alias, label, descr?)
        //   Container/Component: (alias, label, techn?, descr?)
        // Dispatch on C4ShapeType.hasTechnologySlot so technology↔description
        // don't swap on round-trip.
        let tech = shape.technology ?? ""
        let desc = shape.description ?? ""
        if shape.typeC4Shape.hasTechnologySlot {
            if !tech.isEmpty || !desc.isEmpty {
                args.append(quoted(tech))
            }
            if !desc.isEmpty {
                args.append(quoted(desc))
            }
        } else {
            if !desc.isEmpty {
                args.append(quoted(desc))
            }
            // technology drops on Person/System macros — there's no positional
            // slot for it. Caller can detect by re-parsing or by counting
            // diagnostics on the Mermaid emit; we don't surface one here so as
            // to keep the PlantUML emit diagnostics-free, matching the rest
            // of this slice.
        }
        return "\(macro)(\(args.joined(separator: ", ")))"
    }

    private static func relationshipLine(_ rel: C4Relationship) -> String {
        let macro = relationshipMacroName(for: rel.kind)
        var args = [rel.from, rel.to, quoted(rel.label)]
        if let technology = rel.technology, !technology.isEmpty {
            args.append(quoted(technology))
        }
        return "\(macro)(\(args.joined(separator: ", ")))"
    }

    private static func macroName(for shape: C4ShapeType) -> String {
        switch shape {
        case .person:                       return "Person"
        case .external_person:               return "Person_Ext"
        case .system:                        return "System"
        case .system_db:                     return "SystemDb"
        case .system_queue:                  return "SystemQueue"
        case .external_system:               return "System_Ext"
        case .external_system_db:            return "SystemDb_Ext"
        case .external_system_queue:         return "SystemQueue_Ext"
        case .container:                     return "Container"
        case .container_db:                  return "ContainerDb"
        case .container_queue:               return "ContainerQueue"
        case .external_container:            return "Container_Ext"
        case .external_container_db:         return "ContainerDb_Ext"
        case .external_container_queue:      return "ContainerQueue_Ext"
        case .component:                     return "Component"
        case .component_db:                  return "ComponentDb"
        case .component_queue:               return "ComponentQueue"
        case .external_component:            return "Component_Ext"
        case .external_component_db:         return "ComponentDb_Ext"
        case .external_component_queue:      return "ComponentQueue_Ext"
        }
    }

    private static func relationshipMacroName(for kind: C4RelationshipKind) -> String {
        switch kind {
        case .rel:    return "Rel"
        case .birel:  return "BiRel"
        case .rel_u:  return "Rel_Up"
        case .rel_d:  return "Rel_Down"
        case .rel_l:  return "Rel_Left"
        case .rel_r:  return "Rel_Right"
        case .rel_b:  return "Rel_Back"
        }
    }

    private static func quoted(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        return "\"\(escaped)\""
    }

    private static func escape(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

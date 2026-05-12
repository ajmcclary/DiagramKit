import Foundation
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Structurizr DSL source-format exporter.
///
/// Emits valid Structurizr DSL source for C4 diagrams from `DiagramDocument`.
public struct StructurizrExporter: DiagramExporter {
    public let name = "Structurizr"
    public let formatID = DiagramFormatID.structurizr
    public let supportedDiagramTypes: Set<DiagramType> = [.c4]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .c4(let model):
            return try StructurizrC4Export.emit(model)
        default:
            return DiagramExportResult(
                source: "",
                diagnostics: [
                    DiagramDiagnostic(
                        severity: .unsupported,
                        message: "Structurizr export for '\(document.type.rawValue)' is not supported"
                    )
                ]
            )
        }
    }
}

// MARK: - Structurizr C4 Export

enum StructurizrC4Export {

    static func emit(_ model: C4Diagram) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        lines.append("workspace {")
        lines.append("  model {")

        // Emit shapes as model elements
        for shape in model.shapes {
            let stype = structurizrType(shape.typeC4Shape)
            let escapedLabel = escape(shape.label)
            let escapedDesc = shape.description.map { escape($0) } ?? ""

            if !escapedDesc.isEmpty {
                lines.append("    \(shape.alias) = \(stype) \"\(escapedLabel)\" \"\(escapedDesc)\"")
            } else {
                lines.append("    \(shape.alias) = \(stype) \"\(escapedLabel)\"")
            }

            // Tags
            if let tags = shape.tags, !tags.isEmpty {
                lines.append("    \(shape.alias) tags \"\(escape(tags))\"")
            }
        }

        // Boundaries as groups
        for boundary in model.boundaries {
            lines.append("    group \"\(escape(boundary.label))\" {")
            // Children are implied by shapes with parentBoundary matching
            for shape in model.shapes where shape.parentBoundary == boundary.alias {
                lines.append("      include \(shape.alias)")
            }
            lines.append("    }")
        }

        // Relationships
        for rel in model.relationships {
            var relLine = "    \(rel.from) -> \(rel.to)"
            if !rel.label.isEmpty {
                relLine += " \"\(escape(rel.label))\""
            }
            if let tech = rel.technology, !tech.isEmpty {
                relLine += " \"\(escape(tech))\""
            }
            lines.append(relLine)
        }

        lines.append("  }")

        // Views
        let viewType: String
        switch model.kind {
        case .context: viewType = "systemLandscape"
        case .container: viewType = "container"
        case .component: viewType = "component"
        case .dynamic: viewType = "dynamic"
        case .deployment: viewType = "deployment"
        }

        // Find the system alias for container/component views
        var systemAlias: String? = nil
        if model.kind == .container || model.kind == .component {
            systemAlias = model.shapes.first(where: { $0.typeC4Shape == .system })?.alias
        }

        lines.append("  views {")
        if let sysAlias = systemAlias {
            lines.append("    \(viewType) \(sysAlias) {")
        } else {
            lines.append("    \(viewType) {")
        }

        lines.append("      include *")
        lines.append("    }")
        lines.append("  }")

        lines.append("}")

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func structurizrType(_ type: C4ShapeType) -> String {
        switch type {
        case .person, .external_person: return "person"
        case .system, .external_system: return "softwareSystem"
        case .system_db, .external_system_db: return "softwareSystem"
        case .system_queue, .external_system_queue: return "softwareSystem"
        case .container, .external_container: return "container"
        case .container_db, .external_container_db: return "container"
        case .container_queue, .external_container_queue: return "container"
        case .component, .external_component: return "component"
        case .component_db, .external_component_db: return "component"
        case .component_queue, .external_component_queue: return "component"
        }
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
    }
}

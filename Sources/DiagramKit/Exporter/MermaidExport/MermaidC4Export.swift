import Foundation
import DiagramKitModel
import DiagramKitImport

/// Emits Mermaid C4 diagram source from a `C4Diagram`.
enum MermaidC4Export {

    static func emit(_ model: C4Diagram) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        // Kind header
        let kindStr: String
        switch model.kind {
        case .context: kindStr = "C4Context"
        case .container: kindStr = "C4Container"
        case .component: kindStr = "C4Component"
        case .dynamic: kindStr = "C4Dynamic"
        case .deployment: kindStr = "C4Deployment"
        }
        lines.append(kindStr)

        // Title
        if let title = model.title {
            let (q, _) = MermaidExportHelpers.quote(title)
            lines.append("  title \(q)")
        }

        // Shapes
        for shape in model.shapes {
            let shapeFunc = c4ShapeFunction(shape.typeC4Shape)
            let (sanitizedAlias, ad) = MermaidExportHelpers.sanitizeIdentifier(shape.alias)
            diagnostics.append(contentsOf: ad)

            let (ql, _) = MermaidExportHelpers.quote(shape.label)
            let desc = shape.description ?? ""
            let tech = shape.technology ?? ""

            var shapeLine: String

            if !desc.isEmpty && !tech.isEmpty {
                let (qd, _) = MermaidExportHelpers.quote(desc)
                let (qt, _) = MermaidExportHelpers.quote(tech)
                shapeLine = "  \(shapeFunc)(\(sanitizedAlias), \(ql), \(qd), \(qt))"
            } else if !desc.isEmpty {
                let (qd, _) = MermaidExportHelpers.quote(desc)
                shapeLine = "  \(shapeFunc)(\(sanitizedAlias), \(ql), \(qd))"
            } else if !tech.isEmpty {
                let (qt, _) = MermaidExportHelpers.quote(tech)
                shapeLine = "  \(shapeFunc)(\(sanitizedAlias), \(ql), \(qt))"
            } else {
                shapeLine = "  \(shapeFunc)(\(sanitizedAlias), \(ql))"
            }

            // Tags
            if let tags = shape.tags, !tags.isEmpty {
                let (qt, _) = MermaidExportHelpers.quote(tags)
                shapeLine += " $tags=\(qt)"
            }

            // Parent boundary
            if shape.parentBoundary != "global" && !shape.parentBoundary.isEmpty {
                let (pb, _) = MermaidExportHelpers.sanitizeIdentifier(shape.parentBoundary)
                shapeLine += " $boundary=\(pb)"
            }

            lines.append(shapeLine)
        }

        // Boundaries
        for boundary in model.boundaries {
            let (sanitizedAlias, ad) = MermaidExportHelpers.sanitizeIdentifier(boundary.alias)
            diagnostics.append(contentsOf: ad)

            let (ql, _) = MermaidExportHelpers.quote(boundary.label)

            var boundaryLine: String
            if let desc = boundary.description, !desc.isEmpty {
                let (qd, _) = MermaidExportHelpers.quote(desc)
                boundaryLine = "  Boundary(\(sanitizedAlias), \(ql), \(qd))"
            } else {
                boundaryLine = "  Boundary(\(sanitizedAlias), \(ql))"
            }

            if boundary.parentBoundary != "global" && !boundary.parentBoundary.isEmpty {
                let (pb, _) = MermaidExportHelpers.sanitizeIdentifier(boundary.parentBoundary)
                boundaryLine += " $parent=\(pb)"
            }

            lines.append(boundaryLine)
        }

        // Relationships
        for rel in model.relationships {
            let (sanitizedFrom, fd) = MermaidExportHelpers.sanitizeIdentifier(rel.from)
            let (sanitizedTo, td) = MermaidExportHelpers.sanitizeIdentifier(rel.to)
            diagnostics.append(contentsOf: fd)
            diagnostics.append(contentsOf: td)

            let relFunc = c4RelFunction(rel.kind)
            let (ql, _) = MermaidExportHelpers.quote(rel.label)

            var relLine: String
            if let tech = rel.technology, !tech.isEmpty {
                let (qt, _) = MermaidExportHelpers.quote(tech)
                relLine = "  \(relFunc)(\(sanitizedFrom), \(sanitizedTo), \(ql), \(qt))"
            } else {
                relLine = "  \(relFunc)(\(sanitizedFrom), \(sanitizedTo), \(ql))"
            }

            if let desc = rel.description, !desc.isEmpty {
                let (qd, _) = MermaidExportHelpers.quote(desc)
                relLine += " $descr=\(qd)"
            }

            lines.append(relLine)
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // MARK: - C4 shape function names

    private static func c4ShapeFunction(_ type: C4ShapeType) -> String {
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

    // MARK: - C4 relationship function names

    private static func c4RelFunction(_ kind: C4RelationshipKind) -> String {
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
}

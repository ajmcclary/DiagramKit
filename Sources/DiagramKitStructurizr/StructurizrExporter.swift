import Foundation
import DiagramKitCommon
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
            return .unsupportedDiagram(formatName: name, type: document.type)
        }
    }
}

// MARK: - Structurizr C4 Export

enum StructurizrC4Export {

    static func emit(_ model: C4Diagram) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        // Sanitize aliases once. Mermaid permits aliases with characters that
        // the bundled Structurizr parser would split or reject (spaces, leading
        // digits, etc.). Build a stable rename map so element defs, relationship
        // endpoints, and view scopes all agree.
        var aliasMap: [String: String] = [:]
        var usedAliases: Set<String> = []
        for shape in model.shapes {
            let sanitized = uniqueSanitizedAlias(
                shape.alias,
                used: &usedAliases,
                diagnostics: &diagnostics
            )
            aliasMap[shape.alias] = sanitized
        }

        lines.append("workspace {")
        lines.append("  model {")

        // Partition boundaries by origin. .authored entries emit as `group { ... }`
        // blocks; .viewScopeSynthesized entries silently drop (the next import
        // re-derives them from the same view scope).
        //
        // SILENT-DROP(viewScopeSynthesized boundaries are re-derived from the
        // view scope on the next Structurizr import; round-trip-stable).
        // Pinned by: viewScopeBoundariesRoundTrip
        // Allowed under §4 of docs/diagnostic-severity-discipline.md.
        let authoredBoundaries = model.boundaries.filter { $0.origin == .authored }
        let authoredAliases = Set(authoredBoundaries.map(\.alias))
        let shapesByBoundary: [String: [C4Shape]] = Dictionary(grouping: model.shapes) { $0.parentBoundary }

        // Authored boundaries → `group "label" { ... }`. Nested authored boundaries
        // flatten to siblings with one `.warning` per dropped parent link. Empty
        // authored boundaries (no direct shape members) are dropped with a `.warning`.
        for boundary in authoredBoundaries {
            if !boundary.parentBoundary.isEmpty && boundary.parentBoundary != "global" {
                diagnostics.append(.lossyTransform(
                    .boundaryFlatten,
                    message: "Structurizr `group` is non-nestable; flattening boundary '\(boundary.alias)' (parent: '\(boundary.parentBoundary)') to top-level"
                ))
            }

            let members = shapesByBoundary[boundary.alias] ?? []
            if members.isEmpty {
                diagnostics.append(.lossyTransform(
                    .boundaryFlatten,
                    message: "Empty group '\(boundary.label)' (alias '\(boundary.alias)') has no direct shapes after Structurizr flattening; dropping"
                ))
                continue
            }

            lines.append("    group \"\(escape(boundary.label))\" {")
            for shape in members {
                emitShape(shape, indent: "      ", aliasMap: aliasMap, into: &lines, diagnostics: &diagnostics)
            }
            lines.append("    }")
        }

        // Root-level shapes (parentBoundary == "global", empty, or pointing at
        // a non-authored boundary like .viewScopeSynthesized) emit at the model
        // root, exactly as today.
        for shape in model.shapes {
            let parent = shape.parentBoundary
            if parent == "global" || parent.isEmpty || !authoredAliases.contains(parent) {
                emitShape(shape, indent: "    ", aliasMap: aliasMap, into: &lines, diagnostics: &diagnostics)
            }
        }

        // Relationships
        for rel in model.relationships {
            let from = aliasMap[rel.from] ?? rel.from
            let to = aliasMap[rel.to] ?? rel.to
            var relLine = "    \(from) -> \(to)"
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
        case .context: viewType = "systemContext"
        case .container: viewType = "container"
        case .component: viewType = "component"
        case .dynamic: viewType = "dynamic"
        case .deployment: viewType = "deployment"
        }

        // The current importer requires scoped views, so context/container/component
        // exports all use a software system alias when one is available.
        var systemOriginalAlias: String? = nil
        if model.kind == .context || model.kind == .container || model.kind == .component {
            systemOriginalAlias = model.shapes.first(where: { $0.typeC4Shape == .system })?.alias
        }
        let viewScopeOriginal = systemOriginalAlias ?? model.shapes.first?.alias
        let viewScopeAlias = viewScopeOriginal.flatMap { aliasMap[$0] } ?? viewScopeOriginal

        lines.append("  views {")
        if let scopeAlias = viewScopeAlias {
            lines.append("    \(viewType) \(scopeAlias) {")
            lines.append("      include *")
            lines.append("    }")
        }
        lines.append("  }")

        lines.append("}")

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func emitShape(
        _ shape: C4Shape,
        indent: String,
        aliasMap: [String: String],
        into lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let safeAlias = aliasMap[shape.alias] ?? shape.alias
        let stype = structurizrType(shape.typeC4Shape)
        let escapedLabel = escape(shape.label)
        let escapedDesc = shape.description.map { escape($0) } ?? ""

        if !escapedDesc.isEmpty {
            lines.append("\(indent)\(safeAlias) = \(stype) \"\(escapedLabel)\" \"\(escapedDesc)\"")
        } else {
            lines.append("\(indent)\(safeAlias) = \(stype) \"\(escapedLabel)\"")
        }

        if let tags = shape.tags, !tags.isEmpty {
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "Structurizr parser does not currently support element-scoped tags; dropping `tags \"\(tags)\"` for alias '\(shape.alias)'"
            ))
        }
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
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
    }

    /// Returns a parser-safe alias and, if rewriting was required, appends a
    /// `.warning` diagnostic explaining the rename. Matches the StructurizrLexer
    /// identifier grammar: first char letter/underscore; subsequent chars
    /// letter/digit/underscore/dot/slash/colon/hyphen.
    static func sanitizeStructurizrIdentifier(_ alias: String) -> String {
        guard !alias.isEmpty else { return "_" }
        var out = ""
        var isFirst = true
        for c in alias {
            if isFirst {
                if c.isLetter || c == "_" {
                    out.append(c)
                } else {
                    out.append("_")
                }
                isFirst = false
            } else {
                if c.isLetter || c.isNumber || c == "_" || c == "." || c == "/" || c == ":" || c == "-" {
                    out.append(c)
                } else {
                    out.append("_")
                }
            }
        }
        return out
    }

    private static func uniqueSanitizedAlias(
        _ original: String,
        used: inout Set<String>,
        diagnostics: inout [DiagramDiagnostic]
    ) -> String {
        let sanitized = sanitizeStructurizrIdentifier(original)
        var candidate = sanitized
        var counter = 2
        while used.contains(candidate) {
            candidate = "\(sanitized)_\(counter)"
            counter += 1
        }
        used.insert(candidate)
        if candidate != original {
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "Renamed alias '\(original)' to '\(candidate)' for Structurizr parser compatibility"
            ))
        }
        return candidate
    }
}

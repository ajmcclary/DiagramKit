import Foundation
import DiagramKitModel
import DiagramKitImport

/// Converts `StructurizrWorkspace` → `C4Diagram` plus diagnostics.
///
/// Builds a `StructurizrModelRegistry` from the model section, resolves
/// the first view against it, and maps elements to C4 types.
public struct StructurizrMapper: Sendable {

    public init() {}

    /// Map a parsed workspace to a `C4Diagram`.
    /// - Parameter workspace: The parsed Structurizr workspace AST.
    /// - Returns: A tuple of the mapped `C4Diagram` and any diagnostics.
    public func map(_ workspace: StructurizrWorkspace) -> (diagram: C4Diagram, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []

        // Build registry
        guard let model = workspace.model else {
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "workspace contains no model section"
            ))
            return (.empty, diagnostics)
        }

        let registry = StructurizrModelRegistry(
            elements: model.elements,
            relationships: model.relationships
        )

        // Build a stable alias for each unique group label encountered in the model.
        var groupAliasMap: [String: String] = [:]
        var usedGroupAliases: Set<String> = []
        for element in registry.elementsByAlias.values {
            guard let label = element.group, groupAliasMap[label] == nil else { continue }
            let alias = uniqueSanitizedGroupAlias(label, used: &usedGroupAliases)
            groupAliasMap[label] = alias
        }

        // Handle views
        if workspace.views.isEmpty {
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "workspace contains no views; no diagram produced"
            ))
            return (.empty, diagnostics)
        }

        // Multiple views diagnostic
        if workspace.views.count > 1 {
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "workspace contains \(workspace.views.count) views; only the first view is imported in this release"
            ))
        }

        let view = workspace.views[0]

        // Deferred view kinds
        switch view.kind {
        case .dynamic:
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "dynamic views not yet supported"
            ))
            return (.empty, diagnostics)
        case .deployment:
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "deployment views not yet supported"
            ))
            return (.empty, diagnostics)
        default:
            break
        }

        guard registry.element(for: view.scopeAlias) != nil else {
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "unknown view scope alias: \(view.scopeAlias)"
            ))
            return (.empty, diagnostics)
        }

        // Resolve visible elements
        var visibleAliases: Set<String>
        if view.includes.contains(.wildcard) {
            visibleAliases = registry.resolveWildcardInclude(
                scopeAlias: view.scopeAlias,
                viewKind: view.kind
            )
        } else {
            // Explicit includes
            var aliases: Set<String> = [view.scopeAlias]
            for include in view.includes {
                if case .element(let alias) = include {
                    if registry.element(for: alias) != nil {
                        aliases.insert(alias)
                    } else {
                        diagnostics.append(.featureDropped(
                            .diagramFamilyUnsupported,
                            message: "unknown included element alias: \(alias)"
                        ))
                    }
                }
            }
            visibleAliases = aliases
        }

        visibleAliases = visibleAliases.filter { alias in
            guard let element = registry.element(for: alias) else { return false }
            return element.kind != .deploymentNode
        }

        // Classify shapes vs boundaries
        let (shapeAliases, boundaryAliases) = registry.classifyViewElements(
            scopeAlias: view.scopeAlias,
            viewKind: view.kind,
            visibleAliases: visibleAliases
        )

        // Map to C4 diagram kind
        let diagramKind: C4DiagramKind
        switch view.kind {
        case .systemContext: diagramKind = .context
        case .container: diagramKind = .container
        case .component: diagramKind = .component
        default: diagramKind = .context
        }

        // Map shapes
        var c4Shapes: [C4Shape] = []
        for alias in shapeAliases {
            guard let element = registry.element(for: alias) else { continue }

            let shapeType = c4ShapeType(for: element.kind)
            let boundaryName: String

            // Determine parentBoundary
            if boundaryAliases.contains(element.parentAlias ?? "") {
                boundaryName = element.parentAlias ?? "global"
            } else if element.parentAlias != nil, shapeAliases.contains(alias) {
                // If parent is not a boundary (e.g., in systemContext view),
                // the shape goes at global level
                boundaryName = "global"
            } else if view.kind == .component {
                // Component view: components go inside the scope boundary
                if boundaryAliases.contains(view.scopeAlias) && element.parentAlias == view.scopeAlias {
                    boundaryName = view.scopeAlias
                } else {
                    boundaryName = "global"
                }
            } else if view.kind == .container {
                // Container view: containers go inside scope boundary
                if boundaryAliases.contains(view.scopeAlias) && element.parentAlias == view.scopeAlias {
                    boundaryName = view.scopeAlias
                } else {
                    boundaryName = "global"
                }
            } else {
                boundaryName = "global"
            }

            // Group tagging takes precedence over view-scope-derived boundaryName.
            var effectiveBoundary = boundaryName
            if let groupLabel = element.group, let groupAlias = groupAliasMap[groupLabel] {
                effectiveBoundary = groupAlias
            }

            let shape = C4Shape(
                alias: element.alias,
                label: element.name,
                typeC4Shape: shapeType,
                technology: element.technology,
                description: element.description,
                parentBoundary: effectiveBoundary
            )
            c4Shapes.append(shape)
        }

        // Map boundaries.
        //
        // Structurizr DSL has no first-class `Boundary(...)` macro; boundaries
        // are inferred from the view scope (see
        // StructurizrModelRegistry.classifyViewElements — container and
        // component views reclassify the scopeAlias element as a boundary).
        // When a diagram round-trips through Structurizr from a format that
        // does carry boundary metadata (e.g. Mermaid C4 `Boundary(alias,
        // label, descr)`), the original label/description cannot be recovered:
        // we surface the scope element's name/description instead. Emit a
        // .warning per synthesized boundary so the user can correlate with
        // the StructurizrExporter's drop diagnostic at the other end of the
        // round-trip.
        var c4Boundaries: [C4Boundary] = []

        // Authored boundaries from `group "..." { ... }` (appended first so
        // .authored entries precede .viewScopeSynthesized entries in the
        // resulting C4Diagram.boundaries list).
        for (label, alias) in groupAliasMap {
            c4Boundaries.append(C4Boundary(
                alias: alias,
                label: label,
                type: "group",
                parentBoundary: "global",
                origin: .authored
            ))
        }

        for alias in boundaryAliases {
            guard let element = registry.element(for: alias) else { continue }

            let boundary = C4Boundary(
                alias: element.alias,
                label: element.name,
                type: boundaryType(for: element.kind),
                description: element.description,
                parentBoundary: "global",
                origin: .viewScopeSynthesized
            )
            c4Boundaries.append(boundary)

            diagnostics.append(.lossyTransform(
                .boundaryFlatten,
                message: "Boundary '\(element.alias)' was synthesized from the Structurizr view scope; if the source originated as an authored boundary in another format, the original label/description may differ from '\(element.name)'"
            ))
        }

        // Map relationships — only those whose both endpoints are visible
        var c4Relationships: [C4Relationship] = []
        for rel in model.relationships {
            guard visibleAliases.contains(rel.source) && visibleAliases.contains(rel.target) else {
                continue
            }

            let c4Rel = C4Relationship(
                kind: .rel,
                from: rel.source,
                to: rel.target,
                label: rel.label ?? rel.description ?? "",
                technology: rel.technology,
                description: rel.description
            )
            c4Relationships.append(c4Rel)
        }

        // Deployment nodes diagnostic
        for element in model.elements {
            checkDeploymentNodes(element, &diagnostics)
        }

        // Tags diagnostic
        for element in model.elements {
            checkTags(element, &diagnostics)
        }

        // Title / description
        let title = view.title ?? view.scopeAlias
        let accDescr = view.description

        let c4Diagram = C4Diagram(
            kind: diagramKind,
            title: title,
            accDescr: accDescr,
            shapes: c4Shapes,
            boundaries: c4Boundaries,
            relationships: c4Relationships
        )

        return (c4Diagram, diagnostics)
    }

    // MARK: - Helpers

    private func c4ShapeType(for kind: StructurizrElementKind) -> C4ShapeType {
        switch kind {
        case .person: return .person
        case .softwareSystem: return .system
        case .container: return .container
        case .component: return .component
        case .deploymentNode: return .system  // fallback (will have diagnostic)
        }
    }

    private func boundaryType(for kind: StructurizrElementKind) -> String? {
        switch kind {
        case .softwareSystem: return "system"
        case .container: return "container"
        default: return nil
        }
    }

    private func checkDeploymentNodes(_ element: StructurizrModelElement, _ diagnostics: inout [DiagramDiagnostic]) {
        if element.kind == .deploymentNode {
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "deployment nodes not yet supported"
            ))
        }
        for child in element.children {
            checkDeploymentNodes(child, &diagnostics)
        }
    }

    private func checkTags(_ element: StructurizrModelElement, _ diagnostics: inout [DiagramDiagnostic]) {
        if !element.tags.isEmpty {
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "tag-based shape refinement not yet supported; rendered as base type"
            ))
        }
        for child in element.children {
            checkTags(child, &diagnostics)
        }
    }

    // MARK: - group alias helper

    private func uniqueSanitizedGroupAlias(
        _ label: String,
        used: inout Set<String>
    ) -> String {
        let sanitized = StructurizrC4Export.sanitizeStructurizrIdentifier(label)
        var candidate = sanitized
        var counter = 2
        while used.contains(candidate) {
            candidate = "\(sanitized)_\(counter)"
            counter += 1
        }
        used.insert(candidate)
        return candidate
    }
}

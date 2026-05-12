import Foundation

// MARK: - Model Registry

/// Registry that indexes model elements by alias for fast lookup.
/// Supports hierarchical parent-child traversal for view scoping.
public struct StructurizrModelRegistry: Sendable {
    /// All model elements indexed by alias (flattened: includes nested children).
    public let elementsByAlias: [String: StructurizrModelElement]
    /// All explicit relationships (model-level + scoped).
    public let relationships: [StructurizrRelationshipDef]

    public init(
        elements: [StructurizrModelElement],
        relationships: [StructurizrRelationshipDef] = []
    ) {
        var byAlias: [String: StructurizrModelElement] = [:]
        func collect(_ el: StructurizrModelElement) {
            byAlias[el.alias] = el
            for child in el.children { collect(child) }
        }
        for el in elements { collect(el) }
        self.elementsByAlias = byAlias
        self.relationships = relationships
    }

    /// Look up an element by alias.
    public func element(for alias: String) -> StructurizrModelElement? {
        elementsByAlias[alias]
    }

    /// All top-level elements (no parentAlias).
    public var topLevelElements: [StructurizrModelElement] {
        elementsByAlias.values.filter { $0.parentAlias == nil }
    }

    /// All aliases connected to `alias` via any relationship (source or target).
    public func connectedAliases(to alias: String) -> Set<String> {
        var result: Set<String> = []
        for rel in relationships {
            if rel.source == alias { result.insert(rel.target) }
            if rel.target == alias { result.insert(rel.source) }
        }
        return result
    }

    // MARK: - View resolution

    /// Resolve `include *` to a set of aliases visible in the view.
    /// Returns the aliases of elements that should appear in the diagram.
    public func resolveWildcardInclude(
        scopeAlias: String,
        viewKind: StructurizrViewKind
    ) -> Set<String> {
        guard let scopeElement = element(for: scopeAlias) else {
            return [scopeAlias]
        }

        // Always include the scope element
        var visible: Set<String> = [scopeAlias]

        // Collect all descendants of scope (for container/component views)
        let descendantAliases = collectDescendants(of: scopeElement)

        switch viewKind {
        case .systemContext:
            // Include all persons and softwareSystems connected to the scope
            let connected = connectedAliases(to: scopeAlias)
            for alias in connected {
                guard let el = element(for: alias) else { continue }
                switch el.kind {
                case .person, .softwareSystem:
                    visible.insert(alias)
                default:
                    break
                }
            }

        case .container:
            // Include scope's direct container children
            visible.formUnion(descendantAliases.filter { alias in
                guard let el = element(for: alias) else { return false }
                return el.kind == .container
            })

            // Include all persons and external softwareSystems connected to scope or its containers
            var allRelevant = visible
            for alias in visible {
                for connected in connectedAliases(to: alias) {
                    guard let el = element(for: connected) else { continue }
                    switch el.kind {
                    case .person, .softwareSystem:
                        allRelevant.insert(connected)
                    default:
                        break
                    }
                }
            }
            visible = allRelevant

        case .component:
            // Include parent softwareSystem (scope's parent)
            if let parentAlias = scopeElement.parentAlias {
                visible.insert(parentAlias)
            }

            // Include scope's direct component children
            visible.formUnion(descendantAliases.filter { alias in
                guard let el = element(for: alias) else { return false }
                return el.kind == .component
            })

            // Include all persons and containers connected to scope or its components
            var allRelevant = visible
            for alias in visible {
                for connected in connectedAliases(to: alias) {
                    guard let el = element(for: connected) else { continue }
                    switch el.kind {
                    case .person, .container:
                        allRelevant.insert(connected)
                    default:
                        break
                    }
                }
            }
            visible = allRelevant

        case .dynamic, .deployment:
            break
        }

        return visible
    }

    // MARK: - Helpers

    private func collectDescendants(of element: StructurizrModelElement) -> Set<String> {
        var result: Set<String> = []
        func walk(_ el: StructurizrModelElement) {
            for child in el.children {
                result.insert(child.alias)
                walk(child)
            }
        }
        walk(element)
        return result
    }

    /// Determine which aliases should be shapes vs boundaries in the diagram.
    /// Returns (shapeAliases, boundaryAliases).
    public func classifyViewElements(
        scopeAlias: String,
        viewKind: StructurizrViewKind,
        visibleAliases: Set<String>
    ) -> (shapes: Set<String>, boundaries: Set<String>) {
        switch viewKind {
        case .systemContext:
            // Scope is a shape, no boundary
            return (visibleAliases, [])

        case .container:
            // Scope softwareSystem is a boundary, its containers are shapes
            var shapes = visibleAliases
            shapes.remove(scopeAlias)
            return (shapes, [scopeAlias])

        case .component:
            // Scope container is a boundary, its components are shapes
            var shapes = visibleAliases
            shapes.remove(scopeAlias)
            // The parent softwareSystem (if present) stays as a shape
            return (shapes, [scopeAlias])

        case .dynamic, .deployment:
            return (visibleAliases, [])
        }
    }
}

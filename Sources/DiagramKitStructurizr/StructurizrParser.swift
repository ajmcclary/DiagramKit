import Foundation
import DiagramKitModel
import DiagramKitImport

/// Recursive-descent parser for the narrow Structurizr DSL subset.
///
/// Consumes `[StructurizrToken]` from `StructurizrLexer`, returns
/// `(StructurizrWorkspace, [DiagramDiagnostic])`.
public struct StructurizrParser: Sendable {

    public init() {}

    // MARK: - Public entry point

    public func parse(_ tokens: [StructurizrToken]) throws -> (workspace: StructurizrWorkspace, diagnostics: [DiagramDiagnostic]) {
        var s = StructurizrParserState(tokens: tokens)
        let workspace = try parseWorkspace(&s)
        return (workspace, s.diagnostics)
    }

    // MARK: - workspace

    private func parseWorkspace(_ s: inout StructurizrParserState) throws -> StructurizrWorkspace {
        guard let keyword = s.consumeIdentifier(), keyword == "workspace" else {
            throw DiagramError.notYetImplemented("Structurizr source must start with 'workspace'")
        }
        let name = s.consumeString()
        let description = s.consumeString()
        guard s.peek() == .openBrace else {
            throw DiagramError.notYetImplemented("Expected '{' after workspace declaration")
        }
        _ = s.advance()

        var model: StructurizrModel?
        var views: [StructurizrView] = []

        while let token = s.peek() {
            if token == .closeBrace { break }
            switch token {
            case .identifier("model"): model = try parseModel(&s)
            case .identifier("views"): views = try parseViews(&s)
            case .bang:
                _ = s.advance()
                if let directive = s.consumeIdentifier() { s.skipDirective(directive: directive) }
            case .identifier("tags"):
                s.skipTags()
            case .identifier(let word):
                s.diagnostic("unknown top-level statement: \(word)")
                _ = s.advance()
            default:
                s.diagnostic("unexpected token in workspace body")
                _ = s.advance()
            }
        }

        guard s.peek() == .closeBrace else {
            throw DiagramError.notYetImplemented("Unbalanced braces in workspace: missing '}'")
        }
        _ = s.advance()
        return StructurizrWorkspace(name: name, description: description, model: model, views: views)
    }

    // MARK: - model

    private func parseModel(_ s: inout StructurizrParserState) throws -> StructurizrModel {
        _ = s.advance() // "model"
        guard s.peek() == .openBrace else {
            throw DiagramError.notYetImplemented("Expected '{' after 'model'")
        }
        _ = s.advance()

        var elements: [StructurizrModelElement] = []
        var relationships: [StructurizrRelationshipDef] = []

        while let token = s.peek() {
            if token == .closeBrace { break }
            if case .identifier("tags") = token { s.skipTags(); continue }
            if case .bang = token {
                _ = s.advance()
                if let directive = s.consumeIdentifier() { s.skipDirective(directive: directive) }
                continue
            }
            if case .identifier = token {
                if s.peekAhead(1) == .equals {
                    if let el = try parseElementDef(&s, parentAlias: nil, scopedRelationships: &relationships) {
                        elements.append(el)
                    }
                    continue
                }
                if s.peekAhead(1) == .arrow {
                    if let rel = try parseRelationshipDef(&s) { relationships.append(rel) }
                    continue
                }
                if let word = s.consumeIdentifier() { s.diagnostic("unexpected model statement: \(word)") }
                continue
            }
            _ = s.advance()
        }

        guard s.peek() == .closeBrace else {
            throw DiagramError.notYetImplemented("Unbalanced braces in model: missing '}'")
        }
        _ = s.advance()
        return StructurizrModel(elements: elements, relationships: relationships)
    }

    // MARK: - element_def

    private func parseElementDef(
        _ s: inout StructurizrParserState,
        parentAlias: String?,
        scopedRelationships: inout [StructurizrRelationshipDef]
    ) throws -> StructurizrModelElement? {
        guard let alias = s.consumeIdentifier(), s.peek() == .equals else { return nil }
        _ = s.advance() // '='

        guard let kindName = s.consumeIdentifier() else {
            throw DiagramError.notYetImplemented("Expected element kind after '='")
        }

        let kind: StructurizrElementKind
        switch kindName {
        case "person": kind = .person
        case "softwareSystem": kind = .softwareSystem
        case "container": kind = .container
        case "component": kind = .component
        case "deploymentNode":
            kind = .deploymentNode
            s.diagnostic("deployment nodes not yet supported")
        default:
            throw DiagramError.notYetImplemented("Unknown element kind: '\(kindName)'")
        }

        guard let name = s.consumeString() else {
            throw DiagramError.notYetImplemented("Expected element name string after '\(kindName)'")
        }

        let description: String?
        let technology: String?
        switch kind {
        case .person, .softwareSystem:
            description = s.consumeString()
            technology = nil
        case .container, .component, .deploymentNode:
            let second = s.consumeString()
            if let d = second { description = d; technology = s.consumeString() }
            else { description = nil; technology = nil }
        }

        var children: [StructurizrModelElement] = []
        if s.peek() == .openBrace {
            _ = s.advance()
            while let token = s.peek() {
                if token == .closeBrace { break }
                if case .identifier("tags") = token { s.skipTags(); continue }
                if case .bang = token {
                    _ = s.advance()
                    if let directive = s.consumeIdentifier() { s.skipDirective(directive: directive) }
                    continue
                }
                if case .identifier = token {
                    if s.peekAhead(1) == .equals {
                        if let child = try parseElementDef(&s, parentAlias: alias, scopedRelationships: &scopedRelationships) {
                            children.append(child)
                        }
                        continue
                    }
                    if s.peekAhead(1) == .arrow {
                        if let rel = try parseRelationshipDef(&s) { scopedRelationships.append(rel) }
                        continue
                    }
                    if let word = s.consumeIdentifier() { s.diagnostic("unexpected statement in element block: \(word)") }
                    continue
                }
                _ = s.advance()
            }
            guard s.peek() == .closeBrace else {
                throw DiagramError.notYetImplemented("Unbalanced braces in element block: missing '}'")
            }
            _ = s.advance()
        }

        return StructurizrModelElement(
            alias: alias, kind: kind, name: name,
            description: description, technology: technology,
            tags: [], parentAlias: parentAlias, children: children
        )
    }

    // MARK: - relationship_def

    private func parseRelationshipDef(_ s: inout StructurizrParserState) throws -> StructurizrRelationshipDef? {
        guard let source = s.consumeIdentifier(), s.peek() == .arrow else { return nil }
        _ = s.advance()
        guard let target = s.consumeIdentifier() else {
            throw DiagramError.notYetImplemented("Expected target identifier after '->'")
        }
        let label = s.consumeString()
        let technology = s.consumeString()
        let description = s.consumeString()
        return StructurizrRelationshipDef(
            source: source, target: target, label: label,
            technology: technology, description: description, tags: []
        )
    }

    // MARK: - views

    private func parseViews(_ s: inout StructurizrParserState) throws -> [StructurizrView] {
        _ = s.advance() // "views"
        guard s.peek() == .openBrace else {
            throw DiagramError.notYetImplemented("Expected '{' after 'views'")
        }
        _ = s.advance()

        var views: [StructurizrView] = []

        while let token = s.peek() {
            if token == .closeBrace { break }
            guard case .identifier(let word) = token else { _ = s.advance(); continue }

            let viewKind: StructurizrViewKind?
            switch word {
            case "systemContext": viewKind = .systemContext
            case "container": viewKind = .container
            case "component": viewKind = .component
            case "dynamic": viewKind = .dynamic; s.diagnostic("dynamic views not yet supported")
            case "deployment": viewKind = .deployment; s.diagnostic("deployment views not yet supported")
            default:
                viewKind = nil
                s.diagnostic("unknown view kind: \(word)")
                _ = s.advance()
                s.skipBlock()
                continue
            }
            _ = s.advance()

            guard let scopeAlias = s.consumeIdentifier() else {
                throw DiagramError.notYetImplemented("Expected scope alias after view kind")
            }
            let title = s.consumeString()
            let description = s.consumeString()

            guard s.peek() == .openBrace else {
                throw DiagramError.notYetImplemented("Expected '{' after view declaration")
            }
            _ = s.advance()

            var includes: [StructurizrViewInclude] = []
            var autoLayout = false

            while let innerToken = s.peek() {
                if innerToken == .closeBrace { break }
                guard case .identifier(let vw) = innerToken else { _ = s.advance(); continue }

                switch vw {
                case "include":
                    _ = s.advance()
                    if s.peek() == .star { includes.append(.wildcard); _ = s.advance() }
                    else if let en = s.consumeIdentifier() { includes.append(.element(en)) }
                    else { s.diagnostic("expected '*' or element alias after 'include'") }
                case "autoLayout":
                    _ = s.advance(); autoLayout = true
                    s.diagnostic("autoLayout configuration not yet supported")
                    if s.peek() == .openBrace { s.skipBlock() }
                case "animation":
                    _ = s.advance()
                    s.diagnostic("animation configuration not yet supported")
                    if s.peek() == .openBrace { s.skipBlock() }
                case "styles":
                    _ = s.advance()
                    s.diagnostic("custom styles not yet supported")
                    if s.peek() == .openBrace { s.skipBlock() }
                case "exclude":
                    _ = s.advance()
                    s.diagnostic("exclude directive not yet supported")
                    _ = s.consumeIdentifier()
                case "tags":
                    _ = s.advance()
                    s.diagnostic("tag-based relationship styling not yet supported")
                    _ = s.consumeString()
                default:
                    s.diagnostic("unsupported view statement: \(vw)")
                    _ = s.advance()
                    if s.peek() == .openBrace { s.skipBlock() }
                }
            }

            guard s.peek() == .closeBrace else {
                throw DiagramError.notYetImplemented("Unbalanced braces in view: missing '}'")
            }
            _ = s.advance()

            if let kind = viewKind {
                views.append(StructurizrView(
                    kind: kind, scopeAlias: scopeAlias, title: title,
                    description: description, includes: includes, autoLayout: autoLayout
                ))
            }
        }

        guard s.peek() == .closeBrace else {
            throw DiagramError.notYetImplemented("Unbalanced braces in views: missing '}'")
        }
        _ = s.advance()
        return views
    }
}

import Foundation

// MARK: - Top-level workspace

/// Top-level: a complete Structurizr workspace definition.
public struct StructurizrWorkspace: Sendable {
    public var name: String?
    public var description: String?
    public var model: StructurizrModel?
    public var views: [StructurizrView]

    public init(
        name: String? = nil,
        description: String? = nil,
        model: StructurizrModel? = nil,
        views: [StructurizrView] = []
    ) {
        self.name = name
        self.description = description
        self.model = model
        self.views = views
    }
}

// MARK: - Model

/// The model section: all element definitions and relationships.
public struct StructurizrModel: Sendable {
    public var elements: [StructurizrModelElement]
    public var relationships: [StructurizrRelationshipDef]

    public init(
        elements: [StructurizrModelElement] = [],
        relationships: [StructurizrRelationshipDef] = []
    ) {
        self.elements = elements
        self.relationships = relationships
    }
}

// MARK: - Model element

/// A single model element (person, softwareSystem, container, component).
public struct StructurizrModelElement: Sendable {
    public var alias: String
    public var kind: StructurizrElementKind
    public var name: String
    public var description: String?
    public var technology: String?
    public var tags: [String]
    public var parentAlias: String?
    public var children: [StructurizrModelElement]

    public init(
        alias: String,
        kind: StructurizrElementKind,
        name: String,
        description: String? = nil,
        technology: String? = nil,
        tags: [String] = [],
        parentAlias: String? = nil,
        children: [StructurizrModelElement] = []
    ) {
        self.alias = alias
        self.kind = kind
        self.name = name
        self.description = description
        self.technology = technology
        self.tags = tags
        self.parentAlias = parentAlias
        self.children = children
    }
}

public enum StructurizrElementKind: Sendable, Equatable {
    case person
    case softwareSystem
    case container
    case component
    case deploymentNode
}

// MARK: - Relationship

/// An explicit relationship definition from the model section or element block.
public struct StructurizrRelationshipDef: Sendable {
    public var source: String
    public var target: String
    public var label: String?
    public var technology: String?
    public var description: String?
    public var tags: [String]

    public init(
        source: String,
        target: String,
        label: String? = nil,
        technology: String? = nil,
        description: String? = nil,
        tags: [String] = []
    ) {
        self.source = source
        self.target = target
        self.label = label
        self.technology = technology
        self.description = description
        self.tags = tags
    }
}

// MARK: - View

/// A single view definition from the views section.
public struct StructurizrView: Sendable {
    public var kind: StructurizrViewKind
    public var scopeAlias: String
    public var title: String?
    public var description: String?
    public var includes: [StructurizrViewInclude]
    public var autoLayout: Bool

    public init(
        kind: StructurizrViewKind,
        scopeAlias: String,
        title: String? = nil,
        description: String? = nil,
        includes: [StructurizrViewInclude] = [],
        autoLayout: Bool = false
    ) {
        self.kind = kind
        self.scopeAlias = scopeAlias
        self.title = title
        self.description = description
        self.includes = includes
        self.autoLayout = autoLayout
    }
}

public enum StructurizrViewKind: Sendable, Equatable {
    case systemContext
    case container
    case component
    case dynamic
    case deployment
}

/// A single include directive within a view.
public enum StructurizrViewInclude: Sendable, Equatable {
    case wildcard
    case element(String)
}

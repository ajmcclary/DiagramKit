import Foundation

/// AST for a PlantUML class diagram body (text between
/// `@startuml`/`@enduml`).
///
/// Captures classes, member declarations, relationships, and notes
/// with enough detail for `PlantUMLClassMapper` to emit a
/// `ClassDiagram` payload. Advanced features (stereotypes, generics,
/// hidden members, packages) are accepted as raw text or rejected
/// with a `.unsupported` diagnostic upstream.
public struct PlantUMLClassAST: Sendable {
    public var classes: [PlantUMLClassDecl]
    public var relationships: [PlantUMLClassRelationship]
    public var notes: [PlantUMLClassNote]
    public var packages: [PlantUMLPackageDecl]
    public var unsupportedLines: [String]

    public init(
        classes: [PlantUMLClassDecl] = [],
        relationships: [PlantUMLClassRelationship] = [],
        notes: [PlantUMLClassNote] = [],
        packages: [PlantUMLPackageDecl] = [],
        unsupportedLines: [String] = []
    ) {
        self.classes = classes
        self.relationships = relationships
        self.notes = notes
        self.packages = packages
        self.unsupportedLines = unsupportedLines
    }
}

public struct PlantUMLPackageDecl: Sendable, Equatable {
    public var name: String
    public var displayName: String?
    public var classIds: [String]

    public init(name: String, displayName: String? = nil, classIds: [String] = []) {
        self.name = name
        self.displayName = displayName
        self.classIds = classIds
    }
}

public struct PlantUMLClassDecl: Sendable {
    public enum Kind: String, Sendable {
        case classDecl
        case interfaceDecl
        case abstractDecl
        case enumDecl
        case annotationDecl
    }
    public var kind: Kind
    public var name: String
    /// Optional display label (PlantUML supports `class "Display" as Alias`).
    public var label: String?
    /// Free-form stereotype text from `<<stereotype>>` decoration. Multiple
    /// stereotype markers join with a comma-space separator.
    public var stereotype: String?
    /// Name of the enclosing `package` block, if the class declaration
    /// appeared inside one.
    public var packageName: String?
    public var members: [PlantUMLClassMember]

    public init(
        kind: Kind,
        name: String,
        label: String? = nil,
        stereotype: String? = nil,
        packageName: String? = nil,
        members: [PlantUMLClassMember] = []
    ) {
        self.kind = kind
        self.name = name
        self.label = label
        self.stereotype = stereotype
        self.packageName = packageName
        self.members = members
    }
}

public struct PlantUMLClassMember: Sendable {
    public enum Visibility: String, Sendable {
        case publicVis = "+"
        case privateVis = "-"
        case protectedVis = "#"
        case packageVis = "~"
        case none = ""
    }
    public enum Kind: String, Sendable {
        case field
        case method
    }
    public var visibility: Visibility
    public var kind: Kind
    /// Identifier (field name or method name without parens).
    public var identifier: String
    /// Method parameter list as raw text (no parens). Empty for fields.
    public var parameters: String
    /// Return type / field type. Empty if unspecified.
    public var typeAnnotation: String

    public init(
        visibility: Visibility,
        kind: Kind,
        identifier: String,
        parameters: String = "",
        typeAnnotation: String = ""
    ) {
        self.visibility = visibility
        self.kind = kind
        self.identifier = identifier
        self.parameters = parameters
        self.typeAnnotation = typeAnnotation
    }
}

public struct PlantUMLClassRelationship: Sendable {
    public var leftId: String
    public var rightId: String
    /// Endpoint shape on the left side.
    public var leftEndpoint: PlantUMLEndpointShape
    /// Endpoint shape on the right side.
    public var rightEndpoint: PlantUMLEndpointShape
    public var lineStyle: PlantUMLLineStyle
    public var label: String?
    public var leftCardinality: String?
    public var rightCardinality: String?

    public init(
        leftId: String,
        rightId: String,
        leftEndpoint: PlantUMLEndpointShape,
        rightEndpoint: PlantUMLEndpointShape,
        lineStyle: PlantUMLLineStyle,
        label: String? = nil,
        leftCardinality: String? = nil,
        rightCardinality: String? = nil
    ) {
        self.leftId = leftId
        self.rightId = rightId
        self.leftEndpoint = leftEndpoint
        self.rightEndpoint = rightEndpoint
        self.lineStyle = lineStyle
        self.label = label
        self.leftCardinality = leftCardinality
        self.rightCardinality = rightCardinality
    }
}

/// The shape at one end of a PlantUML class arrow.
///
/// Matches the syntax appearing immediately adjacent to the line
/// (`<|`, `*`, `o`, `<`, `>`, etc.) — independent of line style.
public enum PlantUMLEndpointShape: String, Sendable {
    case none           // no decoration
    case inheritance    // `<|` / `|>` (triangle)
    case composition    // `*`
    case aggregation    // `o`
    case dependency     // `<` / `>` (open arrow)
}

public enum PlantUMLLineStyle: String, Sendable {
    case solid
    case dotted // `..`
}

public struct PlantUMLClassNote: Sendable {
    /// The class alias the note is attached to (`note left of X`),
    /// or nil for standalone notes.
    public var attachedTo: String?
    /// "left", "right", "top", "bottom", or nil.
    public var position: String?
    public var text: String

    public init(attachedTo: String? = nil, position: String? = nil, text: String) {
        self.attachedTo = attachedTo
        self.position = position
        self.text = text
    }
}

import Foundation

/// AST for a PlantUML C4 diagram body. Captures the high-level macro
/// invocations plus an unsupported-lines bin for diagnostics.
public struct PlantUMLC4AST: Sendable {
    public var declarations: [PlantUMLC4Declaration]
    public var relationships: [PlantUMLC4Relationship]
    public var unsupportedLines: [String]

    public init(
        declarations: [PlantUMLC4Declaration] = [],
        relationships: [PlantUMLC4Relationship] = [],
        unsupportedLines: [String] = []
    ) {
        self.declarations = declarations
        self.relationships = relationships
        self.unsupportedLines = unsupportedLines
    }
}

public struct PlantUMLC4Declaration: Sendable {
    public var macro: String
    public var alias: String
    public var label: String
    public var technology: String?
    public var description: String?

    public init(macro: String, alias: String, label: String, technology: String? = nil, description: String? = nil) {
        self.macro = macro
        self.alias = alias
        self.label = label
        self.technology = technology
        self.description = description
    }
}

public struct PlantUMLC4Relationship: Sendable {
    public var macro: String
    public var from: String
    public var to: String
    public var label: String
    public var technology: String?

    public init(macro: String, from: String, to: String, label: String, technology: String? = nil) {
        self.macro = macro
        self.from = from
        self.to = to
        self.label = label
        self.technology = technology
    }
}

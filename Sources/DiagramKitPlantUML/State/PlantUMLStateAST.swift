import Foundation

/// AST for a PlantUML state/activity diagram body (text between
/// `@startuml`/`@enduml`).
public struct PlantUMLStateAST: Sendable {
    public var states: [PlantUMLStateDecl]
    public var transitions: [PlantUMLStateTransition]
    public var notes: [PlantUMLStateNote]
    public var unsupportedLines: [String]

    public init(
        states: [PlantUMLStateDecl] = [],
        transitions: [PlantUMLStateTransition] = [],
        notes: [PlantUMLStateNote] = [],
        unsupportedLines: [String] = []
    ) {
        self.states = states
        self.transitions = transitions
        self.notes = notes
        self.unsupportedLines = unsupportedLines
    }
}

public struct PlantUMLStateDecl: Sendable {
    public var id: String
    /// Display label (`state Idle : Waiting`). Empty if not provided.
    public var label: String
    /// Composite-state children (nested PlantUMLStateAST). Nil for simple
    /// states.
    public var children: PlantUMLStateAST?

    public init(id: String, label: String = "", children: PlantUMLStateAST? = nil) {
        self.id = id
        self.label = label
        self.children = children
    }
}

public struct PlantUMLStateTransition: Sendable {
    /// Source state id, or "[*]" for the initial pseudostate.
    public var source: String
    /// Target state id, or "[*]" for the final pseudostate.
    public var target: String
    public var label: String?

    public init(source: String, target: String, label: String? = nil) {
        self.source = source
        self.target = target
        self.label = label
    }
}

public struct PlantUMLStateNote: Sendable {
    public var attachedTo: String?
    public var position: String?
    public var text: String

    public init(attachedTo: String? = nil, position: String? = nil, text: String) {
        self.attachedTo = attachedTo
        self.position = position
        self.text = text
    }
}

/// Root AST for a PlantUML sequence diagram body.
public struct PlantUMLSequenceAST: Sendable, Equatable {
    public var participants: [PlantUMLParticipant]
    public var items: [PlantUMLSequenceItem]
    public var hasAutoNumber: Bool

    public init(
        participants: [PlantUMLParticipant] = [],
        items: [PlantUMLSequenceItem] = [],
        hasAutoNumber: Bool = false
    ) {
        self.participants = participants
        self.items = items
        self.hasAutoNumber = hasAutoNumber
    }
}

public struct PlantUMLParticipant: Sendable, Equatable {
    public var kind: PlantUMLParticipantKind
    public var alias: String
    public var displayName: String?
    public var boxName: String?

    public init(
        kind: PlantUMLParticipantKind = .participant,
        alias: String,
        displayName: String? = nil,
        boxName: String? = nil
    ) {
        self.kind = kind
        self.alias = alias
        self.displayName = displayName
        self.boxName = boxName
    }
}

public enum PlantUMLParticipantKind: String, Sendable, Equatable {
    case participant
    case actor
}

public enum PlantUMLSequenceItem: Sendable, Equatable {
    case message(PlantUMLSequenceMessage)
    case note(PlantUMLSequenceNote)
    case activate(String)            // target alias
    case deactivate(String)          // target alias
    case groupStart(String, kind: PlantUMLGroupKind)
    case groupEnd
    case divergent(String)           // else label
    case autoNumberStart
    case autoNumberStop
    case unsupported(String, line: Int)
}

public struct PlantUMLSequenceMessage: Sendable, Equatable {
    public var from: String
    public var to: String
    public var arrow: PlantUMLArrowType
    public var label: String?

    public init(from: String, to: String, arrow: PlantUMLArrowType = .solid, label: String? = nil) {
        self.from = from
        self.to = to
        self.arrow = arrow
        self.label = label
    }
}

public enum PlantUMLArrowType: Sendable, Equatable {
    case solid           // ->
    case dotted          // -->
    case open            // ->>
    case circle          // ->o
    case cross           // ->x
    case bidirectional   // <->

    /// Parse from the arrow string portion (e.g., "->", "-->", "->>").
    public static func parse(_ arrow: String) -> PlantUMLArrowType? {
        switch arrow {
        case "->":  return .solid
        case "-->": return .dotted
        case "->>": return .open
        case "->o": return .circle
        case "->x": return .cross
        case "<->": return .bidirectional
        default: return nil
        }
    }
}

public enum PlantUMLGroupKind: String, Sendable, Equatable {
    case alt
    case loop
    case opt
    case group
    case box
}

public struct PlantUMLSequenceNote: Sendable, Equatable {
    public var position: PlantUMLNotePosition
    public var targets: [String]     // participant aliases
    public var text: String

    public init(position: PlantUMLNotePosition, targets: [String], text: String) {
        self.position = position
        self.targets = targets
        self.text = text
    }
}

public enum PlantUMLNotePosition: String, Sendable, Equatable {
    case left
    case right
    case over
}

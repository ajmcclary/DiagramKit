import Foundation

/// Top-level: a d2 document is a list of statements.
public struct D2Document: Sendable {
    public var statements: [D2Statement]

    public init(statements: [D2Statement] = []) {
        self.statements = statements
    }
}

public enum D2Statement: Sendable {
    case nodeDefinition(D2NodeDefinition)      // `name: value` or `name { ... }`
    case edgeDefinition(D2EdgeDefinition)      // `A -> B` or `A -> B: label`
    case containerOpen(D2ContainerOpen)        // `name {`
    case containerClose                        // `}`
}

public struct D2NodeDefinition: Sendable {
    public var id: String                    // key name
    public var label: String?                // value (if scalar string)
    public var shape: String?                // from `shape: <name>`
    public var direction: String?            // from `direction: right`
    public var tooltip: String?              // from `tooltip: ...`
    public var link: String?                 // from `link: ...`
    public var icon: String?                 // from `icon: ...`
    public var width: Double?                // from `width: N`
    public var height: Double?               // from `height: N`

    public init(
        id: String,
        label: String? = nil,
        shape: String? = nil,
        direction: String? = nil,
        tooltip: String? = nil,
        link: String? = nil,
        icon: String? = nil,
        width: Double? = nil,
        height: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.shape = shape
        self.direction = direction
        self.tooltip = tooltip
        self.link = link
        self.icon = icon
        self.width = width
        self.height = height
    }
}

public struct D2EdgeDefinition: Sendable {
    public var source: String
    public var target: String
    public var label: String?                // value after the edge
    public var sourceArrow: Bool             // `<` prefix on source
    public var targetArrow: Bool             // `>` suffix on target
    public var edgeKind: D2EdgeKind

    public init(
        source: String,
        target: String,
        label: String? = nil,
        sourceArrow: Bool = false,
        targetArrow: Bool = true,
        edgeKind: D2EdgeKind = .directional
    ) {
        self.source = source
        self.target = target
        self.label = label
        self.sourceArrow = sourceArrow
        self.targetArrow = targetArrow
        self.edgeKind = edgeKind
    }
}

public enum D2EdgeKind: Sendable {
    case directional                  // `->`
    case bidirectional                // `<->`
    case undirected                   // `--`
}

public struct D2ContainerOpen: Sendable {
    public var id: String
    public var label: String?                // value after colon on same line as `{`

    public init(id: String, label: String? = nil) {
        self.id = id
        self.label = label
    }
}

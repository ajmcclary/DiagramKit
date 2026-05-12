import Foundation

// MARK: - Top-level document

/// Top-level: a DOT document is a graph or digraph with a list of statements.
public struct DOTDocument: Sendable {
    public var kind: DOTGraphKind          // graph or digraph
    public var strict: Bool                // strict graph / strict digraph
    public var id: String?                 // graph name (optional in DOT)
    public var statements: [DOTStatement]

    public init(kind: DOTGraphKind, strict: Bool = false,
                id: String? = nil, statements: [DOTStatement] = []) {
        self.kind = kind
        self.strict = strict
        self.id = id
        self.statements = statements
    }
}

public enum DOTGraphKind: Sendable {
    case graph                             // undirected
    case digraph                           // directed
}

// MARK: - Statements

public enum DOTStatement: Sendable {
    case nodeStatement(DOTNodeStatement)       // `A;` or `A [attr=val];`
    case edgeStatement(DOTEdgeStatement)       // `A -> B;` or `A -- B;`
    case attrStatement(DOTAttrStatement)       // `node [shape=box];` or `edge [color=red];`
    case subgraph(DOTSubgraph)                 // `subgraph cluster_0 { ... }`
    case graphAttr(String, String)             // graph-level key=value (e.g., rankdir)
}

// MARK: - Node statement

public struct DOTNodeStatement: Sendable {
    public var id: String
    public var attributes: [DOTAttribute]
    public var label: String? { attributes.first(where: { $0.key == "label" })?.value }

    public init(id: String, attributes: [DOTAttribute] = []) {
        self.id = id
        self.attributes = attributes
    }
}

// MARK: - Edge statement

public struct DOTEdgeStatement: Sendable {
    public var source: String
    public var target: String
    public var directed: Bool                  // true for `->`, false for `--`
    public var attributes: [DOTAttribute]
    public var label: String? { attributes.first(where: { $0.key == "label" })?.value }

    public init(source: String, target: String,
                directed: Bool = true, attributes: [DOTAttribute] = []) {
        self.source = source
        self.target = target
        self.directed = directed
        self.attributes = attributes
    }
}

// MARK: - Attribute statement (default assignment)

public struct DOTAttrStatement: Sendable {
    public var target: DOTAttrTarget           // node, edge, or graph
    public var attributes: [DOTAttribute]

    public init(target: DOTAttrTarget, attributes: [DOTAttribute]) {
        self.target = target
        self.attributes = attributes
    }
}

public enum DOTAttrTarget: Sendable {
    case node                                // `node [shape=box]`
    case edge                                // `edge [color=red]`
    case graph                               // `graph [rankdir=LR]`
}

// MARK: - Subgraph

public struct DOTSubgraph: Sendable {
    public var id: String?                     // e.g., "cluster_0" (nil for anonymous)
    public var statements: [DOTStatement]

    public init(id: String? = nil, statements: [DOTStatement] = []) {
        self.id = id
        self.statements = statements
    }

    /// True when this subgraph's id starts with "cluster_" — DOT convention
    /// for clusters that render as named containers.
    public var isCluster: Bool {
        id?.hasPrefix("cluster_") ?? false
    }

    /// The display label for this subgraph. Derived from `label` attribute
    /// on a graph-level attr statement within the subgraph, or from the id
    /// itself (stripping `cluster_` prefix).
    public func displayLabel(from attributes: [DOTAttribute]) -> String? {
        attributes.first(where: { $0.key == "label" })?.value
            ?? id.map { $0.hasPrefix("cluster_") ? String($0.dropFirst(8)) : $0 }
    }
}

// MARK: - Attribute

public struct DOTAttribute: Sendable, Hashable {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

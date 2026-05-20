import Foundation
import DiagramKitModel

/// Typed AST for a PlantUML deployment-diagram body. Built by
/// `PlantUMLDeploymentParser` and consumed by `PlantUMLDeploymentMapper`.
public struct PlantUMLDeploymentAST: Sendable, Equatable {
    public var title: String?
    public var roots: [Node]
    public var edges: [Edge]
    public var notes: [NoteAttachment]
    public var legend: String?

    public init(
        title: String? = nil,
        roots: [Node] = [],
        edges: [Edge] = [],
        notes: [NoteAttachment] = [],
        legend: String? = nil
    ) {
        self.title = title
        self.roots = roots
        self.edges = edges
        self.notes = notes
        self.legend = legend
    }

    public indirect enum Node: Sendable, Equatable {
        case shape(Shape)
        case group(Group)
    }

    public struct Shape: Sendable, Equatable {
        public var id: String
        public var label: String?
        public var kind: ArchitectureServiceKind
        public var stereotype: String?
        public var color: String?

        public init(
            id: String, label: String?, kind: ArchitectureServiceKind,
            stereotype: String? = nil, color: String? = nil
        ) {
            self.id = id
            self.label = label
            self.kind = kind
            self.stereotype = stereotype
            self.color = color
        }
    }

    public struct Group: Sendable, Equatable {
        public var id: String
        public var label: String?
        public var kind: ArchitectureServiceKind
        public var stereotype: String?
        public var color: String?
        public var children: [Node]

        public init(
            id: String, label: String?, kind: ArchitectureServiceKind,
            stereotype: String? = nil, color: String? = nil,
            children: [Node] = []
        ) {
            self.id = id
            self.label = label
            self.kind = kind
            self.stereotype = stereotype
            self.color = color
            self.children = children
        }
    }

    public enum EdgeDirection: String, Sendable, Equatable {
        case forward     // -->
        case backward    // <--
        case both        // <-->
    }

    public enum EdgeStyle: String, Sendable, Equatable {
        case solid       // -->
        case dashed      // ..>
    }

    public struct Edge: Sendable, Equatable {
        public var lhsId: String
        public var rhsId: String
        public var direction: EdgeDirection
        public var style: EdgeStyle
        public var label: String?
        public var stereotype: String?

        public init(
            lhsId: String, rhsId: String,
            direction: EdgeDirection = .forward, style: EdgeStyle = .solid,
            label: String? = nil, stereotype: String? = nil
        ) {
            self.lhsId = lhsId
            self.rhsId = rhsId
            self.direction = direction
            self.style = style
            self.label = label
            self.stereotype = stereotype
        }
    }

    public struct NoteAttachment: Sendable, Equatable {
        public var serviceId: String
        public var position: String     // "left" | "right" | "above" | "below"
        public var body: String

        public init(serviceId: String, position: String, body: String) {
            self.serviceId = serviceId
            self.position = position
            self.body = body
        }
    }
}

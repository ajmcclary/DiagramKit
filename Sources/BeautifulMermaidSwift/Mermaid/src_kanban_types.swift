import Foundation

public enum KanbanNodeShape: Int, Sendable, Equatable {
    case default_     = 0
    case roundedRect  = 1
    case rect         = 2
    case circle       = 3
    case cloud        = 4
    case bang         = 5
    case hexagon      = 6
}

public struct KanbanNode: Sendable, Equatable {
    public var id: String
    public var label: String
    public var level: Int
    public var shape: KanbanNodeShape
    public var parentId: String?
    public var icon: String?
    public var assigned: String?
    public var ticket: String?
    public var priority: String?
    public var cssClasses: String?
    public var width: Double
    public var padding: Double
    public var isGroup: Bool
}

public struct KanbanDiagram: Sendable, Equatable {
    public var nodes: [KanbanNode]
    public var sections: [KanbanNode]
    public var config: KanbanDiagramConfig
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
}

public struct KanbanDiagramConfig: Sendable, Equatable {
    public var padding: Double
    public var sectionWidth: Double
    public var ticketBaseUrl: String
    public var useMaxWidth: Bool

    public init(
        padding: Double = 8,
        sectionWidth: Double = 200,
        ticketBaseUrl: String = "",
        useMaxWidth: Bool = true
    ) {
        self.padding = padding
        self.sectionWidth = sectionWidth
        self.ticketBaseUrl = ticketBaseUrl
        self.useMaxWidth = useMaxWidth
    }

    public static let `default` = KanbanDiagramConfig()
}

public struct PositionedKanbanSection: Sendable {
    public var id: String
    public var label: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rx: Double
    public var ry: Double
    public var sectionIndex: Int
    public var cssClasses: String?
    public var icon: String?
}

public struct PositionedKanbanCard: Sendable {
    public var id: String
    public var label: String
    public var parentSectionId: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rx: Double
    public var ry: Double
    public var ticket: String?
    public var assigned: String?
    public var priority: String?
    public var icon: String?
    public var cssClasses: String?
}

public struct PositionedKanbanDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var sections: [PositionedKanbanSection]
    public var cards: [PositionedKanbanCard]
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: KanbanDiagramConfig

    public static let empty = PositionedKanbanDiagram(
        width: 0, height: 0,
        sections: [], cards: [],
        accTitle: nil, accDescr: nil, diagramTitle: nil,
        config: KanbanDiagramConfig()
    )
}

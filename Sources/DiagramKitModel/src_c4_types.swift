import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - C4 Diagram Kind

public enum C4DiagramKind: String, Sendable, Equatable, CaseIterable {
    case context = "C4Context"
    case container = "C4Container"
    case component = "C4Component"
    case dynamic = "C4Dynamic"
    case deployment = "C4Deployment"
}

// MARK: - C4 Shape Type (22 variants)

public enum C4ShapeType: String, Sendable, Equatable, CaseIterable {
    case person
    case external_person
    case system
    case system_db
    case system_queue
    case external_system
    case external_system_db
    case external_system_queue
    case container
    case container_db
    case container_queue
    case external_container
    case external_container_db
    case external_container_queue
    case component
    case component_db
    case component_queue
    case external_component
    case external_component_db
    case external_component_queue
}

// MARK: - C4 Relationship Kind

public enum C4RelationshipKind: String, Sendable, Equatable, CaseIterable {
    case rel
    case birel
    case rel_u
    case rel_d
    case rel_l
    case rel_r
    case rel_b
}

// MARK: - C4 Diagram Config

public struct C4DiagramConfig: Sendable, Equatable {
    // Layout
    public var diagramMarginX: Double = 50
    public var diagramMarginY: Double = 10
    public var c4ShapeMargin: Double = 50
    public var c4ShapePadding: Double = 20
    public var width: Double = 216
    public var height: Double = 60
    public var boxMargin: Double = 10
    public var c4ShapeInRow: Int = 4
    public var nextLinePaddingX: Double = 0
    public var c4BoundaryInRow: Int = 2
    public var useMaxWidth: Bool = true
    public var useWidth: Double? = nil

    // Wrap
    public var wrap: Bool = true
    public var wrapPadding: Double = 10

    // Font settings — per shape family
    public var personFontSize: Double = 14
    public var personFontFamily: String = "\"Open Sans\", sans-serif"
    public var personFontWeight: String = "normal"
    public var external_personFontSize: Double = 14
    public var external_personFontFamily: String = "\"Open Sans\", sans-serif"
    public var external_personFontWeight: String = "normal"
    public var systemFontSize: Double = 14
    public var systemFontFamily: String = "\"Open Sans\", sans-serif"
    public var systemFontWeight: String = "normal"
    public var external_systemFontSize: Double = 14
    public var external_systemFontFamily: String = "\"Open Sans\", sans-serif"
    public var external_systemFontWeight: String = "normal"
    public var system_dbFontSize: Double = 14
    public var system_dbFontFamily: String = "\"Open Sans\", sans-serif"
    public var system_dbFontWeight: String = "normal"
    public var external_system_dbFontSize: Double = 14
    public var external_system_dbFontFamily: String = "\"Open Sans\", sans-serif"
    public var external_system_dbFontWeight: String = "normal"
    public var system_queueFontSize: Double = 14
    public var system_queueFontFamily: String = "\"Open Sans\", sans-serif"
    public var system_queueFontWeight: String = "normal"
    public var external_system_queueFontSize: Double = 14
    public var external_system_queueFontFamily: String = "\"Open Sans\", sans-serif"
    public var external_system_queueFontWeight: String = "normal"
    public var containerFontSize: Double = 14
    public var containerFontFamily: String = "\"Open Sans\", sans-serif"
    public var containerFontWeight: String = "normal"
    public var external_containerFontSize: Double = 14
    public var external_containerFontFamily: String = "\"Open Sans\", sans-serif"
    public var external_containerFontWeight: String = "normal"
    public var container_dbFontSize: Double = 14
    public var container_dbFontFamily: String = "\"Open Sans\", sans-serif"
    public var container_dbFontWeight: String = "normal"
    public var external_container_dbFontSize: Double = 14
    public var external_container_dbFontFamily: String = "\"Open Sans\", sans-serif"
    public var external_container_dbFontWeight: String = "normal"
    public var container_queueFontSize: Double = 14
    public var container_queueFontFamily: String = "\"Open Sans\", sans-serif"
    public var container_queueFontWeight: String = "normal"
    public var external_container_queueFontSize: Double = 14
    public var external_container_queueFontFamily: String = "\"Open Sans\", sans-serif"
    public var external_container_queueFontWeight: String = "normal"
    public var componentFontSize: Double = 14
    public var componentFontFamily: String = "\"Open Sans\", sans-serif"
    public var componentFontWeight: String = "normal"
    public var external_componentFontSize: Double = 14
    public var external_componentFontFamily: String = "\"Open Sans\", sans-serif"
    public var external_componentFontWeight: String = "normal"
    public var component_dbFontSize: Double = 14
    public var component_dbFontFamily: String = "\"Open Sans\", sans-serif"
    public var component_dbFontWeight: String = "normal"
    public var external_component_dbFontSize: Double = 14
    public var external_component_dbFontFamily: String = "\"Open Sans\", sans-serif"
    public var external_component_dbFontWeight: String = "normal"
    public var component_queueFontSize: Double = 14
    public var component_queueFontFamily: String = "\"Open Sans\", sans-serif"
    public var component_queueFontWeight: String = "normal"
    public var external_component_queueFontSize: Double = 14
    public var external_component_queueFontFamily: String = "\"Open Sans\", sans-serif"
    public var external_component_queueFontWeight: String = "normal"
    public var boundaryFontSize: Double = 14
    public var boundaryFontFamily: String = "\"Open Sans\", sans-serif"
    public var boundaryFontWeight: String = "normal"
    public var messageFontSize: Double = 12
    public var messageFontFamily: String = "\"Open Sans\", sans-serif"
    public var messageFontWeight: String = "normal"

    // Colors — all 22 shape families
    public var person_bg_color: String = "#08427B"
    public var person_border_color: String = "#073B6F"
    public var external_person_bg_color: String = "#686868"
    public var external_person_border_color: String = "#8A8A8A"
    public var system_bg_color: String = "#1168BD"
    public var system_border_color: String = "#3C7FC0"
    public var system_db_bg_color: String = "#1168BD"
    public var system_db_border_color: String = "#3C7FC0"
    public var system_queue_bg_color: String = "#1168BD"
    public var system_queue_border_color: String = "#3C7FC0"
    public var external_system_bg_color: String = "#999999"
    public var external_system_border_color: String = "#8A8A8A"
    public var external_system_db_bg_color: String = "#999999"
    public var external_system_db_border_color: String = "#8A8A8A"
    public var external_system_queue_bg_color: String = "#999999"
    public var external_system_queue_border_color: String = "#8A8A8A"
    public var container_bg_color: String = "#438DD5"
    public var container_border_color: String = "#3C7FC0"
    public var container_db_bg_color: String = "#438DD5"
    public var container_db_border_color: String = "#3C7FC0"
    public var container_queue_bg_color: String = "#438DD5"
    public var container_queue_border_color: String = "#3C7FC0"
    public var external_container_bg_color: String = "#B3B3B3"
    public var external_container_border_color: String = "#A6A6A6"
    public var external_container_db_bg_color: String = "#B3B3B3"
    public var external_container_db_border_color: String = "#A6A6A6"
    public var external_container_queue_bg_color: String = "#B3B3B3"
    public var external_container_queue_border_color: String = "#A6A6A6"
    public var component_bg_color: String = "#85BBF0"
    public var component_border_color: String = "#78A8D8"
    public var component_db_bg_color: String = "#85BBF0"
    public var component_db_border_color: String = "#78A8D8"
    public var component_queue_bg_color: String = "#85BBF0"
    public var component_queue_border_color: String = "#78A8D8"
    public var external_component_bg_color: String = "#CCCCCC"
    public var external_component_border_color: String = "#BFBFBF"
    public var external_component_db_bg_color: String = "#CCCCCC"
    public var external_component_db_border_color: String = "#BFBFBF"
    public var external_component_queue_bg_color: String = "#CCCCCC"
    public var external_component_queue_border_color: String = "#BFBFBF"

    public init() {}

    public func bgColor(for shapeType: C4ShapeType) -> String {
        switch shapeType {
        case .person: return person_bg_color
        case .external_person: return external_person_bg_color
        case .system: return system_bg_color
        case .system_db: return system_db_bg_color
        case .system_queue: return system_queue_bg_color
        case .external_system: return external_system_bg_color
        case .external_system_db: return external_system_db_bg_color
        case .external_system_queue: return external_system_queue_bg_color
        case .container: return container_bg_color
        case .container_db: return container_db_bg_color
        case .container_queue: return container_queue_bg_color
        case .external_container: return external_container_bg_color
        case .external_container_db: return external_container_db_bg_color
        case .external_container_queue: return external_container_queue_bg_color
        case .component: return component_bg_color
        case .component_db: return component_db_bg_color
        case .component_queue: return component_queue_bg_color
        case .external_component: return external_component_bg_color
        case .external_component_db: return external_component_db_bg_color
        case .external_component_queue: return external_component_queue_bg_color
        }
    }

    public func borderColor(for shapeType: C4ShapeType) -> String {
        switch shapeType {
        case .person: return person_border_color
        case .external_person: return external_person_border_color
        case .system: return system_border_color
        case .system_db: return system_db_border_color
        case .system_queue: return system_queue_border_color
        case .external_system: return external_system_border_color
        case .external_system_db: return external_system_db_border_color
        case .external_system_queue: return external_system_queue_border_color
        case .container: return container_border_color
        case .container_db: return container_db_border_color
        case .container_queue: return container_queue_border_color
        case .external_container: return external_container_border_color
        case .external_container_db: return external_container_db_border_color
        case .external_container_queue: return external_container_queue_border_color
        case .component: return component_border_color
        case .component_db: return component_db_border_color
        case .component_queue: return component_queue_border_color
        case .external_component: return external_component_border_color
        case .external_component_db: return external_component_db_border_color
        case .external_component_queue: return external_component_queue_border_color
        }
    }

    public func font(for shapeType: C4ShapeType) -> (family: String, size: Double, weight: String) {
        switch shapeType {
        case .person: return (personFontFamily, personFontSize, personFontWeight)
        case .external_person: return (external_personFontFamily, external_personFontSize, external_personFontWeight)
        case .system: return (systemFontFamily, systemFontSize, systemFontWeight)
        case .system_db: return (system_dbFontFamily, system_dbFontSize, system_dbFontWeight)
        case .system_queue: return (system_queueFontFamily, system_queueFontSize, system_queueFontWeight)
        case .external_system: return (external_systemFontFamily, external_systemFontSize, external_systemFontWeight)
        case .external_system_db: return (external_system_dbFontFamily, external_system_dbFontSize, external_system_dbFontWeight)
        case .external_system_queue: return (external_system_queueFontFamily, external_system_queueFontSize, external_system_queueFontWeight)
        case .container: return (containerFontFamily, containerFontSize, containerFontWeight)
        case .container_db: return (container_dbFontFamily, container_dbFontSize, container_dbFontWeight)
        case .container_queue: return (container_queueFontFamily, container_queueFontSize, container_queueFontWeight)
        case .external_container: return (external_containerFontFamily, external_containerFontSize, external_containerFontWeight)
        case .external_container_db: return (external_container_dbFontFamily, external_container_dbFontSize, external_container_dbFontWeight)
        case .external_container_queue: return (external_container_queueFontFamily, external_container_queueFontSize, external_container_queueFontWeight)
        case .component: return (componentFontFamily, componentFontSize, componentFontWeight)
        case .component_db: return (component_dbFontFamily, component_dbFontSize, component_dbFontWeight)
        case .component_queue: return (component_queueFontFamily, component_queueFontSize, component_queueFontWeight)
        case .external_component: return (external_componentFontFamily, external_componentFontSize, external_componentFontWeight)
        case .external_component_db: return (external_component_dbFontFamily, external_component_dbFontSize, external_component_dbFontWeight)
        case .external_component_queue: return (external_component_queueFontFamily, external_component_queueFontSize, external_component_queueFontWeight)
        }
    }
}

// MARK: - C4 Semantic Model

public struct C4Diagram: Sendable {
    public var kind: C4DiagramKind
    public var title: String?
    public var accDescr: String?
    public var shapes: [C4Shape]
    public var boundaries: [C4Boundary]
    public var relationships: [C4Relationship]
    public var config: C4DiagramConfig

    public init(
        kind: C4DiagramKind = .context,
        title: String? = nil,
        accDescr: String? = nil,
        shapes: [C4Shape] = [],
        boundaries: [C4Boundary] = [],
        relationships: [C4Relationship] = [],
        config: C4DiagramConfig = C4DiagramConfig()
    ) {
        self.kind = kind
        self.title = title
        self.accDescr = accDescr
        self.shapes = shapes
        self.boundaries = boundaries
        self.relationships = relationships
        self.config = config
    }

    public static let empty = C4Diagram()
}

public struct C4Shape: Sendable, Equatable {
    public var alias: String
    public var label: String
    public var typeC4Shape: C4ShapeType
    public var technology: String?
    public var description: String?
    public var sprite: String?
    public var tags: String?
    public var link: String?
    public var parentBoundary: String
    public var wrap: Bool
    public var bgColor: String?
    public var fontColor: String?
    public var borderColor: String?
    public var shadowing: String?
    public var shapeOverride: String?
    public var techn: String?
    public var legendText: String?
    public var legendSprite: String?

    public init(
        alias: String,
        label: String,
        typeC4Shape: C4ShapeType,
        technology: String? = nil,
        description: String? = nil,
        sprite: String? = nil,
        tags: String? = nil,
        link: String? = nil,
        parentBoundary: String = "global",
        wrap: Bool = false,
        bgColor: String? = nil,
        fontColor: String? = nil,
        borderColor: String? = nil,
        shadowing: String? = nil,
        shapeOverride: String? = nil,
        techn: String? = nil,
        legendText: String? = nil,
        legendSprite: String? = nil
    ) {
        self.alias = alias
        self.label = label
        self.typeC4Shape = typeC4Shape
        self.technology = technology
        self.description = description
        self.sprite = sprite
        self.tags = tags
        self.link = link
        self.parentBoundary = parentBoundary
        self.wrap = wrap
        self.bgColor = bgColor
        self.fontColor = fontColor
        self.borderColor = borderColor
        self.shadowing = shadowing
        self.shapeOverride = shapeOverride
        self.techn = techn
        self.legendText = legendText
        self.legendSprite = legendSprite
    }
}

public struct C4Boundary: Sendable, Equatable {
    public var alias: String
    public var label: String
    public var type: String?
    public var description: String?
    public var tags: String?
    public var link: String?
    public var parentBoundary: String
    public var nodeType: String?
    public var wrap: Bool
    public var bgColor: String?
    public var fontColor: String?
    public var borderColor: String?

    public init(
        alias: String,
        label: String,
        type: String? = nil,
        description: String? = nil,
        tags: String? = nil,
        link: String? = nil,
        parentBoundary: String = "",
        nodeType: String? = nil,
        wrap: Bool = false,
        bgColor: String? = nil,
        fontColor: String? = nil,
        borderColor: String? = nil
    ) {
        self.alias = alias
        self.label = label
        self.type = type
        self.description = description
        self.tags = tags
        self.link = link
        self.parentBoundary = parentBoundary
        self.nodeType = nodeType
        self.wrap = wrap
        self.bgColor = bgColor
        self.fontColor = fontColor
        self.borderColor = borderColor
    }
}

public struct C4Relationship: Sendable, Equatable {
    public var kind: C4RelationshipKind
    public var from: String
    public var to: String
    public var label: String
    public var technology: String?
    public var description: String?
    public var sprite: String?
    public var tags: String?
    public var link: String?
    public var wrap: Bool
    public var textColor: String?
    public var lineColor: String?
    public var offsetX: Int?
    public var offsetY: Int?

    public init(
        kind: C4RelationshipKind,
        from: String,
        to: String,
        label: String,
        technology: String? = nil,
        description: String? = nil,
        sprite: String? = nil,
        tags: String? = nil,
        link: String? = nil,
        wrap: Bool = false,
        textColor: String? = nil,
        lineColor: String? = nil,
        offsetX: Int? = nil,
        offsetY: Int? = nil
    ) {
        self.kind = kind
        self.from = from
        self.to = to
        self.label = label
        self.technology = technology
        self.description = description
        self.sprite = sprite
        self.tags = tags
        self.link = link
        self.wrap = wrap
        self.textColor = textColor
        self.lineColor = lineColor
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

// MARK: - Positioned Types

public struct PositionedC4Diagram: Sendable {
    public var width: Double
    public var height: Double
    public var shapes: [PositionedC4Shape]
    public var boundaries: [PositionedC4Boundary]
    public var relationships: [PositionedC4Relationship]
    public var title: String?
    public var accTitle: String?
    public var accDescr: String?

    public init(
        width: Double = 0,
        height: Double = 0,
        shapes: [PositionedC4Shape] = [],
        boundaries: [PositionedC4Boundary] = [],
        relationships: [PositionedC4Relationship] = [],
        title: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil
    ) {
        self.width = width
        self.height = height
        self.shapes = shapes
        self.boundaries = boundaries
        self.relationships = relationships
        self.title = title
        self.accTitle = accTitle
        self.accDescr = accDescr
    }

    public static let empty = PositionedC4Diagram()
}

public struct PositionedC4Shape: Sendable {
    public var alias: String
    public var typeC4Shape: C4ShapeType
    public var label: String
    public var technology: String?
    public var description: String?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var margin: Double
    public var labelY: Double
    public var labelWidth: Double
    public var labelHeight: Double
    public var technY: Double
    public var technWidth: Double
    public var technHeight: Double
    public var descrY: Double
    public var descrWidth: Double
    public var descrHeight: Double
    public var imageY: Double
    public var imageWidth: Double
    public var imageHeight: Double
    public var stereotypeY: Double
    public var stereotypeWidth: Double
    public var stereotypeHeight: Double
    public var bgColor: String?
    public var fontColor: String?
    public var borderColor: String?
    public var wrap: Bool

    public init(
        alias: String = "",
        typeC4Shape: C4ShapeType = .system,
        label: String = "",
        technology: String? = nil,
        description: String? = nil,
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        margin: Double = 50,
        labelY: Double = 0,
        labelWidth: Double = 0,
        labelHeight: Double = 0,
        technY: Double = 0,
        technWidth: Double = 0,
        technHeight: Double = 0,
        descrY: Double = 0,
        descrWidth: Double = 0,
        descrHeight: Double = 0,
        imageY: Double = 0,
        imageWidth: Double = 0,
        imageHeight: Double = 0,
        stereotypeY: Double = 0,
        stereotypeWidth: Double = 0,
        stereotypeHeight: Double = 0,
        bgColor: String? = nil,
        fontColor: String? = nil,
        borderColor: String? = nil,
        wrap: Bool = false
    ) {
        self.alias = alias
        self.typeC4Shape = typeC4Shape
        self.label = label
        self.technology = technology
        self.description = description
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.margin = margin
        self.labelY = labelY
        self.labelWidth = labelWidth
        self.labelHeight = labelHeight
        self.technY = technY
        self.technWidth = technWidth
        self.technHeight = technHeight
        self.descrY = descrY
        self.descrWidth = descrWidth
        self.descrHeight = descrHeight
        self.imageY = imageY
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.stereotypeY = stereotypeY
        self.stereotypeWidth = stereotypeWidth
        self.stereotypeHeight = stereotypeHeight
        self.bgColor = bgColor
        self.fontColor = fontColor
        self.borderColor = borderColor
        self.wrap = wrap
    }

    public static let empty = PositionedC4Shape()
}

public struct PositionedC4Boundary: Sendable {
    public var alias: String
    public var label: String
    public var type: String?
    public var description: String?
    public var nodeType: String?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var labelY: Double
    public var labelWidth: Double
    public var labelHeight: Double
    public var typeY: Double
    public var typeWidth: Double
    public var typeHeight: Double
    public var descrY: Double
    public var descrWidth: Double
    public var descrHeight: Double
    public var bgColor: String?
    public var fontColor: String?
    public var borderColor: String?
    public var wrap: Bool

    public init(
        alias: String = "",
        label: String = "",
        type: String? = nil,
        description: String? = nil,
        nodeType: String? = nil,
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        labelY: Double = 0,
        labelWidth: Double = 0,
        labelHeight: Double = 0,
        typeY: Double = 0,
        typeWidth: Double = 0,
        typeHeight: Double = 0,
        descrY: Double = 0,
        descrWidth: Double = 0,
        descrHeight: Double = 0,
        bgColor: String? = nil,
        fontColor: String? = nil,
        borderColor: String? = nil,
        wrap: Bool = false
    ) {
        self.alias = alias
        self.label = label
        self.type = type
        self.description = description
        self.nodeType = nodeType
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.labelY = labelY
        self.labelWidth = labelWidth
        self.labelHeight = labelHeight
        self.typeY = typeY
        self.typeWidth = typeWidth
        self.typeHeight = typeHeight
        self.descrY = descrY
        self.descrWidth = descrWidth
        self.descrHeight = descrHeight
        self.bgColor = bgColor
        self.fontColor = fontColor
        self.borderColor = borderColor
        self.wrap = wrap
    }

    public static let empty = PositionedC4Boundary()
}

public struct PositionedC4Relationship: Sendable {
    public var kind: C4RelationshipKind
    public var from: String
    public var to: String
    public var label: String
    public var technology: String?
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var labelX: Double
    public var labelY: Double
    public var labelWidth: Double
    public var labelHeight: Double
    public var technX: Double
    public var technY: Double
    public var technWidth: Double
    public var technHeight: Double
    public var textColor: String?
    public var lineColor: String?
    public var offsetX: Int?
    public var offsetY: Int?
    public var dynamicIndex: Int?

    public init(
        kind: C4RelationshipKind = .rel,
        from: String = "",
        to: String = "",
        label: String = "",
        technology: String? = nil,
        startPoint: CGPoint = .zero,
        endPoint: CGPoint = .zero,
        labelX: Double = 0,
        labelY: Double = 0,
        labelWidth: Double = 0,
        labelHeight: Double = 0,
        technX: Double = 0,
        technY: Double = 0,
        technWidth: Double = 0,
        technHeight: Double = 0,
        textColor: String? = nil,
        lineColor: String? = nil,
        offsetX: Int? = nil,
        offsetY: Int? = nil,
        dynamicIndex: Int? = nil
    ) {
        self.kind = kind
        self.from = from
        self.to = to
        self.label = label
        self.technology = technology
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.labelX = labelX
        self.labelY = labelY
        self.labelWidth = labelWidth
        self.labelHeight = labelHeight
        self.technX = technX
        self.technY = technY
        self.technWidth = technWidth
        self.technHeight = technHeight
        self.textColor = textColor
        self.lineColor = lineColor
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.dynamicIndex = dynamicIndex
    }

    public static let empty = PositionedC4Relationship()
}

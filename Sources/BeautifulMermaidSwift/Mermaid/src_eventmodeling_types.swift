import Foundation

// MARK: - Entity Types

public enum EventModelingEntityType: String, Sendable, Equatable, CaseIterable {
    case ui
    case cmd       // command
    case evt       // event
    case pcr       // processor
    case rmo       // readmodel
}

// MARK: - Data Type Annotation

public enum EventModelingDataType: String, Sendable, Equatable, CaseIterable {
    case json
    case jsobj
    case figma
    case salt
    case uri
    case md
    case html
    case text
}

// MARK: - Frame (Time Frame or Reset Frame)

public struct EventModelingFrame: Sendable, Equatable {
    public var name: String                // 1-3 digit frame ID as string
    public var modelEntityType: EventModelingEntityType
    public var entityIdentifier: String    // qualified name, e.g. "Inventory.ItemAdded"
    public var isResetFrame: Bool
    public var sourceFrameNames: [String]  // ordered referenced frame IDs
    public var dataReferenceName: String?  // data entity name from [[...]]
    public var dataInlineType: EventModelingDataType?
    public var dataInlineValue: String?    // raw content between { and }

    public init(
        name: String,
        modelEntityType: EventModelingEntityType,
        entityIdentifier: String,
        isResetFrame: Bool = false,
        sourceFrameNames: [String] = [],
        dataReferenceName: String? = nil,
        dataInlineType: EventModelingDataType? = nil,
        dataInlineValue: String? = nil
    ) {
        self.name = name
        self.modelEntityType = modelEntityType
        self.entityIdentifier = entityIdentifier
        self.isResetFrame = isResetFrame
        self.sourceFrameNames = sourceFrameNames
        self.dataReferenceName = dataReferenceName
        self.dataInlineType = dataInlineType
        self.dataInlineValue = dataInlineValue
    }
}

// MARK: - Data Entity

public struct EventModelingDataEntity: Sendable, Equatable {
    public var name: String
    public var dataType: EventModelingDataType?
    public var dataBlockValue: String      // raw content between outer { and }

    public init(
        name: String,
        dataType: EventModelingDataType? = nil,
        dataBlockValue: String = ""
    ) {
        self.name = name
        self.dataType = dataType
        self.dataBlockValue = dataBlockValue
    }
}

// MARK: - Note Entity

public struct EventModelingNoteEntity: Sendable, Equatable {
    public var sourceFrameName: String
    public var dataType: EventModelingDataType?
    public var dataBlockValue: String

    public init(
        sourceFrameName: String,
        dataType: EventModelingDataType? = nil,
        dataBlockValue: String = ""
    ) {
        self.sourceFrameName = sourceFrameName
        self.dataType = dataType
        self.dataBlockValue = dataBlockValue
    }
}

// MARK: - Model Entity (for GWT references)

public struct EventModelingModelEntity: Sendable, Equatable {
    public var name: String                // qualified name

    public init(name: String) {
        self.name = name
    }
}

// MARK: - GWT Entity

public struct EventModelingGwtStatement: Sendable, Equatable {
    public var entityType: EventModelingEntityType
    public var modelEntityName: String     // references EmModelEntity by name

    public init(entityType: EventModelingEntityType, modelEntityName: String) {
        self.entityType = entityType
        self.modelEntityName = modelEntityName
    }
}

public struct EventModelingGwtEntity: Sendable, Equatable {
    public var sourceFrameName: String
    public var givenStatements: [EventModelingGwtStatement]
    public var whenStatements: [EventModelingGwtStatement]
    public var thenStatements: [EventModelingGwtStatement]

    public init(
        sourceFrameName: String,
        givenStatements: [EventModelingGwtStatement] = [],
        whenStatements: [EventModelingGwtStatement] = [],
        thenStatements: [EventModelingGwtStatement] = []
    ) {
        self.sourceFrameName = sourceFrameName
        self.givenStatements = givenStatements
        self.whenStatements = whenStatements
        self.thenStatements = thenStatements
    }
}

// MARK: - Parsed Diagram

public struct EventModelingDiagram: Sendable, Equatable {
    public var frames: [EventModelingFrame]          // source order
    public var dataEntities: [EventModelingDataEntity]
    public var noteEntities: [EventModelingNoteEntity]
    public var gwtEntities: [EventModelingGwtEntity]
    public var modelEntities: [EventModelingModelEntity]
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: EventModelingDiagramConfig
    public var themeVariables: EventModelingThemeVariables

    public init(
        frames: [EventModelingFrame] = [],
        dataEntities: [EventModelingDataEntity] = [],
        noteEntities: [EventModelingNoteEntity] = [],
        gwtEntities: [EventModelingGwtEntity] = [],
        modelEntities: [EventModelingModelEntity] = [],
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: EventModelingDiagramConfig = EventModelingDiagramConfig(),
        themeVariables: EventModelingThemeVariables = EventModelingThemeVariables()
    ) {
        self.frames = frames
        self.dataEntities = dataEntities
        self.noteEntities = noteEntities
        self.gwtEntities = gwtEntities
        self.modelEntities = modelEntities
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.themeVariables = themeVariables
    }

    public static let empty = EventModelingDiagram()
}

// MARK: - Diagram Config

public struct EventModelingDiagramConfig: Sendable, Equatable {
    public var padding: Double             // default 30
    public var rowHeight: Double           // default 32; not yet used in reference renderer
    public var useMaxWidth: Bool

    public init(
        padding: Double = 30,
        rowHeight: Double = 32,
        useMaxWidth: Bool = false
    ) {
        self.padding = padding
        self.rowHeight = rowHeight
        self.useMaxWidth = useMaxWidth
    }
}

// MARK: - Theme Variables

public struct EventModelingThemeVariables: Sendable, Equatable {
    public var emUiFill: String?
    public var emUiStroke: String?
    public var emProcessorFill: String?
    public var emProcessorStroke: String?
    public var emReadModelFill: String?
    public var emReadModelStroke: String?
    public var emCommandFill: String?
    public var emCommandStroke: String?
    public var emEventFill: String?
    public var emEventStroke: String?
    public var emSwimlaneBackgroundOdd: String?
    public var emSwimlaneBackgroundStroke: String?
    public var emRelationStroke: String?
    public var emArrowhead: String?

    public init(
        emUiFill: String? = nil,
        emUiStroke: String? = nil,
        emProcessorFill: String? = nil,
        emProcessorStroke: String? = nil,
        emReadModelFill: String? = nil,
        emReadModelStroke: String? = nil,
        emCommandFill: String? = nil,
        emCommandStroke: String? = nil,
        emEventFill: String? = nil,
        emEventStroke: String? = nil,
        emSwimlaneBackgroundOdd: String? = nil,
        emSwimlaneBackgroundStroke: String? = nil,
        emRelationStroke: String? = nil,
        emArrowhead: String? = nil
    ) {
        self.emUiFill = emUiFill
        self.emUiStroke = emUiStroke
        self.emProcessorFill = emProcessorFill
        self.emProcessorStroke = emProcessorStroke
        self.emReadModelFill = emReadModelFill
        self.emReadModelStroke = emReadModelStroke
        self.emCommandFill = emCommandFill
        self.emCommandStroke = emCommandStroke
        self.emEventFill = emEventFill
        self.emEventStroke = emEventStroke
        self.emSwimlaneBackgroundOdd = emSwimlaneBackgroundOdd
        self.emSwimlaneBackgroundStroke = emSwimlaneBackgroundStroke
        self.emRelationStroke = emRelationStroke
        self.emArrowhead = emArrowhead
    }
}

// MARK: - Default Theme Values

public extension EventModelingThemeVariables {
    static func defaultFill(for entityType: EventModelingEntityType) -> String {
        switch entityType {
        case .ui:  return "white"
        case .pcr: return "#edb3f6"
        case .rmo: return "#d3f1a2"
        case .cmd: return "#bcd6fe"
        case .evt: return "#ffb778"
        }
    }

    static func defaultStroke(for entityType: EventModelingEntityType) -> String {
        switch entityType {
        case .ui:  return "#dbdada"
        case .pcr: return "#b88cbf"
        case .rmo: return "#a3b732"
        case .cmd: return "#679ac3"
        case .evt: return "#c19a0f"
        }
    }

    func fill(for entityType: EventModelingEntityType) -> String {
        switch entityType {
        case .ui:  return emUiFill ?? Self.defaultFill(for: .ui)
        case .pcr: return emProcessorFill ?? Self.defaultFill(for: .pcr)
        case .rmo: return emReadModelFill ?? Self.defaultFill(for: .rmo)
        case .cmd: return emCommandFill ?? Self.defaultFill(for: .cmd)
        case .evt: return emEventFill ?? Self.defaultFill(for: .evt)
        }
    }

    func stroke(for entityType: EventModelingEntityType) -> String {
        switch entityType {
        case .ui:  return emUiStroke ?? Self.defaultStroke(for: .ui)
        case .pcr: return emProcessorStroke ?? Self.defaultStroke(for: .pcr)
        case .rmo: return emReadModelStroke ?? Self.defaultStroke(for: .rmo)
        case .cmd: return emCommandStroke ?? Self.defaultStroke(for: .cmd)
        case .evt: return emEventStroke ?? Self.defaultStroke(for: .evt)
        }
    }

    var swimlaneBackgroundOdd: String {
        emSwimlaneBackgroundOdd ?? "rgb(250,250,250)"
    }

    var swimlaneBackgroundStroke: String {
        emSwimlaneBackgroundStroke ?? "rgb(240,240,240)"
    }

    var arrowhead: String {
        emArrowhead ?? "#000000"
    }
}

// MARK: - Swimlane

public struct PositionedEventModelingSwimlane: Sendable, Equatable {
    public var index: Int
    public var label: String
    public var namespace: String?
    public var r: Double              // right edge x
    public var y: Double              // top y
    public var height: Double
    public var maxHeight: Double

    public init(
        index: Int,
        label: String,
        namespace: String? = nil,
        r: Double = 0,
        y: Double = 0,
        height: Double = 0,
        maxHeight: Double = 0
    ) {
        self.index = index
        self.label = label
        self.namespace = namespace
        self.r = r
        self.y = y
        self.height = height
        self.maxHeight = maxHeight
    }
}

// MARK: - Box

public struct PositionedEventModelingBox: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var r: Double              // right edge
    public var width: Double
    public var height: Double
    public var swimlaneIndex: Int
    public var fill: String           // entity-type color
    public var stroke: String         // entity-type stroke
    public var textContent: String    // HTML-formatted label (bold name + optional code data)
    public var frameIndex: Int        // source line order
    public var frameName: String

    public init(
        x: Double = 0,
        y: Double = 0,
        r: Double = 0,
        width: Double = 0,
        height: Double = 0,
        swimlaneIndex: Int = 0,
        fill: String = "white",
        stroke: String = "#dbdada",
        textContent: String = "",
        frameIndex: Int = 0,
        frameName: String = ""
    ) {
        self.x = x
        self.y = y
        self.r = r
        self.width = width
        self.height = height
        self.swimlaneIndex = swimlaneIndex
        self.fill = fill
        self.stroke = stroke
        self.textContent = textContent
        self.frameIndex = frameIndex
        self.frameName = frameName
    }
}

// MARK: - Relation

public struct PositionedEventModelingRelation: Sendable, Equatable {
    public var sourceX: Double
    public var sourceY: Double
    public var targetX: Double
    public var targetY: Double
    public var sourceBoxIndex: Int
    public var targetBoxIndex: Int
    public var fill: String
    public var stroke: String

    public init(
        sourceX: Double = 0,
        sourceY: Double = 0,
        targetX: Double = 0,
        targetY: Double = 0,
        sourceBoxIndex: Int = 0,
        targetBoxIndex: Int = 0,
        fill: String = "none",
        stroke: String = "#000000"
    ) {
        self.sourceX = sourceX
        self.sourceY = sourceY
        self.targetX = targetX
        self.targetY = targetY
        self.sourceBoxIndex = sourceBoxIndex
        self.targetBoxIndex = targetBoxIndex
        self.fill = fill
        self.stroke = stroke
    }
}

// MARK: - Positioned Diagram

public struct PositionedEventModelingDiagram: Sendable, Equatable {
    public var width: Double           // maxR + swimlanePadding
    public var height: Double          // last swimlane y + height
    public var swimlanes: [PositionedEventModelingSwimlane]  // sorted by index
    public var boxes: [PositionedEventModelingBox]
    public var relations: [PositionedEventModelingRelation]
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: EventModelingDiagramConfig
    public var themeVariables: EventModelingThemeVariables

    public init(
        width: Double = 0,
        height: Double = 0,
        swimlanes: [PositionedEventModelingSwimlane] = [],
        boxes: [PositionedEventModelingBox] = [],
        relations: [PositionedEventModelingRelation] = [],
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: EventModelingDiagramConfig = EventModelingDiagramConfig(),
        themeVariables: EventModelingThemeVariables = EventModelingThemeVariables()
    ) {
        self.width = width
        self.height = height
        self.swimlanes = swimlanes
        self.boxes = boxes
        self.relations = relations
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.themeVariables = themeVariables
    }

    public static let empty = PositionedEventModelingDiagram()
}

// MARK: - Parser Errors

public enum EventModelingParserError: Error, LocalizedError {
    case emptySource
    case missingHeader
    case invalidFrameToken(String, Int)        // line content, line number
    case duplicateFrameId(String)               // frame id
    case invalidEntityType(String, Int)         // type string, line number
    case missingEntityIdentifier(Int)           // line number
    case invalidFrameReference(String, Int)     // ref string, line number
    case invalidDataReference(String, Int)      // ref string, line number
    case malformedInlineData(Int)               // line number
    case malformedDataBlock(String, Int)        // name, line number
    case malformedGwtStatement(Int)             // line number
    case missingGwtBlock(String, Int)           // "given"/"when"/"then", line number
    case invalidSourceFrameType(source: EventModelingEntityType, target: EventModelingEntityType, Int)
    case negativeValue(String, Double)          // label, value

    public var errorDescription: String? {
        switch self {
        case .emptySource:
            return "Event Modeling source is empty."
        case .missingHeader:
            return "Event Modeling diagram must start with 'eventmodeling'."
        case let .invalidFrameToken(content, line):
            return "Invalid frame token at line \(line): '\(content)'."
        case let .duplicateFrameId(id):
            return "Duplicate frame ID: '\(id)'."
        case let .invalidEntityType(type, line):
            return "Invalid entity type '\(type)' at line \(line)."
        case let .missingEntityIdentifier(line):
            return "Missing entity identifier at line \(line)."
        case let .invalidFrameReference(ref, line):
            return "Invalid frame reference '\(ref)' at line \(line)."
        case let .invalidDataReference(ref, line):
            return "Invalid data reference '\(ref)' at line \(line)."
        case let .malformedInlineData(line):
            return "Malformed inline data at line \(line)."
        case let .malformedDataBlock(name, line):
            return "Malformed data block '\(name)' at line \(line)."
        case let .malformedGwtStatement(line):
            return "Malformed GWT statement at line \(line)."
        case let .missingGwtBlock(block, line):
            return "Missing '\(block)' block in GWT statement at line \(line)."
        case let .invalidSourceFrameType(source, target, line):
            return "Invalid Event Modeling source frame type at line \(line): '\(target.rawValue)' cannot receive input from '\(source.rawValue)'."
        case let .negativeValue(label, value):
            return "Negative value for \(label): \(value)."
        }
    }
}

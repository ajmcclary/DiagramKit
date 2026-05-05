// Ported from original/src/sequence/types.ts
import Foundation

public typealias Actor = SequenceActor
public typealias Message = SequenceMessage
public typealias Block = SequenceBlock
public typealias Note = SequenceNote
public typealias PositionedActor = PositionedSequenceActor
public typealias Lifeline = SequenceLifeline
public typealias PositionedMessage = PositionedSequenceMessage
public typealias Activation = SequenceActivation
public typealias PositionedBlock = PositionedSequenceBlock
public typealias PositionedNote = PositionedSequenceNote

// MARK: - Diagram Root

public struct SequenceDiagram: Sendable {
    public var items: [SequenceItem]

    // MARK: Derived arrays

    public var actors: [SequenceActor] {
        var seen = Set<String>()
        var result: [SequenceActor] = []
        // Include actors from box sections too
        for item in items {
            switch item {
            case .actor(let a):
                if seen.insert(a.id).inserted { result.append(a) }
            case .createParticipant(let a):
                if seen.insert(a.id).inserted { result.append(a) }
            case .message(let m):
                if seen.insert(m.from).inserted { result.append(SequenceActor(id: m.from, label: m.from, type: .participant)) }
                if seen.insert(m.to).inserted { result.append(SequenceActor(id: m.to, label: m.to, type: .participant)) }
            default: break
            }
        }
        return result
    }

    public var messages: [SequenceMessage] {
        items.compactMap { item in
            if case .message(let m) = item { return m }
            return nil
        }
    }

    public var blocks: [SequenceBlock] {
        var result: [SequenceBlock] = []
        var stack: [(type: String, label: String, startItemIndex: Int)] = []
        var pendingDividers: [SequenceBlockDivider] = []
        for (idx, item) in items.enumerated() {
            switch item {
            case .blockStart(let type, let label):
                stack.append((type: type, label: label, startItemIndex: idx))
            case .blockDivider(_, let label):
                pendingDividers.append(SequenceBlockDivider(itemIndex: idx, label: label))
            case .blockEnd:
                guard let top = stack.popLast() else { continue }
                result.append(SequenceBlock(
                    type: top.type,
                    label: top.label,
                    startItemIndex: top.startItemIndex,
                    endItemIndex: idx,
                    dividers: pendingDividers
                ))
                pendingDividers = []
            default:
                break
            }
        }
        return result
    }

    public var notes: [SequenceNote] {
        items.compactMap { item in
            if case .note(let n) = item { return n }
            return nil
        }
    }

    public var boxes: [SequenceBox] {
        var result: [SequenceBox] = []
        var pending: (fill: String, title: String?, wrap: Bool, startIdx: Int)? = nil
        var actorIds: [String] = []
        for (idx, item) in items.enumerated() {
            switch item {
            case .boxStart(let fill, let title, let wrap):
                pending = (fill: fill, title: title, wrap: wrap, startIdx: idx)
                actorIds = []
            case .actor(let a):
                actorIds.append(a.id)
            case .createParticipant(let a):
                actorIds.append(a.id)
            case .boxEnd:
                guard let p = pending else { continue }
                result.append(SequenceBox(
                    id: "box-\(p.startIdx)",
                    name: p.title,
                    fill: p.fill,
                    wrap: p.wrap,
                    actorIds: actorIds
                ))
                pending = nil
                actorIds = []
            default: break
            }
        }
        return result
    }

    public var title: String? {
        for item in items {
            if case .title(let t) = item { return t }
        }
        return nil
    }

    public var accTitle: String? {
        for item in items {
            if case .accTitle(let t) = item { return t }
        }
        return nil
    }

    public var accDescr: String? {
        for item in items {
            if case .accDescr(let d) = item { return d }
        }
        return nil
    }

    public var autonumberEnabled: Bool {
        var enabled = false
        for item in items {
            if case .autonumberEvent(_, _, let visible) = item { enabled = visible }
        }
        return enabled
    }

    public var autonumberStart: Double {
        for item in items {
            if case .autonumberEvent(let start, _, let visible) = item, visible { return start }
        }
        return 1.0
    }

    public var autonumberStep: Double {
        for item in items {
            if case .autonumberEvent(_, let step, let visible) = item, visible { return step }
        }
        return 1.0
    }

    public var createdActorIds: Set<String> {
        var result = Set<String>()
        for item in items {
            if case .createParticipant(let a) = item { result.insert(a.id) }
        }
        return result
    }

    public var destroyedActorIds: Set<String> {
        var result = Set<String>()
        for item in items {
            if case .destroyParticipant(let id) = item { result.insert(id) }
        }
        return result
    }

    public init(items: [SequenceItem] = []) {
        self.items = items
    }

    /// Legacy convenience init — translates old-style arrays into SequenceItem items
    public init(actors legacyActors: [SequenceActor], messages legacyMessages: [SequenceMessage], blocks legacyBlocks: [SequenceBlock], notes legacyNotes: [SequenceNote]) {
        var items: [SequenceItem] = []
        for a in legacyActors { items.append(.actor(a)) }
        for m in legacyMessages { items.append(.message(m)) }
        // Reconstruct blocks from indices — approximate conversion
        let sortedBlocks = legacyBlocks.sorted { $0.startItemIndex <= $1.startItemIndex }
        for block in sortedBlocks {
            items.append(.blockStart(type: block.type, label: block.label))
            for div in block.dividers {
                items.append(.blockDivider(type: block.type, label: div.label))
            }
            items.append(.blockEnd(type: block.type))
        }
        for n in legacyNotes { items.append(.note(n)) }
        self.items = items
    }
}

// MARK: - SequenceItem — Ordered timeline

public enum SequenceItem: Sendable {
    case actor(SequenceActor)
    case message(SequenceMessage)
    case note(SequenceNote)
    case activationStart(actorId: String)
    case activationEnd(actorId: String)
    case createParticipant(SequenceActor)
    case destroyParticipant(actorId: String)
    case autonumberEvent(start: Double, step: Double, visible: Bool)
    case blockStart(type: String, label: String)
    case blockDivider(type: String, label: String)
    case blockEnd(type: String)
    case boxStart(fill: String, title: String?, wrap: Bool)
    case boxEnd
    case title(String)
    case accTitle(String)
    case accDescr(String)
    case link(String, label: String, url: String)   // actorId
    case links(String, json: String)                 // actorId
    case properties(String, json: String)            // actorId
    case details(String, elementId: String)          // actorId
}

// MARK: - Participant Types

public enum ParticipantType: String, Sendable, CaseIterable {
    case participant
    case actor
    case boundary
    case control
    case entity
    case database
    case collections
    case queue
}

public struct ParticipantConfig: Sendable, Equatable {
    public var type: ParticipantType?
    public var alias: String?

    public init(type: ParticipantType? = nil, alias: String? = nil) {
        self.type = type
        self.alias = alias
    }
}

// MARK: - SequenceActor

public struct SequenceActor: Sendable {
    public var id: String
    public var label: String
    public var type: ParticipantType
    public var config: ParticipantConfig?
    public var boxId: String?
    public var links: [String: String]
    public var properties: [String: String]
    public var detailsElementId: String?
    public var createdAtMessageIndex: Int?
    public var destroyedAtMessageIndex: Int?
    public var isExplicit: Bool
    public var wrap: Bool?

    public init(
        id: String,
        label: String,
        type: ParticipantType = .participant,
        config: ParticipantConfig? = nil,
        boxId: String? = nil,
        links: [String: String] = [:],
        properties: [String: String] = [:],
        detailsElementId: String? = nil,
        createdAtMessageIndex: Int? = nil,
        destroyedAtMessageIndex: Int? = nil,
        isExplicit: Bool = true,
        wrap: Bool? = nil
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.config = config
        self.boxId = boxId
        self.links = links
        self.properties = properties
        self.detailsElementId = detailsElementId
        self.createdAtMessageIndex = createdAtMessageIndex
        self.destroyedAtMessageIndex = destroyedAtMessageIndex
        self.isExplicit = isExplicit
        self.wrap = wrap
    }

    /// Legacy type accessor (for backward compat where String was used)
    public var typeString: String {
        type.rawValue
    }
}

// MARK: - Arrow Types

public enum SequenceArrowType: Int, Sendable, CaseIterable {
    case solid = 0
    case dotted = 1
    case solidCross = 3
    case dottedCross = 4
    case solidOpen = 5
    case dottedOpen = 6
    case solidPoint = 24
    case dottedPoint = 25
    case bidirectionalSolid = 33
    case bidirectionalDotted = 34

    case solidArrowTop = 41
    case solidArrowBottom = 42
    case stickArrowTop = 43
    case stickArrowBottom = 44

    case solidArrowTopReverse = 45
    case solidArrowBottomReverse = 46
    case stickArrowTopReverse = 47
    case stickArrowBottomReverse = 48

    case solidArrowTopDotted = 51
    case solidArrowBottomDotted = 52
    case stickArrowTopDotted = 53
    case stickArrowBottomDotted = 54

    case solidArrowTopReverseDotted = 55
    case solidArrowBottomReverseDotted = 56
    case stickArrowTopReverseDotted = 57
    case stickArrowBottomReverseDotted = 58
}

public struct SequenceArrowStyle: Sendable, Equatable {
    public var type: SequenceArrowType
    public var isDotted: Bool
    public var hasArrowEnd: Bool
    public var isCross: Bool
    public var isOpenArrow: Bool
    public var isBidirectional: Bool
    public var isHalfArrow: Bool
    public var halfArrowDirection: HalfArrowDirection?
    public var halfArrowStyle: HalfArrowStyle?
    public var isReversed: Bool

    public init(type: SequenceArrowType) {
        self.type = type
        switch type {
        case .solid, .solidCross, .solidPoint: isDotted = false
        case .dotted, .dottedCross, .dottedPoint: isDotted = true
        case .solidOpen, .dottedOpen: isDotted = type == .dottedOpen
        case .bidirectionalSolid: isDotted = false
        case .bidirectionalDotted: isDotted = true
        case .solidArrowTop, .solidArrowBottom, .stickArrowTop, .stickArrowBottom,
             .solidArrowTopReverse, .solidArrowBottomReverse, .stickArrowTopReverse, .stickArrowBottomReverse: isDotted = false
        case .solidArrowTopDotted, .solidArrowBottomDotted, .stickArrowTopDotted, .stickArrowBottomDotted,
             .solidArrowTopReverseDotted, .solidArrowBottomReverseDotted, .stickArrowTopReverseDotted, .stickArrowBottomReverseDotted: isDotted = true
        }

        hasArrowEnd = type != .solidOpen && type != .dottedOpen
        isCross = type == .solidCross || type == .dottedCross
        isOpenArrow = type == .solidPoint || type == .dottedPoint
        isBidirectional = type == .bidirectionalSolid || type == .bidirectionalDotted

        let half: HalfArrowInfo = {
            switch type {
            case .solidArrowTop: return (.top, .arrow, false)
            case .solidArrowBottom: return (.bottom, .arrow, false)
            case .stickArrowTop: return (.top, .stick, false)
            case .stickArrowBottom: return (.bottom, .stick, false)
            case .solidArrowTopReverse: return (.top, .arrow, true)
            case .solidArrowBottomReverse: return (.bottom, .arrow, true)
            case .stickArrowTopReverse: return (.top, .stick, true)
            case .stickArrowBottomReverse: return (.bottom, .stick, true)
            case .solidArrowTopDotted: return (.top, .arrow, false)
            case .solidArrowBottomDotted: return (.bottom, .arrow, false)
            case .stickArrowTopDotted: return (.top, .stick, false)
            case .stickArrowBottomDotted: return (.bottom, .stick, false)
            case .solidArrowTopReverseDotted: return (.top, .arrow, true)
            case .solidArrowBottomReverseDotted: return (.bottom, .arrow, true)
            case .stickArrowTopReverseDotted: return (.top, .stick, true)
            case .stickArrowBottomReverseDotted: return (.bottom, .stick, true)
            default: return (nil, nil, false)
            }
        }()

        isHalfArrow = half.direction != nil
        halfArrowDirection = half.direction
        halfArrowStyle = half.style
        isReversed = half.reversed
    }

    private typealias HalfArrowInfo = (direction: HalfArrowDirection?, style: HalfArrowStyle?, reversed: Bool)
}

public enum HalfArrowDirection: String, Sendable {
    case top
    case bottom
}

public enum HalfArrowStyle: String, Sendable {
    case arrow
    case stick
}

public enum CentralConnectionType: Sendable {
    case dest
    case source
    case both
}

// MARK: - SequenceMessage

public struct SequenceMessage: Sendable {
    public var from: String
    public var to: String
    public var label: String
    public var arrowType: SequenceArrowType
    public var activate: Bool
    public var deactivate: Bool
    public var centralConnection: CentralConnectionType?
    public var wrap: Bool?
    public var sequenceNumber: Double?
    public var sequenceVisible: Bool

    public init(
        from: String,
        to: String,
        label: String,
        arrowType: SequenceArrowType = .solid,
        activate: Bool = false,
        deactivate: Bool = false,
        centralConnection: CentralConnectionType? = nil,
        wrap: Bool? = nil,
        sequenceNumber: Double? = nil,
        sequenceVisible: Bool = false
    ) {
        self.from = from
        self.to = to
        self.label = label
        self.arrowType = arrowType
        self.activate = activate
        self.deactivate = deactivate
        self.centralConnection = centralConnection
        self.wrap = wrap
        self.sequenceNumber = sequenceNumber
        self.sequenceVisible = sequenceVisible
    }

    public var lineStyle: String {
        SequenceArrowStyle(type: arrowType).isDotted ? "dashed" : "solid"
    }

    public var arrowHead: String {
        let style = SequenceArrowStyle(type: arrowType)
        if style.isCross { return "cross" }
        if style.isOpenArrow { return "open" }
        if !style.hasArrowEnd { return "none" }
        return "filled"
    }
}

// MARK: - Blocks

public struct SequenceBlockDivider: Sendable {
    public var itemIndex: Int
    public var label: String

    public init(itemIndex: Int, label: String) {
        self.itemIndex = itemIndex
        self.label = label
    }
}

public struct SequenceBlock: Sendable {
    public var type: String
    public var label: String
    public var startItemIndex: Int
    public var endItemIndex: Int
    public var dividers: [SequenceBlockDivider]
    public var isHighlight: Bool
    public var highlightFill: String?

    public init(
        type: String,
        label: String,
        startItemIndex: Int,
        endItemIndex: Int,
        dividers: [SequenceBlockDivider] = [],
        isHighlight: Bool = false,
        highlightFill: String? = nil
    ) {
        self.type = type
        self.label = label
        self.startItemIndex = startItemIndex
        self.endItemIndex = endItemIndex
        self.dividers = dividers
        self.isHighlight = isHighlight
        self.highlightFill = highlightFill
    }
}

// MARK: - Notes

public struct SequenceNote: Sendable {
    public var actorIds: [String]
    public var text: String
    public var position: String
    public var afterItemIndex: Int
    public var wrap: Bool?

    public init(actorIds: [String], text: String, position: String, afterItemIndex: Int = 0, wrap: Bool? = nil) {
        self.actorIds = actorIds
        self.text = text
        self.position = position
        self.afterItemIndex = afterItemIndex
        self.wrap = wrap
    }
}

// MARK: - Boxes

public struct SequenceBox: Sendable {
    public var id: String
    public var name: String?
    public var fill: String
    public var wrap: Bool
    public var actorIds: [String]

    public init(id: String, name: String?, fill: String, wrap: Bool, actorIds: [String]) {
        self.id = id
        self.name = name
        self.fill = fill
        self.wrap = wrap
        self.actorIds = actorIds
    }
}

// MARK: - Diagram Config

public struct SequenceDiagramConfig: Sendable, Equatable {
    public var diagramMarginX: Double
    public var diagramMarginY: Double
    public var actorMargin: Double
    public var width: Double
    public var height: Double
    public var boxMargin: Double
    public var boxTextMargin: Double
    public var noteMargin: Double
    public var messageMargin: Double
    public var activationWidth: Double
    public var messageAlign: TextAlign
    public var noteAlign: TextAlign
    public var bottomMarginAdj: Double
    public var useMaxWidth: Bool
    public var mirrorActors: Bool
    public var hideUnusedParticipants: Bool
    public var rightAngles: Bool
    public var showSequenceNumbers: Bool
    public var forceMenus: Bool
    public var arrowMarkerAbsolute: Bool
    public var wrap: Bool
    public var wrapPadding: Double
    public var labelBoxWidth: Double
    public var labelBoxHeight: Double

    public var actorFontFamily: String?
    public var actorFontSize: Double?
    public var actorFontWeight: String?
    public var messageFontFamily: String?
    public var messageFontSize: Double?
    public var messageFontWeight: String?
    public var noteFontFamily: String?
    public var noteFontSize: Double?
    public var noteFontWeight: String?

    public enum TextAlign: String, Sendable {
        case left, center, right
    }

    public static let `default` = SequenceDiagramConfig()

    public init(
        diagramMarginX: Double = 50,
        diagramMarginY: Double = 10,
        actorMargin: Double = 140,
        width: Double = 150,
        height: Double = 65,
        boxMargin: Double = 10,
        boxTextMargin: Double = 5,
        noteMargin: Double = 10,
        messageMargin: Double = 35,
        activationWidth: Double = 10,
        messageAlign: TextAlign = .center,
        noteAlign: TextAlign = .center,
        bottomMarginAdj: Double = 1,
        useMaxWidth: Bool = true,
        mirrorActors: Bool = true,
        hideUnusedParticipants: Bool = false,
        rightAngles: Bool = false,
        showSequenceNumbers: Bool = false,
        forceMenus: Bool = false,
        arrowMarkerAbsolute: Bool = false,
        wrap: Bool = false,
        wrapPadding: Double = 10,
        labelBoxWidth: Double = 50,
        labelBoxHeight: Double = 20,
        actorFontFamily: String? = nil,
        actorFontSize: Double? = nil,
        actorFontWeight: String? = nil,
        messageFontFamily: String? = nil,
        messageFontSize: Double? = nil,
        messageFontWeight: String? = nil,
        noteFontFamily: String? = nil,
        noteFontSize: Double? = nil,
        noteFontWeight: String? = nil
    ) {
        self.diagramMarginX = diagramMarginX
        self.diagramMarginY = diagramMarginY
        self.actorMargin = actorMargin
        self.width = width
        self.height = height
        self.boxMargin = boxMargin
        self.boxTextMargin = boxTextMargin
        self.noteMargin = noteMargin
        self.messageMargin = messageMargin
        self.activationWidth = activationWidth
        self.messageAlign = messageAlign
        self.noteAlign = noteAlign
        self.bottomMarginAdj = bottomMarginAdj
        self.useMaxWidth = useMaxWidth
        self.mirrorActors = mirrorActors
        self.hideUnusedParticipants = hideUnusedParticipants
        self.rightAngles = rightAngles
        self.showSequenceNumbers = showSequenceNumbers
        self.forceMenus = forceMenus
        self.arrowMarkerAbsolute = arrowMarkerAbsolute
        self.wrap = wrap
        self.wrapPadding = wrapPadding
        self.labelBoxWidth = labelBoxWidth
        self.labelBoxHeight = labelBoxHeight
        self.actorFontFamily = actorFontFamily
        self.actorFontSize = actorFontSize
        self.actorFontWeight = actorFontWeight
        self.messageFontFamily = messageFontFamily
        self.messageFontSize = messageFontSize
        self.messageFontWeight = messageFontWeight
        self.noteFontFamily = noteFontFamily
        self.noteFontSize = noteFontSize
        self.noteFontWeight = noteFontWeight
    }
}

// MARK: - Positioned Types

public struct PositionedSequenceDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var actors: [PositionedSequenceActor]
    public var lifelines: [SequenceLifeline]
    public var messages: [PositionedSequenceMessage]
    public var activations: [SequenceActivation]
    public var blocks: [PositionedSequenceBlock]
    public var notes: [PositionedSequenceNote]
    public var boxes: [PositionedSequenceBox]
    public var bottomActors: [PositionedSequenceActor]
    public var rectHighlights: [PositionedRectHighlight]
    public var title: String?
    public var accTitle: String?
    public var accDescr: String?

    public init(
        width: Double,
        height: Double,
        actors: [PositionedSequenceActor] = [],
        lifelines: [SequenceLifeline] = [],
        messages: [PositionedSequenceMessage] = [],
        activations: [SequenceActivation] = [],
        blocks: [PositionedSequenceBlock] = [],
        notes: [PositionedSequenceNote] = [],
        boxes: [PositionedSequenceBox] = [],
        bottomActors: [PositionedSequenceActor] = [],
        rectHighlights: [PositionedRectHighlight] = [],
        title: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil
    ) {
        self.width = width
        self.height = height
        self.actors = actors
        self.lifelines = lifelines
        self.messages = messages
        self.activations = activations
        self.blocks = blocks
        self.notes = notes
        self.boxes = boxes
        self.bottomActors = bottomActors
        self.rectHighlights = rectHighlights
        self.title = title
        self.accTitle = accTitle
        self.accDescr = accDescr
    }
}

public struct PositionedSequenceActor: Sendable {
    public var id: String
    public var label: String
    public var type: String
    public var participantType: ParticipantType
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(id: String, label: String, type: String = "participant", participantType: ParticipantType = .participant, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.label = label
        self.type = type
        self.participantType = participantType
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct SequenceLifeline: Sendable {
    public var actorId: String
    public var x: Double
    public var topY: Double
    public var bottomY: Double

    public init(actorId: String, x: Double, topY: Double, bottomY: Double) {
        self.actorId = actorId
        self.x = x
        self.topY = topY
        self.bottomY = bottomY
    }
}

public struct PositionedSequenceMessage: Sendable {
    public var from: String
    public var to: String
    public var label: String
    public var lineStyle: String
    public var arrowHead: String
    public var arrowType: SequenceArrowType
    public var centralConnection: CentralConnectionType?
    public var x1: Double
    public var x2: Double
    public var y: Double
    public var isSelf: Bool
    public var sequenceNumber: Double?
    public var sequenceVisible: Bool

    public init(from: String, to: String, label: String, lineStyle: String, arrowHead: String, arrowType: SequenceArrowType = .solid, centralConnection: CentralConnectionType? = nil, x1: Double, x2: Double, y: Double, isSelf: Bool, sequenceNumber: Double? = nil, sequenceVisible: Bool = false) {
        self.from = from
        self.to = to
        self.label = label
        self.lineStyle = lineStyle
        self.arrowHead = arrowHead
        self.arrowType = arrowType
        self.centralConnection = centralConnection
        self.x1 = x1
        self.x2 = x2
        self.y = y
        self.isSelf = isSelf
        self.sequenceNumber = sequenceNumber
        self.sequenceVisible = sequenceVisible
    }
}

public struct SequenceActivation: Sendable {
    public var actorId: String
    public var x: Double
    public var topY: Double
    public var bottomY: Double
    public var width: Double

    public init(actorId: String, x: Double, topY: Double, bottomY: Double, width: Double) {
        self.actorId = actorId
        self.x = x
        self.topY = topY
        self.bottomY = bottomY
        self.width = width
    }
}

public struct PositionedSequenceBlockDivider: Sendable {
    public var y: Double
    public var label: String

    public init(y: Double, label: String) {
        self.y = y
        self.label = label
    }
}

public struct PositionedSequenceBlock: Sendable {
    public var type: String
    public var label: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var dividers: [PositionedSequenceBlockDivider]
    public var isHighlight: Bool
    public var highlightFill: String?

    public init(type: String, label: String, x: Double, y: Double, width: Double, height: Double, dividers: [PositionedSequenceBlockDivider] = [], isHighlight: Bool = false, highlightFill: String? = nil) {
        self.type = type
        self.label = label
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.dividers = dividers
        self.isHighlight = isHighlight
        self.highlightFill = highlightFill
    }
}

public struct PositionedSequenceNote: Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var position: String
    public var actors: [String]

    public init(text: String, x: Double, y: Double, width: Double, height: Double, position: String, actors: [String]) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.position = position
        self.actors = actors
    }
}

public struct PositionedSequenceBox: Sendable {
    public var id: String
    public var name: String?
    public var fill: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var actorIds: [String]

    public init(id: String, name: String?, fill: String, x: Double, y: Double, width: Double, height: Double, actorIds: [String]) {
        self.id = id
        self.name = name
        self.fill = fill
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.actorIds = actorIds
    }
}

public struct PositionedRectHighlight: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var fill: String

    public init(x: Double, y: Double, width: Double, height: Double, fill: String) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.fill = fill
    }
}

// MARK: - Backward Compatibility Extensions

extension SequenceBlock {
    public var startIndex: Int { startItemIndex }
    public var endIndex: Int { endItemIndex }
}

extension SequenceBlockDivider {
    public var index: Int { itemIndex }
}

extension SequenceNote {
    public var afterIndex: Int { afterItemIndex }
}

// MARK: - Factory

open class original_src_sequence_types {
    public init() {}

    public static func makeActor(id: String, label: String, type: String = "participant") -> SequenceActor {
        SequenceActor(id: id, label: label, type: ParticipantType(rawValue: type) ?? .participant)
    }

    public static func makeMessage(
        from: String,
        to: String,
        label: String,
        lineStyle: String = "solid",
        arrowHead: String = "open",
        activate: Bool = false,
        deactivate: Bool = false
    ) -> SequenceMessage {
        let at: SequenceArrowType
        switch (lineStyle, arrowHead) {
        case ("dashed", "filled"): at = .dotted
        case ("dashed", "open"): at = .dottedOpen
        case ("dashed", "cross"): at = .dottedCross
        case ("dashed", "none"): at = .dottedOpen
        case (_, "filled"): at = .solid
        case (_, "open"): at = .solidPoint
        case (_, "cross"): at = .solidCross
        case (_, "none"): at = .solidOpen
        default: at = .solid
        }
        return SequenceMessage(
            from: from,
            to: to,
            label: label,
            arrowType: at,
            activate: activate,
            deactivate: deactivate
        )
    }

    public static func makeDiagram(
        actors: [SequenceActor] = [],
        messages: [SequenceMessage] = [],
        blocks: [SequenceBlock] = [],
        notes: [SequenceNote] = []
    ) -> SequenceDiagram {
        SequenceDiagram(actors: actors, messages: messages, blocks: blocks, notes: notes)
    }
}

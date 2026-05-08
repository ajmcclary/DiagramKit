import Foundation
import CoreGraphics

// MARK: - ZenUML Semantic Model (Layer 2)

public enum ZenUMLMessageType: String, Sendable, CaseIterable {
    case sync
    case async
    case creation
    case `return`
}

public struct ZenUMLParticipant: Sendable {
    public var name: String
    public var label: String?
    public var type: String?
    public var stereotype: String?
    public var color: String?
    public var emoji: String?
    public var width: Int?
    public var groupId: String?
    public var explicit: Bool
    public var isStarter: Bool
    public var comment: String?

    public init(
        name: String,
        label: String? = nil,
        type: String? = nil,
        stereotype: String? = nil,
        color: String? = nil,
        emoji: String? = nil,
        width: Int? = nil,
        groupId: String? = nil,
        explicit: Bool = false,
        isStarter: Bool = false,
        comment: String? = nil
    ) {
        self.name = name
        self.label = label
        self.type = type
        self.stereotype = stereotype
        self.color = color
        self.emoji = emoji
        self.width = width
        self.groupId = groupId
        self.explicit = explicit
        self.isStarter = isStarter
        self.comment = comment
    }
}

public enum ZenUMLFragmentKind: String, Sendable, CaseIterable {
    case alt
    case loop
    case par
    case opt
    case critical
    case section
    case ref
    case tcf
}

public struct ZenUMLFragmentSection: Sendable {
    public var label: String
    public var statements: [ZenUMLStatement]

    public init(label: String = "", statements: [ZenUMLStatement] = []) {
        self.label = label
        self.statements = statements
    }
}

public indirect enum ZenUMLStatement: Sendable {
    case message(from: String, to: String, signature: String, type: ZenUMLMessageType, block: [ZenUMLStatement]?, comment: String?)
    case asyncMessage(from: String, to: String, content: String?, comment: String?)
    case creation(assignee: String?, type: String?, construct: String, to: String, params: [String]?, block: [ZenUMLStatement]?, comment: String?)
    case `return`(from: String, to: String, value: String?, comment: String?)
    case fragment(kind: ZenUMLFragmentKind, condition: String?, sections: [ZenUMLFragmentSection])
    case divider(label: String)
    case comment(text: String)
}

public struct ZenUMLGroup: Sendable {
    public var id: String?
    public var participants: [String]

    public init(id: String? = nil, participants: [String] = []) {
        self.id = id
        self.participants = participants
    }
}

public struct ZenUMLDiagram: Sendable {
    public var title: String?
    public var participants: [ZenUMLParticipant]
    public var groups: [ZenUMLGroup]
    public var statements: [ZenUMLStatement]
    public var errors: [ZenUMLParseError]
    public var accTitle: String?
    public var accDescr: String?

    public init(
        title: String? = nil,
        participants: [ZenUMLParticipant] = [],
        groups: [ZenUMLGroup] = [],
        statements: [ZenUMLStatement] = [],
        errors: [ZenUMLParseError] = [],
        accTitle: String? = nil,
        accDescr: String? = nil
    ) {
        self.title = title
        self.participants = participants
        self.groups = groups
        self.statements = statements
        self.errors = errors
        self.accTitle = accTitle
        self.accDescr = accDescr
    }

    public static var empty: ZenUMLDiagram {
        ZenUMLDiagram()
    }
}

public struct ZenUMLParseError: Sendable {
    public var line: Int
    public var column: Int
    public var message: String

    public init(line: Int, column: Int, message: String) {
        self.line = line
        self.column = column
        self.message = message
    }
}

// MARK: - ZenUML Positioned Geometry (Layer 3)

public enum ZenUMLArrowStyle: String, Sendable {
    case solid
    case dashed
    case `open`
}

public struct PositionedZenUMLParticipant: Sendable {
    public var name: String
    public var label: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var isStarter: Bool
    public var showBottom: Bool
    public var labelWidth: Double?
    public var type: String?
    public var stereotype: String?
    public var stereotypeWidth: Double?
    public var color: String?
    public var emoji: String?
    public var groupId: String?

    public init(
        name: String = "",
        label: String = "",
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        isStarter: Bool = false,
        showBottom: Bool = false,
        labelWidth: Double? = nil,
        type: String? = nil,
        stereotype: String? = nil,
        stereotypeWidth: Double? = nil,
        color: String? = nil,
        emoji: String? = nil,
        groupId: String? = nil
    ) {
        self.name = name
        self.label = label
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.isStarter = isStarter
        self.showBottom = showBottom
        self.labelWidth = labelWidth
        self.type = type
        self.stereotype = stereotype
        self.stereotypeWidth = stereotypeWidth
        self.color = color
        self.emoji = emoji
        self.groupId = groupId
    }
}

public struct PositionedZenUMLLifeline: Sendable {
    public var participantName: String
    public var x: Double
    public var topY: Double
    public var bottomY: Double
    public var dashed: Bool

    public init(
        participantName: String = "",
        x: Double = 0,
        topY: Double = 0,
        bottomY: Double = 0,
        dashed: Bool = false
    ) {
        self.participantName = participantName
        self.x = x
        self.topY = topY
        self.bottomY = bottomY
        self.dashed = dashed
    }
}

public struct PositionedZenUMLMessage: Sendable {
    public var fromX: Double
    public var toX: Double
    public var y: Double
    public var label: String
    public var arrowStyle: ZenUMLArrowStyle
    public var isSelf: Bool
    public var isReverse: Bool
    public var number: String?

    public init(
        fromX: Double = 0,
        toX: Double = 0,
        y: Double = 0,
        label: String = "",
        arrowStyle: ZenUMLArrowStyle = .solid,
        isSelf: Bool = false,
        isReverse: Bool = false,
        number: String? = nil
    ) {
        self.fromX = fromX
        self.toX = toX
        self.y = y
        self.label = label
        self.arrowStyle = arrowStyle
        self.isSelf = isSelf
        self.isReverse = isReverse
        self.number = number
    }
}

public struct PositionedZenUMLSelfCall: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var label: String
    public var arrowStyle: ZenUMLArrowStyle
    public var number: String?

    public init(
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        label: String = "",
        arrowStyle: ZenUMLArrowStyle = .solid,
        number: String? = nil
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.label = label
        self.arrowStyle = arrowStyle
        self.number = number
    }
}

public struct PositionedZenUMLOccurrence: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var participantName: String

    public init(
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        participantName: String = ""
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.participantName = participantName
    }
}

public struct PositionedZenUMLCreation: Sendable {
    public var participant: PositionedZenUMLParticipant
    public var message: PositionedZenUMLMessage

    public init(
        participant: PositionedZenUMLParticipant = PositionedZenUMLParticipant(),
        message: PositionedZenUMLMessage = PositionedZenUMLMessage()
    ) {
        self.participant = participant
        self.message = message
    }
}

public struct PositionedZenUMLFragment: Sendable {
    public var kind: ZenUMLFragmentKind
    public var label: String
    public var labelWidth: Double?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var headerY: Double
    public var sections: [PositionedZenUMLFragmentSection]
    public var number: String?
    public var depth: Int

    public init(
        kind: ZenUMLFragmentKind = .alt,
        label: String = "",
        labelWidth: Double? = nil,
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        headerY: Double = 0,
        sections: [PositionedZenUMLFragmentSection] = [],
        number: String? = nil,
        depth: Int = 0
    ) {
        self.kind = kind
        self.label = label
        self.labelWidth = labelWidth
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.headerY = headerY
        self.sections = sections
        self.number = number
        self.depth = depth
    }
}

public struct PositionedZenUMLFragmentSection: Sendable {
    public var label: String
    public var y: Double
    public var height: Double
    public var labelWidth: Double?
    public var innerLabel: String?
    public var keyword: String?
    public var detail: String?

    public init(
        label: String = "",
        y: Double = 0,
        height: Double = 0,
        labelWidth: Double? = nil,
        innerLabel: String? = nil,
        keyword: String? = nil,
        detail: String? = nil
    ) {
        self.label = label
        self.y = y
        self.height = height
        self.labelWidth = labelWidth
        self.innerLabel = innerLabel
        self.keyword = keyword
        self.detail = detail
    }
}

public struct PositionedZenUMLReturn: Sendable {
    public var fromX: Double
    public var toX: Double
    public var y: Double
    public var label: String
    public var isReverse: Bool
    public var isSelf: Bool
    public var number: String?

    public init(
        fromX: Double = 0,
        toX: Double = 0,
        y: Double = 0,
        label: String = "",
        isReverse: Bool = false,
        isSelf: Bool = false,
        number: String? = nil
    ) {
        self.fromX = fromX
        self.toX = toX
        self.y = y
        self.label = label
        self.isReverse = isReverse
        self.isSelf = isSelf
        self.number = number
    }
}

public struct PositionedZenUMLDivider: Sendable {
    public var y: Double
    public var width: Double
    public var label: String
    public var labelWidth: Double?

    public init(
        y: Double = 0,
        width: Double = 0,
        label: String = "",
        labelWidth: Double? = nil
    ) {
        self.y = y
        self.width = width
        self.label = label
        self.labelWidth = labelWidth
    }
}

public struct PositionedZenUMLComment: Sendable {
    public var x: Double
    public var y: Double
    public var text: String
    public var fragmentComment: Bool

    public init(
        x: Double = 0,
        y: Double = 0,
        text: String = "",
        fragmentComment: Bool = false
    ) {
        self.x = x
        self.y = y
        self.text = text
        self.fragmentComment = fragmentComment
    }
}

public struct PositionedZenUMLGroup: Sendable {
    public var name: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(
        name: String = "",
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0
    ) {
        self.name = name
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PositionedZenUMLDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var frameBorderLeft: Double
    public var frameBorderRight: Double
    public var title: String?
    public var participants: [PositionedZenUMLParticipant]
    public var lifelines: [PositionedZenUMLLifeline]
    public var messages: [PositionedZenUMLMessage]
    public var selfCalls: [PositionedZenUMLSelfCall]
    public var occurrences: [PositionedZenUMLOccurrence]
    public var creations: [PositionedZenUMLCreation]
    public var fragments: [PositionedZenUMLFragment]
    public var dividers: [PositionedZenUMLDivider]
    public var returns: [PositionedZenUMLReturn]
    public var comments: [PositionedZenUMLComment]
    public var groups: [PositionedZenUMLGroup]

    public init(
        width: Double = 0,
        height: Double = 0,
        frameBorderLeft: Double = 0,
        frameBorderRight: Double = 0,
        title: String? = nil,
        participants: [PositionedZenUMLParticipant] = [],
        lifelines: [PositionedZenUMLLifeline] = [],
        messages: [PositionedZenUMLMessage] = [],
        selfCalls: [PositionedZenUMLSelfCall] = [],
        occurrences: [PositionedZenUMLOccurrence] = [],
        creations: [PositionedZenUMLCreation] = [],
        fragments: [PositionedZenUMLFragment] = [],
        dividers: [PositionedZenUMLDivider] = [],
        returns: [PositionedZenUMLReturn] = [],
        comments: [PositionedZenUMLComment] = [],
        groups: [PositionedZenUMLGroup] = []
    ) {
        self.width = width
        self.height = height
        self.frameBorderLeft = frameBorderLeft
        self.frameBorderRight = frameBorderRight
        self.title = title
        self.participants = participants
        self.lifelines = lifelines
        self.messages = messages
        self.selfCalls = selfCalls
        self.occurrences = occurrences
        self.creations = creations
        self.fragments = fragments
        self.dividers = dividers
        self.returns = returns
        self.comments = comments
        self.groups = groups
    }

    public static var empty: PositionedZenUMLDiagram {
        PositionedZenUMLDiagram()
    }
}

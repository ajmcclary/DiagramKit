import Foundation

// MARK: - TimelineDirection

public enum TimelineDirection: String, Sendable, Equatable, CaseIterable {
    case LR
    case TD
}

// MARK: - TimelineEvent

public struct TimelineEvent: Sendable, Equatable, Identifiable {
    public var id: Int
    public var text: String

    public init(id: Int, text: String) {
        self.id = id
        self.text = text
    }
}

// MARK: - TimelineTask

public struct TimelineTask: Sendable, Equatable, Identifiable {
    public var id: Int
    public var section: String
    public var text: String
    public var events: [TimelineEvent]

    public init(id: Int, section: String, text: String, events: [TimelineEvent] = []) {
        self.id = id
        self.section = section
        self.text = text
        self.events = events
    }
}

// MARK: - TimelineDiagramConfig

public struct TimelineDiagramConfig: Sendable, Equatable {
    public var diagramMarginX: Double
    public var diagramMarginY: Double
    public var leftMargin: Double
    public var width: Double
    public var height: Double
    public var padding: Double
    public var boxMargin: Double
    public var boxTextMargin: Double
    public var noteMargin: Double
    public var messageMargin: Double
    public var messageAlign: String
    public var bottomMarginAdj: Double
    public var rightAngles: Bool
    public var taskFontSize: Double
    public var taskFontFamily: String
    public var taskMargin: Double
    public var activationWidth: Double
    public var textPlacement: String
    public var actorColours: [String]
    public var sectionFills: [String]
    public var sectionColours: [String]
    public var disableMulticolor: Bool
    public var useMaxWidth: Bool
    public var useWidth: Double?

    public init(
        diagramMarginX: Double = 50,
        diagramMarginY: Double = 10,
        leftMargin: Double = 150,
        width: Double = 150,
        height: Double = 50,
        padding: Double = 50,
        boxMargin: Double = 10,
        boxTextMargin: Double = 5,
        noteMargin: Double = 10,
        messageMargin: Double = 35,
        messageAlign: String = "center",
        bottomMarginAdj: Double = 1,
        rightAngles: Bool = false,
        taskFontSize: Double = 14,
        taskFontFamily: String = "\"Open Sans\", sans-serif",
        taskMargin: Double = 50,
        activationWidth: Double = 10,
        textPlacement: String = "fo",
        actorColours: [String] = ["#8FBC8F", "#7CFC00", "#00FFFF", "#20B2AA", "#B0E0E6", "#FFFFE0"],
        sectionFills: [String] = ["#191970", "#8B008B", "#4B0082", "#2F4F4F", "#800000", "#8B4513", "#00008B"],
        sectionColours: [String] = ["#fff"],
        disableMulticolor: Bool = false,
        useMaxWidth: Bool = false,
        useWidth: Double? = nil
    ) {
        self.diagramMarginX = diagramMarginX
        self.diagramMarginY = diagramMarginY
        self.leftMargin = leftMargin
        self.width = width
        self.height = height
        self.padding = padding
        self.boxMargin = boxMargin
        self.boxTextMargin = boxTextMargin
        self.noteMargin = noteMargin
        self.messageMargin = messageMargin
        self.messageAlign = messageAlign
        self.bottomMarginAdj = bottomMarginAdj
        self.rightAngles = rightAngles
        self.taskFontSize = taskFontSize
        self.taskFontFamily = taskFontFamily
        self.taskMargin = taskMargin
        self.activationWidth = activationWidth
        self.textPlacement = textPlacement
        self.actorColours = actorColours
        self.sectionFills = sectionFills
        self.sectionColours = sectionColours
        self.disableMulticolor = disableMulticolor
        self.useMaxWidth = useMaxWidth
        self.useWidth = useWidth
    }

    public static let `default` = TimelineDiagramConfig()
}

// MARK: - TimelineThemeConfig

public struct TimelineThemeConfig: Sendable, Equatable {
    public var cScale: [String]
    public var cScaleLabel: [String]
    public var cScaleInv: [String]
    public var themeColorLimit: Int
    public var fontFamily: String
    public var fontSize: Double
    public var mainBkg: String
    public var nodeBorder: String
    public var borderColorArray: [String]
    public var useGradient: Bool
    public var gradientStart: String
    public var gradientStop: String
    public var dropShadow: String

    public init(
        cScale: [String] = ["#0052CC", "#0065FF", "#2684FF", "#4C9AFF", "#84B9FF", "#A5CCFF", "#C6DFFF", "#0052CC", "#0065FF", "#2684FF", "#4C9AFF", "#84B9FF"],
        cScaleLabel: [String] = ["#ffffff", "#ffffff", "#ffffff", "#ffffff", "#172B4D", "#172B4D", "#172B4D", "#ffffff", "#ffffff", "#ffffff", "#ffffff", "#172B4D"],
        cScaleInv: [String] = ["#003380", "#003D99", "#1750B3", "#3063B3", "#537399", "#6B8099", "#8099B3", "#003380", "#003D99", "#1750B3", "#3063B3", "#537399"],
        themeColorLimit: Int = 12,
        fontFamily: String = "\"Open Sans\", sans-serif",
        fontSize: Double = 16,
        mainBkg: String = "#ffffff",
        nodeBorder: String = "#333333",
        borderColorArray: [String] = [],
        useGradient: Bool = false,
        gradientStart: String = "#ececff",
        gradientStop: String = "#ffffff",
        dropShadow: String = "none"
    ) {
        self.cScale = cScale
        self.cScaleLabel = cScaleLabel
        self.cScaleInv = cScaleInv
        self.themeColorLimit = themeColorLimit
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.mainBkg = mainBkg
        self.nodeBorder = nodeBorder
        self.borderColorArray = borderColorArray
        self.useGradient = useGradient
        self.gradientStart = gradientStart
        self.gradientStop = gradientStop
        self.dropShadow = dropShadow
    }

    public static let `default` = TimelineThemeConfig()

    public func colorIndex(_ rawIndex: Int) -> Int {
        let limit = max(1, themeColorLimit)
        return ((rawIndex % limit) + limit) % limit
    }
}

// MARK: - TimelineDiagram

public struct TimelineDiagram: Sendable, Equatable {
    public var direction: TimelineDirection
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var sections: [String]
    public var tasks: [TimelineTask]
    public var config: TimelineDiagramConfig
    public var theme: TimelineThemeConfig
    public var themeName: String?
    public var look: String?

    public init(
        direction: TimelineDirection = .LR,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        sections: [String] = [],
        tasks: [TimelineTask] = [],
        config: TimelineDiagramConfig = TimelineDiagramConfig(),
        theme: TimelineThemeConfig = .default,
        themeName: String? = nil,
        look: String? = nil
    ) {
        self.direction = direction
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.sections = sections
        self.tasks = tasks
        self.config = config
        self.theme = theme
        self.themeName = themeName
        self.look = look
    }

    public static var empty: TimelineDiagram {
        TimelineDiagram()
    }
}

// MARK: - Positioned Timeline types

public struct PositionedTimelineSection: Sendable, Equatable {
    public var text: String
    public var sectionIndex: Int
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var colorIndex: Int

    public init(
        text: String = "",
        sectionIndex: Int = 0,
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        colorIndex: Int = 0
    ) {
        self.text = text
        self.sectionIndex = sectionIndex
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.colorIndex = colorIndex
    }
}

public struct PositionedTimelineTask: Sendable, Equatable {
    public var id: Int
    public var text: String
    public var section: String
    public var sectionIndex: Int
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var colorIndex: Int

    public init(
        id: Int = 0,
        text: String = "",
        section: String = "",
        sectionIndex: Int = 0,
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        colorIndex: Int = 0
    ) {
        self.id = id
        self.text = text
        self.section = section
        self.sectionIndex = sectionIndex
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.colorIndex = colorIndex
    }
}

public struct PositionedTimelineEvent: Sendable, Equatable {
    public var id: Int
    public var taskId: Int
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var colorIndex: Int

    public init(
        id: Int = 0,
        taskId: Int = 0,
        text: String = "",
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        colorIndex: Int = 0
    ) {
        self.id = id
        self.taskId = taskId
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.colorIndex = colorIndex
    }
}

public struct PositionedTimelineConnector: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case verticalLR(x1: Double, y1: Double, x2: Double, y2: Double)
        case horizontalTD(x1: Double, y1: Double, x2: Double, y2: Double)
    }
    public var kind: Kind
    public var colorIndex: Int

    public init(kind: Kind, colorIndex: Int = 0) {
        self.kind = kind
        self.colorIndex = colorIndex
    }
}

public struct PositionedTimelineActivityLine: Sendable, Equatable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double

    public init(x1: Double = 0, y1: Double = 0, x2: Double = 0, y2: Double = 0) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

public struct PositionedTimelineTitle: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double

    public init(text: String = "", x: Double = 0, y: Double = 0) {
        self.text = text
        self.x = x
        self.y = y
    }
}

public struct PositionedTimelineDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var direction: TimelineDirection
    public var sections: [PositionedTimelineSection]
    public var tasks: [PositionedTimelineTask]
    public var events: [PositionedTimelineEvent]
    public var connectors: [PositionedTimelineConnector]
    public var activityLine: PositionedTimelineActivityLine
    public var title: PositionedTimelineTitle?
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: TimelineDiagramConfig
    public var theme: TimelineThemeConfig
    public var look: String?
    public var themeName: String?

    public init(
        width: Double = 0,
        height: Double = 0,
        direction: TimelineDirection = .LR,
        sections: [PositionedTimelineSection] = [],
        tasks: [PositionedTimelineTask] = [],
        events: [PositionedTimelineEvent] = [],
        connectors: [PositionedTimelineConnector] = [],
        activityLine: PositionedTimelineActivityLine = PositionedTimelineActivityLine(),
        title: PositionedTimelineTitle? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        diagramTitle: String? = nil,
        config: TimelineDiagramConfig = .default,
        theme: TimelineThemeConfig = .default,
        look: String? = nil,
        themeName: String? = nil
    ) {
        self.width = width
        self.height = height
        self.direction = direction
        self.sections = sections
        self.tasks = tasks
        self.events = events
        self.connectors = connectors
        self.activityLine = activityLine
        self.title = title
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
        self.theme = theme
        self.look = look
        self.themeName = themeName
    }

    public static var empty: PositionedTimelineDiagram {
        PositionedTimelineDiagram()
    }
}

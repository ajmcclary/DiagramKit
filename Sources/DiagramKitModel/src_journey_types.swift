import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - JourneyDiagramConfig

public struct JourneyDiagramConfig: Sendable {
    public var diagramMarginX: Double = 50
    public var diagramMarginY: Double = 10
    public var leftMargin: Double = 150
    public var maxLabelWidth: Double = 360
    public var width: Double = 150
    public var height: Double = 50
    public var boxMargin: Double = 10
    public var boxTextMargin: Double = 5
    public var noteMargin: Double = 10
    public var messageMargin: Double = 35
    public var messageAlign: String = "center"
    public var bottomMarginAdj: Double = 1
    public var useMaxWidth: Bool = true
    public var rightAngles: Bool = false
    public var taskFontSize: Double = 14
    public var taskFontFamily: String = "\"Open Sans\", sans-serif"
    public var taskMargin: Double = 50
    public var activationWidth: Double = 10
    public var textPlacement: String = "fo"

    public var actorColours: [String] = [
        "#8FBC8F", "#7CFC00", "#00FFFF", "#20B2AA", "#B0E0E6", "#FFFFE0"
    ]
    public var sectionFills: [String] = [
        "#191970", "#8B008B", "#4B0082", "#2F4F4F", "#800000", "#8B4513", "#00008B"
    ]
    public var sectionColours: [String] = ["#fff"]

    public var titleColor: String = ""
    public var titleFontFamily: String = "\"trebuchet ms\", verdana, arial, sans-serif"
    public var titleFontSize: String = "4ex"
    public var faceColor: String = "#FFF8DC"

    public static let `default` = JourneyDiagramConfig()
}

// MARK: - JourneyTask

public struct JourneyTask: Sendable, Equatable {
    public var section: String
    public var task: String
    public var score: Int
    public var people: [String]

    public init(section: String = "", task: String = "", score: Int = 0, people: [String] = []) {
        self.section = section
        self.task = task
        self.score = score
        self.people = people
    }
}

// MARK: - JourneyDiagram

public struct JourneyDiagram: Sendable {
    public var title: String?
    public var accTitle: String?
    public var accDescr: String?
    public var sections: [String]
    public var tasks: [JourneyTask]
    public var actors: [String]
    public var config: JourneyDiagramConfig?

    public init(
        title: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        sections: [String] = [],
        tasks: [JourneyTask] = [],
        actors: [String] = [],
        config: JourneyDiagramConfig? = nil
    ) {
        self.title = title
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.sections = sections
        self.tasks = tasks
        self.actors = actors
        self.config = config
    }
}

// MARK: - PositionedJourneyActor

public struct PositionedJourneyActor: Sendable {
    public var name: String
    public var color: String
    public var index: Int
    public var lines: [String]
    public var circleCenter: CGPoint
    public var labelOrigin: CGPoint

    public init(
        name: String = "",
        color: String = "",
        index: Int = 0,
        lines: [String] = [],
        circleCenter: CGPoint = .zero,
        labelOrigin: CGPoint = .zero
    ) {
        self.name = name
        self.color = color
        self.index = index
        self.lines = lines
        self.circleCenter = circleCenter
        self.labelOrigin = labelOrigin
    }
}

// MARK: - PositionedJourneySection

public struct PositionedJourneySection: Sendable {
    public var name: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var fill: String
    public var colour: String
    public var num: Int

    public init(
        name: String = "",
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        fill: String = "",
        colour: String = "",
        num: Int = 0
    ) {
        self.name = name
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.fill = fill
        self.colour = colour
        self.num = num
    }
}

// MARK: - PositionedJourneyTask

public struct PositionedJourneyTask: Sendable {
    public var section: String
    public var task: String
    public var score: Int
    public var people: [String]
    public var x: Double
    public var y: Double
    public var rectWidth: Double
    public var rectHeight: Double
    public var boundsWidth: Double
    public var boundsHeight: Double
    public var fill: String
    public var colour: String
    public var num: Int
    public var faceY: Double
    public var taskIndex: Int

    public init(
        section: String = "",
        task: String = "",
        score: Int = 0,
        people: [String] = [],
        x: Double = 0,
        y: Double = 0,
        rectWidth: Double = 0,
        rectHeight: Double = 0,
        boundsWidth: Double = 0,
        boundsHeight: Double = 0,
        fill: String = "",
        colour: String = "",
        num: Int = 0,
        faceY: Double = 0,
        taskIndex: Int = 0
    ) {
        self.section = section
        self.task = task
        self.score = score
        self.people = people
        self.x = x
        self.y = y
        self.rectWidth = rectWidth
        self.rectHeight = rectHeight
        self.boundsWidth = boundsWidth
        self.boundsHeight = boundsHeight
        self.fill = fill
        self.colour = colour
        self.num = num
        self.faceY = faceY
        self.taskIndex = taskIndex
    }
}

// MARK: - PositionedJourneyDiagram

public struct PositionedJourneyDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var title: String?
    public var accTitle: String?
    public var accDescr: String?
    public var actors: [PositionedJourneyActor]
    public var legendWidth: Double
    public var effectiveLeftMargin: Double
    public var sections: [PositionedJourneySection]
    public var tasks: [PositionedJourneyTask]
    public var activityLineY: Double
    public var config: JourneyDiagramConfig?

    public init(
        width: Double = 0,
        height: Double = 0,
        title: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        actors: [PositionedJourneyActor] = [],
        legendWidth: Double = 0,
        effectiveLeftMargin: Double = 0,
        sections: [PositionedJourneySection] = [],
        tasks: [PositionedJourneyTask] = [],
        activityLineY: Double = 0,
        config: JourneyDiagramConfig? = nil
    ) {
        self.width = width
        self.height = height
        self.title = title
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.actors = actors
        self.legendWidth = legendWidth
        self.effectiveLeftMargin = effectiveLeftMargin
        self.sections = sections
        self.tasks = tasks
        self.activityLineY = activityLineY
        self.config = config
    }

    public static let empty = PositionedJourneyDiagram()
}

import Foundation
import CoreGraphics

// MARK: - GanttDiagramConfig

public struct GanttDiagramConfig: Sendable {
    public var useMaxWidth: Bool = true
    public var useWidth: Double? = nil
    public var titleTopMargin: Double = 25
    public var barHeight: Double = 20
    public var barGap: Double = 4
    public var topPadding: Double = 50
    public var rightPadding: Double = 75
    public var leftPadding: Double = 75
    public var gridLineStartPadding: Double = 35
    public var fontSize: Double = 11
    public var sectionFontSize: Double = 11
    public var numberSectionStyles: Int = 4
    public var axisFormat: String? = nil
    public var tickInterval: String? = nil
    public var topAxis: Bool = false
    public var displayMode: String = ""
    public var weekday: String = "sunday"

    public static let `default` = GanttDiagramConfig()
}

// MARK: - GanttTaskTags

public struct GanttTaskTags: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let active    = GanttTaskTags(rawValue: 1 << 0)
    public static let done      = GanttTaskTags(rawValue: 1 << 1)
    public static let crit      = GanttTaskTags(rawValue: 1 << 2)
    public static let milestone = GanttTaskTags(rawValue: 1 << 3)
    public static let vert      = GanttTaskTags(rawValue: 1 << 4)
}

// MARK: - GanttRawTaskData

public struct GanttRawTaskData: Sendable {
    public var data: String
    public var startTime: GanttStartType?
    public var endTime: GanttEndType?

    public init(data: String = "", startTime: GanttStartType? = nil, endTime: GanttEndType? = nil) {
        self.data = data
        self.startTime = startTime
        self.endTime = endTime
    }
}

public enum GanttStartType: Sendable {
    case prevTaskEnd
    case getStartDate(String)
}

public enum GanttEndType: Sendable {
    case data(String)
}

// MARK: - GanttRawTask

public struct GanttRawTask: Sendable {
    public var section: String
    public var type: String
    public var processed: Bool = false
    public var manualEndTime: Bool = false
    public var renderEndTime: Date? = nil
    public var raw: GanttRawTaskData
    public var task: String
    public var classes: [String] = []
    public var id: String = ""
    public var prevTaskId: String?
    public var tags: GanttTaskTags = []
    public var order: Int = 0
    public var startTime: Date?
    public var endTime: Date?
    public var link: String?
    public var callbackName: String?
    public var callbackArgs: [String]?

    public init(
        section: String = "",
        type: String = "",
        processed: Bool = false,
        manualEndTime: Bool = false,
        renderEndTime: Date? = nil,
        raw: GanttRawTaskData = GanttRawTaskData(),
        task: String = "",
        classes: [String] = [],
        id: String = "",
        prevTaskId: String? = nil,
        tags: GanttTaskTags = [],
        order: Int = 0,
        startTime: Date? = nil,
        endTime: Date? = nil,
        link: String? = nil,
        callbackName: String? = nil,
        callbackArgs: [String]? = nil
    ) {
        self.section = section
        self.type = type
        self.processed = processed
        self.manualEndTime = manualEndTime
        self.renderEndTime = renderEndTime
        self.raw = raw
        self.task = task
        self.classes = classes
        self.id = id
        self.prevTaskId = prevTaskId
        self.tags = tags
        self.order = order
        self.startTime = startTime
        self.endTime = endTime
        self.link = link
        self.callbackName = callbackName
        self.callbackArgs = callbackArgs
    }
}

// MARK: - GanttTask

public struct GanttTask: Sendable, Identifiable {
    public var id: String
    public var task: String
    public var section: String
    public var type: String
    public var tags: GanttTaskTags
    public var startTime: Date
    public var endTime: Date
    public var renderEndTime: Date?
    public var manualEndTime: Bool
    public var order: Int
    public var classes: [String]
    public var link: String?
    public var callbackName: String?
    public var callbackArgs: [String]?

    public init(
        id: String = "",
        task: String = "",
        section: String = "",
        type: String = "",
        tags: GanttTaskTags = [],
        startTime: Date = Date(),
        endTime: Date = Date(),
        renderEndTime: Date? = nil,
        manualEndTime: Bool = false,
        order: Int = 0,
        classes: [String] = [],
        link: String? = nil,
        callbackName: String? = nil,
        callbackArgs: [String]? = nil
    ) {
        self.id = id
        self.task = task
        self.section = section
        self.type = type
        self.tags = tags
        self.startTime = startTime
        self.endTime = endTime
        self.renderEndTime = renderEndTime
        self.manualEndTime = manualEndTime
        self.order = order
        self.classes = classes
        self.link = link
        self.callbackName = callbackName
        self.callbackArgs = callbackArgs
    }
}

// MARK: - GanttSection

public struct GanttSection: Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var index: Int

    public init(name: String = "", index: Int = 0) {
        self.name = name
        self.index = index
    }
}

// MARK: - GanttDiagram

public struct GanttDiagram: Sendable {
    public var title: String?
    public var accTitle: String?
    public var accDescr: String?
    public var dateFormat: String = "YYYY-MM-DD"
    public var axisFormat: String?
    public var tickInterval: String?
    public var todayMarker: String = ""
    public var includes: [String] = []
    public var excludes: [String] = []
    public var inclusiveEndDates: Bool = false
    public var topAxis: Bool = false
    public var weekday: String = "sunday"
    public var weekend: String = "saturday"
    public var displayMode: String = ""
    public var sections: [GanttSection] = []
    public var tasks: [GanttTask] = []
    public var links: [String: String] = [:]
    public var config: GanttDiagramConfig?

    public static let empty = GanttDiagram()
}

// MARK: - PositionedGanttTask

public struct PositionedGanttTask: Sendable, Identifiable {
    public var id: String { task.id }
    public var task: GanttTask
    public var barRect: CGRect
    public var labelPoint: CGPoint
    public var labelClass: String
    public var row: Int
    public var svgClass: String
    public var sectionStyleIndex: Int

    public init(
        task: GanttTask = GanttTask(),
        barRect: CGRect = .zero,
        labelPoint: CGPoint = .zero,
        labelClass: String = "",
        row: Int = 0,
        svgClass: String = "",
        sectionStyleIndex: Int = 0
    ) {
        self.task = task
        self.barRect = barRect
        self.labelPoint = labelPoint
        self.labelClass = labelClass
        self.row = row
        self.svgClass = svgClass
        self.sectionStyleIndex = sectionStyleIndex
    }
}

// MARK: - PositionedGanttSection

public struct PositionedGanttSection: Sendable {
    public var name: String
    public var rowStart: Int
    public var rowCount: Int
    public var backgroundRect: CGRect
    public var labelPoint: CGPoint
    public var styleIndex: Int

    public init(
        name: String = "",
        rowStart: Int = 0,
        rowCount: Int = 0,
        backgroundRect: CGRect = .zero,
        labelPoint: CGPoint = .zero,
        styleIndex: Int = 0
    ) {
        self.name = name
        self.rowStart = rowStart
        self.rowCount = rowCount
        self.backgroundRect = backgroundRect
        self.labelPoint = labelPoint
        self.styleIndex = styleIndex
    }
}

// MARK: - GanttExcludedRange

public struct GanttExcludedRange: Sendable {
    public var start: Date
    public var end: Date
    public var backgroundRect: CGRect

    public init(start: Date = Date(), end: Date = Date(), backgroundRect: CGRect = .zero) {
        self.start = start
        self.end = end
        self.backgroundRect = backgroundRect
    }
}

// MARK: - GanttAxisTick

public struct GanttAxisTick: Sendable {
    public var date: Date
    public var label: String
    public var x: Double

    public init(date: Date = Date(), label: String = "", x: Double = 0) {
        self.date = date
        self.label = label
        self.x = x
    }
}

// MARK: - PositionedGanttDiagram

public struct PositionedGanttDiagram: Sendable {
    public var diagramId: String = ""
    public var width: Double = 0
    public var height: Double = 0
    public var title: String?
    public var accTitle: String?
    public var accDescr: String?
    public var sections: [PositionedGanttSection] = []
    public var tasks: [PositionedGanttTask] = []
    public var excludedRanges: [GanttExcludedRange] = []
    public var todayLineX: Double?
    public var todayMarkerStyle: String?
    public var axisTicks: [GanttAxisTick] = []
    public var topAxisTicks: [GanttAxisTick]? = nil
    public var config: GanttDiagramConfig = .default
    public var categories: [String] = []
    public var categoryHeights: [String: Int] = [:]

    public static let empty = PositionedGanttDiagram()
}

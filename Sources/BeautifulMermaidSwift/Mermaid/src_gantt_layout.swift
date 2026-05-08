import Foundation
import CoreGraphics

// MARK: - Entry Point

public func layoutGanttDiagram(_ diagram: GanttDiagram) -> PositionedGanttDiagram {
    let config = diagram.config ?? .default
    let width = config.useWidth ?? 1200.0

    guard !diagram.tasks.isEmpty else {
        return PositionedGanttDiagram(
            width: width,
            height: 2 * config.topPadding + config.titleTopMargin,
            title: diagram.title,
            accTitle: diagram.accTitle,
            accDescr: diagram.accDescr,
            config: config
        )
    }

    // Sort tasks by startTime for visual positioning (not model order)
    let sortedTasks = diagram.tasks.sorted { a, b in
        if a.startTime != b.startTime { return a.startTime < b.startTime }
        return a.order < b.order
    }

    // Determine time domain
    guard let minTime = sortedTasks.map({ $0.startTime }).min(),
          let maxTime = sortedTasks.map({ $0.renderEndTime ?? $0.endTime }).max() else {
        return PositionedGanttDiagram(
            width: width,
            height: 2 * config.topPadding + config.titleTopMargin,
            title: diagram.title,
            accTitle: diagram.accTitle,
            accDescr: diagram.accDescr,
            config: config
        )
    }

    let domainMin = minTime
    let domainMax = maxTime
    let rangeMin = config.leftPadding
    let rangeMax = width - config.rightPadding

    func scale(_ date: Date) -> Double {
        let fullSpan = domainMax.timeIntervalSince(domainMin)
        if fullSpan <= 0 { return rangeMin }
        let fraction = date.timeIntervalSince(domainMin) / fullSpan
        return rangeMin + fraction * (rangeMax - rangeMin)
    }

    // Row assignment
    let isCompact = diagram.displayMode == "compact" || config.displayMode == "compact"
    let gap = config.barHeight + config.barGap

    // Map tasks to rows
    struct RowAssignment {
        var taskIndex: Int
        var row: Int
    }

    var assignments: [RowAssignment] = []

    if isCompact {
        // Compact mode: group by section and place each task in the first
        // non-overlapping lane, matching Mermaid's compact row packing.
        let sectionNames = diagram.sections.isEmpty
            ? _uniqueInOrder(sortedTasks.map(\.section))
            : diagram.sections.map { $0.name }
        var totalRows = 0

        for sectionName in sectionNames {
            let sectionTasks = sortedTasks.enumerated()
                .filter { $0.element.section == sectionName }
                .sorted {
                    if $0.element.startTime != $1.element.startTime {
                        return $0.element.startTime < $1.element.startTime
                    }
                    return $0.element.order < $1.element.order
                }
            var laneEndTimes: [Date] = []
            for (idx, task) in sectionTasks {
                var placedLane: Int?
                for lane in laneEndTimes.indices {
                    if task.startTime >= laneEndTimes[lane] {
                        laneEndTimes[lane] = task.endTime
                        placedLane = lane
                        break
                    }
                }
                if placedLane == nil {
                    laneEndTimes.append(task.endTime)
                    placedLane = laneEndTimes.count - 1
                }
                assignments.append(RowAssignment(taskIndex: idx, row: totalRows + (placedLane ?? 0)))
            }
            totalRows += max(laneEndTimes.count, sectionTasks.isEmpty ? 0 : 1)
        }
    } else {
        // Normal mode: one task per row
        for (i, _) in sortedTasks.enumerated() {
            assignments.append(RowAssignment(taskIndex: i, row: i))
        }
    }

    let totalRows: Int = isCompact ? (assignments.map { $0.row }.max() ?? sortedTasks.count) + 1 : sortedTasks.count
    let height = 2 * config.topPadding + Double(totalRows) * gap

    // Compute positioned tasks
    var positionedTasks: [PositionedGanttTask] = []

    for assignment in assignments {
        let task = sortedTasks[assignment.taskIndex]
        let row = assignment.row

        let renderEnd = task.renderEndTime ?? task.endTime
        let startX = scale(task.startTime)
        let endX = scale(renderEnd)

        var barWidth = endX - startX
        if barWidth < 1 { barWidth = 1 }

        let isMilestone = task.tags.contains(.milestone)
        let isVert = task.tags.contains(.vert)

        let barX: Double
        let barH: Double

        if isVert {
            barX = startX
            barWidth = 0.08 * config.barHeight
            barH = height - config.topPadding - config.gridLineStartPadding + config.barHeight * 2
        } else if isMilestone {
            barX = startX + (endX - startX) / 2 - config.barHeight / 2
            barWidth = config.barHeight
            barH = config.barHeight
        } else {
            barX = startX
            barH = config.barHeight
        }

        let barY: Double
        if isVert {
            barY = config.gridLineStartPadding
        } else if isMilestone {
            barY = Double(row) * gap + config.topPadding + gap / 2 - config.barHeight / 2
        } else {
            barY = Double(row) * gap + config.topPadding
        }

        let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barH)

        // Label placement
        let textWidth = original_src_text_metrics.measureTextWidth(task.task, fontSize: config.fontSize, fontWeight: 400)
        let labelPlacement = _computeLabelPlacement(textWidth: textWidth, barX: barX, barEndX: barX + barWidth, pageWidth: width, leftPadding: config.leftPadding)

        let labelX = labelPlacement.x
        let labelClass = labelPlacement.class

        let labelY: Double
        if isVert {
            labelY = config.gridLineStartPadding + Double(sortedTasks.count) * gap + 60
        } else {
            labelY = Double(row) * gap + config.barHeight / 2 + (config.fontSize / 2 - 2) + config.topPadding
        }

        let labelPoint = CGPoint(x: labelX, y: labelY)

        // CSS class assembly
        let sectionIndex = diagram.sections.firstIndex(where: { $0.name == task.section }) ?? 0
        let styleIndex = sectionIndex % config.numberSectionStyles

        let tagClass: String
        if task.tags.contains(.done) && task.tags.contains(.crit) {
            tagClass = "doneCrit"
        } else if task.tags.contains(.active) && task.tags.contains(.crit) {
            tagClass = "activeCrit"
        } else if task.tags.contains(.active) {
            tagClass = "active"
        } else if task.tags.contains(.done) {
            tagClass = "done"
        } else if task.tags.contains(.crit) {
            tagClass = "crit"
        } else {
            tagClass = ""
        }

        var taskClasses = ["task"]
        if isMilestone { taskClasses.append("milestone") }
        if isVert { taskClasses.append("vert") }
        taskClasses.append("\(tagClass.isEmpty ? "task" : tagClass)\(styleIndex)")
        taskClasses.append(contentsOf: task.classes)

        var labelClasses = task.classes
        labelClasses.append(labelClass)
        if labelClass == "taskText" {
            labelClasses.append("taskText\(styleIndex)")
        } else {
            labelClasses.append("taskTextOutside\(styleIndex)")
        }
        if !tagClass.isEmpty {
            labelClasses.append("\(tagClass)Text\(styleIndex)")
        }
        if isMilestone { labelClasses.append("milestoneText") }
        if isVert { labelClasses.append("vertText") }
        labelClasses.append("width-\(Int(ceil(textWidth)))")

        let positioned = PositionedGanttTask(
            task: task,
            barRect: barRect,
            labelPoint: labelPoint,
            labelClass: labelClasses.joined(separator: " "),
            row: row,
            svgClass: taskClasses.joined(separator: " "),
            sectionStyleIndex: styleIndex
        )
        positionedTasks.append(positioned)
    }

    // Compute section backgrounds
    var positionedSections: [PositionedGanttSection] = []
    for section in diagram.sections {
        let sectionTasks = positionedTasks.filter { $0.task.section == section.name }
        guard !sectionTasks.isEmpty else { continue }

        let minRow = sectionTasks.map { $0.row }.min() ?? 0
        let maxRow = sectionTasks.map { $0.row }.max() ?? 0
        let rowCount = maxRow - minRow + 1

        let bgY = Double(minRow) * gap + config.topPadding - 2
        let bgHeight = Double(rowCount) * gap - 2
        let bgRect = CGRect(x: 0, y: bgY, width: width - config.rightPadding / 2, height: max(bgHeight, 1))

        let styleIndex = section.index % config.numberSectionStyles

        // Section label: vertically centered
        let labelY = bgY + bgHeight / 2 + config.sectionFontSize / 2 - 2
        let labelX: Double = 0

        let positionedSection = PositionedGanttSection(
            name: section.name,
            rowStart: minRow,
            rowCount: rowCount,
            backgroundRect: bgRect,
            labelPoint: CGPoint(x: labelX, y: labelY),
            styleIndex: styleIndex
        )
        positionedSections.append(positionedSection)
    }

    // Compute excluded ranges
    var excludedRanges: [GanttExcludedRange] = []
    if !diagram.excludes.isEmpty || !diagram.includes.isEmpty {
        let cal = Calendar.current
        var currentDate = domainMin
        let endDate = domainMax

        // Skip if span > 5 years
        let yearsSpan = cal.dateComponents([.year], from: domainMin, to: domainMax).year ?? 0
        if yearsSpan <= 5 {
            var rangeStart: Date? = nil
            var rangeEnd: Date? = nil
            let dateFmt = diagram.dateFormat
            let excludes = diagram.excludes
            let includes = diagram.includes
            let weekend = diagram.weekend

            while currentDate <= endDate {
                let isInvalid = _ganttIsInvalidDate(currentDate, dateFormat: dateFmt, excludes: excludes, includes: includes, weekend: weekend)

                if isInvalid {
                    if rangeStart == nil {
                        rangeStart = currentDate
                    }
                    rangeEnd = currentDate
                } else if let start = rangeStart, let end = rangeEnd {
                    excludedRanges.append(_makeExcludedRange(start: start, end: end, height: height, config: config, scale: scale))
                    rangeStart = nil
                    rangeEnd = nil
                }
                currentDate = cal.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
            }
            if let start = rangeStart, let end = rangeEnd {
                excludedRanges.append(_makeExcludedRange(start: start, end: end, height: height, config: config, scale: scale))
            }
        }
    }

    // Today marker
    var todayLineX: Double? = nil
    if diagram.todayMarker != "off" {
        let today = Calendar.current.startOfDay(for: Date())
        todayLineX = scale(today)
    }

    // Grid line height: spans full chart area between top and bottom padding
    let gridLineHeight = height - config.topPadding - config.gridLineStartPadding

    // Axis ticks
    let axisFormat = diagram.axisFormat ?? config.axisFormat ?? _deriveAxisFormat(from: diagram.dateFormat)
    let tickWeekday = diagram.weekday != "sunday" ? diagram.weekday : config.weekday
    let axisTicks = _generateAxisTicks(
        minTime: domainMin,
        maxTime: domainMax,
        axisFormat: axisFormat,
        tickInterval: diagram.tickInterval ?? config.tickInterval,
        weekday: tickWeekday,
        width: width,
        config: config,
        scale: scale
    )

    var topAxisTicks: [GanttAxisTick]? = nil
    if diagram.topAxis || config.topAxis {
        topAxisTicks = axisTicks
    }

    return PositionedGanttDiagram(
        width: width,
        height: height,
        title: diagram.title,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        sections: positionedSections,
        tasks: positionedTasks,
        excludedRanges: excludedRanges,
        todayLineX: todayLineX,
            todayMarkerStyle: diagram.todayMarker.isEmpty ? nil : diagram.todayMarker.replacingOccurrences(of: ",", with: ";"),
        axisTicks: axisTicks,
        topAxisTicks: topAxisTicks,
        gridLineHeight: gridLineHeight,
        config: config,
        categories: diagram.sections.map { $0.name },
        categoryHeights: _computeCategoryHeights(diagram.sections, positionedTasks: positionedTasks)
    )
}

// MARK: - Helpers

private func _uniqueInOrder(_ values: [String]) -> [String] {
    var seen: Set<String> = []
    var result: [String] = []
    for value in values where !seen.contains(value) {
        seen.insert(value)
        result.append(value)
    }
    return result
}

private func _computeLabelPlacement(textWidth: Double, barX: Double, barEndX: Double, pageWidth: Double, leftPadding: Double) -> (x: Double, class: String) {
    let barWidth = barEndX - barX
    if textWidth <= barWidth {
        return (barX + barWidth / 2, "taskText")
    } else if barEndX + textWidth + 1.5 * leftPadding > pageWidth {
        return (barX - 5, "taskTextOutsideLeft")
    } else {
        return (barEndX + 5, "taskTextOutsideRight")
    }
}

private func _deriveAxisFormat(from dateFormat: String) -> String {
    if dateFormat == "D" || dateFormat == "d" {
        return "%d"
    }
    if dateFormat == "YYYY-MM-DD" {
        return "%Y-%m-%d"
    }
    return "%Y-%m-%d"
}

private func _ganttIsInvalidDate(_ date: Date, dateFormat: String, excludes: [String], includes: [String], weekend: String) -> Bool {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone.current
    df.dateFormat = _translateDayjsFormatToSwift(dateFormat)
    let formattedDate = df.string(from: date)

    df.dateFormat = "yyyy-MM-dd"
    let dateOnly = df.string(from: date)

    if includes.contains(formattedDate) || includes.contains(dateOnly) { return false }
    if excludes.contains("weekends") {
        let comps = Calendar.current.dateComponents([.weekday], from: date)
        let dow = comps.weekday ?? 1
        let weekendStart: Int = weekend == "friday" ? 6 : 7
        if dow == weekendStart || dow == (weekendStart == 7 ? 1 : weekendStart + 1) {
            return true
        }
    }
    df.dateFormat = "EEEE"
    let dayName = df.string(from: date).lowercased()
    if excludes.contains(dayName) { return true }
    return excludes.contains(formattedDate) || excludes.contains(dateOnly)
}

private func _makeExcludedRange(
    start: Date,
    end: Date,
    height: Double,
    config: GanttDiagramConfig,
    scale: (Date) -> Double
) -> GanttExcludedRange {
    let cal = Calendar.current
    let startOfRange = cal.startOfDay(for: start)
    let endOfDay = cal.date(byAdding: DateComponents(day: 1, second: -1), to: cal.startOfDay(for: end)) ?? end
    let x = scale(startOfRange)
    let width = max(0, scale(endOfDay) - x)
    return GanttExcludedRange(
        start: startOfRange,
        end: cal.startOfDay(for: end),
        backgroundRect: CGRect(
            x: x,
            y: config.gridLineStartPadding,
            width: width,
            height: max(0, height - config.topPadding - config.gridLineStartPadding)
        )
    )
}

private enum _GanttTickStep {
    case seconds(Double)
    case calendar(Calendar.Component, Int)
    case week(Int, String)
}

private func _generateAxisTicks(
    minTime: Date,
    maxTime: Date,
    axisFormat: String,
    tickInterval: String?,
    weekday: String,
    width: Double,
    config: GanttDiagramConfig,
    scale: (Date) -> Double
) -> [GanttAxisTick] {
    let cal = Calendar.current
    let span = maxTime.timeIntervalSince(minTime)

    var step: _GanttTickStep
    var approximateSeconds: Double
    var firstTick: Date
    let maxTickCount = 10000.0

    if let tickStr = tickInterval {
        let pattern = try? NSRegularExpression(pattern: #"^([1-9]\d*)(millisecond|second|minute|hour|day|week|month)$"#)
        if let match = pattern?.firstMatch(in: tickStr, range: NSRange(tickStr.startIndex..<tickStr.endIndex, in: tickStr)),
           let valRange = Range(match.range(at: 1), in: tickStr),
           let unitRange = Range(match.range(at: 2), in: tickStr) {
            let value = Int(tickStr[valRange]) ?? 1
            let unit = String(tickStr[unitRange])
            switch unit {
            case "millisecond":
                approximateSeconds = Double(value) / 1000.0
                step = _GanttTickStep.seconds(approximateSeconds)
                firstTick = minTime
            case "second":
                approximateSeconds = Double(value)
                step = _GanttTickStep.seconds(approximateSeconds)
                firstTick = minTime
            case "minute":
                approximateSeconds = Double(value) * 60
                step = _GanttTickStep.seconds(approximateSeconds)
                firstTick = minTime
            case "hour":
                approximateSeconds = Double(value) * 3600
                step = _GanttTickStep.seconds(approximateSeconds)
                firstTick = minTime
            case "day":
                approximateSeconds = Double(value) * 86400
                step = _GanttTickStep.calendar(.day, value)
                firstTick = cal.startOfDay(for: minTime)
            case "week":
                approximateSeconds = Double(value) * 86400 * 7
                step = _GanttTickStep.week(value, weekday)
                firstTick = _alignToWeekday(cal.startOfDay(for: minTime), weekday: weekday)
            case "month":
                approximateSeconds = Double(value) * 86400 * 30
                step = _GanttTickStep.calendar(.month, value)
                var comps = cal.dateComponents([.year, .month], from: minTime)
                comps.day = 1
                firstTick = cal.date(from: comps) ?? minTime
            default:
                approximateSeconds = 86400 * 7
                step = _GanttTickStep.calendar(.day, 7)
                firstTick = cal.startOfDay(for: minTime)
            }
        } else {
            approximateSeconds = 86400 * 7
            step = _GanttTickStep.calendar(.day, 7)
            firstTick = cal.startOfDay(for: minTime)
        }

        // Cap tick count
        let estimatedTicks = approximateSeconds > 0 ? span / approximateSeconds : Double.infinity
        if estimatedTicks > maxTickCount {
            approximateSeconds = max(span / maxTickCount, 0.001)
            step = _GanttTickStep.seconds(approximateSeconds)
            firstTick = minTime
        }
    } else {
        // D3-inspired default tick generation when no tickInterval is specified
        let availableWidth = width - config.leftPadding - config.rightPadding
        let targetTickCount = max(2.0, min(availableWidth / 80.0, 20.0))
        let rawStep = span / targetTickCount

        // Snap to nice time units
        let minute = 60.0
        let hour = 3600.0
        let day = 86400.0

        func niceSpan(_ rough: Double) -> (Double, _GanttTickStep) {
            let steps: [Double] = [0.001, 0.005, 0.01, 0.05, 0.1, 0.5,
                                   1, 5, 10, 30,
                                   minute, minute * 5, minute * 15, minute * 30,
                                   hour, hour * 3, hour * 6, hour * 12,
                                   day, day * 2, day * 3, day * 5, day * 7,
                                   day * 14, day * 30, day * 90, day * 365]
            for s in steps where s >= rough { return (s, _stepForSeconds(s, weekday: weekday)) }
            return (day * 365, _GanttTickStep.calendar(.year, 1))
        }

        let (_, tickStep) = niceSpan(rawStep)
        step = tickStep

        // Align start to nice boundary
        switch tickStep {
        case .calendar(.month, let value):
            var comps = cal.dateComponents([.year, .month], from: minTime)
            comps.day = 1
            comps.hour = 0; comps.minute = 0; comps.second = 0
            firstTick = cal.date(from: comps) ?? minTime
            step = _GanttTickStep.calendar(.month, value)
        case .calendar(.day, let value):
            firstTick = cal.startOfDay(for: minTime)
            step = _GanttTickStep.calendar(.day, value >= 1 ? value : 1)
        case .week(let value, _):
            firstTick = _alignToWeekday(cal.startOfDay(for: minTime), weekday: weekday)
            step = _GanttTickStep.week(value, weekday)
        case .calendar(.year, let value):
            var comps = cal.dateComponents([.year], from: minTime)
            comps.month = 1; comps.day = 1
            comps.hour = 0; comps.minute = 0; comps.second = 0
            firstTick = cal.date(from: comps) ?? minTime
            step = _GanttTickStep.calendar(.year, value)
        case .seconds(let s):
            firstTick = minTime
            step = _GanttTickStep.seconds(s)
        default:
            firstTick = cal.startOfDay(for: minTime)
        }
    }

    // Generate ticks
    var result: [GanttAxisTick] = []
    var currentDate = firstTick

    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.dateFormat = _translateDayjsFormatToSwift(axisFormat)

    while currentDate <= maxTime {
        let x = scale(currentDate)
        let label = df.string(from: currentDate)
        result.append(GanttAxisTick(date: currentDate, label: label, x: x))
        let nextDate: Date?
        switch step {
        case .seconds(let seconds):
            nextDate = currentDate.addingTimeInterval(seconds)
        case .calendar(let component, let value):
            nextDate = cal.date(byAdding: component, value: value, to: currentDate)
        case .week(let value, _):
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate)
            nextDate = cal.date(byAdding: .weekOfYear, value: value, to: cal.date(from: comps) ?? currentDate)
        }
        guard let nextDate, nextDate > currentDate else { break }
        currentDate = nextDate
    }

    return result
}

private func _stepForSeconds(_ seconds: Double, weekday: String) -> _GanttTickStep {
    switch seconds {
    case 0.0..<1: return _GanttTickStep.seconds(seconds)
    case 1.0..<60: return _GanttTickStep.seconds(seconds)
    case 60.0..<3600: return _GanttTickStep.seconds(seconds)
    case 3600.0..<86400: return _GanttTickStep.seconds(seconds)
    case 86400.0..<(86400 * 7): return _GanttTickStep.calendar(.day, max(1, Int(seconds / 86400)))
    case (86400 * 7)..<(86400 * 30): return _GanttTickStep.week(max(1, Int(seconds / (86400 * 7))), weekday)
    case (86400 * 30)..<(86400 * 365): return _GanttTickStep.calendar(.month, max(1, Int(seconds / (86400 * 30))))
    default: return _GanttTickStep.calendar(.year, max(1, Int(seconds / (86400 * 365))))
    }
}

private func _translateDayjsFormatToSwift(_ format: String) -> String {
    var result = format
    let mappings: [(String, String)] = [
        ("%Y", "yyyy"), ("%y", "yy"), ("%m", "MM"), ("%b", "MMM"), ("%B", "MMMM"),
        ("%d", "dd"), ("%e", "d"),
        ("%H", "HH"), ("%M", "mm"), ("%S", "ss"),
        ("YYYY", "yyyy"), ("YY", "yy"), ("MMMM", "MMMM"), ("MMM", "MMM"),
        ("MM", "MM"), ("M", "M"), ("DD", "dd"), ("D", "d"),
        ("HH", "HH"), ("H", "H"), ("mm", "mm"), ("m", "m"), ("ss", "ss"), ("s", "s"),
        ("SSS", "SSS"), ("SS", "SS"), ("S", "S"),
    ]
    for (dayjsToken, swiftToken) in mappings {
        result = result.replacingOccurrences(of: dayjsToken, with: swiftToken)
    }
    return result
}

private func _alignToWeekday(_ date: Date, weekday: String) -> Date {
    let targetIso: [String: Int] = [
        "monday": 1, "tuesday": 2, "wednesday": 3, "thursday": 4,
        "friday": 5, "saturday": 6, "sunday": 7,
    ]
    let target = targetIso[weekday] ?? 7
    let cal = Calendar.current
    let currentDow = cal.dateComponents([.weekday], from: date).weekday ?? 1
    let currentIso = currentDow == 1 ? 7 : currentDow - 1
    let daysToAdd = (target - currentIso + 7) % 7
    return cal.startOfDay(for: cal.date(byAdding: .day, value: daysToAdd, to: date) ?? date)
}

private func _computeCategoryHeights(_ sections: [GanttSection], positionedTasks: [PositionedGanttTask]) -> [String: Int] {
    var heights: [String: Int] = [:]
    for section in sections {
        let tasks = positionedTasks.filter { $0.task.section == section.name }
        let maxRow = tasks.map { $0.row }.max() ?? 0
        let minRow = tasks.map { $0.row }.min() ?? 0
        heights[section.name] = maxRow - minRow + 1
    }
    return heights
}

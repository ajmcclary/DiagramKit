import Foundation
import DiagramKitCommon

// MARK: - Errors

public enum GanttParserError: Error, LocalizedError, _RecoverableDiagramError {
    case invalidHeader(String)
    case invalidTaskDefinition(String)
    case unexpectedLine(String)
    case unresolvedDependency(String)
    case invalidDate(String)
    case invalidDuration(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let msg): return "Invalid Gantt header: \(msg)"
        case .invalidTaskDefinition(let msg): return "Invalid task definition: \(msg)"
        case .unexpectedLine(let msg): return "Unexpected line: \(msg)"
        case .unresolvedDependency(let msg): return "Unresolved dependency: \(msg)"
        case .invalidDate(let msg): return "Invalid date: \(msg)"
        case .invalidDuration(let msg): return "Invalid duration: \(msg)"
        }
    }
}

// MARK: - Parser Entry Point

public func parseGanttDiagram(
    _ lines: [String],
    frontmatter: DiagramFrontmatter? = nil
) throws -> GanttDiagram {
    try _parseGanttDiagramEntry(lines, frontmatter: frontmatter)
}

private func _parseGanttDiagramEntry(
    _ lines: [String],
    frontmatter: DiagramFrontmatter?
) throws -> GanttDiagram {
    var diagram = GanttDiagram()

    // Configure from frontmatter
    if let fm = frontmatter {
        if diagram.title == nil { diagram.title = fm.title ?? fm.diagramTitle }
        if let gc = fm.ganttConfig {
            diagram.config = gc
            if !gc.displayMode.isEmpty { diagram.displayMode = gc.displayMode }
        }
    }

    // State for line-at-a-time parsing
    var rawTasks: [GanttRawTask] = []
    var sections: [GanttSection] = []
    var currentSection: String = ""
    var taskIdLookup: [String: Int] = [:]  // taskId -> index in rawTasks
    var lastTaskID: String? = nil
    var lastOrder: Int = 0
    var taskCnt: Int = 0
    var multilineAccDescr: String? = nil
    var inMultilineAccDescr: Bool = false

    enum State {
        case expectHeader
        case body
    }
    var state: State = .expectHeader

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { continue }

        let lower = trimmed.lowercased()

        // Handle multiline accDescr
        if inMultilineAccDescr {
            if trimmed == "}" {
                diagram.accDescr = multilineAccDescr?.trimmingCharacters(in: .whitespacesAndNewlines)
                inMultilineAccDescr = false
                multilineAccDescr = nil
                continue
            }
            multilineAccDescr = (multilineAccDescr ?? "") + trimmed + "\n"
            continue
        }

        // Skip comments
        if trimmed.hasPrefix("%%") { continue }

        switch state {
        case .expectHeader:
            if lower.hasPrefix("gantt") {
                state = .body
                continue
            }
            throw GanttParserError.invalidHeader(trimmed)

        case .body:
            // dateFormat
            if lower.hasPrefix("dateformat") {
                let value = _extractAfterKeyword(trimmed, keyword: "dateFormat")
                diagram.dateFormat = value
                continue
            }

            // axisFormat
            if lower.hasPrefix("axisformat") {
                let value = _extractAfterKeyword(trimmed, keyword: "axisFormat")
                diagram.axisFormat = value
                continue
            }

            // tickInterval
            if lower.hasPrefix("tickinterval") {
                let value = _extractAfterKeyword(trimmed, keyword: "tickInterval")
                diagram.tickInterval = value
                continue
            }

            // inclusiveEndDates
            if lower.hasPrefix("inclusiveenddates") {
                diagram.inclusiveEndDates = true
                continue
            }

            // topAxis
            if lower.hasPrefix("topaxis") {
                diagram.topAxis = true
                continue
            }

            // todayMarker
            if lower.hasPrefix("todaymarker") {
                let value = _extractAfterKeyword(trimmed, keyword: "todayMarker")
                diagram.todayMarker = value
                continue
            }

            // weekday
            if lower.hasPrefix("weekday") {
                let value = _extractAfterKeyword(trimmed, keyword: "weekday").lowercased()
                if ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"].contains(value) {
                    diagram.weekday = value
                }
                continue
            }

            // weekend
            if lower.hasPrefix("weekend") {
                let value = _extractAfterKeyword(trimmed, keyword: "weekend").lowercased()
                if value == "friday" || value == "saturday" {
                    diagram.weekend = value
                }
                continue
            }

            // excludes
            if lower.hasPrefix("excludes") {
                let value = _extractAfterKeyword(trimmed, keyword: "excludes")
                diagram.excludes = value.lowercased().split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init).filter { !$0.isEmpty }
                continue
            }

            // includes
            if lower.hasPrefix("includes") {
                let value = _extractAfterKeyword(trimmed, keyword: "includes")
                diagram.includes = value.lowercased().split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init).filter { !$0.isEmpty }
                continue
            }

            // title
            if lower.hasPrefix("title") {
                let value = _extractAfterKeyword(trimmed, keyword: "title")
                diagram.title = value
                continue
            }

            // accTitle
            if lower.hasPrefix("acctitle:") {
                let value = _extractAfterColon(trimmed)
                diagram.accTitle = value
                continue
            }

            // accDescr (multiline)
            if lower.hasPrefix("accdescr:") {
                let afterColon = _extractAfterColon(trimmed)
                if afterColon.hasPrefix("{") {
                    inMultilineAccDescr = true
                    multilineAccDescr = ""
                    if afterColon != "{" {
                        let inner = afterColon.dropFirst().trimmingCharacters(in: .whitespaces)
                        if !inner.isEmpty {
                            multilineAccDescr = inner + "\n"
                        }
                    }
                } else {
                    diagram.accDescr = afterColon
                }
                continue
            }

            if lower.hasPrefix("accdescr") && trimmed.contains("{") {
                inMultilineAccDescr = true
                multilineAccDescr = ""
                if let braceIdx = trimmed.firstIndex(of: "{") {
                    let afterBrace = trimmed[trimmed.index(after: braceIdx)...]
                    if let closeIdx = afterBrace.firstIndex(of: "}") {
                        let inner = String(afterBrace[..<closeIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                        diagram.accDescr = inner
                        inMultilineAccDescr = false
                        multilineAccDescr = nil
                    } else {
                        let inner = String(afterBrace).trimmingCharacters(in: .whitespaces)
                        if !inner.isEmpty {
                            multilineAccDescr = inner + "\n"
                        }
                    }
                }
                continue
            }

            // section
            if lower.hasPrefix("section") {
                let value = _extractAfterKeyword(trimmed, keyword: "section")
                currentSection = value
                let section = GanttSection(name: value, index: sections.count)
                sections.append(section)
                continue
            }

            // click statement
            if lower.hasPrefix("click") {
                _parseClickStatement(trimmed, rawTasks: &rawTasks, taskIdLookup: taskIdLookup)
                continue
            }

            // Task line: taskText : taskData
            if let colonIdx = trimmed.firstIndex(of: ":") {
                let taskText = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let taskDataStr = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

                if !taskText.isEmpty {
                    let rawTask = _parseTaskData(
                        taskText: taskText,
                        taskDataStr: taskDataStr,
                        currentSection: currentSection,
                        lastTaskID: lastTaskID,
                        lastOrder: &lastOrder,
                        taskCnt: &taskCnt
                    )
                    let pos = rawTasks.count
                    rawTasks.append(rawTask)
                    taskIdLookup[rawTask.id] = pos
                    lastTaskID = rawTask.id
                }
                continue
            }
        }
    }

    // Compile tasks
    _compileTasks(
        &rawTasks,
        dateFormat: diagram.dateFormat,
        inclusiveEndDates: diagram.inclusiveEndDates,
        excludes: diagram.excludes,
        includes: diagram.includes,
        weekend: diagram.weekend,
        weekday: diagram.weekday,
        taskIdLookup: taskIdLookup
    )

    // Convert to GanttTask array (preserving insertion order)
    diagram.tasks = rawTasks.map { raw in
        GanttTask(
            id: raw.id,
            task: raw.task,
            section: raw.section,
            type: raw.type,
            tags: raw.tags,
            startTime: raw.startTime ?? Date(),
            endTime: raw.endTime ?? Date(),
            renderEndTime: raw.renderEndTime,
            manualEndTime: raw.manualEndTime,
            order: raw.order,
            classes: raw.classes,
            link: raw.link,
            callbackName: raw.callbackName,
            callbackArgs: raw.callbackArgs
        )
    }

    diagram.sections = sections
    diagram.links = _linksFromTasks(rawTasks)
    return diagram
}

// MARK: - Keyword Extraction Helpers

private func _extractAfterKeyword(_ line: String, keyword: String) -> String {
    let lower = line.lowercased()
    guard let range = lower.range(of: keyword.lowercased()) else { return "" }
    let after = line[range.upperBound...]
    return after.trimmingCharacters(in: .whitespaces)
}

private func _extractAfterColon(_ line: String) -> String {
    guard let colonIdx = line.firstIndex(of: ":") else { return "" }
    return String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
}

// MARK: - Task Data Parsing

private let _ganttTags = ["active", "done", "crit", "milestone", "vert"]

private func _parseTaskData(
    taskText: String,
    taskDataStr: String,
    currentSection: String,
    lastTaskID: String?,
    lastOrder: inout Int,
    taskCnt: inout Int
) -> GanttRawTask {
    let ds = taskDataStr.hasPrefix(":") ? String(taskDataStr.dropFirst()) : taskDataStr
    var data = ds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

    var tags = GanttTaskTags()

    // Consume leading tags
    var matchFound = true
    while matchFound {
        matchFound = false
        for tag in _ganttTags {
            let pattern = #"^\s*\#(tag)\s*$"#
            if data.first?.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                switch tag {
                case "active": tags.insert(.active)
                case "done": tags.insert(.done)
                case "crit": tags.insert(.crit)
                case "milestone": tags.insert(.milestone)
                case "vert": tags.insert(.vert)
                default: break
                }
                data.removeFirst()
                matchFound = true
                break
            }
        }
        if data.isEmpty { break }
    }

    let order = lastOrder
    lastOrder += 1

    var rawTask = GanttRawTask(
        section: currentSection,
        type: currentSection,
        raw: GanttRawTaskData(data: ds),
        task: taskText,
        order: order
    )

    rawTask.tags = tags
    rawTask.prevTaskId = lastTaskID

    switch data.count {
    case 1:
        taskCnt += 1
        rawTask.id = "task\(taskCnt)"
        rawTask.raw.startTime = .prevTaskEnd
        rawTask.raw.endTime = .data(data[0])
    case 2:
        taskCnt += 1
        rawTask.id = "task\(taskCnt)"
        rawTask.raw.startTime = .getStartDate(data[0])
        rawTask.raw.endTime = .data(data[1])
    case 3:
        rawTask.id = data[0]
        rawTask.raw.startTime = .getStartDate(data[1])
        rawTask.raw.endTime = .data(data[2])
    default:
        taskCnt += 1
        rawTask.id = "task\(taskCnt)"
        rawTask.raw.startTime = .prevTaskEnd
        rawTask.raw.endTime = .data("")
    }

    return rawTask
}

// MARK: - Date/Duration Resolution

private let _weekendStartDay: [String: Int] = ["friday": 5, "saturday": 6]

private func _translateDayjsFormat(_ format: String) -> String {
    var result = format
    let mappings: [(String, String)] = [
        ("YYYY", "yyyy"), ("YY", "yy"), ("MMMM", "MMMM"), ("MMM", "MMM"),
        ("MM", "MM"), ("M", "M"), ("DD", "dd"), ("D", "d"),
        ("HH", "HH"), ("H", "H"), ("hh", "hh"), ("h", "h"),
        ("mm", "mm"), ("m", "m"), ("ss", "ss"), ("s", "s"),
        ("SSS", "SSS"), ("SS", "SS"), ("S", "S"),
        ("a", "a"), ("A", "a"), ("ZZ", "ZZZZZ"), ("Z", "Z"),
    ]
    for (dayjsToken, swiftToken) in mappings {
        result = result.replacingOccurrences(of: dayjsToken, with: swiftToken)
    }
    return result
}

private nonisolated(unsafe) let _dateFormatterCache = NSCache<NSString, DateFormatter>()

private func _dateFormatter(for dateFormat: String) -> DateFormatter {
    let key = dateFormat as NSString
    if let cached = _dateFormatterCache.object(forKey: key) {
        return cached
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = _translateDayjsFormat(dateFormat)
    formatter.timeZone = TimeZone.current
    _dateFormatterCache.setObject(formatter, forKey: key)
    return formatter
}

private func _isTimestampFormat(_ format: String) -> Bool {
    let trimmed = format.trimmingCharacters(in: .whitespaces)
    return trimmed == "x" || trimmed == "X"
}

private func _findLatestTaskEnd(_ ids: [String], taskIdLookup: [String: Int], rawTasks: [GanttRawTask]) -> Date? {
    var foundKnownTask = false
    var latest: Date? = nil
    for id in ids {
        guard let idx = taskIdLookup[id] else { continue }
        foundKnownTask = true
        guard let endTime = rawTasks[idx].endTime else {
            return nil
        }
        if latest.map({ endTime > $0 }) ?? true {
            latest = endTime
        }
    }
    return foundKnownTask ? latest : _todayMidnight()
}

private func _findEarliestTaskStart(_ ids: [String], taskIdLookup: [String: Int], rawTasks: [GanttRawTask]) -> Date? {
    var foundKnownTask = false
    var earliest: Date? = nil
    for id in ids {
        guard let idx = taskIdLookup[id] else { continue }
        foundKnownTask = true
        guard let startTime = rawTasks[idx].startTime else {
            return nil
        }
        if earliest.map({ startTime < $0 }) ?? true {
            earliest = startTime
        }
    }
    return foundKnownTask ? earliest : _todayMidnight()
}

private func _todayMidnight() -> Date {
    Calendar.current.startOfDay(for: Date())
}

private func _getStartDate(prevTime: Date?, dateFormat: String, str: String, taskIdLookup: [String: Int], rawTasks: [GanttRawTask]) throws -> Date? {
    let trimmed = str.trimmingCharacters(in: .whitespaces)

    // Timestamp format (x = ms, X = seconds)
    if _isTimestampFormat(dateFormat) {
        let isMilliseconds = dateFormat.trimmingCharacters(in: .whitespaces) == "x"
        if let numeric = Double(trimmed) {
            let interval = isMilliseconds ? numeric / 1000.0 : numeric
            return Date(timeIntervalSince1970: interval)
        }
    }

    // after keyword
    let afterPattern = try NSRegularExpression(pattern: #"^after\s+(?<ids>[\d\w\- ]+)"#, options: .caseInsensitive)
    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
    if let match = afterPattern.firstMatch(in: trimmed, options: [], range: range) {
        if let idsRange = Range(match.range(withName: "ids"), in: trimmed) {
            let idsStr = String(trimmed[idsRange])
            let ids = idsStr.split(separator: " ").map(String.init)
            return _findLatestTaskEnd(ids, taskIdLookup: taskIdLookup, rawTasks: rawTasks)
        }
    }

    // Strict parsing with dateFormat
    let fmt = _dateFormatter(for: dateFormat)
    if let parsed = fmt.date(from: trimmed) {
        return parsed
    }

    // Fallback: Date(str)
    let d = _fallbackDateParse(trimmed)
    if let date = d {
        return date
    }

    throw GanttParserError.invalidDate(trimmed)
}

private func _getEndDate(prevTime: Date, dateFormat: String, str: String, inclusive: Bool, taskIdLookup: [String: Int], rawTasks: [GanttRawTask]) throws -> Date? {
    let trimmed = str.trimmingCharacters(in: .whitespaces)

    // until keyword
    let untilPattern = try NSRegularExpression(pattern: #"^until\s+(?<ids>[\d\w\- ]+)"#, options: .caseInsensitive)
    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
    if let match = untilPattern.firstMatch(in: trimmed, options: [], range: range) {
        if let idsRange = Range(match.range(withName: "ids"), in: trimmed) {
            let idsStr = String(trimmed[idsRange])
            let ids = idsStr.split(separator: " ").map(String.init)
            return _findEarliestTaskStart(ids, taskIdLookup: taskIdLookup, rawTasks: rawTasks)
        }
    }

    // Strict parsing with dateFormat
    let fmt = _dateFormatter(for: dateFormat)
    if let parsed = fmt.date(from: trimmed) {
        if inclusive {
            return Calendar.current.date(byAdding: .day, value: 1, to: parsed) ?? parsed
        }
        return parsed
    }

    // Duration parsing
    let (durationValue, durationUnit) = _parseDuration(trimmed)
    if !durationValue.isNaN {
        let added = _addDuration(to: prevTime, value: durationValue, unit: durationUnit)
        return added
    }

    return prevTime
}

private func _parseDuration(_ str: String) -> (Double, String) {
    let pattern = try! NSRegularExpression(pattern: #"^(\d+(?:\.\d+)?)([Mdhmswy]|ms)$"#)
    let range = NSRange(str.startIndex..<str.endIndex, in: str)
    if let match = pattern.firstMatch(in: str, options: [], range: range) {
        if let valRange = Range(match.range(at: 1), in: str),
           let unitRange = Range(match.range(at: 2), in: str) {
            let val = Double(str[valRange]) ?? Double.nan
            let unit = String(str[unitRange])
            return (val, unit)
        }
    }
    return (Double.nan, "ms")
}

private func _addDuration(to date: Date, value: Double, unit: String) -> Date {
    let cal = Calendar.current
    switch unit {
    case "ms":
        return date.addingTimeInterval(value / 1000.0)
    case "s":
        return date.addingTimeInterval(value)
    case "m":
        return date.addingTimeInterval(value * 60)
    case "h":
        return date.addingTimeInterval(value * 3600)
    case "d":
        return date.addingTimeInterval(value * 86400)
    case "w":
        return date.addingTimeInterval(value * 86400 * 7)
    case "M":
        let wholeMonths = Int(value)
        let fractionalDays = (value - Double(wholeMonths)) * 30
        var d = cal.date(byAdding: .month, value: wholeMonths, to: date) ?? date
        d = d.addingTimeInterval(fractionalDays * 86400)
        return d
    case "y":
        let wholeYears = Int(value)
        let fractionalDays = (value - Double(wholeYears)) * 365
        var d = cal.date(byAdding: .year, value: wholeYears, to: date) ?? date
        d = d.addingTimeInterval(fractionalDays * 86400)
        return d
    default:
        return date
    }
}

private func _fallbackDateParse(_ str: String) -> Date? {
    // Try ISO 8601 first
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = isoFormatter.date(from: str) {
        if d.timeIntervalSinceReferenceDate.isNaN { return nil }
        let comps = Calendar.current.dateComponents([.year], from: d)
        if let year = comps.year, year < -10000 || year > 10000 { return nil }
        return d
    }

    // Try without fractional seconds
    isoFormatter.formatOptions = [.withInternetDateTime]
    if let d = isoFormatter.date(from: str) {
        if d.timeIntervalSinceReferenceDate.isNaN { return nil }
        let comps = Calendar.current.dateComponents([.year], from: d)
        if let year = comps.year, year < -10000 || year > 10000 { return nil }
        return d
    }

    // Try common date formats
    let fallbackFormats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy", "dd/MM/yyyy"]
    let fmtr = DateFormatter()
    fmtr.locale = Locale(identifier: "en_US_POSIX")
    for fmt in fallbackFormats {
        fmtr.dateFormat = fmt
        if let d = fmtr.date(from: str) {
            let comps = Calendar.current.dateComponents([.year], from: d)
            if let year = comps.year, year < -10000 || year > 10000 { return nil }
            return d
        }
    }

    return nil
}

// MARK: - isInvalidDate

private func _isInvalidDate(_ date: Date, dateFormat: String, excludes: [String], includes: [String], weekend: String, weekday: String) -> Bool {
    let df = _dateFormatter(for: dateFormat)
    let formattedDate = df.string(from: date)

    let dateOnlyFmt = DateFormatter()
    dateOnlyFmt.locale = Locale(identifier: "en_US_POSIX")
    dateOnlyFmt.dateFormat = "yyyy-MM-dd"
    let dateOnly = dateOnlyFmt.string(from: date)

    if includes.contains(formattedDate) || includes.contains(dateOnly) {
        return false
    }

    if excludes.contains("weekends") {
        let comps = Calendar.current.dateComponents([.weekday], from: date)
        if let dow = comps.weekday {
            let weekendStart = _weekendStartDay[weekend] ?? 6
            let weekendEnd = weekendStart == 5 ? 6 : 7
            let adjustedDow = dow == 1 ? 7 : dow - 1  // Convert to Mon=1..Sun=7 (ISO)
            if adjustedDow == weekendStart || adjustedDow == weekendEnd {
                return true
            }
        }
    }

    let weekDayNameFormatter = DateFormatter()
    weekDayNameFormatter.dateFormat = "EEEE"
    let dayName = weekDayNameFormatter.string(from: date).lowercased()
    if excludes.contains(dayName) {
        return true
    }

    return excludes.contains(formattedDate) || excludes.contains(dateOnly)
}

// MARK: - checkTaskDates

private func _checkTaskDates(_ rawTask: inout GanttRawTask, dateFormat: String, excludes: [String], includes: [String], weekend: String, weekday: String) {
    guard !excludes.isEmpty, !rawTask.manualEndTime,
          let startTime = rawTask.startTime,
          let endTime = rawTask.endTime else { return }

    let cal = Calendar.current
    var checkDate = startTime
    var adjustedEnd = endTime
    var renderEndTime: Date? = nil
    var previousDateWasInvalid = false

    while checkDate <= adjustedEnd {
        if !previousDateWasInvalid {
            renderEndTime = adjustedEnd
        }
        let currentDateIsInvalid = _isInvalidDate(checkDate, dateFormat: dateFormat, excludes: excludes, includes: includes, weekend: weekend, weekday: weekday)
        if currentDateIsInvalid {
            adjustedEnd = cal.date(byAdding: .day, value: 1, to: adjustedEnd) ?? adjustedEnd
        }
        previousDateWasInvalid = currentDateIsInvalid
        checkDate = cal.date(byAdding: .day, value: 1, to: checkDate) ?? checkDate
    }

    rawTask.endTime = adjustedEnd
    rawTask.renderEndTime = renderEndTime
}

// MARK: - Compile Tasks

private func _compileTasks(
    _ rawTasks: inout [GanttRawTask],
    dateFormat: String,
    inclusiveEndDates: Bool,
    excludes: [String],
    includes: [String],
    weekend: String,
    weekday: String,
    taskIdLookup: [String: Int]
) {
    let maxDepth = 10
    var allProcessed = false
    var iteration = 0

    while !allProcessed && iteration < maxDepth {
        allProcessed = true
        for i in rawTasks.indices {
            if rawTasks[i].processed { continue }

            let raw = rawTasks[i]

            // Resolve startTime
            var startTime: Date? = nil
            if let startType = raw.raw.startTime {
                switch startType {
                case .prevTaskEnd:
                    if let prevId = raw.prevTaskId, let prevIdx = taskIdLookup[prevId], let prevEnd = rawTasks[prevIdx].endTime {
                        startTime = prevEnd
                    }
                case .getStartDate(let startData):
                    do {
                        startTime = try _getStartDate(prevTime: nil, dateFormat: dateFormat, str: startData, taskIdLookup: taskIdLookup, rawTasks: rawTasks)
                    } catch {
                        startTime = nil
                    }
                }
            }

            if let st = startTime {
                rawTasks[i].startTime = st

                // Resolve endTime
                if let endType = raw.raw.endTime {
                    if case .data(let endData) = endType {
                        if let et = try? _getEndDate(prevTime: st, dateFormat: dateFormat, str: endData, inclusive: inclusiveEndDates, taskIdLookup: taskIdLookup, rawTasks: rawTasks) {
                            rawTasks[i].endTime = et
                            rawTasks[i].processed = true

                            // manualEndTime check: is endData a valid date?
                            let isoFmt = ISO8601DateFormatter()
                            isoFmt.formatOptions = [.withFullDate]
                            let df = _dateFormatter(for: "YYYY-MM-DD")
                            if df.date(from: endData.trimmingCharacters(in: .whitespaces)) != nil || isoFmt.date(from: endData.trimmingCharacters(in: .whitespaces)) != nil {
                                rawTasks[i].manualEndTime = true
                            }

                            // checkTaskDates
                            _checkTaskDates(&rawTasks[i], dateFormat: dateFormat, excludes: excludes, includes: includes, weekend: weekend, weekday: weekday)
                        }
                    }
                }
            }

            if !rawTasks[i].processed {
                allProcessed = false
            }
        }
        iteration += 1
    }
}

// MARK: - Click Statement Parsing

private func _parseClickStatement(_ line: String, rawTasks: inout [GanttRawTask], taskIdLookup: [String: Int]) {
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    guard trimmed.lowercased().hasPrefix("click") else { return }
    let afterClick = _extractAfterKeyword(trimmed, keyword: "click")

    guard let idTokenEnd = afterClick.firstIndex(where: { $0.isWhitespace }) else { return }
    let ids = afterClick[..<idTokenEnd]
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    let commands = String(afterClick[idTokenEnd...])

    let href = _parseClickHref(commands)
    let callback = _parseClickCallback(commands)

    for id in ids {
        if let idx = taskIdLookup[id] {
            if !rawTasks[idx].classes.contains("clickable") {
                rawTasks[idx].classes.append("clickable")
            }
            if let href {
                rawTasks[idx].link = href
            }
            if let callback {
                rawTasks[idx].callbackName = callback.name
                rawTasks[idx].callbackArgs = callback.args.isEmpty ? [id] : callback.args
            }
        }
    }
}

private func _parseClickHref(_ commands: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: #"(?i)\bhref\s+"([^"]*)""#) else { return nil }
    let range = NSRange(commands.startIndex..<commands.endIndex, in: commands)
    guard let match = regex.firstMatch(in: commands, options: [], range: range),
          let hrefRange = Range(match.range(at: 1), in: commands) else {
        return nil
    }
    return _sanitizeGanttUrl(String(commands[hrefRange]))
}

private func _parseClickCallback(_ commands: String) -> (name: String, args: [String])? {
    guard let regex = try? NSRegularExpression(pattern: #"(?i)\bcall\s+([^\s(]+)\s*\(([^)]*)\)"#) else { return nil }
    let range = NSRange(commands.startIndex..<commands.endIndex, in: commands)
    guard let match = regex.firstMatch(in: commands, options: [], range: range),
          let nameRange = Range(match.range(at: 1), in: commands),
          let argsRange = Range(match.range(at: 2), in: commands) else {
        return nil
    }
    let name = String(commands[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    let args = _splitCallbackArgs(String(commands[argsRange]))
    return (name, args)
}

private func _splitCallbackArgs(_ str: String) -> [String] {
    var args: [String] = []
    var current = ""
    var inQuote = false

    for ch in str {
        if ch == "\"" {
            inQuote.toggle()
            current.append(ch)
            continue
        }
        if ch == "," && !inQuote {
            let item = _cleanCallbackArg(current)
            if !item.isEmpty {
                args.append(item)
            }
            current = ""
        } else {
            current.append(ch)
        }
    }

    let tail = _cleanCallbackArg(current)
    if !tail.isEmpty {
        args.append(tail)
    }
    return args
}

private func _cleanCallbackArg(_ value: String) -> String {
    var item = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if item.hasPrefix("\"") && item.hasSuffix("\"") && item.count >= 2 {
        item.removeFirst()
        item.removeLast()
    }
    return item
}

private func _sanitizeGanttUrl(_ href: String) -> String? {
    let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowered = trimmed.lowercased()
    if lowered.hasPrefix("javascript:") || lowered.hasPrefix("data:") || lowered.hasPrefix("vbscript:") || lowered.hasPrefix("file:") {
        return nil
    }
    return trimmed
}


// MARK: - Links

private func _linksFromTasks(_ rawTasks: [GanttRawTask]) -> [String: String] {
    var links: [String: String] = [:]
    for task in rawTasks {
        if let link = task.link {
            links[task.id] = link
        }
    }
    return links
}

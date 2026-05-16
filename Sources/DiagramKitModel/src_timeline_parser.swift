import Foundation
import DiagramKitCommon

// MARK: - Parse Errors

public enum TimelineParserError: Error, LocalizedError, _RecoverableDiagramError {
    case invalidHeader(String)
    case strayEventContinuation(String)
    case incompleteMultilineAccDescr

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let found):
            return "Invalid timeline header. Expected 'timeline' or 'timeline LR'/'timeline TD', found '\(found)'."
        case .strayEventContinuation(let line):
            return "Stray event continuation '\(line)' before any period statement."
        case .incompleteMultilineAccDescr:
            return "Unfinished accDescr { } block."
        }
    }
}

// MARK: - Parser

public func parseTimelineDiagram(_ lines: [String], frontmatter: DiagramFrontmatter?) throws -> (TimelineDiagram, [DiagramDiagnostic]) {
    (try _parseTimelineDiagram(lines, frontmatter: frontmatter), [])
}

private func _parseTimelineDiagram(_ lines: [String], frontmatter: DiagramFrontmatter?) throws -> TimelineDiagram {
    enum ParseState {
        case expectHeader
        case body
    }

    var state = ParseState.expectHeader
    var direction = TimelineDirection.LR
    var diagramTitle: String?
    var accTitle: String?
    var accDescr: String?
    var inMultilineAccDescr = false

    var currentSection = ""
    var sections: [String] = []
    var tasks: [TimelineTask] = []
    var currentTaskId = 0

    func appendAccDescrLine(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        accDescr = (accDescr ?? "") + (accDescr != nil ? "\n" : "") + trimmed
    }

    for rawLine in lines {
        let trimmedRaw = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmedRaw.isEmpty {
            continue
        }

        switch state {
        case .expectHeader:
            let headerLower = trimmedRaw.lowercased()
            if headerLower == "timeline" {
                direction = .LR
                state = .body
                continue
            }
            if headerLower == "timeline lr" {
                direction = .LR
                state = .body
                continue
            }
            if headerLower == "timeline td" {
                direction = .TD
                state = .body
                continue
            }
            throw TimelineParserError.invalidHeader(trimmedRaw)

        case .body:
            break
        }

        if trimmedRaw.hasPrefix("%%") {
            continue
        }

        if trimmedRaw.hasPrefix("#") {
            continue
        }

        let lineWithoutTrailingComment = _stripTrailingPercentComment(trimmedRaw)
        guard !lineWithoutTrailingComment.isEmpty else { continue }

        if inMultilineAccDescr {
            if let closeIndex = lineWithoutTrailingComment.firstIndex(of: "}") {
                appendAccDescrLine(String(lineWithoutTrailingComment[..<closeIndex]))
                inMultilineAccDescr = false
                continue
            }
            appendAccDescrLine(lineWithoutTrailingComment)
            continue
        }

        if let afterOpen = _timelineAccessibilityBlockRemainder(lineWithoutTrailingComment, keyword: "accDescr") {
                if let closeIndex = afterOpen.firstIndex(of: "}") {
                    appendAccDescrLine(String(afterOpen[..<closeIndex]))
                    continue
                }
                appendAccDescrLine(afterOpen)
                inMultilineAccDescr = true
                continue
        }

        if let descr = _timelineAccessibilityColonRemainder(lineWithoutTrailingComment, keyword: "accDescr") {
            accDescr = descr
            continue
        }

        if let title = _timelineAccessibilityColonRemainder(lineWithoutTrailingComment, keyword: "accTitle") {
            accTitle = title
            continue
        }

        if let title = _timelineDirectiveRemainder(lineWithoutTrailingComment, keyword: "title") {
            diagramTitle = title
            continue
        }

        if let section = _timelineDirectiveRemainder(lineWithoutTrailingComment, keyword: "section") {
            currentSection = section
            sections.append(currentSection)
            continue
        }

        if lineWithoutTrailingComment.hasPrefix(":") {
            let afterColon = String(lineWithoutTrailingComment.dropFirst())
            if afterColon.hasPrefix(" ") {
                let eventText = afterColon.trimmingCharacters(in: .whitespaces)
                guard !tasks.isEmpty else {
                    throw TimelineParserError.strayEventContinuation(lineWithoutTrailingComment)
                }
                let events = _splitEvents(eventText)
                for text in events {
                    let eventId = tasks[tasks.count - 1].events.count
                    tasks[tasks.count - 1].events.append(TimelineEvent(id: eventId, text: text))
                }
                continue
            }
        }

        let (periodText, events) = _splitPeriodAndEvents(lineWithoutTrailingComment)
        guard !periodText.isEmpty else {
            continue
        }

        let task = TimelineTask(
            id: currentTaskId,
            section: currentSection,
            text: periodText,
            events: events.enumerated().map { TimelineEvent(id: $0.offset, text: $0.element) }
        )
        tasks.append(task)
        currentTaskId += 1
    }

    if inMultilineAccDescr {
        throw TimelineParserError.incompleteMultilineAccDescr
    }

    var diagram = TimelineDiagram(
        direction: direction,
        diagramTitle: diagramTitle,
        accTitle: accTitle,
        accDescr: accDescr,
        sections: sections,
        tasks: tasks,
        config: TimelineDiagramConfig(),
        theme: TimelineThemeConfig.default,
        themeName: nil,
        look: nil
    )

    if let fm = frontmatter {
        if diagram.diagramTitle == nil { diagram.diagramTitle = fm.shared.title }
        if let tc = fm.perDiagram.timeline.config { diagram.config = tc }
        if let tt = fm.perDiagram.timeline.theme { diagram.theme = tt }
        diagram.themeName = fm.shared.theme
        diagram.look = fm.shared.look
    }

    return diagram
}

// MARK: - Colon splitting helpers

private func _splitPeriodAndEvents(_ line: String) -> (period: String, events: [String]) {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    var period = ""
    var events: [String] = []
    var currentIndex = trimmed.startIndex

    while currentIndex < trimmed.endIndex {
        if trimmed[currentIndex] == ":" {
            let nextIndex = trimmed.index(after: currentIndex)
            if nextIndex < trimmed.endIndex && trimmed[nextIndex] == " " {
                let afterColon = String(trimmed[nextIndex...]).trimmingCharacters(in: .whitespaces)
                events = _splitEvents(afterColon)
                break
            }
        }
        period.append(trimmed[currentIndex])
        currentIndex = trimmed.index(after: currentIndex)
    }

    return (period.trimmingCharacters(in: .whitespaces), events)
}

private func _splitEvents(_ text: String) -> [String] {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return [] }

    var events: [String] = []
    var current = ""
    var currentIndex = trimmed.startIndex

    while currentIndex < trimmed.endIndex {
        if trimmed[currentIndex] == ":" {
            let nextIndex = trimmed.index(after: currentIndex)
            if nextIndex < trimmed.endIndex && trimmed[nextIndex] == " " {
                events.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                currentIndex = trimmed.index(nextIndex, offsetBy: 1)
                continue
            }
        }
        current.append(trimmed[currentIndex])
        currentIndex = trimmed.index(after: currentIndex)
    }

    events.append(current.trimmingCharacters(in: .whitespaces))
    return events.filter { !$0.isEmpty }
}

private func _stripTrailingPercentComment(_ line: String) -> String {
    guard let range = line.range(of: "%%") else { return line }
    return String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
}

private func _timelineKeywordEnd(_ line: String, keyword: String) -> String.Index? {
    guard line.count >= keyword.count else { return nil }
    let end = line.index(line.startIndex, offsetBy: keyword.count)
    guard String(line[..<end]).lowercased() == keyword.lowercased() else { return nil }
    return end
}

private func _timelineDirectiveRemainder(_ line: String, keyword: String) -> String? {
    guard let keywordEnd = _timelineKeywordEnd(line, keyword: keyword),
          keywordEnd < line.endIndex,
          line[keywordEnd].isWhitespace
    else {
        return nil
    }
    return String(line[line.index(after: keywordEnd)...]).trimmingCharacters(in: .whitespaces)
}

private func _timelineAccessibilityColonRemainder(_ line: String, keyword: String) -> String? {
    guard let keywordEnd = _timelineKeywordEnd(line, keyword: keyword) else { return nil }
    var index = keywordEnd
    while index < line.endIndex, line[index].isWhitespace {
        index = line.index(after: index)
    }
    guard index < line.endIndex, line[index] == ":" else { return nil }
    index = line.index(after: index)
    while index < line.endIndex, line[index].isWhitespace {
        index = line.index(after: index)
    }
    return String(line[index...]).trimmingCharacters(in: .whitespaces)
}

private func _timelineAccessibilityBlockRemainder(_ line: String, keyword: String) -> String? {
    guard let keywordEnd = _timelineKeywordEnd(line, keyword: keyword) else { return nil }
    var index = keywordEnd
    while index < line.endIndex, line[index].isWhitespace {
        index = line.index(after: index)
    }
    guard index < line.endIndex, line[index] == "{" else { return nil }
    index = line.index(after: index)
    while index < line.endIndex, line[index].isWhitespace {
        index = line.index(after: index)
    }
    return String(line[index...])
}

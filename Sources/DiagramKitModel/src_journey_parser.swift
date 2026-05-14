import Foundation
import DiagramKitCommon

// MARK: - Parse Errors

public enum JourneyParserError: Error, LocalizedError, _RecoverableDiagramError {
    case invalidHeader(String)
    case unexpectedLine(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidHeader(line):
            return "Invalid journey diagram header. Expected 'journey', found '\(line)'."
        case let .unexpectedLine(line):
            return "Unexpected line in journey diagram: \(line)"
        }
    }
}

// MARK: - Parser

public func parseJourneyDiagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> (JourneyDiagram, [DiagramDiagnostic]) {
    (try _parseJourneyDiagramEntry(lines, frontmatter: frontmatter), [])
}

private func _parseJourneyDiagramEntry(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> JourneyDiagram {
    enum ParseState {
        case expectHeader
        case body
    }

    var state = ParseState.expectHeader
    var currentSection = ""
    var sections: [String] = []
    var tasks: [JourneyTask] = []
    var title: String? = nil
    var accTitle: String? = nil
    var accDescr: String? = nil
    var inMultilineAccDescr = false

    func appendAccDescrLine(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        accDescr = (accDescr ?? "") + (accDescr != nil ? "\n" : "") + trimmed
    }

    func stripComment(_ line: String) -> String {
        var inQuote = false
        for (i, ch) in line.enumerated() {
            if ch == "\"" || ch == "'" {
                inQuote.toggle()
            }
            if ch == "#" && !inQuote {
                return String(line[line.startIndex..<line.index(line.startIndex, offsetBy: i)]).trimmingCharacters(in: .whitespaces)
            }
        }
        return line.trimmingCharacters(in: .whitespaces)
    }

    for rawLine in lines {
        let trimmedRaw = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmedRaw.isEmpty || trimmedRaw.hasPrefix("%%") {
            continue
        }

        switch state {
        case .expectHeader:
            guard trimmedRaw.lowercased() == "journey" else {
                throw JourneyParserError.invalidHeader(trimmedRaw)
            }
            state = .body
            continue

        case .body:
            break
        }

        let line = stripComment(rawLine).trimmingCharacters(in: .whitespaces)
        if line.isEmpty { continue }

        if inMultilineAccDescr {
            if let closeIndex = line.firstIndex(of: "}") {
                appendAccDescrLine(String(line[..<closeIndex]))
                inMultilineAccDescr = false
                continue
            }
            appendAccDescrLine(line)
            continue
        }

        // accDescr multiline start
        if let m = line.firstMatch(of: #/^accDescr\s*\{\s*(.*)/#) {
            let afterOpen = String(m.output.1)
            if let closeIndex = afterOpen.firstIndex(of: "}") {
                appendAccDescrLine(String(afterOpen[..<closeIndex]))
                inMultilineAccDescr = false
            } else {
                appendAccDescrLine(afterOpen)
                inMultilineAccDescr = true
            }
            continue
        }

        // accTitle: value
        if let m = line.firstMatch(of: #/^accTitle\s*:\s*(.+)/#) {
            accTitle = String(m.output.1).trimmingCharacters(in: .whitespaces)
            continue
        }

        // accDescr: value (single line)
        if let m = line.firstMatch(of: #/^accDescr\s*:\s*(.+)/#) {
            accDescr = String(m.output.1).trimmingCharacters(in: .whitespaces)
            continue
        }

        // title <text>
        if let m = line.firstMatch(of: #/^title\s+(.+)/#) {
            title = String(m.output.1).trimmingCharacters(in: .whitespaces)
            continue
        }

        // section <text>
        if let m = line.firstMatch(of: #/^section\s+(.+)/#) {
            currentSection = String(m.output.1).trimmingCharacters(in: .whitespaces)
            sections.append(currentSection)
            continue
        }

        // task line: everything before first colon is taskName, everything after is taskData
        if let colonIdx = line.firstIndex(of: ":") {
            let taskName = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let taskData = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

            let score: Int
            let people: [String]

            let pieces = taskData.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            if pieces.count <= 1 {
                score = Int(pieces.first ?? "") ?? 0
                people = []
            } else {
                score = Int(pieces[0]) ?? 0
                people = pieces[1].split(separator: ",", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }

            tasks.append(JourneyTask(
                section: currentSection,
                task: taskName,
                score: score,
                people: people
            ))
            continue
        }

        throw JourneyParserError.unexpectedLine(line)
    }

    var seenActors = Set<String>()
    var actors: [String] = []
    for person in tasks.flatMap(\.people) {
        if seenActors.insert(person).inserted {
            actors.append(person)
        }
    }

    var diagram = JourneyDiagram(
        title: title,
        accTitle: accTitle,
        accDescr: accDescr,
        sections: sections,
        tasks: tasks,
        actors: actors,
        config: nil
    )

    if let fm = frontmatter {
        if diagram.title == nil { diagram.title = fm.title }
        diagram.config = fm.journeyConfig
    }

    return diagram
}

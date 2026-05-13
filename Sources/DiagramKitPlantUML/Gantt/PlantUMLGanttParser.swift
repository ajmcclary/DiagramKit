import Foundation
import DiagramKitImport

/// Line-based parser for PlantUML gantt bodies between
/// `@startgantt`/`@endgantt`.
///
/// Supported lines:
///   - `project starts YYYY-MM-DD`
///   - `[Name] lasts N days`
///   - `[Name] starts YYYY-MM-DD`
///   - `[Name] ends YYYY-MM-DD`
///   - `[Name] starts at [Other]'s end`
///
/// Lines that don't match are reported via `unsupportedLines` for
/// upstream diagnostics.
public struct PlantUMLGanttParser {

    public init() {}

    public func parse(_ body: String) -> PlantUMLGanttAST {
        var ast = PlantUMLGanttAST()
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("'") { continue }

            if let date = parseProjectStarts(trimmed) {
                ast.projectStart = date
                continue
            }

            if let stmt = parseTaskStatement(trimmed) {
                ast.statements.append(stmt)
                continue
            }

            ast.unsupportedLines.append(trimmed)
        }
        return ast
    }

    // MARK: - Project header

    private func parseProjectStarts(_ line: String) -> Date? {
        let prefix = "project starts "
        guard line.lowercased().hasPrefix(prefix) else { return nil }
        let dateStr = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        return Self.parseISODate(dateStr)
    }

    // MARK: - Task statements

    private func parseTaskStatement(_ line: String) -> PlantUMLGanttStatement? {
        // All supported statements begin with `[Name]`
        guard line.hasPrefix("[") else { return nil }
        guard let closingBracket = line.firstIndex(of: "]") else { return nil }
        let name = String(line[line.index(after: line.startIndex)..<closingBracket])
            .trimmingCharacters(in: .whitespaces)
        let rest = line[line.index(after: closingBracket)...]
            .trimmingCharacters(in: .whitespaces)

        // `lasts N days`
        if rest.lowercased().hasPrefix("lasts ") {
            let after = String(rest.dropFirst("lasts ".count))
            // Accept "N days" or "N day"
            let tokens = after.split(separator: " ").map(String.init)
            if let first = tokens.first, let days = Int(first) {
                return .duration(name: name, days: days)
            }
            return nil
        }

        // `starts at [Other]'s end`
        if rest.lowercased().hasPrefix("starts at ") {
            let after = String(rest.dropFirst("starts at ".count))
                .trimmingCharacters(in: .whitespaces)
            guard after.hasPrefix("[") else { return nil }
            guard let closing = after.firstIndex(of: "]") else { return nil }
            let other = String(after[after.index(after: after.startIndex)..<closing])
                .trimmingCharacters(in: .whitespaces)
            let tail = after[after.index(after: closing)...]
                .trimmingCharacters(in: .whitespaces)
            // Accept apostrophe variants ("'s end" or "s end").
            if tail.contains("end") {
                return .startsAtOtherEnd(name: name, other: other)
            }
            return nil
        }

        // `starts YYYY-MM-DD`
        if rest.lowercased().hasPrefix("starts ") {
            let dateStr = String(rest.dropFirst("starts ".count))
                .trimmingCharacters(in: .whitespaces)
            if let date = Self.parseISODate(dateStr) {
                return .startsAt(name: name, date: date)
            }
            return nil
        }

        // `ends YYYY-MM-DD`
        if rest.lowercased().hasPrefix("ends ") {
            let dateStr = String(rest.dropFirst("ends ".count))
                .trimmingCharacters(in: .whitespaces)
            if let date = Self.parseISODate(dateStr) {
                return .endsAt(name: name, date: date)
            }
            return nil
        }

        return nil
    }

    // MARK: - Date parsing

    static func parseISODate(_ raw: String) -> Date? {
        let parts = raw.split(separator: "-").map(String.init)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return cal.date(from: comps)
    }
}

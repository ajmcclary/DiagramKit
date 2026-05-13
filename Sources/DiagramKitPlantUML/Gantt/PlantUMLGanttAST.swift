import Foundation

/// AST for a PlantUML gantt diagram body (between
/// `@startgantt`/`@endgantt`).
public struct PlantUMLGanttAST: Sendable {
    public var projectStart: Date?
    public var statements: [PlantUMLGanttStatement]
    public var unsupportedLines: [String]

    public init(
        projectStart: Date? = nil,
        statements: [PlantUMLGanttStatement] = [],
        unsupportedLines: [String] = []
    ) {
        self.projectStart = projectStart
        self.statements = statements
        self.unsupportedLines = unsupportedLines
    }
}

public enum PlantUMLGanttStatement: Sendable {
    /// `[Name] lasts N days`
    case duration(name: String, days: Int)
    /// `[Name] starts at [Other]'s end`
    case startsAtOtherEnd(name: String, other: String)
    /// `[Name] starts YYYY-MM-DD`
    case startsAt(name: String, date: Date)
    /// `[Name] ends YYYY-MM-DD`
    case endsAt(name: String, date: Date)
}

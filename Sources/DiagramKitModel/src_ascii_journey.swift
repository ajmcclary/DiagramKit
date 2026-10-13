import DiagramKitCommon
import Foundation

/// Render a `JourneyDiagram` as a tabular list grouped by section.
/// Each task line shows `<task> | <score> | <people>`.
public func renderJourneyAscii(_ model: JourneyDiagram) -> String {
    var lines: [String] = []
    if let title = model.title, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(terminalDisplayWidth(title), 1)))
    }

    var currentSection: String? = nil
    let maxTaskWidth = model.tasks.map { terminalDisplayWidth($0.task) }.max() ?? 0
    for task in model.tasks {
        if task.section != currentSection {
            if !task.section.isEmpty {
                lines.append("[\(task.section)]")
            }
            currentSection = task.section
        }
        let padded = _padToTerminalWidth(task.task, toWidth: maxTaskWidth)
        let people = task.people.isEmpty ? "" : " — \(task.people.joined(separator: ", "))"
        lines.append("\(padded) | score: \(task.score)\(people)")
    }

    return lines.joined(separator: "\n")
}

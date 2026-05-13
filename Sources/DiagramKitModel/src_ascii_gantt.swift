import Foundation

/// Render a `GanttDiagram` as a tabular ASCII chart: section header,
/// task name, ISO start/end dates, and a `#` bar whose width is
/// proportional to the task duration relative to the longest task.
public func renderGanttAscii(_ model: GanttDiagram) -> String {
    var lines: [String] = []
    if let title = model.title, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }
    guard !model.tasks.isEmpty else { return lines.joined(separator: "\n") }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!

    let maxDuration = model.tasks.reduce(0.0) { acc, task in
        max(acc, task.endTime.timeIntervalSince(task.startTime))
    }
    let maxTaskWidth = model.tasks.map(\.task.count).max() ?? 0

    var currentSection: String? = nil
    for task in model.tasks {
        if task.section != currentSection {
            if !task.section.isEmpty {
                lines.append("[\(task.section)]")
            }
            currentSection = task.section
        }
        let duration = task.endTime.timeIntervalSince(task.startTime)
        let scaled = maxDuration > 0 ? duration / maxDuration : 0
        let barWidth = max(1, Int((scaled * 40).rounded()))
        let bar = String(repeating: "#", count: barWidth)
        let padded = task.task.padding(toLength: maxTaskWidth, withPad: " ", startingAt: 0)
        let start = iso(task.startTime, calendar: calendar)
        let end = iso(task.endTime, calendar: calendar)
        lines.append("\(padded) | \(start) → \(end) | \(bar)")
    }

    return lines.joined(separator: "\n")
}

private func iso(_ date: Date, calendar: Calendar) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

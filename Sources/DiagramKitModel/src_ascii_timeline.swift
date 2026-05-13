import Foundation

/// Render a `TimelineDiagram` as a vertical timeline. Sections become
/// underlined headers; tasks within a section render as `<text> →
/// <event>` rows.
public func renderTimelineAscii(_ model: TimelineDiagram) -> String {
    var lines: [String] = []
    if let title = model.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }

    var currentSection: String? = nil
    for task in model.tasks {
        if task.section != currentSection {
            if !task.section.isEmpty {
                lines.append("[\(task.section)]")
            }
            currentSection = task.section
        }
        if task.events.isEmpty {
            lines.append("• \(task.text)")
        } else {
            for event in task.events {
                lines.append("• \(task.text) → \(event.text)")
            }
        }
    }
    return lines.joined(separator: "\n")
}

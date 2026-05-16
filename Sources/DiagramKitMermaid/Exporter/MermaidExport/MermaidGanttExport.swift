import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid gantt source from a `GanttDiagram`.
///
/// Always declares `dateFormat YYYY-MM-DD` and emits every task in the
/// 3-arg form (`id, start, end`) with absolute ISO dates. That keeps the
/// output insulated from `prevTaskEnd` / `after`-relative drift across
/// re-parses, at the cost of `manualEndTime` flipping to `true` and
/// duration semantics collapsing to dates — both invisible to the
/// round-trip diff (count + ids + names).
enum MermaidGanttExport {

    static func emit(_ model: GanttDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["gantt"]
        var diagnostics: [DiagramDiagnostic] = []

        if let title = model.title, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            if accDescr.contains("\n") {
                lines.append("    accDescr: {")
                for sub in accDescr.split(separator: "\n", omittingEmptySubsequences: false) {
                    lines.append("        \(sub)")
                }
                lines.append("    }")
            } else {
                lines.append("    accDescr: \(accDescr)")
            }
        }

        // Stable round-trip pivot: declare dates as ISO so the parser
        // walks the same DateFormatter we use below.
        lines.append("    dateFormat YYYY-MM-DD")

        if let axisFormat = model.axisFormat, !axisFormat.isEmpty {
            lines.append("    axisFormat \(axisFormat)")
        }
        if let tickInterval = model.tickInterval, !tickInterval.isEmpty {
            lines.append("    tickInterval \(tickInterval)")
        }
        if !model.excludes.isEmpty {
            lines.append("    excludes \(model.excludes.joined(separator: " "))")
        }
        if !model.includes.isEmpty {
            lines.append("    includes \(model.includes.joined(separator: " "))")
        }
        if model.inclusiveEndDates {
            lines.append("    inclusiveEndDates")
        }
        if model.topAxis {
            lines.append("    topAxis")
        }
        if !model.todayMarker.isEmpty {
            lines.append("    todayMarker \(model.todayMarker)")
        }
        if model.weekday != "sunday" {
            lines.append("    weekday \(model.weekday)")
        }
        if model.weekend != "saturday" {
            lines.append("    weekend \(model.weekend)")
        }

        // `config` survives via frontmatter only. We don't re-emit
        // frontmatter from the gantt slice, so flag it so callers know.
        if model.config != nil {
            diagnostics.append(.lossyTransform(
                .configDrop,
                message: "Gantt frontmatter config not re-emitted (display-only fields)"
            ))
        }

        let formatter = Self.dateFormatter()
        var currentSection: String? = nil

        // The parser tracks `currentSection` from the most recent
        // `section` line and assigns it to every following task. Mirror
        // that by walking tasks in insertion order and emitting a
        // header lazily when the section changes. Empty section name
        // means "no section" and emits raw tasks.
        for task in model.tasks {
            if task.section != currentSection {
                if !task.section.isEmpty {
                    lines.append("    section \(task.section)")
                }
                currentSection = task.section
            }
            lines.append("        \(emitTaskLine(task, formatter: formatter, inclusiveEndDates: model.inclusiveEndDates))")
        }

        // Click statements (links + callbacks). Emit after tasks so all
        // ids exist when the parser walks back through them.
        for task in model.tasks {
            if let href = task.link {
                let escaped = href
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                lines.append("    click \(task.id) href \"\(escaped)\"")
            }
            if let callbackName = task.callbackName {
                let args = (task.callbackArgs ?? []).map { arg in
                    "\"\(arg.replacingOccurrences(of: "\"", with: "\\\""))\""
                }.joined(separator: ", ")
                lines.append("    click \(task.id) call \(callbackName)(\(args))")
            }
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    // MARK: - Task line

    private static func emitTaskLine(
        _ task: GanttTask,
        formatter: DateFormatter,
        inclusiveEndDates: Bool
    ) -> String {
        var components: [String] = []

        // Tag order matches the parser's leading-tag loop so re-parse
        // recovers the same set without reordering.
        if task.tags.contains(.done)      { components.append("done") }
        if task.tags.contains(.active)    { components.append("active") }
        if task.tags.contains(.crit)      { components.append("crit") }
        if task.tags.contains(.milestone) { components.append("milestone") }
        if task.tags.contains(.vert)      { components.append("vert") }

        // 3-arg form: id, start, end
        components.append(task.id)
        components.append(formatter.string(from: task.startTime))

        // The parser bumps `endTime` by +1 day when `inclusiveEndDates`
        // is on, so back the emitted date off by 1 day to balance the
        // round-trip.
        let emittedEnd: Date
        if inclusiveEndDates {
            emittedEnd = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: task.endTime) ?? task.endTime
        } else {
            emittedEnd = task.endTime
        }
        components.append(formatter.string(from: emittedEnd))

        let label = singleLine(task.task)
        return "\(label) :\(components.joined(separator: ", "))"
    }

    private static func dateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}

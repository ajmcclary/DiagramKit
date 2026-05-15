import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

/// Converts `PlantUMLGanttAST` into a `GanttDiagram` payload.
///
/// Resolves task start/end dates by walking statements in order:
///   - `project starts D` sets the rolling cursor.
///   - `[Name] starts D` pins the task start; cursor advances past
///     the task's known end if computed.
///   - `[Name] lasts N days` sets the task's end relative to its
///     current start (creating the start = cursor if needed).
///   - `[Name] starts at [Other]'s end` pins the task start to the
///     other task's end.
public struct PlantUMLGanttMapper {

    public init() {}

    public func map(_ ast: PlantUMLGanttAST) -> (model: GanttDiagram, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var tasks: [String: GanttTask] = [:]
        var order: [String] = []
        var cursor: Date = ast.projectStart ?? Date()
        var orderCounter = 0

        for stmt in ast.statements {
            switch stmt {
            case .duration(let name, let days):
                var task = tasks[name] ?? newTask(name: name, start: cursor, orderCounter: &orderCounter, order: &order)
                let end = calendar.date(byAdding: .day, value: days, to: task.startTime) ?? task.startTime
                task.endTime = end
                tasks[name] = task
                cursor = end

            case .startsAt(let name, let date):
                var task = tasks[name] ?? newTask(name: name, start: date, orderCounter: &orderCounter, order: &order)
                task.startTime = date
                if task.endTime < date {
                    task.endTime = date
                }
                tasks[name] = task
                cursor = task.endTime

            case .endsAt(let name, let date):
                var task = tasks[name] ?? newTask(name: name, start: cursor, orderCounter: &orderCounter, order: &order)
                task.endTime = date
                tasks[name] = task
                cursor = date

            case .startsAtOtherEnd(let name, let other):
                guard let otherTask = tasks[other] else {
                    diagnostics.append(.lossyTransform(
                        .configDrop,
                        message: "PlantUML gantt: [\(name)] starts at [\(other)]'s end but [\(other)] is unknown"
                    ))
                    continue
                }
                var task = tasks[name] ?? newTask(name: name, start: otherTask.endTime, orderCounter: &orderCounter, order: &order)
                task.startTime = otherTask.endTime
                if task.endTime < task.startTime {
                    task.endTime = task.startTime
                }
                tasks[name] = task
                cursor = task.endTime
            }
        }

        for line in ast.unsupportedLines {
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "PlantUML gantt line not yet supported: \(line)"
            ))
        }

        let orderedTasks = order.compactMap { tasks[$0] }
        let model = GanttDiagram(
            title: nil,
            dateFormat: "YYYY-MM-DD",
            tasks: orderedTasks
        )
        return (model, diagnostics)
    }

    private func newTask(
        name: String,
        start: Date,
        orderCounter: inout Int,
        order: inout [String]
    ) -> GanttTask {
        defer {
            orderCounter += 1
            order.append(name)
        }
        let id = name.replacingOccurrences(of: " ", with: "_")
        return GanttTask(
            id: id,
            task: name,
            startTime: start,
            endTime: start,
            order: orderCounter
        )
    }
}

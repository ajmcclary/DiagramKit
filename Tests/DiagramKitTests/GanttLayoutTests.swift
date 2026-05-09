import Testing
import Foundation
import CoreGraphics
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("Gantt Layout")
struct GanttLayoutTests {

    @Test("Normal mode height calculation")
    func normalModeHeight() throws {
        let diagram = _basicDiagram(taskCount: 3)
        let positioned = layoutGanttDiagram(diagram)
        let config = positioned.config
        let expectedHeight = 2 * config.topPadding + Double(3) * (config.barHeight + config.barGap)
        #expect(abs(positioned.height - expectedHeight) < 1.0)
    }

    @Test("Width defaults to 1200 when useWidth not set")
    func defaultWidth() throws {
        let diagram = _basicDiagram(taskCount: 2)
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.width == 1200.0)
    }

    @Test("Width respects config.useWidth")
    func useWidthOverride() throws {
        var diagram = _basicDiagram(taskCount: 2)
        var config = diagram.config ?? .default
        config.useWidth = 800
        diagram.config = config
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.width == 800.0)
    }

    @Test("Tasks have positioned bars")
    func taskBarPositioning() throws {
        let diagram = _basicDiagram(taskCount: 2)
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.tasks.count == 2)
        for task in positioned.tasks {
            #expect(task.barRect.width > 0)
            #expect(task.barRect.height > 0)
        }
    }

    @Test("Milestone has correct bar dimensions")
    func milestoneBarSize() throws {
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "m1", task: "Milestone", section: "S1", type: "S1",
            tags: .milestone,
            startTime: _date(2024, 1, 15), endTime: _date(2024, 1, 15),
            order: 0
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.tasks.count == 1)
        #expect(abs(positioned.tasks[0].barRect.width - config.barHeight) < 1.0)
        #expect(abs(positioned.tasks[0].barRect.height - config.barHeight) < 1.0)
    }

    @Test("Vertical marker has thin bar")
    func vertMarkerSize() throws {
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "v1", task: "Vert", section: "S1", type: "S1",
            tags: .vert,
            startTime: _date(2024, 1, 15), endTime: _date(2024, 1, 15),
            order: 0
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.tasks.count == 1)
        #expect(abs(positioned.tasks[0].barRect.width - (0.08 * config.barHeight)) < 0.5)
    }

    @Test("Time scale maps tasks to correct x-positions")
    func timeScaleMapping() throws {
        let config = GanttDiagramConfig.default
        let task1 = GanttTask(
            id: "t1", task: "First", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 10),
            order: 0
        )
        let task2 = GanttTask(
            id: "t2", task: "Second", section: "S1", type: "S1",
            startTime: _date(2024, 1, 15), endTime: _date(2024, 1, 25),
            order: 1
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task1, task2], config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.tasks.count == 2)
        #expect(positioned.tasks[0].barRect.minX < positioned.tasks[1].barRect.minX)
    }

    @Test("Task label positioning when label fits inside bar")
    func labelInsideBar() throws {
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "t1", task: "Short", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 3, 1),
            order: 0
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.tasks.count == 1)
        // Label should be inside the bar bounds when bar is wide enough
        #expect(positioned.tasks[0].labelClass.contains("taskText"))
        #expect(!positioned.tasks[0].labelClass.contains("taskTextOutside"))
        #expect(positioned.tasks[0].labelPoint.x >= positioned.tasks[0].barRect.minX)
        #expect(positioned.tasks[0].labelPoint.x <= positioned.tasks[0].barRect.maxX)
    }

    @Test("Today marker line when not off")
    func todayMarkerPresent() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: Calendar.current.date(byAdding: .day, value: -30, to: today)!,
            endTime: Calendar.current.date(byAdding: .day, value: 30, to: today)!,
            order: 0
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.todayLineX != nil)
    }

    @Test("Today marker off suppresses line")
    func todayMarkerOff() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: Calendar.current.date(byAdding: .day, value: -30, to: today)!,
            endTime: Calendar.current.date(byAdding: .day, value: 30, to: today)!,
            order: 0
        )
        var diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        diagram.todayMarker = "off"
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.todayLineX == nil)
    }

    @Test("Empty diagram returns minimal layout")
    func emptyDiagram() throws {
        let diagram = GanttDiagram.empty
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.tasks.isEmpty)
        #expect(positioned.width == 1200.0)
    }

    @Test("Section backgrounds are positioned")
    func sectionBackgrounds() throws {
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 10),
            order: 0
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD",
            sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        #expect(!positioned.sections.isEmpty)
        #expect(positioned.sections[0].backgroundRect.height > 0)
    }

    @Test("Axis ticks are generated")
    func axisTicks() throws {
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 31),
            order: 0
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        #expect(!positioned.axisTicks.isEmpty)
    }

    @Test("Top axis ticks when topAxis enabled")
    func topAxisEnabled() throws {
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 31),
            order: 0
        )
        var diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        diagram.topAxis = true
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.topAxisTicks != nil)
        #expect(!positioned.topAxisTicks!.isEmpty)
    }

    @Test("Compact mode from config packs overlapping tasks on separate rows")
    func compactModeFromConfigPacksOverlaps() throws {
        var config = GanttDiagramConfig.default
        config.displayMode = "compact"
        let tasks = [
            GanttTask(id: "a", task: "A", section: "S1", type: "S1", startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 10), order: 0),
            GanttTask(id: "b", task: "B", section: "S1", type: "S1", startTime: _date(2024, 1, 5), endTime: _date(2024, 1, 15), order: 1),
            GanttTask(id: "c", task: "C", section: "S1", type: "S1", startTime: _date(2024, 1, 11), endTime: _date(2024, 1, 20), order: 2),
        ]
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD",
            sections: [GanttSection(name: "S1", index: 0)],
            tasks: tasks,
            config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        let rows = Dictionary(uniqueKeysWithValues: positioned.tasks.map { ($0.task.id, $0.row) })
        #expect(rows["a"] == rows["c"])
        #expect(rows["a"] != rows["b"])
        #expect(positioned.height == 2 * config.topPadding + 2 * (config.barHeight + config.barGap))
    }

    @Test("Excluded ranges span contiguous invalid dates")
    func excludedRangesSpanContiguousDates() throws {
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 5),
            order: 0
        )
        var diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD",
            sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task],
            config: .default
        )
        diagram.excludes = ["2024-01-02", "2024-01-03"]
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.excludedRanges.count == 1)
        #expect(Calendar.current.isDate(positioned.excludedRanges[0].start, inSameDayAs: _date(2024, 1, 2)))
        #expect(Calendar.current.isDate(positioned.excludedRanges[0].end, inSameDayAs: _date(2024, 1, 3)))
        #expect(positioned.excludedRanges[0].backgroundRect.width > 2)
    }

    @Test("Diagram axisFormat controls tick labels")
    func diagramAxisFormatControlsTickLabels() throws {
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 3),
            order: 0
        )
        var diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD",
            sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task],
            config: .default
        )
        diagram.axisFormat = "%m/%d"
        diagram.tickInterval = "1day"
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.axisTicks.map(\.label).contains("01/01"))
    }

    @Test("Millisecond tick interval advances")
    func millisecondTickIntervalAdvances() throws {
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 0.003),
            order: 0
        )
        var diagram = GanttDiagram(
            dateFormat: "x",
            sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task],
            config: .default
        )
        diagram.tickInterval = "1millisecond"
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.axisTicks.count >= 3)
        #expect(positioned.axisTicks.count < 20)
    }

    @Test("Default ticks use nice time intervals for month-span data")
    func defaultTicksUseNiceIntervals() throws {
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 3, 31),
            order: 0
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        #expect(!positioned.axisTicks.isEmpty)
        let labels = positioned.axisTicks.map(\.label)
        #expect(positioned.axisTicks.count > 3)
        #expect(positioned.axisTicks.count <= 15)
        #expect(labels.contains("2024-01-07") || labels.contains("2024-01-01"))
    }

    @Test("Grid line height matches chart dimensions")
    func gridLineHeightMatchesChart() throws {
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 31),
            order: 0
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        let expected = positioned.height - config.topPadding - config.gridLineStartPadding
        #expect(abs(positioned.gridLineHeight - expected) < 1.0)
    }

    @Test("Milestone bar is vertically centered within its row")
    func milestoneVerticalCentering() throws {
        let config = GanttDiagramConfig.default
        let task = GanttTask(
            id: "m1", task: "Milestone", section: "S1", type: "S1",
            tags: .milestone,
            startTime: _date(2024, 1, 15), endTime: _date(2024, 1, 15),
            order: 0
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        let gap = config.barHeight + config.barGap
        let expectedCenterY = gap / 2 + config.topPadding
        let actualCenterY = positioned.tasks[0].barRect.midY
        #expect(abs(actualCenterY - expectedCenterY) < 1.0)
    }

    @Test("Compact mode section label centered across multi-row section")
    func compactSectionLabelCentering() throws {
        var config = GanttDiagramConfig.default
        config.displayMode = "compact"
        let tasks = [
            GanttTask(id: "a", task: "A", section: "S1", type: "S1", startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 10), order: 0),
            GanttTask(id: "b", task: "B", section: "S1", type: "S1", startTime: _date(2024, 1, 5), endTime: _date(2024, 1, 15), order: 1),
        ]
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD",
            sections: [GanttSection(name: "S1", index: 0)],
            tasks: tasks,
            config: config
        )
        let positioned = layoutGanttDiagram(diagram)
        #expect(positioned.sections.count == 1)
        let sectionRect = positioned.sections[0].backgroundRect
        #expect(sectionRect.height > config.barHeight)
    }
}

private func _basicDiagram(taskCount: Int) -> GanttDiagram {
    let config = GanttDiagramConfig.default
    var tasks: [GanttTask] = []
    for i in 0..<taskCount {
        let start = _date(2024, 1, 1 + i * 10)
        let task = GanttTask(
            id: "task\(i + 1)", task: "Task \(i + 1)", section: "Section1", type: "Section1",
            startTime: start,
            endTime: Calendar.current.date(byAdding: .day, value: 5, to: start)!,
            order: i
        )
        tasks.append(task)
    }
    return GanttDiagram(
        dateFormat: "YYYY-MM-DD",
        sections: [GanttSection(name: "Section1", index: 0)],
        tasks: tasks,
        config: config
    )
}

private func _date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    let comps = DateComponents(year: y, month: m, day: d)
    return Calendar.current.date(from: comps)!
}

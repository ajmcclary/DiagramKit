import Testing
import Foundation
import CoreGraphics
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("Gantt SVG Renderer")
struct GanttRendererTests {

    @Test("SVG contains viewBox")
    func svgHasViewBox() throws {
        let positioned = _basicPositionedDiagram()
        let svg = try renderGanttSvg(positioned, diagramId: "test-1", _defaultColors(), "Inter", false)
        #expect(svg.contains("viewBox"))
    }

    @Test("SVG contains task IDs")
    func svgContainsTaskIds() throws {
        let positioned = _basicPositionedDiagram()
        let svg = try renderGanttSvg(positioned, diagramId: "diag", _defaultColors(), "Inter", false)
        #expect(svg.contains("diag-task1"))
    }

    @Test("SVG contains task text IDs")
    func svgContainsTaskTextIds() throws {
        let positioned = _basicPositionedDiagram()
        let svg = try renderGanttSvg(positioned, diagramId: "diag", _defaultColors(), "Inter", false)
        #expect(svg.contains("diag-task1-text"))
    }

    @Test("SVG contains <svg> tag")
    func svgHasSvgTag() throws {
        let positioned = _basicPositionedDiagram()
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("<svg"))
    }

    @Test("SVG contains styles")
    func svgContainsStyles() throws {
        let positioned = _basicPositionedDiagram()
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("<style>"))
    }

    @Test("SVG contains grid class")
    func svgContainsGrid() throws {
        let positioned = _basicPositionedDiagram()
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("grid"))
    }

    @Test("SVG contains section classes")
    func svgContainsSection() throws {
        let positioned = _basicPositionedDiagram()
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("section"))
    }

    @Test("SVG contains title when present")
    func svgContainsTitle() throws {
        var positioned = _basicPositionedDiagram()
        positioned.title = "My Gantt"
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("My Gantt"))
    }

    @Test("SVG contains accessibility title")
    func svgContainsAccTitle() throws {
        var positioned = _basicPositionedDiagram()
        positioned.accTitle = "Accessible Gantt"
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("Accessible Gantt"))
    }

    @Test("SVG contains accessibility description")
    func svgContainsAccDescr() throws {
        var positioned = _basicPositionedDiagram()
        positioned.accDescr = "A project timeline"
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("A project timeline"))
    }

    @Test("SVG contains today marker when present")
    func svgContainsTodayMarker() throws {
        var positioned = _basicPositionedDiagram()
        positioned.todayLineX = 500
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("today"))
    }

    @Test("SVG contains today marker style")
    func svgContainsTodayMarkerStyle() throws {
        var positioned = _basicPositionedDiagram()
        positioned.todayLineX = 500
        positioned.todayMarkerStyle = "stroke-width:2px"
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("stroke-width:2px"))
    }

    @Test("SVG has milestone transform")
    func svgHasMilestoneTransform() throws {
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
        let svg = try renderGanttSvg(positioned, diagramId: "diag", _defaultColors(), "Inter", false)
        #expect(svg.contains("rotate"))
        #expect(svg.contains("milestone"))
    }

    @Test("SVG XML escapes special characters")
    func svgEscapesXml() throws {
        var positioned = _basicPositionedDiagram()
        positioned.title = "Test & <Gantt>"
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("&amp;"))
        #expect(svg.contains("&lt;"))
        #expect(svg.contains("&gt;"))
    }

    @Test("Excluded ranges have correct ID format")
    func excludedRangeIds() throws {
        let cal = Calendar.current
        let config = GanttDiagramConfig.default
        let start = _date(2024, 1, 1)
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: start,
            endTime: cal.date(byAdding: .day, value: 3, to: start)!,
            order: 0
        )
        var diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD", sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task], config: config
        )
        diagram.excludes = ["2024-01-02"]
        let positioned = layoutGanttDiagram(diagram)
        let svg = try renderGanttSvg(positioned, diagramId: "diag", _defaultColors(), "Inter", false)
        // May or may not have excluded ranges depending on layout
        if positioned.excludedRanges.count > 0 {
            #expect(svg.contains("exclude-"))
        }
    }

    @Test("Zero tasks returns valid SVG")
    func zeroTasksSvg() throws {
        let positioned = PositionedGanttDiagram.empty
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
    }

    @Test("SVG wraps linked task in anchor")
    func svgWrapsLinkedTaskInAnchor() throws {
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 10),
            order: 0,
            classes: ["clickable"],
            link: "https://example.com"
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD",
            sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task],
            config: .default
        )
        let svg = try renderGanttSvg(layoutGanttDiagram(diagram), diagramId: "diag", _defaultColors(), "Inter", false)
        #expect(svg.contains("<a "))
        #expect(svg.contains("xlink:href=\"https://example.com\""))
        #expect(svg.contains("diag-t1"))
        #expect(svg.contains("diag-t1-text"))
    }

    @Test("SVG includes Mermaid task and task text classes")
    func svgIncludesMermaidClasses() throws {
        let defaultTask = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 10),
            order: 0
        )
        let doneCritTask = GanttTask(
            id: "t2", task: "Done Crit", section: "S1", type: "S1",
            tags: [.done, .crit],
            startTime: _date(2024, 1, 11), endTime: _date(2024, 1, 20),
            order: 1
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD",
            sections: [GanttSection(name: "S1", index: 0)],
            tasks: [defaultTask, doneCritTask],
            config: .default
        )
        let svg = try renderGanttSvg(layoutGanttDiagram(diagram), diagramId: "diag", _defaultColors(), "Inter", false)
        #expect(svg.contains(#"class="task task0""#))
        #expect(svg.contains("doneCrit0"))
        #expect(svg.contains("taskText0"))
        #expect(svg.contains("doneCritText0"))
    }

    @Test("SVG includes callback metadata")
    func svgIncludesCallbackMetadata() throws {
        let task = GanttTask(
            id: "t1", task: "Task", section: "S1", type: "S1",
            startTime: _date(2024, 1, 1), endTime: _date(2024, 1, 10),
            order: 0,
            classes: ["clickable"],
            callbackName: "myCallback",
            callbackArgs: ["a,b", "c"]
        )
        let diagram = GanttDiagram(
            dateFormat: "YYYY-MM-DD",
            sections: [GanttSection(name: "S1", index: 0)],
            tasks: [task],
            config: .default
        )
        let svg = try renderGanttSvg(layoutGanttDiagram(diagram), diagramId: "diag", _defaultColors(), "Inter", false)
        #expect(svg.contains("data-callback=\"myCallback\""))
        #expect(svg.contains("data-callback-args=\"a,b,c\""))
    }

    @Test("SVG grid text has fill stroke and font-size styling")
    func svgGridTextStyling() throws {
        let positioned = _basicPositionedDiagram()
        let svg = try renderGanttSvg(positioned, diagramId: "test", _defaultColors(), "Inter", false)
        #expect(svg.contains("fill=\"#000\""))
        #expect(svg.contains("stroke=\"none\""))
        #expect(svg.contains("font-size=\"10\""))
    }
}

private func _defaultColors() -> DiagramColors {
    DiagramColors(bg: "#FFFFFF", fg: "#27272A")
}

private func _basicPositionedDiagram() -> PositionedGanttDiagram {
    let config = GanttDiagramConfig.default
    let task = GanttTask(
        id: "task1", task: "Test Task", section: "Section1", type: "Section1",
        startTime: _date(2024, 1, 1),
        endTime: _date(2024, 1, 10),
        order: 0
    )
    let diagram = GanttDiagram(
        title: "Test Gantt",
        dateFormat: "YYYY-MM-DD",
        sections: [GanttSection(name: "Section1", index: 0)],
        tasks: [task],
        config: config
    )
    return layoutGanttDiagram(diagram)
}

private func _date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    let comps = DateComponents(year: y, month: m, day: d)
    return Calendar.current.date(from: comps)!
}

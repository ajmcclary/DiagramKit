import Foundation
import CoreGraphics
import DiagramKitCommon

// MARK: - Bounds helper

private struct _Bounds {
    var minX: Double = .infinity
    var minY: Double = .infinity
    var maxX: Double = -.infinity
    var maxY: Double = -.infinity

    mutating func insert(_ x: Double, _ y: Double, _ x2: Double, _ y2: Double) {
        minX = Swift.min(minX, Swift.min(x, x2))
        minY = Swift.min(minY, Swift.min(y, y2))
        maxX = Swift.max(maxX, Swift.max(x, x2))
        maxY = Swift.max(maxY, Swift.max(y, y2))
    }

    var startX: Double { minX.isFinite ? minX : 0 }
    var startY: Double { minY.isFinite ? minY : 0 }
    var stopX: Double { maxX.isFinite ? maxX : 0 }
    var stopY: Double { maxY.isFinite ? maxY : 0 }
}

// MARK: - Text wrapping

private func _journeyWrapText(_ text: String, maxWidth: Double, fontSize: Double, fontWeight: Int = 400) -> [String] {
    let fullWidth = original_src_text_metrics.measureTextWidth(text, fontSize: fontSize, fontWeight: fontWeight)
    if fullWidth <= maxWidth {
        return [text]
    }

    let words = text.split(separator: " ").map(String.init)
    var lines: [String] = []
    var currentLine = ""

    for word in words {
        let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
        let testWidth = original_src_text_metrics.measureTextWidth(testLine, fontSize: fontSize, fontWeight: fontWeight)

        if testWidth > maxWidth {
            if !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = word
            } else {
                currentLine = word
            }
            // If the word alone exceeds maxWidth, hyphenate it
            if original_src_text_metrics.measureTextWidth(word, fontSize: fontSize, fontWeight: fontWeight) > maxWidth {
                var brokenWord = ""
                for ch in word {
                    brokenWord.append(ch)
                    if original_src_text_metrics.measureTextWidth(brokenWord + "-", fontSize: fontSize, fontWeight: fontWeight) > maxWidth {
                        lines.append(String(brokenWord.dropLast()) + "-")
                        brokenWord = String(ch)
                    }
                }
                currentLine = brokenWord
            }
        } else {
            currentLine = testLine
        }
    }

    if !currentLine.isEmpty {
        lines.append(currentLine)
    }

    return lines
}

// MARK: - Layout function

public func layoutJourneyDiagram(
    _ diagram: JourneyDiagram,
    options: RenderOptions = RenderOptions(),
    config: JourneyDiagramConfig? = nil
) -> PositionedJourneyDiagram {
    let conf = config ?? .default
    let fontSize = conf.taskFontSize

    var bounds = _Bounds()

    // 1. Actor Legend (left side)
    var actors: [PositionedJourneyActor] = []
    var legendWidth: Double = 0
    var spacingLegendWidth: Double = 0
    let rowHeight: Double = 20

    for (idx, actorName) in diagram.actors.enumerated() {
        let color = _journeyPaletteValue(conf.actorColours, index: idx, fallback: "#8FBC8F")
        let wrappedLines = _journeyWrapText(actorName, maxWidth: conf.maxLabelWidth, fontSize: fontSize, fontWeight: 400)

        for line in wrappedLines {
            let lineW = original_src_text_metrics.measureTextWidth(line, fontSize: fontSize, fontWeight: 400)
            legendWidth = Swift.max(legendWidth, lineW)
            if lineW > spacingLegendWidth && lineW > conf.leftMargin - lineW {
                spacingLegendWidth = lineW
            }
        }

        var y: Double
        if idx == 0 {
            y = 60
        } else {
            let prevLines = actors[idx - 1].lines.count
            y = actors[idx - 1].circleCenter.y + Swift.max(rowHeight, Double(prevLines) * fontSize * 1.3)
        }

        let circleCenter = CGPoint(x: 20, y: y)
        let labelOrigin = CGPoint(x: 40, y: y + 7)

        actors.append(PositionedJourneyActor(
            name: actorName,
            color: color,
            index: idx,
            lines: wrappedLines,
            circleCenter: circleCenter,
            labelOrigin: labelOrigin
        ))

        let legendAreaRight = 40 + legendWidth + 10
        bounds.insert(0, 0, legendAreaRight, y + 30)
    }

    // Legend width: the measured width plus circle radius + gap
    let measuredLegendWidth = 40 + legendWidth + 10
    legendWidth = measuredLegendWidth

    // 2. effectiveLeftMargin
    let effectiveLeftMargin = conf.leftMargin + spacingLegendWidth

    // 3. Task positioning (horizontal grid)
    let taskStartY: Double = 50 + conf.height * 2 + conf.diagramMarginY

    // Pre-compute contiguous section runs. Mermaid starts a new section band when the
    // current section changes, even if the same section name appears again later.
    var sectionRuns: [(name: String, firstIndex: Int, count: Int)] = []
    for (i, task) in diagram.tasks.enumerated() {
        if let last = sectionRuns.indices.last, sectionRuns[last].name == task.section {
            sectionRuns[last].count += 1
        } else {
            sectionRuns.append((name: task.section, firstIndex: i, count: 1))
        }
    }

    var taskColors = Array(
        repeating: (fill: "#191970", colour: "#fff", num: 0),
        count: diagram.tasks.count
    )
    for (sn, run) in sectionRuns.enumerated() {
        let fill = _journeyPaletteValue(conf.sectionFills, index: sn, fallback: "#191970")
        let colour = _journeyPaletteValue(conf.sectionColours, index: sn, fallback: "#fff")
        let num = _journeyPaletteIndex(conf.sectionFills, index: sn)
        for offset in 0..<run.count {
            taskColors[run.firstIndex + offset] = (fill: fill, colour: colour, num: num)
        }
    }

    // Position tasks
    var positionedTasks: [PositionedJourneyTask] = []
    for (i, task) in diagram.tasks.enumerated() {
        let colors = taskColors[i]

        let tx = Double(i) * conf.taskMargin + Double(i) * conf.width + effectiveLeftMargin
        let ty = taskStartY
        let clampedScore = Swift.max(1, Swift.min(5, task.score))
        let faceY = 300.0 + (5.0 - Double(clampedScore)) * 30.0

        positionedTasks.append(PositionedJourneyTask(
            section: task.section,
            task: task.task,
            score: task.score,
            people: task.people,
            x: tx,
            y: ty,
            rectWidth: conf.width,
            rectHeight: conf.height,
            boundsWidth: conf.diagramMarginX,
            boundsHeight: conf.diagramMarginY,
            fill: colors.fill,
            colour: colors.colour,
            num: colors.num,
            faceY: faceY,
            taskIndex: i
        ))

        // Bounds insert for task
        let bLeft = tx
        let bRight = tx + conf.diagramMarginX + conf.taskMargin
        let bBottom = 300.0 + 5.0 * 30.0
        bounds.insert(bLeft, ty, bRight, bBottom)
    }

    // 4. Section rectangles
    var positionedSections: [PositionedJourneySection] = []
    for (sn, run) in sectionRuns.enumerated() {
        let fill = _journeyPaletteValue(conf.sectionFills, index: sn, fallback: "#191970")
        let colour = _journeyPaletteValue(conf.sectionColours, index: sn, fallback: "#fff")
        let num = _journeyPaletteIndex(conf.sectionFills, index: sn)

        let firstTask = positionedTasks[run.firstIndex]
        let sx = firstTask.x
        let sy: Double = 50
        let sw = conf.width * Double(run.count) + conf.diagramMarginX * Double(run.count - 1)
        let sh = conf.height

        positionedSections.append(PositionedJourneySection(
            name: run.name,
            x: sx,
            y: sy,
            width: sw,
            height: sh,
            fill: fill,
            colour: colour,
            num: num
        ))
    }

    // 5. Activity line
    let activityLineY: Double = taskStartY + conf.height + conf.diagramMarginY

    // 6. Final bounds
    let boxStartY = bounds.startY
    let boxStopY = bounds.stopY

    let diagramHeight = boxStopY - boxStartY + 2 * conf.diagramMarginY
    let rightmostTaskEdge = positionedTasks.map { $0.x + $0.rectWidth }.max() ?? effectiveLeftMargin
    let diagramWidth = max(legendWidth, rightmostTaskEdge) + conf.diagramMarginX

    // Title offset
    let extraVertForTitle: Double = diagram.title != nil ? 70 : 0

    let totalHeight = diagramHeight + extraVertForTitle + 25
    let totalWidth = diagramWidth

    return PositionedJourneyDiagram(
        width: totalWidth,
        height: totalHeight,
        title: diagram.title,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        actors: actors,
        legendWidth: legendWidth,
        effectiveLeftMargin: effectiveLeftMargin,
        sections: positionedSections,
        tasks: positionedTasks,
        activityLineY: activityLineY,
        config: conf
    )
}

private func _journeyPaletteValue(_ palette: [String], index: Int, fallback: String) -> String {
    guard !palette.isEmpty else { return fallback }
    return palette[index % palette.count]
}

private func _journeyPaletteIndex(_ palette: [String], index: Int) -> Int {
    guard !palette.isEmpty else { return 0 }
    return index % palette.count
}

func _journeyActorDotXPositions(taskX: Double, taskWidth: Double, dotCount: Int, dotRadius: Double = 7) -> [Double] {
    guard dotCount > 0 else { return [] }
    let centerX = taskX + taskWidth / 2
    guard dotCount > 1 else { return [centerX] }

    let preferredSpacing = dotRadius * 2 + 4
    let availableSpan = max(0, taskWidth - dotRadius * 2)
    let spacing = min(preferredSpacing, availableSpan / Double(dotCount - 1))
    let totalSpan = spacing * Double(dotCount - 1)
    let startX = centerX - totalSpan / 2
    return (0..<dotCount).map { startX + Double($0) * spacing }
}

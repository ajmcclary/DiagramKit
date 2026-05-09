import Foundation
import DiagramKitCommon

// MARK: - Layout constants (LR)

private let LR_LEFT_MARGIN: Double = 50
private let LR_MASTER_Y_OFFSET: Double = 50
private let LR_SECTION_MIN_WIDTH: Double = 150
private let LR_TASK_WIDTH: Double = 150
private let LR_TASK_SPACING: Double = 200
private let LR_SECTION_TASK_GAP: Double = 50
private let LR_TASK_EVENT_GAP: Double = 100
private let LR_EVENT_SPACING: Double = 10
private let LR_NODE_PADDING: Double = 20
private let LR_ARROW_SIZE: Double = 10
private let LR_FONT_SIZE: Double = 16

// MARK: - Layout constants (TD)

private let TD_NODE_WIDTH: Double = 200
private let TD_NODE_PADDING: Double = 5
private let TD_EVENT_WIDTH: Double = 300
private let TD_EVENT_SPACING: Double = 10
private let TD_SECTION_TASK_GAP: Double = 20
private let TD_TASK_AXIS_GAP: Double = 20
private let TD_TASK_VERTICAL_GAP: Double = 30
private let TD_EVENT_AXIS_GAP: Double = 50
private let TD_FONT_SIZE: Double = 16

// MARK: - Layout entry point

public func layoutTimelineDiagram(_ diagram: TimelineDiagram) -> PositionedTimelineDiagram {
    guard !diagram.tasks.isEmpty else { return .empty }
    switch diagram.direction {
    case .LR:
        return _layoutTimelineLR(diagram)
    case .TD:
        return _layoutTimelineTD(diagram)
    }
}

// MARK: - LR Layout

private func _layoutTimelineLR(_ diagram: TimelineDiagram) -> PositionedTimelineDiagram {
    let conf = diagram.config
    let leftMargin = conf.leftMargin > 0 ? conf.leftMargin : LR_LEFT_MARGIN
    let padding = conf.padding > 0 ? conf.padding : 50.0
    let taskWidth = conf.width > 0 ? conf.width : LR_TASK_WIDTH
    let taskSpacing = LR_TASK_SPACING
    let fontSize = conf.taskFontSize > 0 ? conf.taskFontSize : LR_FONT_SIZE

    var positionedSections: [PositionedTimelineSection] = []
    var positionedTasks: [PositionedTimelineTask] = []
    var positionedEvents: [PositionedTimelineEvent] = []
    var connectors: [PositionedTimelineConnector] = []

    let titleHeight: Double = diagram.diagramTitle != nil ? max(fontSize * 2, 40) : 0
    let contentTopY = titleHeight + LR_MASTER_Y_OFFSET

    // Measure section heights
    var sectionHeights: [Int: Double] = [:]
    if !diagram.sections.isEmpty {
        for (i, sectionName) in diagram.sections.enumerated() {
            let wrapped = _wrapText(sectionName, maxWidth: LR_SECTION_MIN_WIDTH, fontSize: fontSize)
            let textH = fontSize * 1.1 * (Double(wrapped.count) + 0.5)
            sectionHeights[i] = max(textH + LR_NODE_PADDING, 40)
        }
    }
    let maxSectionHeight = diagram.sections.isEmpty ? 0 : (sectionHeights.values.max() ?? 40)

    // Measure task heights
    var taskHeights: [Int: Double] = [:]
    for task in diagram.tasks {
        let taskWrapped = _wrapText(task.text, maxWidth: taskWidth, fontSize: fontSize)
        let taskH = max(fontSize * 1.1 * (Double(taskWrapped.count) + 0.5) + LR_NODE_PADDING, 40)
        taskHeights[task.id] = taskH
    }
    let maxTaskHeight: Double = taskHeights.values.max() ?? 40

    // Measure event stack heights
    var eventStackHeights: [Int: Double] = [:]
    for task in diagram.tasks {
        var height: Double = 0
        for event in task.events {
            let ew = _wrapText(event.text, maxWidth: taskWidth, fontSize: fontSize)
            let eh = max(fontSize * 1.1 * (Double(ew.count) + 0.5) + LR_NODE_PADDING, 30)
            height += eh + LR_EVENT_SPACING
        }
        if !task.events.isEmpty {
            height -= LR_EVENT_SPACING
        }
        eventStackHeights[task.id] = height
    }

    // Has sections path
    if !diagram.sections.isEmpty {
        var sectionTasks: [String: [TimelineTask]] = [:]
        for task in diagram.tasks {
            sectionTasks[task.section, default: []].append(task)
        }

        var sectionX = leftMargin
        let sectionY = contentTopY
        let taskRowY = sectionY + maxSectionHeight + LR_SECTION_TASK_GAP

        for (sectionIdx, sectionName) in diagram.sections.enumerated() {
            let colorIdx = diagram.config.disableMulticolor ? 0 : diagram.theme.colorIndex(sectionIdx)

            let tasksForSection = sectionTasks[sectionName] ?? []
            let sectionTaskCount = max(tasksForSection.count, 1)
            let sectionWidth = max(LR_SECTION_MIN_WIDTH, Double(sectionTaskCount) * taskSpacing - (taskSpacing - taskWidth))

            positionedSections.append(PositionedTimelineSection(
                text: sectionName,
                sectionIndex: sectionIdx,
                x: sectionX,
                y: sectionY,
                width: sectionWidth,
                height: maxSectionHeight,
                colorIndex: colorIdx
            ))

            // Place tasks horizontally
            var taskX = sectionX
            for task in tasksForSection {
                let tH = taskHeights[task.id] ?? 40
                let tY = taskRowY + (maxTaskHeight - tH) / 2

                positionedTasks.append(PositionedTimelineTask(
                    id: task.id,
                    text: task.text,
                    section: sectionName,
                    sectionIndex: sectionIdx,
                    x: taskX,
                    y: tY,
                    width: taskWidth,
                    height: tH,
                    colorIndex: colorIdx
                ))

                // Place events below
                var eventY = taskRowY + maxTaskHeight + LR_TASK_EVENT_GAP
                for event in task.events {
                    let ew = _wrapText(event.text, maxWidth: taskWidth, fontSize: fontSize)
                    let eH = max(fontSize * 1.1 * (Double(ew.count) + 0.5) + LR_NODE_PADDING, 30)
                    let eX = taskX

                    positionedEvents.append(PositionedTimelineEvent(
                        id: event.id,
                        taskId: task.id,
                        text: event.text,
                        x: eX,
                        y: eventY,
                        width: taskWidth,
                        height: eH,
                        colorIndex: colorIdx
                    ))

                    // Dashed connector from task bottom to event top
                    let connectorFromX = taskX + taskWidth / 2
                    let connectorFromY = tY + tH
                    let connectorToX = eX + taskWidth / 2
                    let connectorToY = eventY
                    connectors.append(PositionedTimelineConnector(
                        kind: .verticalLR(x1: connectorFromX, y1: connectorFromY, x2: connectorToX, y2: connectorToY),
                        colorIndex: colorIdx
                    ))

                    eventY += eH + LR_EVENT_SPACING
                }

                taskX += taskSpacing
            }

            sectionX += Double(sectionTaskCount) * taskSpacing
        }
    } else {
        // No sections path
        var taskX = leftMargin
        let taskY = contentTopY
        for (ti, task) in diagram.tasks.enumerated() {
            let colorIdx = diagram.config.disableMulticolor ? 0 : diagram.theme.colorIndex(ti)
            let tH = taskHeights[task.id] ?? 40
            let tY = taskY + (maxTaskHeight - tH) / 2

            positionedTasks.append(PositionedTimelineTask(
                id: task.id,
                text: task.text,
                section: "",
                sectionIndex: ti,
                x: taskX,
                y: tY,
                width: taskWidth,
                height: tH,
                colorIndex: colorIdx
            ))

            var eventY = tY + tH + LR_TASK_EVENT_GAP
            for event in task.events {
                let ew = _wrapText(event.text, maxWidth: taskWidth, fontSize: fontSize)
                let eH = max(fontSize * 1.1 * (Double(ew.count) + 0.5) + LR_NODE_PADDING, 30)
                let eX = taskX

                positionedEvents.append(PositionedTimelineEvent(
                    id: event.id,
                    taskId: task.id,
                    text: event.text,
                    x: eX,
                    y: eventY,
                    width: taskWidth,
                    height: eH,
                    colorIndex: colorIdx
                ))

                let connectorFromX = taskX + taskWidth / 2
                let connectorFromY = tY + tH
                let connectorToX = eX + taskWidth / 2
                let connectorToY = eventY
                connectors.append(PositionedTimelineConnector(
                    kind: .verticalLR(x1: connectorFromX, y1: connectorFromY, x2: connectorToX, y2: connectorToY),
                    colorIndex: colorIdx
                ))

                eventY += eH + LR_EVENT_SPACING
            }

            taskX += taskSpacing
        }
    }

    // Compute diagram bounds
    var maxX: Double = max(leftMargin + taskSpacing, leftMargin + taskWidth)
    var maxY: Double = contentTopY

    for s in positionedSections { maxX = max(maxX, s.x + s.width); maxY = max(maxY, s.y + s.height) }
    for t in positionedTasks { maxX = max(maxX, t.x + t.width); maxY = max(maxY, t.y + t.height) }
    for e in positionedEvents { maxX = max(maxX, e.x + e.width); maxY = max(maxY, e.y + e.height) }

    let activityY: Double
    if diagram.sections.isEmpty {
        activityY = contentTopY + maxTaskHeight + LR_TASK_EVENT_GAP / 2
    } else {
        activityY = contentTopY + maxSectionHeight + maxTaskHeight + LR_SECTION_TASK_GAP + LR_TASK_EVENT_GAP / 2
    }

    let activityLine = PositionedTimelineActivityLine(
        x1: leftMargin,
        y1: activityY,
        x2: maxX + leftMargin,
        y2: activityY
    )
    maxX = max(maxX, activityLine.x2)
    maxY = max(maxY, activityY)

    var title: PositionedTimelineTitle?
    if let t = diagram.diagramTitle, !t.isEmpty {
        title = PositionedTimelineTitle(text: t, x: leftMargin, y: titleHeight - 10)
    }

    return PositionedTimelineDiagram(
        width: maxX + padding,
        height: maxY + padding,
        direction: .LR,
        sections: positionedSections,
        tasks: positionedTasks,
        events: positionedEvents,
        connectors: connectors,
        activityLine: activityLine,
        title: title,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        diagramTitle: diagram.diagramTitle,
        config: diagram.config,
        theme: diagram.theme,
        look: diagram.look,
        themeName: diagram.themeName
    )
}

// MARK: - TD Layout

private func _layoutTimelineTD(_ diagram: TimelineDiagram) -> PositionedTimelineDiagram {
    let conf = diagram.config
    let padding = conf.padding > 0 ? conf.padding : 50.0
    let nodeWidth = TD_NODE_WIDTH
    let eventWidth = TD_EVENT_WIDTH
    let fontSize = conf.taskFontSize > 0 ? conf.taskFontSize : TD_FONT_SIZE

    var positionedSections: [PositionedTimelineSection] = []
    var positionedTasks: [PositionedTimelineTask] = []
    var positionedEvents: [PositionedTimelineEvent] = []
    var connectors: [PositionedTimelineConnector] = []

    let titleHeight: Double = diagram.diagramTitle != nil ? max(fontSize * 2, 40) : 0
    var masterY = titleHeight + LR_MASTER_Y_OFFSET

    let timelineX = padding + nodeWidth + TD_TASK_AXIS_GAP + TD_EVENT_AXIS_GAP

    // Measure section heights
    var sectionHeights: [Int: Double] = [:]
    if !diagram.sections.isEmpty {
        for (i, sectionName) in diagram.sections.enumerated() {
            let wrapped = _wrapText(sectionName, maxWidth: nodeWidth * 2 + TD_EVENT_AXIS_GAP + eventWidth, fontSize: fontSize)
            let textH = fontSize * 1.1 * (Double(wrapped.count) + 0.5)
            sectionHeights[i] = max(textH + TD_NODE_PADDING * 2, 40)
        }
    }

    // Measure task heights
    var taskHeights: [Int: Double] = [:]
    for task in diagram.tasks {
        let taskWrapped = _wrapText(task.text, maxWidth: nodeWidth, fontSize: fontSize)
        let taskH = max(fontSize * 1.1 * (Double(taskWrapped.count) + 0.5) + TD_NODE_PADDING * 2, 30)
        taskHeights[task.id] = taskH
    }
    // Measure event stack heights
    var eventStackHeights: [Int: Double] = [:]
    for task in diagram.tasks {
        var height: Double = 0
        for event in task.events {
            let ew = _wrapText(event.text, maxWidth: eventWidth, fontSize: fontSize)
            let eh = max(fontSize * 1.1 * (Double(ew.count) + 0.5) + TD_NODE_PADDING * 2, 30)
            height += eh + TD_EVENT_SPACING
        }
        if !task.events.isEmpty {
            height -= TD_EVENT_SPACING
        }
        eventStackHeights[task.id] = height
    }

    if !diagram.sections.isEmpty {
        var sectionTasks: [String: [TimelineTask]] = [:]
        for task in diagram.tasks {
            sectionTasks[task.section, default: []].append(task)
        }

        for (sectionIdx, sectionName) in diagram.sections.enumerated() {
            let colorIdx = diagram.config.disableMulticolor ? 0 : diagram.theme.colorIndex(sectionIdx)

            let sH = sectionHeights[sectionIdx] ?? 40
            let sectionWidth = nodeWidth + TD_TASK_AXIS_GAP + eventWidth + TD_EVENT_AXIS_GAP

            let sectionX = padding
            let sectionY = masterY

            positionedSections.append(PositionedTimelineSection(
                text: sectionName,
                sectionIndex: sectionIdx,
                x: sectionX,
                y: sectionY,
                width: sectionWidth + padding * 2,
                height: sH,
                colorIndex: colorIdx
            ))

            masterY += sH + TD_SECTION_TASK_GAP

            let tasksForSection = sectionTasks[sectionName] ?? []
            for task in tasksForSection {
                let tH = taskHeights[task.id] ?? 30
                let taskX = padding
                let taskY = masterY

                positionedTasks.append(PositionedTimelineTask(
                    id: task.id,
                    text: task.text,
                    section: sectionName,
                    sectionIndex: sectionIdx,
                    x: taskX,
                    y: taskY,
                    width: nodeWidth,
                    height: tH,
                    colorIndex: colorIdx
                ))

                // Events to right of axis
                let eventStartX = timelineX
                var eventY = taskY
                let taskMidY = taskY + tH / 2

                for event in task.events {
                    let ew = _wrapText(event.text, maxWidth: eventWidth, fontSize: fontSize)
                    let eH = max(fontSize * 1.1 * (Double(ew.count) + 0.5) + TD_NODE_PADDING * 2, 30)

                    positionedEvents.append(PositionedTimelineEvent(
                        id: event.id,
                        taskId: task.id,
                        text: event.text,
                        x: eventStartX,
                        y: eventY,
                        width: eventWidth,
                        height: eH,
                        colorIndex: colorIdx
                    ))

                    // Dashed connector from axis to event
                    let eventMidY = eventY + eH / 2
                    connectors.append(PositionedTimelineConnector(
                        kind: .horizontalTD(x1: taskX + nodeWidth + TD_TASK_AXIS_GAP, y1: taskMidY, x2: eventStartX, y2: eventMidY),
                        colorIndex: colorIdx
                    ))

                    eventY += eH + TD_EVENT_SPACING
                }

                let taskTotalHeight = max(tH, eventStackHeights[task.id] ?? 0)
                masterY += max(taskTotalHeight + TD_TASK_VERTICAL_GAP, tH + TD_TASK_VERTICAL_GAP)
            }
        }
    } else {
        // No sections path
        var taskIdx = 0
        for task in diagram.tasks {
            let colorIdx = diagram.config.disableMulticolor ? 0 : diagram.theme.colorIndex(taskIdx)

            let tH = taskHeights[task.id] ?? 30
            let taskX = padding
            let taskY = masterY

            positionedTasks.append(PositionedTimelineTask(
                id: task.id,
                text: task.text,
                section: "",
                sectionIndex: taskIdx,
                x: taskX,
                y: taskY,
                width: nodeWidth,
                height: tH,
                colorIndex: colorIdx
            ))

            let eventStartX = timelineX
            var eventY = taskY
            let taskMidY = taskY + tH / 2

            for event in task.events {
                let ew = _wrapText(event.text, maxWidth: eventWidth, fontSize: fontSize)
                let eH = max(fontSize * 1.1 * (Double(ew.count) + 0.5) + TD_NODE_PADDING * 2, 30)

                positionedEvents.append(PositionedTimelineEvent(
                    id: event.id,
                    taskId: task.id,
                    text: event.text,
                    x: eventStartX,
                    y: eventY,
                    width: eventWidth,
                    height: eH,
                    colorIndex: colorIdx
                ))

                let eventMidY = eventY + eH / 2
                connectors.append(PositionedTimelineConnector(
                    kind: .horizontalTD(x1: taskX + nodeWidth + TD_TASK_AXIS_GAP, y1: taskMidY, x2: eventStartX, y2: eventMidY),
                    colorIndex: colorIdx
                ))

                eventY += eH + TD_EVENT_SPACING
            }

            let stackH = eventStackHeights[task.id] ?? 0
            masterY += max(tH, stackH) + TD_TASK_VERTICAL_GAP
            taskIdx += 1
        }
    }

    // Compute bounds
    let diagramWidth = padding + nodeWidth + TD_TASK_AXIS_GAP + TD_EVENT_AXIS_GAP + eventWidth + padding
    let diagramHeight = masterY + padding

    let totalWidth = max(diagramWidth, 600)
    let totalHeight = max(diagramHeight + 50, 200)

    var title: PositionedTimelineTitle?
    if let t = diagram.diagramTitle, !t.isEmpty {
        title = PositionedTimelineTitle(text: t, x: padding, y: titleHeight - 10)
    }

    let contentTopY = titleHeight + LR_MASTER_Y_OFFSET
    let arrowTopOffset = fontSize * 2
    let arrowBottomPadding = fontSize * 0.5 + 20

    let activityLine = PositionedTimelineActivityLine(
        x1: padding + nodeWidth + TD_TASK_AXIS_GAP,
        y1: contentTopY - arrowTopOffset,
        x2: padding + nodeWidth + TD_TASK_AXIS_GAP,
        y2: masterY + arrowBottomPadding
    )

    return PositionedTimelineDiagram(
        width: totalWidth,
        height: totalHeight,
        direction: .TD,
        sections: positionedSections,
        tasks: positionedTasks,
        events: positionedEvents,
        connectors: connectors,
        activityLine: activityLine,
        title: title,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        diagramTitle: diagram.diagramTitle,
        config: diagram.config,
        theme: diagram.theme,
        look: diagram.look,
        themeName: diagram.themeName
    )
}

// MARK: - Text wrapping helpers

private func _wrapText(_ text: String, maxWidth: Double, fontSize: Double) -> [String] {
    let normalized = original_src_multiline_utils.normalizeBrTags(text)
    var allLines: [String] = []
    for rawLine in normalized.components(separatedBy: "\n") {
        allLines.append(contentsOf: _wrapSingleLine(rawLine, maxWidth: maxWidth, fontSize: fontSize))
    }
    return allLines
}

private func _wrapSingleLine(_ line: String, maxWidth: Double, fontSize: Double) -> [String] {
    guard !line.isEmpty else { return [""] }
    let fullWidth = original_src_text_metrics.measureTextWidth(line, fontSize: fontSize, fontWeight: 400)
    if fullWidth <= maxWidth {
        return [line]
    }

    let words = line.split(separator: " ").map(String.init)
    var lines: [String] = []
    var currentLine = ""

    for word in words {
        let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
        let testWidth = original_src_text_metrics.measureTextWidth(testLine, fontSize: fontSize, fontWeight: 400)

        if testWidth > maxWidth {
            if !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = word
            } else {
                lines.append(word)
                currentLine = ""
            }
        } else {
            currentLine = testLine
        }
    }

    if !currentLine.isEmpty {
        lines.append(currentLine)
    }

    return lines.isEmpty ? [line] : lines
}

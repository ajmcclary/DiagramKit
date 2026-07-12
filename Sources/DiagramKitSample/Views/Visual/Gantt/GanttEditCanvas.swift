//
//  GanttEditCanvas.swift
//  DiagramPlayground
//
//  Gantt diagram editor surface. Reads GanttDiagram (sections + tasks)
//  from the persistent editor and paints section bands, week ticks,
//  the today marker, and one bar per task. Dragging the right-end
//  handle of a bar shows a +Nw / -Nw delta tooltip and commits the new
//  end time through `LiveEditorStore.performGanttMutation(.resizeTask)`,
//  which round-trips through `MermaidExporter`'s gantt arm.
//

import SwiftUI
import DiagramKitModel
import DiagramKitInteractive
import DiagramKitSampleDesignSystem

struct GanttEditCanvas: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    /// Live resize state. `@GestureState` auto-resets to nil when the gesture
    /// ends *or is cancelled* (system gesture, window resize, tool switch),
    /// so an interrupted drag can't leave a bar stuck mid-resize.
    @GestureState private var ganttDrag: GanttDragState?

    private struct GanttDragState: Equatable {
        let taskID: String
        let deltaWeeks: Int
    }

    /// Minimum task duration a resize may produce (1 day), so dragging the
    /// end handle left past the start can't commit a negative-length task.
    private let minTaskDuration: TimeInterval = 86400

    var body: some View {
        ZoomableCanvas(store: store) {
            if let diagram = ganttDiagram {
                GeometryReader { geo in
                    canvas(diagram: diagram, size: geo.size)
                }
            } else {
                missingDocumentPlaceholder
            }
        }
        .accessibilityIdentifier(A11yID.Visual.canvas)
    }

    // MARK: - Document access

    private var ganttDiagram: GanttDiagram? {
        guard let payload = store.editor?.document.payload else { return nil }
        if case .gantt(let diagram) = payload { return diagram }
        return nil
    }

    /// Today date — driven by `DIAGRAMKIT_GANTT_TODAY` env var when
    /// set (UITests use it), otherwise `Date()`.
    private var today: Date {
        if let str = ProcessInfo.processInfo.environment["DIAGRAMKIT_GANTT_TODAY"],
           let date = isoDateFormatter.date(from: str) {
            return date
        }
        return Date()
    }

    private let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Canvas

    @ViewBuilder
    private func canvas(diagram: GanttDiagram, size: CGSize) -> some View {
        let topInset: CGFloat = 36
        let leftInset: CGFloat = 140
        let rowHeight: CGFloat = 22

        let tasks = diagram.tasks
        if tasks.isEmpty {
            EmptyView()
        } else {
            let earliest = tasks.map(\.startTime).min() ?? Date()
            let latest = tasks.map(\.endTime).max() ?? Date().addingTimeInterval(86400 * 7)
            let totalSeconds = max(latest.timeIntervalSince(earliest), 1)
            let availableWidth = max(size.width - leftInset - 16, 1)
            let pxPerSecond = availableWidth / CGFloat(totalSeconds)

            ZStack(alignment: .topLeading) {
            sectionBands(
                sections: diagram.sections,
                tasks: tasks,
                topInset: topInset,
                leftInset: leftInset,
                rowHeight: rowHeight,
                width: size.width
            )

            weekTicks(
                earliest: earliest,
                latest: latest,
                topInset: topInset,
                leftInset: leftInset,
                pxPerSecond: pxPerSecond,
                height: size.height - topInset
            )

            todayMarker(
                earliest: earliest,
                topInset: topInset,
                leftInset: leftInset,
                pxPerSecond: pxPerSecond,
                height: size.height - topInset
            )

            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                bar(
                    task: task,
                    index: index,
                    earliest: earliest,
                    topInset: topInset,
                    leftInset: leftInset,
                    rowHeight: rowHeight,
                    pxPerSecond: pxPerSecond
                )
            }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    // MARK: - Sub-views

    private func sectionBands(
        sections: [GanttSection],
        tasks: [GanttTask],
        topInset: CGFloat,
        leftInset: CGFloat,
        rowHeight: CGFloat,
        width: CGFloat
    ) -> some View {
        // Tint each task row by its section's parity, and label a section at
        // its first task row. Row-based rather than a single band per section
        // so the shading stays aligned even if a section's tasks are not
        // contiguous in `tasks` (a single band would then span/overlap the
        // wrong rows).
        var sectionOrder: [String: Int] = [:]
        for (index, section) in sections.enumerated() { sectionOrder[section.name] = index }

        return ZStack(alignment: .topLeading) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                let parity = (sectionOrder[task.section] ?? 0) % 2
                if parity == 1 {
                    Rectangle()
                        .fill(environment.theme.colors.element.color.opacity(DSTokens.Opacity.mist))
                        .frame(width: width, height: rowHeight)
                        .position(
                            x: width / 2,
                            y: topInset + rowHeight * CGFloat(index) + rowHeight / 2
                        )
                }
            }
            ForEach(Array(sections.enumerated()), id: \.element.id) { _, section in
                if let first = tasks.firstIndex(where: { $0.section == section.name }) {
                    Text(section.name)
                        .dsFont(.overline)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                        .position(
                            x: leftInset / 2,
                            y: topInset + rowHeight * CGFloat(first) + rowHeight / 2
                        )
                }
            }
        }
    }

    private func weekTicks(
        earliest: Date,
        latest: Date,
        topInset: CGFloat,
        leftInset: CGFloat,
        pxPerSecond: CGFloat,
        height: CGFloat
    ) -> some View {
        let secondsPerWeek: TimeInterval = 86400 * 7
        let totalWeeks = Int(latest.timeIntervalSince(earliest) / secondsPerWeek) + 1
        return ZStack(alignment: .topLeading) {
            ForEach(0...totalWeeks, id: \.self) { week in
                let x = leftInset + CGFloat(Double(week) * secondsPerWeek) * pxPerSecond
                Path { p in
                    p.move(to: CGPoint(x: x, y: topInset))
                    p.addLine(to: CGPoint(x: x, y: topInset + height))
                }
                .stroke(
                    environment.theme.colors.borderVariant.color.opacity(DSTokens.Opacity.light),
                    lineWidth: DSTokens.Stroke.hairline
                )
                Text("w\(week + 1)")
                    .dsFont(.metric)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                    .position(x: x + 12, y: topInset / 2)
            }
        }
    }

    private func todayMarker(
        earliest: Date,
        topInset: CGFloat,
        leftInset: CGFloat,
        pxPerSecond: CGFloat,
        height: CGFloat
    ) -> some View {
        let dx = CGFloat(today.timeIntervalSince(earliest)) * pxPerSecond
        return Group {
            if dx >= 0 {
                let x = leftInset + dx
                Path { p in
                    p.move(to: CGPoint(x: x, y: topInset))
                    p.addLine(to: CGPoint(x: x, y: topInset + height))
                }
                .stroke(environment.theme.colors.error.color, style: StrokeStyle(lineWidth: DSTokens.Stroke.mediumLight, dash: [3, 2]))
                Text("TODAY")
                    .dsFont(.overline)
                    .padding(.horizontal, DSTokens.Spacing.xxs)
                    .padding(.vertical, DSTokens.Stroke.thin)
                    .background(Capsule().fill(environment.theme.colors.error.color))
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                    .position(x: x, y: topInset / 2 + 12)
            }
        }
    }

    private func bar(
        task: GanttTask,
        index: Int,
        earliest: Date,
        topInset: CGFloat,
        leftInset: CGFloat,
        rowHeight: CGFloat,
        pxPerSecond: CGFloat
    ) -> some View {
        let xStart = leftInset + CGFloat(task.startTime.timeIntervalSince(earliest)) * pxPerSecond
        let renderEnd = task.renderEndTime ?? task.endTime
        let activeDelta = ganttDrag?.taskID == task.id ? (ganttDrag?.deltaWeeks ?? 0) : 0
        let visualEndDelta = CGFloat(activeDelta) * 7 * 86400 * pxPerSecond
        let xEnd = leftInset + CGFloat(renderEnd.timeIntervalSince(earliest)) * pxPerSecond + visualEndDelta
        let width = max(xEnd - xStart, 6)
        let y = topInset + rowHeight * CGFloat(index) + rowHeight / 2
        let tint = barTint(for: task)

        return ZStack(alignment: .leading) {
            Capsule()
                .fill(tint.opacity(0.65))
                .frame(width: width, height: rowHeight - 8)
            HStack {
                Text(task.task)
                    .dsFont(.caption2)
                    .lineLimit(1)
                    .padding(.leading, 6)
                Spacer()
            }
            .frame(width: width, height: rowHeight - 8)

            // Right-end resize handle
            Rectangle()
                .fill(Color.white.opacity(0.001)) // hit-testable transparent
                .frame(width: 12, height: rowHeight - 8)
                .position(x: width - 6, y: (rowHeight - 8) / 2)
                .gesture(
                    DragGesture()
                        .updating($ganttDrag) { value, state, _ in
                            state = GanttDragState(
                                taskID: task.id,
                                deltaWeeks: Int(round(value.translation.width / (pxPerSecond * 7 * 86400)))
                            )
                        }
                        .onEnded { value in
                            let committedDelta = Int(round(value.translation.width / (pxPerSecond * 7 * 86400)))
                            guard committedDelta != 0 else { return }
                            let committedTaskId = task.id
                            let rawEnd = task.endTime.addingTimeInterval(
                                Double(committedDelta) * 7 * 86400
                            )
                            // Never commit an end at/before the start.
                            let committedEnd = max(
                                rawEnd,
                                task.startTime.addingTimeInterval(minTaskDuration)
                            )
                            Task {
                                try? await store.performGanttMutation(
                                    .resizeTask(
                                        taskId: committedTaskId,
                                        newEndTime: committedEnd
                                    )
                                )
                            }
                        }
                )

            if ganttDrag?.taskID == task.id, let delta = ganttDrag?.deltaWeeks, delta != 0 {
                let prefix = delta > 0 ? "+" : ""
                DSGlassSurface(role: .popover) {
                    Text("\(prefix)\(delta)w")
                        .dsFont(.metric)
                        .padding(.horizontal, DSTokens.Spacing.xs)
                        .padding(.vertical, DSTokens.Spacing.xxxs)
                        .foregroundStyle(environment.theme.colors.accent.color)
                }
                    .offset(x: width + 6, y: 0)
            }
        }
        .position(x: xStart + width / 2, y: y)
        .accessibilityIdentifier("visual.gantt.bar.\(task.id)")
    }

    private func barTint(for task: GanttTask) -> Color {
        if task.tags.contains(.milestone) { return .pink }
        if task.tags.contains(.done) { return .green }
        if task.tags.contains(.active) { return .blue }
        if task.tags.contains(.crit) { return .red }
        return .accentColor
    }

    // MARK: - Stubs

    private var missingDocumentPlaceholder: some View {
        VStack(spacing: DSTokens.Spacing.xs) {
            DSIconView(.diagram, size: DSTokens.Icon.lg, colorRole: .muted)
            Text("Switch to a gantt source to use this canvas.")
                .dsFont(.caption)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

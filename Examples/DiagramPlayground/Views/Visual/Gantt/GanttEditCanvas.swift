//
//  GanttEditCanvas.swift
//  DiagramPlayground
//
//  Phase 4 / Task 4.2 — gantt diagram editor surface. Reads
//  GanttDiagram (sections + tasks) from the persistent editor and
//  paints section bands, week ticks, the today marker, and one bar
//  per task. Dragging the right-end handle of a bar shows a +Nw /
//  -Nw delta tooltip; commit is deferred — the library doesn't ship
//  a GanttMutation yet, so this canvas surfaces a banner noting the
//  limitation rather than rewriting the source.
//

import SwiftUI
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct GanttEditCanvas: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var draggingTaskID: String?
    @SwiftUI.State private var dragDeltaWeeks: Int = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(store.previewTheme.background)
                .ignoresSafeArea()

            if let diagram = ganttDiagram {
                GeometryReader { geo in
                    canvas(diagram: diagram, size: geo.size)
                }
            } else {
                missingDocumentPlaceholder
            }

            mutationBanner
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
        ZStack(alignment: .topLeading) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                let bandY = topInset + rowHeight * CGFloat(taskIndex(of: section, in: tasks))
                let bandHeight = rowHeight * CGFloat(taskCount(of: section, in: tasks))
                if bandHeight > 0 {
                    let isAlt = index % 2 == 1
                    Rectangle()
                        .fill(isAlt ? Color.gray.opacity(0.06) : Color.clear)
                        .frame(width: width, height: bandHeight)
                        .position(x: width / 2, y: bandY + bandHeight / 2)
                    Text(section.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .position(x: leftInset / 2, y: bandY + bandHeight / 2)
                }
            }
        }
    }

    private func taskIndex(of section: GanttSection, in tasks: [GanttTask]) -> Int {
        tasks.firstIndex(where: { $0.section == section.name }) ?? 0
    }

    private func taskCount(of section: GanttSection, in tasks: [GanttTask]) -> Int {
        tasks.filter { $0.section == section.name }.count
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
                .stroke(Color.secondary.opacity(0.18), lineWidth: 0.5)
                Text("w\(week + 1)")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
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
                .stroke(Color.red, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                Text("TODAY")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.red))
                    .foregroundStyle(.white)
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
        let visualEndDelta = draggingTaskID == task.id ? CGFloat(dragDeltaWeeks) * 7 * 86400 * pxPerSecond : 0
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
                    .font(.system(size: 10, weight: .medium))
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
                        .onChanged { value in
                            draggingTaskID = task.id
                            dragDeltaWeeks = Int(round(value.translation.width / (pxPerSecond * 7 * 86400)))
                            store.setVisualStage(.edgeDrag)
                        }
                        .onEnded { _ in
                            draggingTaskID = nil
                            dragDeltaWeeks = 0
                            store.setVisualStage(.idle)
                        }
                )

            if draggingTaskID == task.id, dragDeltaWeeks != 0 {
                let prefix = dragDeltaWeeks > 0 ? "+" : ""
                Text("\(prefix)\(dragDeltaWeeks)w")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.regularMaterial))
                    .foregroundStyle(Color.accentColor)
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
        VStack(spacing: 6) {
            Image(systemName: "calendar.day.timeline.left")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Switch to a gantt source to use this canvas.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mutationBanner: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Resize ghost · commit deferred (no GanttMutation yet)")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.regularMaterial))
                .foregroundStyle(.secondary)
                .padding(.trailing, 12)
                .padding(.top, 12)
                Spacer()
            }
            Spacer()
        }
    }
}

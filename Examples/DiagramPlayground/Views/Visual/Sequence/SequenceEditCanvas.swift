//
//  SequenceEditCanvas.swift
//  DiagramPlayground
//
//  Phase 4 / Task 4.1 — sequence diagram editor surface. Reads
//  SequenceDiagram (actors + messages) from the persistent editor
//  and paints lifelines as columns and messages as rows. Dragging a
//  message ghost reorders its target index visually; commit is
//  intentionally deferred — the library doesn't ship a
//  SequenceMutation.move yet, so this canvas surfaces a banner
//  noting the limitation rather than mutating the source.
//

import SwiftUI
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SequenceEditCanvas: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var draggingIndex: Int?
    @SwiftUI.State private var dragOffsetY: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(store.previewTheme.background)
                .ignoresSafeArea()

            if let diagram = sequenceDiagram {
                let actors = diagram.actors
                let msgs = orderedMessages(in: diagram)
                GeometryReader { geo in
                    canvas(
                        actors: actors,
                        messages: msgs,
                        size: geo.size
                    )
                }
            } else {
                missingDocumentPlaceholder
            }

            mutationBanner
        }
        .accessibilityIdentifier(A11yID.Visual.canvas)
    }

    // MARK: - Document access

    private var sequenceDiagram: SequenceDiagram? {
        guard let payload = store.editor?.document.payload else { return nil }
        if case .sequenceDiagram(let diagram) = payload { return diagram }
        return nil
    }

    private func orderedMessages(in diagram: SequenceDiagram) -> [SequenceMessage] {
        diagram.items.compactMap { item in
            if case .message(let m) = item { return m }
            return nil
        }
    }

    // MARK: - Canvas

    @ViewBuilder
    private func canvas(actors: [SequenceActor], messages: [SequenceMessage], size: CGSize) -> some View {
        let topInset: CGFloat = 60
        let leftInset: CGFloat = 24
        let rightInset: CGFloat = 24
        let columnSpacing: CGFloat = max(80, (size.width - leftInset - rightInset) / max(CGFloat(actors.count), 1))
        let rowHeight: CGFloat = 36

        ZStack(alignment: .topLeading) {
            // Lifelines
            ForEach(Array(actors.enumerated()), id: \.element.id) { index, actor in
                let x = leftInset + columnSpacing * (CGFloat(index) + 0.5)
                lifeline(actor: actor, x: x, height: size.height - topInset, topInset: topInset)
            }

            // Messages
            ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                let y = topInset + rowHeight * CGFloat(index) + (draggingIndex == index ? dragOffsetY : 0)
                messageRow(
                    message: message,
                    actors: actors,
                    leftInset: leftInset,
                    columnSpacing: columnSpacing,
                    y: y,
                    rowHeight: rowHeight,
                    isDragging: draggingIndex == index
                )
                .gesture(rowDragGesture(index: index, rowHeight: rowHeight))
            }

            if let dragging = draggingIndex {
                let target = max(0, min(messages.count - 1, dragging + Int(round(dragOffsetY / rowHeight))))
                let y = topInset + rowHeight * CGFloat(target)
                Path { p in
                    p.move(to: CGPoint(x: leftInset, y: y))
                    p.addLine(to: CGPoint(x: size.width - rightInset, y: y))
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func rowDragGesture(index: Int, rowHeight: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                draggingIndex = index
                dragOffsetY = value.translation.height
                store.setVisualStage(.edgeDrag) // reuse for drag-feedback
            }
            .onEnded { _ in
                draggingIndex = nil
                dragOffsetY = 0
                store.setVisualStage(.idle)
            }
    }

    private func lifeline(actor: SequenceActor, x: CGFloat, height: CGFloat, topInset: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(actor.label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.18))
                )
                .foregroundStyle(Color.accentColor)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 0, y: height))
            }
            .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            .frame(height: height)
        }
        .position(x: x, y: topInset / 2 + height / 2)
        .accessibilityIdentifier("visual.sequence.lifeline.\(actor.id)")
    }

    private func messageRow(
        message: SequenceMessage,
        actors: [SequenceActor],
        leftInset: CGFloat,
        columnSpacing: CGFloat,
        y: CGFloat,
        rowHeight: CGFloat,
        isDragging: Bool
    ) -> some View {
        let fromIndex = actors.firstIndex(where: { $0.id == message.from }) ?? 0
        let toIndex = actors.firstIndex(where: { $0.id == message.to }) ?? 0
        let fromX = leftInset + columnSpacing * (CGFloat(fromIndex) + 0.5)
        let toX = leftInset + columnSpacing * (CGFloat(toIndex) + 0.5)
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: fromX, y: y))
                p.addLine(to: CGPoint(x: toX, y: y))
            }
            .stroke(
                isDragging ? Color.accentColor : Color.primary.opacity(0.7),
                style: StrokeStyle(
                    lineWidth: isDragging ? 2 : 1.2,
                    dash: message.lineStyle == "dashed" ? [4, 3] : []
                )
            )

            // Arrowhead at target
            let dir: CGFloat = toX >= fromX ? 1 : -1
            Path { p in
                p.move(to: CGPoint(x: toX, y: y))
                p.addLine(to: CGPoint(x: toX - 6 * dir, y: y - 4))
                p.move(to: CGPoint(x: toX, y: y))
                p.addLine(to: CGPoint(x: toX - 6 * dir, y: y + 4))
            }
            .stroke(isDragging ? Color.accentColor : Color.primary, lineWidth: 1.5)

            // Label centered between endpoints, slightly above the line
            Text(message.label)
                .font(.system(size: 10))
                .padding(.horizontal, 4)
                .background(Capsule().fill(Color(store.previewTheme.background)))
                .foregroundStyle(.primary)
                .position(x: (fromX + toX) / 2, y: y - 8)
        }
        .frame(height: rowHeight, alignment: .top)
        .contentShape(Rectangle())
        .opacity(isDragging ? 0.55 : 1)
    }

    private var missingDocumentPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "rectangle.compress.vertical")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Switch to a sequence diagram source to use this canvas.")
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
                    Text("Reorder ghost · commit deferred (no SequenceMutation yet)")
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

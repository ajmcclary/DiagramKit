//
//  FlowchartEditCanvas.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.3 — flowchart edit canvas. Wraps the library
//  DiagramView for the actual flowchart paint, then layers a click /
//  double-click / drag overlay on top so the visible behavior matches
//  the JSX seven-stage state machine:
//
//    idle → tap node          → nodeSelected (accent ring + 4 handles)
//    nodeSelected → tap empty → idle
//    nodeSelected → dbl-tap   → labelEdited (NodeEditPopover, Task 3.5)
//    nodeSelected → drag a corner handle → edgeDrag (Task 3.4)
//
//  Phase 3.4 layers marquee multi-selection on top of this canvas.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import DiagramKitInteractive

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct FlowchartEditCanvas: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var liveDiagramBounds: CGRect = .zero
    @SwiftUI.State private var liveBoundsLookup: DiagramBoundsLookup?
    @SwiftUI.State private var liveParseError: Error?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color(store.previewTheme.background)
                    .ignoresSafeArea()

                DiagramView(
                    source: store.previewSource,
                    theme: store.previewTheme,
                    layoutConfig: store.previewLayoutConfig,
                    sourceFormat: store.state.sourceFormat.formatID,
                    parseError: parseErrorBinding,
                    diagramBounds: $liveDiagramBounds,
                    boundsLookup: $liveBoundsLookup
                )
                .frame(width: max(liveDiagramBounds.width, 1), height: max(liveDiagramBounds.height, 1))
                .position(centerPoint(in: geometry.size))

                selectionOverlay(in: geometry)

                if !store.state.marqueeSelection.isEmpty {
                    marqueeOverlay(in: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(tapGesture(in: geometry))
            .simultaneousGesture(doubleTapGesture(in: geometry))
            .onChange(of: liveDiagramBounds) { _, _ in
                store.boundsLookup = liveBoundsLookup
            }
        }
        .accessibilityIdentifier(A11yID.Visual.canvas)
    }

    // MARK: - Coordinate helpers

    private func centerPoint(in viewSize: CGSize) -> CGPoint {
        CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
    }

    private var parseErrorBinding: Binding<Error?> {
        Binding(get: { liveParseError }, set: { liveParseError = $0 })
    }

    /// View-space rect for an element's diagram-space `bounds`. Mirrors
    /// the math in PreviewCanvas's selectionOverlay so the corner
    /// handles line up with the live diagram even when the diagram is
    /// smaller than the host view (it's centered).
    private func viewRect(for diagramBounds: DiagramRect, in viewSize: CGSize) -> CGRect {
        let centerX = (viewSize.width - liveDiagramBounds.width) / 2
        let centerY = (viewSize.height - liveDiagramBounds.height) / 2
        return CGRect(
            x: centerX + CGFloat(diagramBounds.minX),
            y: centerY + CGFloat(diagramBounds.minY),
            width: CGFloat(diagramBounds.width),
            height: CGFloat(diagramBounds.height)
        )
    }

    // MARK: - Selection overlay

    @ViewBuilder
    private func selectionOverlay(in geometry: GeometryProxy) -> some View {
        if let selection = store.editor?.selection,
           let bounds = liveBoundsLookup?.bounds(of: selection) {
            let rect = viewRect(for: bounds, in: geometry.size)
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)

                ForEach(handlePositions(rect), id: \.self) { point in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 1.5))
                        .position(point)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func handlePositions(_ rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
    }

    // MARK: - Marquee overlay

    @ViewBuilder
    private func marqueeOverlay(in geometry: GeometryProxy) -> some View {
        // Phase 3.4 paints per-node accent rings for marqueeSelection;
        // Phase 3.3 ships the geometry hook so the rings can be added
        // without a second canvas refactor.
        if let lookup = liveBoundsLookup {
            ForEach(Array(store.state.marqueeSelection), id: \.self) { id in
                let sel = DiagramSelection(diagramType: editorType, elementID: id)
                if let bounds = lookup.bounds(of: sel) {
                    let rect = viewRect(for: bounds, in: geometry.size)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor.opacity(0.65), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var editorType: DiagramType {
        store.editor?.document.type ?? .flowchart
    }

    // MARK: - Gestures

    private func tapGesture(in geometry: GeometryProxy) -> some Gesture {
        SpatialTapGesture(count: 1)
            .onEnded { event in
                handleTap(at: event.location, in: geometry.size)
            }
    }

    private func doubleTapGesture(in geometry: GeometryProxy) -> some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { event in
                handleDoubleTap(at: event.location, in: geometry.size)
            }
    }

    private func handleTap(at viewPoint: CGPoint, in viewSize: CGSize) {
        guard let lookup = liveBoundsLookup else { return }
        let local = diagramPoint(from: viewPoint, viewSize: viewSize)
        if let element = lookup.element(at: local) {
            store.editor?.selection = element
            store.setVisualStage(.nodeSelected)
        } else {
            store.editor?.selection = nil
            store.setMarqueeSelection([])
            store.setVisualStage(.idle)
        }
    }

    private func handleDoubleTap(at viewPoint: CGPoint, in viewSize: CGSize) {
        guard let lookup = liveBoundsLookup else { return }
        let local = diagramPoint(from: viewPoint, viewSize: viewSize)
        if let element = lookup.element(at: local) {
            store.editor?.selection = element
            store.setVisualStage(.labelEdited)
        }
    }

    private func diagramPoint(from viewPoint: CGPoint, viewSize: CGSize) -> DiagramPoint {
        let centerX = (viewSize.width - liveDiagramBounds.width) / 2
        let centerY = (viewSize.height - liveDiagramBounds.height) / 2
        return DiagramPoint(
            x: Double(viewPoint.x - centerX),
            y: Double(viewPoint.y - centerY)
        )
    }
}

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

struct FlowchartEditCanvas: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var liveDiagramBounds: CGRect = .zero
    @SwiftUI.State private var liveBoundsLookup: DiagramBoundsLookup?
    @SwiftUI.State private var liveParseError: Error?

    // Phase 3 / Task 3.4 — drag state for marquee + connector tools.
    @SwiftUI.State private var marqueeStart: CGPoint?
    @SwiftUI.State private var marqueeCurrent: CGPoint?
    @SwiftUI.State private var edgeDragStart: CGPoint?
    @SwiftUI.State private var edgeDragCurrent: CGPoint?
    @SwiftUI.State private var edgeDragSourceID: String?

    // Visual editor plan 3 — drag-to-join (select tool).
    @SwiftUI.State private var nodeDragElementID: String?
    @SwiftUI.State private var nodeDragCurrent: CGPoint?
    @SwiftUI.State private var dropTargetGroupID: String?

    // Visual editor plan 3 — right-click needs a position; SwiftUI's
    // contextMenu doesn't provide one, so track the last hover point.
    @SwiftUI.State private var hoverPoint: CGPoint?

    /// Committed zoom/pan for the visual editor, resolved to a `CanvasTransform`.
    /// Task 6 adds live gesture translation on top of this.
    private var transform: CanvasTransform {
        CanvasTransform(
            scale: store.state.visualZoomScale ?? 1,
            offset: store.state.visualPanOffset ?? .zero
        )
    }

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
                .frame(
                    width: max(liveDiagramBounds.width * transform.scale, 1),
                    height: max(liveDiagramBounds.height * transform.scale, 1)
                )
                .position(diagramCenter(in: geometry.size))

                ForEach(imageNodeOverlays(in: geometry.size), id: \.id) { item in
                    ImageNodeOverlayItem(urlString: item.url, rect: item.rect)
                }

                selectionOverlay(in: geometry)

                if !store.state.marqueeSelection.isEmpty {
                    marqueeOverlay(in: geometry)
                }

                SubgraphOverlay(
                    store: store,
                    viewSize: geometry.size,
                    liveDiagramBounds: liveDiagramBounds,
                    liveBoundsLookup: liveBoundsLookup,
                    transform: transform
                )

                if let start = marqueeStart, let current = marqueeCurrent {
                    marqueeRect(start: start, current: current)
                }

                if let start = edgeDragStart, let current = edgeDragCurrent {
                    edgeRubberBand(start: start, current: current)
                }

                if let current = nodeDragCurrent, let elementID = nodeDragElementID {
                    nodeDragGhost(at: current, elementID: elementID, in: geometry)
                }
                if let targetID = dropTargetGroupID {
                    dropTargetHighlight(groupID: targetID, in: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(dragGesture(in: geometry))
            .simultaneousGesture(tapGesture(in: geometry))
            .simultaneousGesture(doubleTapGesture(in: geometry))
            .onContinuousHover { phase in
                if case .active(let point) = phase {
                    hoverPoint = point
                }
            }
            .contextMenu {
                CanvasContextMenu(store: store, element: elementAtHover(in: geometry.size))
            }
            .onChange(of: liveDiagramBounds) { _, _ in
                store.boundsLookup = liveBoundsLookup
            }
        }
        .accessibilityIdentifier(A11yID.Visual.canvas)
    }

    // MARK: - Coordinate helpers

    private func diagramCenter(in viewSize: CGSize) -> CGPoint {
        let o = transform.origin(diagramBounds: liveDiagramBounds, viewSize: viewSize)
        return CGPoint(
            x: o.x + liveDiagramBounds.width * transform.scale / 2,
            y: o.y + liveDiagramBounds.height * transform.scale / 2
        )
    }

    private var parseErrorBinding: Binding<Error?> {
        Binding(get: { liveParseError }, set: { liveParseError = $0 })
    }

    /// View-space rect for an element's diagram-space `bounds`. Mirrors
    /// the math in PreviewCanvas's selectionOverlay so the corner
    /// handles line up with the live diagram even when the diagram is
    /// smaller than the host view (it's centered).
    private func viewRect(for diagramBounds: DiagramRect, in viewSize: CGSize) -> CGRect {
        transform.viewRect(
            forDiagramBounds: CGRect(
                x: CGFloat(diagramBounds.minX), y: CGFloat(diagramBounds.minY),
                width: CGFloat(diagramBounds.width), height: CGFloat(diagramBounds.height)
            ),
            diagramBounds: liveDiagramBounds,
            viewSize: viewSize
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

    private func elementAtHover(in viewSize: CGSize) -> DiagramSelection? {
        guard let hoverPoint, let lookup = liveBoundsLookup else { return nil }
        return lookup.element(at: diagramPoint(from: hoverPoint, viewSize: viewSize))
    }

    /// (nodeID, url, viewRect) for every image node the lookup can place.
    private func imageNodeOverlays(in viewSize: CGSize) -> [(id: String, url: String, rect: CGRect)] {
        guard
            let lookup = liveBoundsLookup,
            case .flowchart(let graph) = store.editor?.document.payload
        else { return [] }
        return graph.nodesInOrder.compactMap { entry in
            guard let url = entry.node.properties?.img, !url.isEmpty else { return nil }
            let sel = DiagramSelection(diagramType: editorType, elementID: "node:\(entry.id)")
            guard let bounds = lookup.bounds(of: sel) else { return nil }
            return (id: entry.id, url: url, rect: viewRect(for: bounds, in: viewSize))
        }
    }

    private func diagramPoint(from viewPoint: CGPoint, viewSize: CGSize) -> DiagramPoint {
        let p = transform.diagramPoint(
            fromViewPoint: viewPoint, diagramBounds: liveDiagramBounds, viewSize: viewSize
        )
        return DiagramPoint(x: Double(p.x), y: Double(p.y))
    }

    // MARK: - Drag gestures (Phase 3 / Task 3.4)

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                handleDragChanged(value, in: geometry.size)
            }
            .onEnded { value in
                handleDragEnded(value, in: geometry.size)
            }
    }

    private func handleDragChanged(_ value: DragGesture.Value, in viewSize: CGSize) {
        switch store.state.visualTool {
        case .marquee:
            if marqueeStart == nil {
                marqueeStart = value.startLocation
                store.setVisualStage(.marquee)
            }
            marqueeCurrent = value.location
        case .connector:
            if edgeDragStart == nil {
                edgeDragStart = value.startLocation
                edgeDragSourceID = nodeID(at: value.startLocation, in: viewSize)
                store.setVisualStage(.edgeDrag)
            }
            edgeDragCurrent = value.location
        case .select:
            // Visual editor plan 3 — drag-to-join. Only drags that
            // start on a node become membership drags; empty-canvas
            // drags stay no-ops.
            if nodeDragElementID == nil {
                guard
                    let elementID = nodeID(at: value.startLocation, in: viewSize),
                    elementID.hasPrefix("node:")
                else { break }
                nodeDragElementID = elementID
            }
            nodeDragCurrent = value.location
            dropTargetGroupID = groupID(at: value.location, in: viewSize)
        case .pan:
            break
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, in viewSize: CGSize) {
        defer {
            marqueeStart = nil
            marqueeCurrent = nil
            edgeDragStart = nil
            edgeDragCurrent = nil
            edgeDragSourceID = nil
            nodeDragElementID = nil
            nodeDragCurrent = nil
            dropTargetGroupID = nil
        }
        switch store.state.visualTool {
        case .marquee:
            commitMarquee(start: value.startLocation, end: value.location, viewSize: viewSize)
        case .connector:
            commitEdgeDrag(end: value.location, viewSize: viewSize)
        case .select:
            commitNodeDrag(end: value.location, viewSize: viewSize)
        case .pan:
            break
        }
    }

    // MARK: - Marquee commit

    private func commitMarquee(start: CGPoint, end: CGPoint, viewSize: CGSize) {
        guard let lookup = liveBoundsLookup else { return }
        let p1 = diagramPoint(from: start, viewSize: viewSize)
        let p2 = diagramPoint(from: end, viewSize: viewSize)
        let rect = DiagramRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
        let elements = lookup.elements(in: rect)
        store.setMarqueeSelection(Set(elements.map(\.elementID)))
        store.setVisualStage(elements.isEmpty ? .idle : .marquee)
    }

    // MARK: - Edge drag commit

    private func commitEdgeDrag(end: CGPoint, viewSize: CGSize) {
        defer { store.setVisualStage(.idle) }
        guard
            let sourceID = edgeDragSourceID,
            let targetID = nodeID(at: end, in: viewSize),
            sourceID != targetID
        else { return }
        let type = editorType
        let from = DiagramSelection(diagramType: type, elementID: sourceID)
        let to = DiagramSelection(diagramType: type, elementID: targetID)
        let id = "e_\(sourceID)_\(targetID)_\(Int(Date().timeIntervalSince1970))"
        Task {
            do {
                try await store.performFlowchartMutation(
                    .insertEdge(id: id, from: from, to: to, label: nil)
                )
            } catch {
                // performFlowchartMutation already records the error on
                // store.lastMutationError; nothing more to do here.
            }
        }
    }

    private func nodeID(at viewPoint: CGPoint, in viewSize: CGSize) -> String? {
        guard let lookup = liveBoundsLookup else { return nil }
        let local = diagramPoint(from: viewPoint, viewSize: viewSize)
        return lookup.element(at: local)?.elementID
    }

    /// Deepest (smallest-area) subgraph whose bounds contain the view
    /// point. Returns the bare subgraph id (no "group:" prefix).
    private func groupID(at viewPoint: CGPoint, in viewSize: CGSize) -> String? {
        guard let lookup = liveBoundsLookup else { return nil }
        let p = diagramPoint(from: viewPoint, viewSize: viewSize)
        var best: (id: String, area: Double)?
        for elementID in lookup.allElementIDs where elementID.hasPrefix("group:") {
            guard
                let sel = lookup.selection(for: elementID),
                let b = lookup.bounds(of: sel),
                b.contains(p)
            else { continue }
            let area = b.width * b.height
            if best == nil || area < best!.area {
                best = (String(elementID.dropFirst(6)), area)
            }
        }
        return best?.id
    }

    // MARK: - Drag-to-join commit (visual editor plan 3)

    private func commitNodeDrag(end: CGPoint, viewSize: CGSize) {
        guard let elementID = nodeDragElementID else { return }
        let nodeID = String(elementID.dropFirst(5))
        let target = groupID(at: end, in: viewSize)
        let current = store.subgraphID(containing: nodeID)
        guard target != current else { return }  // unchanged → no mutation
        let sel = DiagramSelection(diagramType: editorType, elementID: elementID)
        Task {
            try? await store.performFlowchartMutation(
                .moveToSubgraph(selections: [sel], target: target)
            )
        }
    }

    // MARK: - Drag overlays

    private func marqueeRect(start: CGPoint, current: CGPoint) -> some View {
        let rect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        return Rectangle()
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .background(Rectangle().fill(Color.accentColor.opacity(0.08)))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }

    // MARK: - Drag-to-join overlays

    @ViewBuilder
    private func nodeDragGhost(at point: CGPoint, elementID: String, in geometry: GeometryProxy) -> some View {
        let sel = DiagramSelection(diagramType: editorType, elementID: elementID)
        let size: CGSize = {
            if let b = liveBoundsLookup?.bounds(of: sel) {
                return CGSize(width: CGFloat(b.width), height: CGFloat(b.height))
            }
            return CGSize(width: 80, height: 36)
        }()
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.accentColor.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            )
            .frame(width: size.width, height: size.height)
            .position(point)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func dropTargetHighlight(groupID: String, in geometry: GeometryProxy) -> some View {
        let sel = DiagramSelection(diagramType: editorType, elementID: "group:\(groupID)")
        if let bounds = liveBoundsLookup?.bounds(of: sel) {
            let rect = viewRect(for: bounds, in: geometry.size)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.85), lineWidth: 2.5)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        }
    }

    private func edgeRubberBand(start: CGPoint, current: CGPoint) -> some View {
        Path { p in
            p.move(to: start)
            p.addLine(to: current)
        }
        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
        .allowsHitTesting(false)
    }
}

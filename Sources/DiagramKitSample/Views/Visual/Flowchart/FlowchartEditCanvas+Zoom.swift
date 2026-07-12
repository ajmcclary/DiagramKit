//
//  FlowchartEditCanvas+Zoom.swift
//  DiagramPlayground
//
//  Canvas zoom/pan for the flowchart editor: the resolved `CanvasTransform`
//  (committed zoom/pan + in-flight gesture translation), the pinch gesture,
//  the auto-fit refresh, pan commit, and the floating zoom toolbar overlay.
//  Split out of FlowchartEditCanvas.swift to keep that file under the
//  file-size gate.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

extension FlowchartEditCanvas {

    /// Resolved zoom scale: the user's committed value, or the auto-fit
    /// fallback when the user hasn't set one.
    var currentZoomScale: CGFloat {
        CanvasTransform.clampScale(store.state.visualZoomScale ?? automaticZoomScale)
    }

    /// Whether the canvas is in auto-fit mode (no user-set zoom).
    var isAtAutomaticFit: Bool { store.state.visualZoomScale == nil }

    /// Committed zoom/pan plus the in-flight pan translation, resolved to a
    /// `CanvasTransform` used by every coordinate helper and overlay.
    var transform: CanvasTransform {
        let base = store.state.visualPanOffset ?? .zero
        return CanvasTransform(
            scale: currentZoomScale,
            offset: CGSize(
                width: base.width + activePanTranslation.width,
                height: base.height + activePanTranslation.height
            )
        )
    }

    // MARK: - Coordinate helpers (transform-aware)

    /// Center point for `.position`ing the scaled `DiagramView` frame.
    func diagramCenter(in viewSize: CGSize) -> CGPoint {
        let o = transform.origin(diagramBounds: liveDiagramBounds, viewSize: viewSize)
        return CGPoint(
            x: o.x + liveDiagramBounds.width * transform.scale / 2,
            y: o.y + liveDiagramBounds.height * transform.scale / 2
        )
    }

    /// Diagram-space element bounds → view-space rect (for overlays/handles).
    func viewRect(for diagramBounds: DiagramRect, in viewSize: CGSize) -> CGRect {
        transform.viewRect(
            forDiagramBounds: CGRect(
                x: CGFloat(diagramBounds.minX), y: CGFloat(diagramBounds.minY),
                width: CGFloat(diagramBounds.width), height: CGFloat(diagramBounds.height)
            ),
            diagramBounds: liveDiagramBounds,
            viewSize: viewSize
        )
    }

    /// View-space tap/drag point → diagram-space point (for hit-testing).
    func diagramPoint(from viewPoint: CGPoint, viewSize: CGSize) -> DiagramPoint {
        let p = transform.diagramPoint(
            fromViewPoint: viewPoint, diagramBounds: liveDiagramBounds, viewSize: viewSize
        )
        return DiagramPoint(x: Double(p.x), y: Double(p.y))
    }

    // MARK: - Gestures

    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if gestureBaseZoomScale == nil { gestureBaseZoomScale = currentZoomScale }
                let base = gestureBaseZoomScale ?? currentZoomScale
                store.setVisualZoomScale(CanvasTransform.gestureScale(base: base, value: value))
            }
            .onEnded { _ in gestureBaseZoomScale = nil }
    }

    private var zoomToolbarBinding: Binding<CGFloat> {
        Binding(
            get: { currentZoomScale },
            set: { store.setVisualZoomScale(CanvasTransform.clampScale($0)) }
        )
    }

    func refreshAutomaticFit(bounds: CGRect, viewSize: CGSize) {
        guard bounds.width > 0, viewSize.width > 0 else { return }
        automaticZoomScale = CanvasTransform.fitScale(diagramBounds: bounds, viewSize: viewSize)
    }

    func commitPan(_ translation: CGSize) {
        let base = store.state.visualPanOffset ?? .zero
        store.setVisualPanOffset(CGSize(
            width: base.width + translation.width,
            height: base.height + translation.height
        ))
        activePanTranslation = .zero
    }

    // MARK: - Toolbar

    @ViewBuilder
    var zoomToolbarOverlay: some View {
        CanvasZoomToolbar(
            zoomScale: zoomToolbarBinding,
            gridEnabled: .constant(false),
            panZoomEnabled: .constant(true),
            isAtAutomaticFit: isAtAutomaticFit,
            minZoom: minZoom,
            maxZoom: maxZoom,
            onFitToView: {
                store.setVisualZoomScale(nil)
                store.setVisualPanOffset(.zero)
            },
            onActualSize: {
                store.setVisualZoomScale(1.0)
                store.setVisualPanOffset(.zero)
            },
            onFullWindowPreview: nil,
            showsGrid: false
        )
        .padding(12)
    }
}

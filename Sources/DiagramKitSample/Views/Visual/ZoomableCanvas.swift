//
//  ZoomableCanvas.swift
//  DiagramPlayground
//
//  Reusable pinch + background-pan + toolbar wrapper for custom-layout
//  visual editors (Gantt, Sequence). Applies a `.scaleEffect`/`.offset`
//  transform to its content and binds the shared `CanvasZoomToolbar` to the
//  visual-editor zoom state. Fit / Actual reset to identity (these layouts
//  already fill the available width).
//
//  Flowchart does NOT use this — it threads `CanvasTransform` through its
//  own overlays for per-element hit-testing.
//

import SwiftUI

struct ZoomableCanvas<Content: View>: View {
    @Bindable var store: LiveEditorStore
    @ViewBuilder var content: () -> Content

    @SwiftUI.State private var gestureBaseZoomScale: CGFloat?
    // `@GestureState` auto-resets to `.zero` when the pan gesture ends or is
    // cancelled, so an interrupted pan can't leave the canvas stuck offset.
    @GestureState private var activePanTranslation: CGSize = .zero

    private var currentZoomScale: CGFloat {
        CanvasTransform.clampScale(store.state.visualZoomScale ?? 1)
    }
    private var effectiveOffset: CGSize {
        let base = store.state.visualPanOffset ?? .zero
        return CGSize(width: base.width + activePanTranslation.width,
                      height: base.height + activePanTranslation.height)
    }
    private var isAtAutomaticFit: Bool { store.state.visualZoomScale == nil }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(store.previewTheme.background)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(panGesture)
                .simultaneousGesture(magnificationGesture)

            content()
                .scaleEffect(currentZoomScale, anchor: .topLeading)
                .offset(effectiveOffset)
        }
        .overlay(alignment: .bottomTrailing) { toolbar }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if gestureBaseZoomScale == nil { gestureBaseZoomScale = currentZoomScale }
                let base = gestureBaseZoomScale ?? currentZoomScale
                store.setVisualZoomScale(CanvasTransform.gestureScale(base: base, value: value))
            }
            .onEnded { _ in gestureBaseZoomScale = nil }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($activePanTranslation) { value, state, _ in state = value.translation }
            .onEnded { value in
                let base = store.state.visualPanOffset ?? .zero
                store.setVisualPanOffset(CGSize(width: base.width + value.translation.width,
                                                height: base.height + value.translation.height))
            }
    }

    private var toolbar: some View {
        CanvasZoomToolbar(
            zoomScale: Binding(
                get: { currentZoomScale },
                set: { store.setVisualZoomScale(CanvasTransform.clampScale($0)) }
            ),
            gridEnabled: .constant(false),
            panZoomEnabled: .constant(true),
            isAtAutomaticFit: isAtAutomaticFit,
            minZoom: CanvasTransform.minScale,
            maxZoom: CanvasTransform.maxScale,
            onFitToView: { store.setVisualZoomScale(nil); store.setVisualPanOffset(.zero) },
            onActualSize: { store.setVisualZoomScale(1.0); store.setVisualPanOffset(.zero) },
            onFullWindowPreview: nil,
            showsGrid: false
        )
        .padding(12)
    }
}

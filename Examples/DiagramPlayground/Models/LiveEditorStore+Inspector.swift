//
//  LiveEditorStore+Inspector.swift
//  DiagramPlayground
//
//  Phase 7 inspector drawer toggle, structural undo/redo delegates,
//  the canvas tap dispatcher, and the static viewspace → diagram-space
//  coordinate helper. Extracted from LiveEditorStore.swift.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
extension LiveEditorStore {
    /// Convenience kept here so call sites in Visual views read clean.
    public var hasFlowchartDocument: Bool {
        editor?.document.type == .flowchart
    }

    // MARK: - Inspector pane (Phase 7)

    /// Toggle the floating Inspector drawer.
    public func toggleInspector() {
        state.inspectorOpen.toggle()
    }

    /// Force-opens the inspector regardless of prior state. Used by
    /// UI tests that need a deterministic starting state.
    public func openInspector() {
        state.inspectorOpen = true
    }

    /// Delegate to `editor.undoManager.undo()`. Observation updates flow
    /// through `DiagramEditor.canUndo` / `canRedo` via the editor's
    /// NotificationCenter wiring — no manual tickle needed.
    public func undoStructural() {
        editor?.undoManager.undo()
        moveUndoCursor(by: -1)
    }

    /// Delegate to `editor.undoManager.redo()`.
    public func redoStructural() {
        editor?.undoManager.redo()
        moveUndoCursor(by: 1)
    }

    /// Convert a view-space tap into a selection on `editor`.
    ///
    /// Uses the committed `state.zoomScale` and `state.panOffset` — never the
    /// in-flight gesture state — so the result matches what the user sees.
    public func handleTapAt(viewPoint: CGPoint, viewSize: CGSize) {
        guard let lookup = boundsLookup else { return }
        let localPoint = Self.tapPointInDiagramCoordinates(
            viewPoint: viewPoint,
            viewSize: viewSize,
            diagramBounds: diagramBounds,
            zoomScale: state.zoomScale ?? 1,
            panOffset: state.panOffset ?? .zero
        )
        let diagramPoint = DiagramPoint(x: Double(localPoint.x), y: Double(localPoint.y))
        setSelection(lookup.element(at: diagramPoint))
    }

    // MARK: - Tap coordinate math (Phase 7)

    /// Convert a tap point in `DiagramView` view-space into diagram-space.
    ///
    /// The preview frames `DiagramView` at `diagramBounds * zoomScale` and
    /// centers it inside `viewSize`, then translates by `panOffset`. This
    /// helper inverts that transform.
    ///
    /// `nonisolated` so unit tests can call it without crossing the
    /// `@MainActor` boundary.
    nonisolated public static func tapPointInDiagramCoordinates(
        viewPoint: CGPoint,
        viewSize: CGSize,
        diagramBounds: CGRect,
        zoomScale: CGFloat,
        panOffset: CGSize
    ) -> CGPoint {
        let scaledWidth = diagramBounds.width * zoomScale
        let scaledHeight = diagramBounds.height * zoomScale
        let centerX = (viewSize.width - scaledWidth) / 2 + panOffset.width
        let centerY = (viewSize.height - scaledHeight) / 2 + panOffset.height
        let localX = (viewPoint.x - centerX) / zoomScale
        let localY = (viewPoint.y - centerY) / zoomScale
        return CGPoint(x: localX, y: localY)
    }
}

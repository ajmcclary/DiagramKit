//
//  CanvasTransform.swift
//  DiagramPlayground
//
//  Pure centering + scale + offset math shared by every zoomable canvas
//  surface (preview + visual editors). The playground frames a diagram at
//  `diagramBounds * scale`, centers it inside the host view, then translates
//  by `offset`. This type is the single source of truth for that transform
//  and its inverse, so hit-testing-under-zoom is verifiable without any UI.
//

import CoreGraphics

struct CanvasTransform: Equatable {
    /// User zoom factor (1 = actual size).
    var scale: CGFloat
    /// Pan translation applied after centering.
    var offset: CGSize

    static let minScale: CGFloat = 0.25
    static let maxScale: CGFloat = 4.0

    /// Top-left of the scaled diagram in view-space.
    func origin(diagramBounds: CGRect, viewSize: CGSize) -> CGPoint {
        let scaledWidth = diagramBounds.width * scale
        let scaledHeight = diagramBounds.height * scale
        return CGPoint(
            x: (viewSize.width - scaledWidth) / 2 + offset.width,
            y: (viewSize.height - scaledHeight) / 2 + offset.height
        )
    }

    /// Diagram-space rect → view-space rect.
    func viewRect(forDiagramBounds bounds: CGRect, diagramBounds: CGRect, viewSize: CGSize) -> CGRect {
        let o = origin(diagramBounds: diagramBounds, viewSize: viewSize)
        return CGRect(
            x: o.x + bounds.minX * scale,
            y: o.y + bounds.minY * scale,
            width: bounds.width * scale,
            height: bounds.height * scale
        )
    }

    /// View-space point → diagram-space point (inverse of `viewRect`'s origin).
    func diagramPoint(fromViewPoint point: CGPoint, diagramBounds: CGRect, viewSize: CGSize) -> CGPoint {
        let o = origin(diagramBounds: diagramBounds, viewSize: viewSize)
        return CGPoint(x: (point.x - o.x) / scale, y: (point.y - o.y) / scale)
    }

    static func clampScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minScale), maxScale)
    }

    /// Fit-to-view scale with breathing room on the tightest axis.
    static func fitScale(diagramBounds: CGRect, viewSize: CGSize, margin: CGFloat = 0.92) -> CGFloat {
        guard diagramBounds.width > 0, diagramBounds.height > 0 else { return 1 }
        let scaleX = (viewSize.width * margin) / diagramBounds.width
        let scaleY = (viewSize.height * margin) / diagramBounds.height
        return clampScale(min(scaleX, scaleY))
    }

    /// New scale for a magnification gesture value against a base scale.
    static func gestureScale(base: CGFloat, value: CGFloat) -> CGFloat {
        clampScale(base * value)
    }
}

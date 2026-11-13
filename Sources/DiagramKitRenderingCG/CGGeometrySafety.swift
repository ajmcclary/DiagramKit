// Apple-only (CoreGraphics / AppKit / UIKit). On Linux this file is empty.
#if canImport(CoreGraphics)
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import DiagramKitModel

// Rounded-rect paths built from layout geometry. A NaN or infinite rect
// reaching `NSBezierPath(roundedRect:…)` raised an Objective-C exception
// ("NaN point value") that nothing catches on the off-main rasterisation
// path, and `CGPath(roundedRect:…)` asserts when a corner radius exceeds
// half the rect. Every CG renderer goes through these two helpers instead:
// a non-finite or empty rect draws nothing, and the radius is clamped.

/// The corner radius `radius` fitted to `rect` (finite, ≥ 0, ≤ half the
/// shorter side).
func _clampedCornerRadius(_ radius: CGFloat, in rect: CGRect) -> CGFloat {
    guard radius.isFinite, radius > 0 else { return 0 }
    return min(radius, rect.width / 2, rect.height / 2)
}

func _isDrawableRect(_ rect: CGRect) -> Bool {
    rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite
        && rect.width >= 0 && rect.height >= 0
}

#if canImport(UIKit) || canImport(AppKit)
func _safeBezierRoundedRect(_ rect: CGRect, cornerRadius: CGFloat) -> BMBezierPath {
    guard _isDrawableRect(rect) else { return BMBezierPath() }
    return BMBezierPath(roundedRect: rect, cornerRadius: _clampedCornerRadius(cornerRadius, in: rect))
}
#endif

func _safeCGRoundedRect(_ rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat) -> CGPath {
    guard _isDrawableRect(rect) else { return CGMutablePath() }
    return CGPath(
        roundedRect: rect,
        cornerWidth: _clampedCornerRadius(cornerWidth, in: rect),
        cornerHeight: _clampedCornerRadius(cornerHeight, in: rect),
        transform: nil
    )
}
#endif

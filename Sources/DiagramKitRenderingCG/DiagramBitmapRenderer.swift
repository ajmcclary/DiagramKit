#if canImport(CoreGraphics)
import Foundation
import CoreGraphics
import DiagramKitCommon
import DiagramKitModel
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Shared UIKit/AppKit bitmap context setup for the package's image
/// rendering paths.
///
/// `DiagramImageRenderer` (programmatic export) and `DiagramLayer`
/// (in-view export) both need:
///   - a platform bitmap context at a target size and scale,
///   - an optional background fill from the diagram theme,
///   - the AppKit y-axis flip so the draw closure sees a y-down
///     coordinate space (matching what UIKit's
///     `UIGraphicsImageRenderer` provides natively).
///
/// Before this helper, each path duplicated that setup verbatim. Any
/// drift between them silently produced different images for the same
/// prepared diagram. Both call sites now route through `render(...)`.
///
/// Not main-actor-isolated (M-CG-4): the AppKit path is raw CGContext +
/// `NSImage(cgImage:size:)` and the UIKit path is `UIGraphicsImageRenderer`
/// — both documented thread-safe — so large bitmaps never need the UI
/// thread.
public enum DiagramBitmapRenderer {

    /// Render a bitmap by invoking `draw` against a CGContext that is:
    /// - sized to `size` in points,
    /// - scaled by `scale` (so each point is `scale` pixels),
    /// - background-filled with `theme.background` unless
    ///   `theme.transparent` is true,
    /// - y-down (UIKit-style) regardless of platform.
    public static func render(
        size: CGSize,
        scale: CGFloat,
        theme: DiagramTheme,
        draw: (CGContext) -> Void
    ) -> BMImage? {
        guard size.width > 0, size.height > 0, scale > 0 else { return nil }

        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { rendererContext in
            let ctx = rendererContext.cgContext
            if !theme.transparent {
                ctx.setFillColor(theme.background.cgColor)
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            draw(ctx)
        }
        #elseif canImport(AppKit)
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0,
              size.width <= 32767, size.height <= 32767,
              size.width * size.height <= 100_000_000 else {
            return nil
        }
        let pixelWidth = _safeInt(size.width * scale, default: 0)
        let pixelHeight = _safeInt(size.height * scale, default: 0)
        guard pixelWidth > 0, pixelHeight > 0,
              pixelWidth <= 32767 * 4, pixelHeight <= 32767 * 4,
              pixelWidth * pixelHeight <= 400_000_000,
              let ctx = CGContext(
                  data: nil,
                  width: pixelWidth,
                  height: pixelHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                              | CGBitmapInfo.byteOrder32Big.rawValue
              )
        else { return nil }

        if !theme.transparent {
            ctx.setFillColor(theme.background.cgColor)
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: pixelWidth, height: pixelHeight)))
        }

        // Raw AppKit CGContext bitmaps are y-up (origin bottom-left).
        // Renderer code assumes a y-down outer context — match what
        // UIGraphicsImageRenderer applies on UIKit/Catalyst.
        ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
        ctx.scaleBy(x: 1, y: -1)
        ctx.scaleBy(x: scale, y: scale)

        draw(ctx)

        guard let cgImage = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: size)
        #else
        return nil
        #endif
    }
}

#endif

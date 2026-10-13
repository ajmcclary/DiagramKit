// Apple-only test helper (CoreGraphics + AppKit/UIKit). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import XCTest
import Foundation
import CoreGraphics
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

/// Shared "ink pixels present" assertions for the CG renderer smoke tests.
///
/// The CG unit suites historically asserted nothing beyond "did not
/// crash" (M-T-3) — which is exactly how H1 (requirement diagrams with
/// no text) and H9 (icon/image nodes never drawn) shipped. These helpers
/// render into a readable bitmap and assert a minimum fraction of
/// non-background pixels, so a renderer that silently no-ops (text
/// drawing into a context with no NSGraphicsContext, a branch that
/// never fires) fails instead of pinning a blank image.
enum CGInkAssertions {

    /// Render `positioned` with `renderer` through the shared bitmap
    /// renderer (the same path image snapshots use), returning canonical
    /// top-down RGBA8 pixels plus dimensions.
    static func readRenderedPixels(
        _ positioned: PositionedGraph,
        renderer: DiagramRenderer = DiagramRenderer()
    ) -> (pixels: [UInt8], width: Int, height: Int)? {
        let width = max(positioned.width.rounded(.up), 1)
        let height = max(positioned.height.rounded(.up), 1)
        let renderScale: CGFloat = 2.0
        let image = DiagramBitmapRenderer.render(
            size: CGSize(width: width, height: height),
            scale: renderScale,
            theme: .default
        ) { ctx in
            renderer.render(positioned, in: ctx, bounds: CGRect(x: 0, y: 0, width: width, height: height))
        }
        guard let image else { return nil }
        #if canImport(AppKit)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cgImage = rep.cgImage else { return nil }
        #else
        guard let cgImage = image.cgImage else { return nil }
        #endif
        return readPixels(cgImage)
    }

    /// Raw RGBA8 pixel buffer read back from `context`, plus dimensions.
    static func readPixels(_ context: CGContext) -> (pixels: [UInt8], width: Int, height: Int)? {
        guard let image = context.makeImage() else { return nil }
        return readPixels(image)
    }

    /// Canonical top-down RGBA8 read of `image` (drawn into an sRGB
    /// context whose buffer rows run top-to-bottom, matching PNG order).
    static func readPixels(_ image: CGImage) -> (pixels: [UInt8], width: Int, height: Int)? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let readOK = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let readContext = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            readContext.interpolationQuality = .none
            readContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard readOK else { return nil }
        return (pixels, width, height)
    }

    /// Background reference components in the same sRGB space the pixels
    /// were read in.
    static func backgroundComponents(
        _ theme: DiagramTheme,
        colorSpace: CGColorSpace
    ) -> (r: Double, g: Double, b: Double, a: Double) {
        let bgCGColor = theme.background.cgColor.converted(
            to: colorSpace, intent: .relativeColorimetric, options: nil
        ) ?? theme.background.cgColor
        let comps = bgCGColor.components ?? [0, 0, 0, 1]
        switch bgCGColor.numberOfComponents {
        case 2:  return (Double(comps[0]), Double(comps[0]), Double(comps[0]), Double(comps[1]))
        default: return (Double(comps[0]), Double(comps[1]), Double(comps[2]), Double(comps[3]))
        }
    }

    private static func isInk(
        _ r: Double, _ g: Double, _ b: Double, _ a: Double,
        background: (r: Double, g: Double, b: Double, a: Double),
        tolerance: Double
    ) -> Bool {
        abs(r - background.r) > tolerance || abs(g - background.g) > tolerance
            || abs(b - background.b) > tolerance || abs(a - background.a) > tolerance
    }

    /// Fraction of pixels that differ from the theme background by more
    /// than `tolerance` (per channel, 0–255 scale).
    static func inkFraction(
        in context: CGContext,
        theme: DiagramTheme = .default,
        tolerance: UInt8 = 8
    ) -> Double {
        guard let read = readPixels(context) else { return 0 }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bg = backgroundComponents(theme, colorSpace: colorSpace)
        let tol = Double(tolerance)
        var ink = 0
        var i = 0
        while i < read.pixels.count {
            let r = Double(read.pixels[i]), g = Double(read.pixels[i + 1])
            let b = Double(read.pixels[i + 2]), a = Double(read.pixels[i + 3])
            if isInk(r, g, b, a, background: bg, tolerance: tol) {
                ink += 1
            }
            i += 4
        }
        return Double(ink) / Double(read.width * read.height)
    }

    /// Count ink pixels inside `rect` (in PIXEL coordinates, y from the
    /// top — the canonical read is top-down, so no mirror is needed).
    static func inkPixelCount(
        pixels: (pixels: [UInt8], width: Int, height: Int),
        within rect: CGRect,
        theme: DiagramTheme = .default,
        tolerance: UInt8 = 8
    ) -> Int {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bg = backgroundComponents(theme, colorSpace: colorSpace)
        let tol = Double(tolerance)
        var count = 0
        let minY = max(Int(rect.minY), 0)
        let maxY = min(Int(rect.maxY), pixels.height - 1)
        let minX = max(Int(rect.minX), 0)
        let maxX = min(Int(rect.maxX), pixels.width - 1)
        guard minY <= maxY, minX <= maxX else { return 0 }
        for row in minY...maxY {
            for col in minX...maxX {
                let i = (row * pixels.width + col) * 4
                let r = Double(pixels.pixels[i]), g = Double(pixels.pixels[i + 1])
                let b = Double(pixels.pixels[i + 2]), a = Double(pixels.pixels[i + 3])
                if isInk(r, g, b, a, background: bg, tolerance: tol) {
                    count += 1
                }
            }
        }
        return count
    }

    /// Count DARK pixels inside `rect` (pixel coordinates, y from top).
    /// Box interiors carry a surface fill that differs from the theme
    /// background, so "differs from background" is vacuous there; text and
    /// glyph ink is dark-on-light, so a luminance cutoff is what actually
    /// detects it.
    static func darkPixelCount(
        pixels: (pixels: [UInt8], width: Int, height: Int),
        within rect: CGRect,
        maxLuminance: Double = 0.55
    ) -> Int {
        var count = 0
        let minY = max(Int(rect.minY), 0)
        let maxY = min(Int(rect.maxY), pixels.height - 1)
        let minX = max(Int(rect.minX), 0)
        let maxX = min(Int(rect.maxX), pixels.width - 1)
        guard minY <= maxY, minX <= maxX else { return 0 }
        for row in minY...maxY {
            for col in minX...maxX {
                let i = (row * pixels.width + col) * 4
                let a = Double(pixels.pixels[i + 3]) / 255.0
                guard a > 0.5 else { continue }
                let r = Double(pixels.pixels[i]) / 255.0
                let g = Double(pixels.pixels[i + 1]) / 255.0
                let b = Double(pixels.pixels[i + 2]) / 255.0
                let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
                if luminance < maxLuminance {
                    count += 1
                }
            }
        }
        return count
    }

    /// Count ink pixels inside `rect` (in diagram coordinates, y from the
    /// top of the rendered content). Raw CGBitmapContext buffers have an
    /// implementation-defined row order relative to the render, so a
    /// pixel counts when its point OR its vertical mirror falls in
    /// `rect` — the union is orientation-agnostic, which is all an ink
    /// presence check needs.
    static func inkPixelCount(
        in context: CGContext,
        within rect: CGRect,
        theme: DiagramTheme = .default,
        tolerance: UInt8 = 8
    ) -> Int {
        guard let read = readPixels(context) else { return 0 }
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bg = backgroundComponents(theme, colorSpace: colorSpace)
        let tol = Double(tolerance)
        let width = read.width
        let height = read.height
        var count = 0
        for row in 0..<height {
            for col in 0..<width {
                let p1 = CGPoint(x: col, y: row)
                let p2 = CGPoint(x: col, y: height - 1 - row)
                guard rect.contains(p1) || rect.contains(p2) else { continue }
                let i = (row * width + col) * 4
                let r = Double(read.pixels[i]), g = Double(read.pixels[i + 1])
                let b = Double(read.pixels[i + 2]), a = Double(read.pixels[i + 3])
                if isInk(r, g, b, a, background: bg, tolerance: tol) {
                    count += 1
                }
            }
        }
        return count
    }

    /// Render `positioned` with `renderer` into a fresh bitmap context
    /// sized to the layout output.
    static func makeRenderedContext(
        _ positioned: PositionedGraph,
        renderer: DiagramRenderer = DiagramRenderer()
    ) -> CGContext? {
        let width = max(Int(positioned.width.rounded(.up)), 1)
        let height = max(Int(positioned.height.rounded(.up)), 1)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        renderer.render(positioned, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))
        return context
    }

    /// Assert a rendered context carries at least `minFraction` non-background
    /// pixels (text/shape presence; robust across diagram scales).
    static func assertInk(
        in context: CGContext,
        theme: DiagramTheme = .default,
        minFraction: Double = 0.01,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let fraction = inkFraction(in: context, theme: theme)
        XCTAssertGreaterThanOrEqual(
            fraction,
            minFraction,
            "expected ≥ \(Int(minFraction * 100))% non-background ink pixels, got \(String(format: "%.2f", fraction * 100))% — renderer drew nothing (or background only)",
            file: file,
            line: line
        )
    }
}
#endif

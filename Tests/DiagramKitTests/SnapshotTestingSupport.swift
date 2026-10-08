#if os(macOS)
#if canImport(AppKit)
import AppKit
#endif
import Foundation
#if canImport(ImageIO)
import ImageIO
#endif
import SnapshotTesting
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
import XCTest

/// SnapshotTesting's perceptual comparator passes a `CGRect` to
/// `kCIInputExtentKey`. macOS 27 requires the documented `CIVector` value and
/// raises an Objective-C exception before Swift can recover. Keep the existing
/// perceptual tolerance on earlier systems and retain a measured raw-pixel
/// tolerance on macOS 27 until the pinned fork adopts the Core Image fix.
func snapshotPixelPrecision(
    macOSMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
) -> Float {
    macOSMajorVersion >= 27 ? 0.97 : 0.99
}

func snapshotPerceptualPrecision(
    macOSMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
) -> Float {
    macOSMajorVersion >= 27 ? 1 : 0.98
}

// MARK: - Display-scale-independent image snapshots

extension Snapshotting where Value == NSImage, Format == CGImage {
    /// Image snapshots that compare the image's native pixels.
    ///
    /// SnapshotTesting's `.image` strategy for `NSImage` reads pixels through
    /// `NSImage.cgImage(forProposedRect: nil, …)` when both recording and
    /// comparing, and that call rasterizes at the *current display's* backing
    /// scale. References recorded on a Retina Mac (2x) therefore never match on
    /// a headless CI runner (1x display), whatever the renderer did. This
    /// strategy takes the rendered bitmap at its native size and encodes /
    /// decodes PNG with ImageIO, so no display is consulted.
    ///
    /// Matches `.image(precision:perceptualPrecision: 1)`: the new image is
    /// PNG round-tripped like the reference, then up to `1 - precision` of
    /// the RGBA bytes may differ.
    static func nativePixels(precision: Float) -> Snapshotting {
        Snapshotting<CGImage, CGImage>(pathExtension: "png", diffing: .nativePixels(precision: precision))
            .pullback { image in
                guard let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let cgImage = rep.cgImage else {
                    preconditionFailure("rendered NSImage has no bitmap representation")
                }
                return cgImage
            }
    }
}

extension Diffing where Value == CGImage {
    static func nativePixels(precision: Float) -> Diffing {
        Diffing(
            toData: { _pngData($0) },
            fromData: { data in
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    preconditionFailure("snapshot reference is not a decodable image")
                }
                return image
            },
            diff: { old, new in
                _compareNativePixels(old, new, precision: precision).map { ($0, []) }
            }
        )
    }
}

private func _pngData(_ image: CGImage) -> Data {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data as CFMutableData, UTType.png.identifier as CFString, 1, nil
    ) else {
        preconditionFailure("could not create a PNG encoder")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        preconditionFailure("could not encode PNG")
    }
    return data as Data
}

/// RGBA8 premultiplied-last bytes in sRGB, `width * 4` bytes per row, so two
/// images compare byte-for-byte regardless of their source layouts.
private func _canonicalRGBA(_ image: CGImage) -> [UInt8]? {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    return drawn ? bytes : nil
}

private func _compareNativePixels(_ old: CGImage, _ new: CGImage, precision: Float) -> String? {
    guard old.width == new.width, old.height == new.height else {
        return "Newly-taken snapshot (\(new.width)×\(new.height) px) does not match reference (\(old.width)×\(old.height) px)."
    }
    // Round-trip the new image through the same PNG encoder as the reference.
    guard let source = CGImageSourceCreateWithData(_pngData(new) as CFData, nil),
          let newer = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let oldBytes = _canonicalRGBA(old),
          let newBytes = _canonicalRGBA(newer) else {
        return "Snapshot pixel data could not be loaded."
    }
    if oldBytes == newBytes { return nil }
    if precision >= 1 { return "Newly-taken snapshot does not match reference." }
    var differentByteCount = 0
    var index = 0
    while index < oldBytes.count {
        if oldBytes[index] != newBytes[index] { differentByteCount += 1 }
        index += 1
    }
    let threshold = Int((1 - precision) * Float(oldBytes.count))
    guard differentByteCount > threshold else { return nil }
    let actual = 1 - Float(differentByteCount) / Float(oldBytes.count)
    return "Actual image precision \(actual) is less than required \(precision)"
}
#endif

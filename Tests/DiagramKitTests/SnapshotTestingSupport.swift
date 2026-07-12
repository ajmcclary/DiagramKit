#if os(macOS)
import Foundation

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
#endif

// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
// Helper to read the bundled VERSION resource. Lives in DiagramKitRenderingCG
// because the Resources/ directory is owned by this target (font bundles +
// VERSION are co-located).

import Foundation

public enum DiagramKitVersion {
    /// Library version. Reads `VERSION` from `DiagramKitRenderingCG.bundle`,
    /// falling back to a hardcoded default if the resource is missing.
    public static let current: String = {
        if let url = Bundle.module.url(forResource: "VERSION", withExtension: nil),
           let v = try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !v.isEmpty {
            return v
        }
        return "0.1.1"
    }()
}
#endif

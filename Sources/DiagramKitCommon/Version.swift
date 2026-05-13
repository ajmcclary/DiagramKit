import Foundation

/// Library version. Reads the `VERSION` resource bundled with this target
/// (Linux + Apple). Lives in `DiagramKitCommon` so every platform — including
/// the Linux build that has no access to the `DiagramKitRenderingCG` font
/// bundle — sees the same string.
public enum DiagramKitVersion {
    public static let current: String = {
        if let url = Bundle.module.url(forResource: "VERSION", withExtension: nil),
           let v = try? String(contentsOf: url, encoding: .utf8)
                            .trimmingCharacters(in: .whitespacesAndNewlines),
           !v.isEmpty {
            return v
        }
        return "0.0.0-unknown"
    }()
}

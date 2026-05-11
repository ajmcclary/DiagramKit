import Foundation
import DiagramKitCommon
import DiagramKitModel

enum SVGIDGenerator {
    static func id(for source: String, policy: SVGIDPolicy) -> String {
        switch policy {
        case .unique:
            return UUID().uuidString
        case .stable:
            return StableID.derive(from: source)
        }
    }
}

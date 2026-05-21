import Foundation
import DiagramKitCommon

/// Detects c4 family signal in DOT source.
///
/// Mirrors `D2C4Probe`: marker-forced family override or any `c4-*`
/// recovery marker present.
enum DOTC4Probe {
    static func detectsC4(_ source: String) -> Bool {
        let scan = DOTRecoveryMarker.scanner.scan(source: source)
        for marker in scan.markers {
            switch marker.kind {
            case .family(let name) where name == "c4":
                return true
            case .c4DiagramKind, .c4ShapeKind, .c4External, .c4Technology,
                 .c4Description, .c4Sprite, .c4Tag, .c4Link, .c4BoundaryKind,
                 .c4RelKind, .c4Color:
                return true
            default:
                continue
            }
        }
        return false
    }
}

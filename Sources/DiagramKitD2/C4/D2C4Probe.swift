import Foundation
import DiagramKitCommon

/// Detects c4 family signal in D2 source.
///
/// Two recognition paths:
/// - **Marker-forced family override:** `# diagramkit:family=c4` anywhere
///   in the source.
/// - **Structural fallback:** any `c4-*` recovery marker present
///   (`c4-diagram-kind`, `c4-shape-kind`, etc.). A c4 source with no
///   markers and no explicit family hint cannot be detected and falls
///   through to the next probe.
enum D2C4Probe {
    static func detectsC4(_ source: String) -> Bool {
        let scan = D2RecoveryMarker.scanner.scan(source: source)
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

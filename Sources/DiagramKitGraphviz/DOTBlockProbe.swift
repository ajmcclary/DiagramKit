import Foundation
import DiagramKitCommon

/// Detects whether DOT source should be mapped as a block diagram.
///
/// **Marker-presence detection only.** Block has no native DOT
/// representation; all block-specific information travels via
/// comment-encoded `block-*` recovery markers. Detection therefore
/// reduces to: the marker-forced `family=block` keyword (handled by
/// the importer upstream) OR the presence of any `block-*` marker.
/// Mirrors the Wave G c4 marker-presence detection pattern.
public enum DOTBlockProbe {
    public static func detectsBlock(
        markers: [RecoveryMarker<DOTRecoveryMarker.Kind>]
    ) -> Bool {
        for marker in markers {
            switch marker.kind {
            case .blockCols, .blockWidth, .blockShapeFallback,
                 .blockArrowDir, .blockSpace, .blockEdgeAttrs,
                 .blockClassDef, .blockClassApply, .blockStyle,
                 .blockAccTitle, .blockAccDescr:
                return true
            default:
                continue
            }
        }
        return false
    }
}

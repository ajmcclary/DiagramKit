import Foundation
import DiagramKitCommon

/// Detects whether D2 source should be mapped as a block diagram.
///
/// **Marker-presence detection only.** Block has no native D2
/// representation (D2 has no `block` keyword and `grid-rows` /
/// `grid-columns` attributes are dropped at parse time with a
/// `featureDropped(.slotUnsupported, …)` diagnostic). All block
/// information travels via comment-encoded `block-*` recovery
/// markers. Detection therefore reduces to: the marker-forced
/// `family=block` keyword (handled by the importer upstream) OR
/// the presence of any `block-*` marker in the source.
///
/// This mirrors the Wave G c4 detection strategy where any
/// `c4-*` marker presence forces c4 family.
public enum D2BlockProbe {

    /// Returns `true` if the source contains any `block-*` recovery
    /// marker. The importer also forces block family on the
    /// `# diagramkit:family=block` marker via the existing
    /// `markerFamily` mechanism; this probe is the structural
    /// fallback for sources that include block markers but omit
    /// the family directive.
    public static func detectsBlock(
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
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

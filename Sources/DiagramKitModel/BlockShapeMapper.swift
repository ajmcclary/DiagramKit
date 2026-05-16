import Foundation

/// Canonical mapping from `BlockNodeType` to the shape-name string used by
/// `ShapeSpecRegistry`. Block SVG and CG renderers consult this single
/// source of truth so they cannot drift in shape selection (audit D2).
///
/// The returned names are the primary `ShapeSpec` aliases (`"rectangle"`,
/// `"parallelogram"`, `"asymmetric"`, …) so the resolved spec is the same
/// one the flowchart/state pipelines use. `BlockNodeType` cases that are
/// not real shapes (`.blockArrow`, `.composite`, `.space`, `.columnSetting`,
/// `.edge`) fall back to `"rectangle"` — callers handle those structural
/// cases before reaching the mapper.
public enum BlockShapeMapper {
    public static func shapeSpecName(for type: BlockNodeType) -> String {
        switch type {
        case .square, .na:    return "rectangle"
        case .round:          return "rounded"
        case .circle:         return "circle"
        case .doublecircle:   return "doublecircle"
        case .diamond:        return "diamond"
        case .hexagon:        return "hexagon"
        case .stadium:        return "stadium"
        case .subroutine:     return "subroutine"
        case .cylinder:       return "cylinder"
        case .leanRight:      return "parallelogram"
        case .leanLeft:       return "parallelogram-alt"
        case .trapezoid:      return "trapezoid"
        case .invTrapezoid:   return "trapezoid-alt"
        case .rectLeftInvArrow: return "asymmetric"
        default:              return "rectangle"
        }
    }
}

import Foundation

// MARK: - Frontmatter theme-key predicates
//
// `themeVariables.*` overrides arrive flattened from the frontmatter
// parser. Per-diagram binding adapters (`FrontmatterBinding+<Diagram>`)
// guard the theme prefix and call these predicates to confirm a key is
// actually consumed by the diagram before marking `hasTheme = true`.
// That gating prevents stray override keys from creating empty default
// theme structs (see audit P2).
//
// Keep these predicates close to the binding adapters that use them;
// per-diagram inlining is fine when the key set is small. Centralise
// here only when the same set is consulted from more than one binding
// or from a non-binding caller (e.g. parsers reading `init {}`).

// MARK: - Quadrant chart theme predicate

public func _isQuadrantThemeKey(_ key: String) -> Bool {
    switch key {
    case "quadrant1Fill", "quadrant2Fill", "quadrant3Fill", "quadrant4Fill",
         "quadrant1TextFill", "quadrant2TextFill", "quadrant3TextFill", "quadrant4TextFill",
         "quadrantPointFill", "quadrantPointTextFill",
         "quadrantXAxisTextFill", "quadrantYAxisTextFill",
         "quadrantInternalBorderStrokeFill", "quadrantExternalBorderStrokeFill",
         "quadrantTitleFill":
        return true
    default:
        return false
    }
}

// MARK: - Timeline theme predicate

public func _isTimelineThemeKey(_ key: String) -> Bool {
    switch key {
    case "cScale0", "cScale1", "cScale2", "cScale3", "cScale4", "cScale5",
         "cScale6", "cScale7", "cScale8", "cScale9", "cScale10", "cScale11",
         "cScaleLabel0", "cScaleLabel1", "cScaleLabel2", "cScaleLabel3",
         "cScaleLabel4", "cScaleLabel5", "cScaleLabel6", "cScaleLabel7",
         "cScaleLabel8", "cScaleLabel9", "cScaleLabel10", "cScaleLabel11",
         "cScaleInv0", "cScaleInv1", "cScaleInv2", "cScaleInv3",
         "cScaleInv4", "cScaleInv5", "cScaleInv6", "cScaleInv7",
         "cScaleInv8", "cScaleInv9", "cScaleInv10", "cScaleInv11",
         "THEME_COLOR_LIMIT", "fontFamily", "fontSize",
         "mainBkg", "nodeBorder", "borderColorArray",
         "useGradient", "gradientStart", "gradientStop", "dropShadow":
        return true
    default:
        return false
    }
}

// MARK: - Architecture theme predicate

public func _isArchThemeKey(_ key: String) -> Bool {
    switch key {
    case "archEdgeColor", "archEdgeArrowColor", "archEdgeWidth",
         "archGroupBorderColor", "archGroupBorderWidth":
        return true
    default:
        return false
    }
}

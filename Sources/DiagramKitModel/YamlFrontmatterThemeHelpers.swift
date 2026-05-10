import Foundation

// MARK: - YAML frontmatter theme-key predicates and parsing helpers
//
// This file used to carry full `_apply<Diagram>ThemeValue` functions that
// mirrored the work now done by `FrontmatterBinding+<Diagram>` adapters.
// Those helpers were dead code — the active path delegates through the
// per-diagram bindings registered in `SourcePreprocessing._activeBindings`.
//
// Only the still-used surface remains:
//
//   - `_parseYamlStringArray` — generic helper used by `src_radar_parser`
//     and other init-directive consumers.
//   - `_isQuadrantThemeKey` / `_isTimelineThemeKey` / `_isArchThemeKey` —
//     predicates still consulted by binding adapters and other call sites.
//
// Removed dead helpers (covered by the binding adapters): the `_*ThemeSubKey`
// extractors, the `_apply*ThemeValue` mutators, and the unused
// `_is<Diagram>ThemeKey` predicates for diagrams whose binding adapter
// already gates the prefix internally (GitGraph, Pie, Radar, Treemap,
// Venn, TreeView, EventModeling).

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

// MARK: - Generic YAML helpers

/// Parse a YAML inline-array string (e.g. `[a, b, "c, d"]`) into a list.
/// Returns `nil` if `value` is not bracketed.
public func _parseYamlStringArray(_ value: String) -> [String]? {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else { return nil }

    let innerStart = trimmed.index(after: trimmed.startIndex)
    let innerEnd = trimmed.index(before: trimmed.endIndex)
    let inner = String(trimmed[innerStart..<innerEnd])
    if inner.trimmingCharacters(in: .whitespaces).isEmpty {
        return []
    }

    var items: [String] = []
    var current = ""
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false

    for ch in inner {
        if inQuote {
            current.append(ch)
            if isEscaped {
                isEscaped = false
                continue
            }
            if ch == "\\" && quoteChar == "\"" {
                isEscaped = true
                continue
            }
            if ch == quoteChar {
                inQuote = false
                quoteChar = nil
            }
            continue
        }

        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            current.append(ch)
            continue
        }

        if ch == "," {
            items.append(_unquote(current))
            current = ""
        } else {
            current.append(ch)
        }
    }

    items.append(_unquote(current))
    return items
}

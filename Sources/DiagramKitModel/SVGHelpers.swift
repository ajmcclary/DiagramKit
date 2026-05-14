// Apple-only — depends on BMColor/BMFont (UIKit/AppKit). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public func _hex(_ color: BMColor) -> String? {
    #if targetEnvironment(macCatalyst) || canImport(UIKit)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
    #elseif canImport(AppKit)
    guard let rgb = color.usingColorSpace(.deviceRGB) else { return nil }
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
    #else
    return nil
    #endif

    let ri = Int(max(0, min(255, (r * 255).rounded())))
    let gi = Int(max(0, min(255, (g * 255).rounded())))
    let bi = Int(max(0, min(255, (b * 255).rounded())))
    return String(format: "#%02X%02X%02X", ri, gi, bi)
}

public func _flattenKnownSvgTokens(_ svg: String, theme: DiagramTheme) -> String {
    let bg = _hex(theme.background) ?? "#FFFFFF"
    let fg = _hex(theme.foreground) ?? "#27272A"
    let line = _hex(theme.effectiveLine()) ?? fg
    let muted = _hex(theme.effectiveMuted()) ?? line
    let surface = _hex(theme.effectiveSurface()) ?? bg
    let border = _hex(theme.effectiveBorder()) ?? line

    let replacements: [(token: String, value: String)] = [
        ("_line", line),
        ("_arrow", line),
        ("_node-fill", surface),
        ("_node-stroke", border),
        ("_group-fill", surface),
        ("_group-hdr", surface),
        ("_inner-stroke", border),
        ("_text", fg),
        ("_text-sec", muted),
        ("_text-muted", muted),
        ("_state-end-outer", fg),
        ("_state-end-inner", bg),
    ]

    var out = svg
    for item in replacements {
        let pattern = #"var\(\s*--\#(item.token)\s*(?:,\s*[^)]*)?\)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(location: 0, length: (out as NSString).length)
            out = regex.stringByReplacingMatches(in: out, range: range, withTemplate: item.value)
        }
    }
    return out
}

public func _resolveSvgCssVariables(_ svg: String) -> String {
    // 1. Collect `--name: value` definitions from <style> blocks.
    let ns = svg as NSString
    let pattern = "--([a-zA-Z0-9_-]+)\\s*:\\s*([^;\\\"]+)"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return svg
    }
    let matches = regex.matches(in: svg, range: NSRange(location: 0, length: ns.length))
    if matches.isEmpty { return svg }

    var vars: [String: String] = [:]
    for m in matches where m.numberOfRanges >= 3 {
        let name = ns.substring(with: m.range(at: 1))
        let value = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
        vars[name] = value
    }

    // 2. Resolve `var(...)` recursively in the variable definitions.
    for _ in 0..<8 {
        var changed = false
        for (k, v) in vars {
            let rv = _resolveVarFunctions(in: v, vars: vars)
            if rv != v {
                vars[k] = rv
                changed = true
            }
        }
        if !changed { break }
    }

    // 3. Resolve `var(...)` in the main SVG body.
    var out = _resolveVarFunctions(in: svg, vars: vars)

    // 4. Flatten any remaining `color-mix(...)` and unresolved `var(...)`
    //    calls to a deterministic solid color, since AppKit/UIKit SVG
    //    rasterizers don't reliably support those CSS functions.
    out = _flattenBalancedFunction(out, name: "color-mix", replacement: "#666666")
    out = _flattenBalancedFunction(out, name: "var", replacement: "#666666")

    return out
}

/// Walk `input` and replace every `var(--name[, fallback])` call with
/// its resolved value, using a paren-counting parser so nested calls
/// in the fallback slot don't truncate at the first `)`. Iterates up
/// to 16 times so an early `var()` whose fallback expands to another
/// `var()` resolves fully in one call.
internal func _resolveVarFunctions(in input: String, vars: [String: String]) -> String {
    var out = input
    for _ in 0..<16 {
        guard let call = _findFirstBalancedFunction(in: out, name: "var") else {
            return out
        }
        // Parse the call body: `--name[, fallback]`.
        let body = String(out[call.bodyRange])
        guard let (key, fallback) = _parseVarBody(body) else {
            // Malformed call; replace with empty string to avoid an
            // infinite loop.
            out.replaceSubrange(call.callRange, with: "")
            continue
        }
        let replacement = vars[key] ?? fallback ?? ""
        out.replaceSubrange(call.callRange, with: replacement)
    }
    return out
}

/// Replace every top-level occurrence of `name(...)` with `replacement`,
/// matching parens so nested arguments don't trip up the scan.
internal func _flattenBalancedFunction(
    _ input: String,
    name: String,
    replacement: String
) -> String {
    var out = input
    while let call = _findFirstBalancedFunction(in: out, name: name) {
        out.replaceSubrange(call.callRange, with: replacement)
    }
    return out
}

internal struct _BalancedFunctionCall {
    /// Range covering `name(...)` — the function name through the
    /// matching close paren.
    var callRange: Range<String.Index>
    /// Range covering just the body inside the outermost parens.
    var bodyRange: Range<String.Index>
}

internal func _findFirstBalancedFunction(
    in source: String,
    name: String
) -> _BalancedFunctionCall? {
    let needle = name + "("
    var searchStart = source.startIndex
    while searchStart < source.endIndex,
          let nameRange = source.range(of: needle, range: searchStart..<source.endIndex) {
        // Ensure the match is at a word boundary on the left.
        // Otherwise `foovar(--x)` would match `var(--x)` mid-identifier.
        if nameRange.lowerBound > source.startIndex {
            let before = source[source.index(before: nameRange.lowerBound)]
            if before.isLetter || before.isNumber || before == "_" || before == "-" {
                searchStart = nameRange.upperBound
                continue
            }
        }
        let bodyStart = nameRange.upperBound
        var depth = 1
        var cursor = bodyStart
        while cursor < source.endIndex {
            let ch = source[cursor]
            if ch == "(" {
                depth += 1
            } else if ch == ")" {
                depth -= 1
                if depth == 0 {
                    return _BalancedFunctionCall(
                        callRange: nameRange.lowerBound..<source.index(after: cursor),
                        bodyRange: bodyStart..<cursor
                    )
                }
            }
            cursor = source.index(after: cursor)
        }
        // Unbalanced parens — no further matches are sensible.
        return nil
    }
    return nil
}

/// Split a `var(...)` body into `(name, fallback)`. Names match
/// `--[a-zA-Z0-9_-]+`; the fallback (if present) is everything after
/// the first top-level comma.
internal func _parseVarBody(_ body: String) -> (name: String, fallback: String?)? {
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("--") else { return nil }

    // Find the first top-level comma (depth-0). Anything before is the
    // name, anything after is the fallback (which may itself contain
    // nested calls).
    var depth = 0
    var splitIndex: String.Index? = nil
    var cursor = trimmed.startIndex
    while cursor < trimmed.endIndex {
        let ch = trimmed[cursor]
        if ch == "(" {
            depth += 1
        } else if ch == ")" {
            depth -= 1
        } else if ch == "," && depth == 0 {
            splitIndex = cursor
            break
        }
        cursor = trimmed.index(after: cursor)
    }

    if let splitIndex {
        let rawName = trimmed[..<splitIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let rawFallback = trimmed[trimmed.index(after: splitIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        let name = String(rawName.dropFirst(2)) // strip leading "--"
        return (name, rawFallback.isEmpty ? nil : rawFallback)
    } else {
        let name = String(trimmed.dropFirst(2))
        return (name, nil)
    }
}
#endif

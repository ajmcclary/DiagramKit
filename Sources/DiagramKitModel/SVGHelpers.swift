// Linux-portable: SVG/geometry code shared by every platform (see PortableRenderSupport.swift).
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit) || canImport(AppKit)
public func _hex(_ color: BMColor) -> String? {
    #if canImport(UIKit)
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
#endif

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

    // Style regions only: label text that happens to read `var(--_text)`
    // is what the author wrote.
    return _transformSVGStyleRegions(svg) { region in
        var out = region
        for item in replacements {
            let pattern = #"var\(\s*--\#(item.token)\s*(?:,\s*[^)]*)?\)"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: (out as NSString).length)
                out = regex.stringByReplacingMatches(in: out, range: range, withTemplate: NSRegularExpression.escapedTemplate(for: item.value))
            }
        }
        return out
    }
}

public func _resolveSvgCssVariables(_ svg: String) -> String {
    // 1. Collect `--name: value` definitions from style scopes only — the
    //    root/element `style="…"` attributes and `<style>` blocks. Scanning
    //    the whole document would also match `--` sequences in escaped
    //    label text (e.g. `A["--foo: red"]`).
    let ns = svg as NSString
    guard let scopeRegex = try? NSRegularExpression(pattern: "style=\"([^\"]*)\"|<style[^>]*>([\\s\\S]*?)</style>"),
          let regex = try? NSRegularExpression(pattern: "--([a-zA-Z0-9_-]+)\\s*:\\s*([^;\\\"]+)") else {
        return svg
    }
    let styleText = scopeRegex.matches(in: svg, range: NSRange(location: 0, length: ns.length))
        .compactMap { m -> String? in
            if m.numberOfRanges >= 2, m.range(at: 1).location != NSNotFound {
                return ns.substring(with: m.range(at: 1))
            }
            if m.numberOfRanges >= 3, m.range(at: 2).location != NSNotFound {
                return ns.substring(with: m.range(at: 2))
            }
            return nil
        }
        .joined(separator: ";\n")
    let styleNS = styleText as NSString
    let matches = regex.matches(in: styleText, range: NSRange(location: 0, length: styleNS.length))
    if matches.isEmpty { return svg }

    var vars: [String: String] = [:]
    for m in matches where m.numberOfRanges >= 3 {
        let name = styleNS.substring(with: m.range(at: 1))
        let value = styleNS.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
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

    // 3–4. Resolve `var(...)` in the CSS-bearing parts of the document
    //    (attribute values and `<style>` text — not label text, where
    //    `use var(--bg)` is what the author wrote), then flatten any
    //    remaining `color-mix(...)` and unresolved `var(...)` calls to a
    //    deterministic solid color, since AppKit/UIKit SVG rasterizers
    //    don't reliably support those CSS functions.
    return _transformSVGStyleRegions(svg) { region in
        var value = _resolveVarFunctions(in: region, vars: vars)
        value = _flattenBalancedFunction(value, name: "color-mix", replacement: "#666666")
        return _flattenBalancedFunction(value, name: "var", replacement: "#666666")
    }
}

/// Applies `transform` to the CSS-bearing parts of an SVG document —
/// quoted attribute values inside tags and the text of `<style>` elements —
/// and copies everything else (text nodes, comments, CDATA) unchanged.
/// Regions that mention neither `var(` nor `color-mix(` are copied without
/// calling `transform`. One left-to-right pass.
internal func _transformSVGStyleRegions(_ svg: String, _ transform: (String) -> String) -> String {
    let bytes = Array(svg.utf8)
    let n = bytes.count
    var out: [UInt8] = []
    out.reserveCapacity(n)

    func starts(_ literal: String, at index: Int) -> Bool {
        let lit = Array(literal.utf8)
        guard index + lit.count <= n else { return false }
        for k in 0..<lit.count where bytes[index + k] != lit[k] { return false }
        return true
    }
    func find(_ literal: String, from index: Int) -> Int? {
        var k = index
        while k < n {
            if starts(literal, at: k) { return k }
            k += 1
        }
        return nil
    }
    func emitRegion(_ lower: Int, _ upper: Int) {
        let slice = bytes[lower..<upper]
        let text = String(decoding: slice, as: UTF8.self)
        if text.contains("var(") || text.contains("color-mix(") {
            out.append(contentsOf: Array(transform(text).utf8))
        } else {
            out.append(contentsOf: slice)
        }
    }
    /// Copies the tag starting at `start` (`<`), transforming its quoted
    /// attribute values; returns the index after its closing `>`.
    func copyTag(_ start: Int) -> Int {
        var k = start
        while k < n {
            let b = bytes[k]
            if b == UInt8(ascii: "\"") || b == UInt8(ascii: "'") {
                out.append(b)
                var close = k + 1
                while close < n, bytes[close] != b { close += 1 }
                emitRegion(k + 1, close)
                if close < n { out.append(b) }
                k = close + 1
                continue
            }
            out.append(b)
            k += 1
            if b == UInt8(ascii: ">") { return k }
        }
        return k
    }

    var i = 0
    while i < n {
        guard bytes[i] == UInt8(ascii: "<") else {
            out.append(bytes[i])
            i += 1
            continue
        }
        if starts("<!--", at: i) {
            let end = (find("-->", from: i + 4) ?? n - 3) + 3
            out.append(contentsOf: bytes[i..<min(end, n)])
            i = end
        } else if starts("<![CDATA[", at: i) {
            let end = (find("]]>", from: i + 9) ?? n - 3) + 3
            out.append(contentsOf: bytes[i..<min(end, n)])
            i = end
        } else if starts("<style", at: i), i + 6 < n,
                  bytes[i + 6] == UInt8(ascii: ">") || bytes[i + 6] == UInt8(ascii: " ") {
            i = copyTag(i)
            let close = find("</style", from: i) ?? n
            emitRegion(i, close)
            i = close
        } else {
            i = copyTag(i)
        }
    }
    return String(decoding: out, as: UTF8.self)
}

/// Replace every `var(--name[, fallback])` call in `input` with its
/// resolved value (`vars[name]`, else the fallback — itself resolved — else
/// the gray the final flatten pass would assign), in one left-to-right
/// pass with a paren-counting parser so nested calls in the fallback slot
/// don't truncate at the first `)`. The previous loop rescanned from the
/// start after each replacement and stopped after 4096: quadratic, and a
/// 1,400-node flowchart came out gray on gray.
internal func _resolveVarFunctions(in input: String, vars: [String: String], depth: Int = 0) -> String {
    guard input.contains("var(") else { return input }
    var out = ""
    out.reserveCapacity(input.utf8.count)
    var cursor = input.startIndex
    while let call = _findFirstBalancedFunction(in: input, name: "var", from: cursor) {
        out += input[cursor..<call.callRange.lowerBound]
        if let (key, fallback) = _parseVarBody(String(input[call.bodyRange])) {
            if let value = vars[key] {
                out += value
            } else if let fallback, depth < 8 {
                out += _resolveVarFunctions(in: fallback, vars: vars, depth: depth + 1)
            } else {
                // Undefined with no fallback: the same gray the final
                // flatten pass would assign (never an empty attribute).
                out += "#666666"
            }
        }
        // A malformed call is dropped.
        cursor = call.callRange.upperBound
    }
    out += input[cursor...]
    return out
}

/// Replace every top-level occurrence of `name(...)` with `replacement`,
/// matching parens so nested arguments don't trip up the scan. One pass.
internal func _flattenBalancedFunction(
    _ input: String,
    name: String,
    replacement: String
) -> String {
    guard input.contains(name + "(") else { return input }
    var out = ""
    var cursor = input.startIndex
    while let call = _findFirstBalancedFunction(in: input, name: name, from: cursor) {
        out += input[cursor..<call.callRange.lowerBound]
        out += replacement
        cursor = call.callRange.upperBound
    }
    out += input[cursor...]
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
    name: String,
    from start: String.Index? = nil
) -> _BalancedFunctionCall? {
    let needle = name + "("
    var searchStart = start ?? source.startIndex
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

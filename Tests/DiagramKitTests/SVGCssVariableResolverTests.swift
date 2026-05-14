#if canImport(UIKit) || canImport(AppKit)
import Testing
@testable import DiagramKitModel

/// REVIEW.md §1 (SVG color-mix resolver). The previous
/// `_resolveSvgCssVariables` used `[^)]+` regex patterns that stopped
/// at the first close-paren, so nested calls like
/// `var(--muted, color-mix(in srgb, var(--fg) 40%, var(--bg)))`
/// produced malformed `stroke="#27272A 40%, #FFFFFF))"` strings.
///
/// The paren-counting walker is unit-tested directly so future
/// regressions are localized here rather than surfaced as a 422-file
/// snapshot rebaseline event.
@Suite struct SVGCssVariableResolverTests {

    @Test("var(--name) with defined value resolves")
    func varWithDefinedValue() {
        let svg = """
        <svg><style>:root { --fg: #FF0000; }</style>\
        <rect fill="var(--fg)"/></svg>
        """
        let out = _resolveSvgCssVariables(svg)
        #expect(out.contains(##"fill="#FF0000""##))
        #expect(!out.contains("var("))
    }

    @Test("var(--name) with undefined name AND fallback resolves to fallback")
    func varWithFallback() {
        let svg = """
        <svg><style>:root { --fg: #FF0000; }</style>\
        <rect fill="var(--undefined, #00FF00)"/></svg>
        """
        let out = _resolveSvgCssVariables(svg)
        #expect(out.contains(##"fill="#00FF00""##))
    }

    @Test("var(--name) with nested var() fallback resolves both levels")
    func nestedVarFallback() {
        let svg = """
        <svg><style>:root { --fg: #FF0000; --bg: #FFFFFF; }</style>\
        <rect fill="var(--undefined, var(--fg))"/></svg>
        """
        let out = _resolveSvgCssVariables(svg)
        #expect(out.contains(##"fill="#FF0000""##))
        #expect(!out.contains("var("))
    }

    @Test("color-mix() flattens to placeholder even when nested var() args are present")
    func colorMixNestedVars() {
        let svg = """
        <svg><style>:root { --fg: #FF0000; --bg: #FFFFFF; }</style>\
        <rect stroke="color-mix(in srgb, var(--fg) 40%, var(--bg))"/></svg>
        """
        let out = _resolveSvgCssVariables(svg)
        #expect(out.contains(##"stroke="#666666""##))
        #expect(!out.contains("color-mix("))
        #expect(!out.contains("40%"))
    }

    @Test("var(--name, color-mix(...)) where var resolves does NOT touch the fallback")
    func varResolvesWithoutEvaluatingFallback() {
        let svg = """
        <svg><style>:root { --muted: #999999; --fg: #FF0000; --bg: #FFFFFF; }</style>\
        <rect fill="var(--muted, color-mix(in srgb, var(--fg) 40%, var(--bg)))"/></svg>
        """
        let out = _resolveSvgCssVariables(svg)
        #expect(out.contains(##"fill="#999999""##))
        #expect(!out.contains("color-mix("))
        #expect(!out.contains("var("))
    }

    @Test("var(--name, color-mix(...)) where var is undefined uses color-mix fallback (then flattens)")
    func varFallsBackToColorMixThenFlattens() {
        let svg = """
        <svg><style>:root { --fg: #FF0000; --bg: #FFFFFF; }</style>\
        <rect fill="var(--undefined, color-mix(in srgb, var(--fg) 40%, var(--bg)))"/></svg>
        """
        let out = _resolveSvgCssVariables(svg)
        // After var() resolves to its fallback (color-mix call),
        // color-mix gets flattened to #666666.
        #expect(out.contains(##"fill="#666666""##))
        #expect(!out.contains("color-mix("))
        // Critical regression check: the bug REVIEW described produced
        // `stroke="#27272A 40%, #FFFFFF))"` strings; verify no literal
        // percent leak.
        #expect(!out.contains("40%"))
        #expect(!out.contains("))"))
    }

    @Test("Multiple var() calls on the same line each resolve")
    func multipleVarsOnLine() {
        let svg = """
        <svg><style>:root { --fg: #111111; --bg: #222222; }</style>\
        <rect fill="var(--fg)" stroke="var(--bg)"/></svg>
        """
        let out = _resolveSvgCssVariables(svg)
        #expect(out.contains(##"fill="#111111""##))
        #expect(out.contains(##"stroke="#222222""##))
    }

    @Test("Word-boundary discipline: 'foovar(--x)' is not a var() call")
    func wordBoundary() {
        // The function-name search must not match `var` inside another
        // identifier. We can't easily wire `foovar(--x)` past the body
        // parser, but we can verify a benign identifier is left alone.
        let svg = """
        <svg><text>foovar foo_var</text></svg>
        """
        let out = _resolveSvgCssVariables(svg)
        #expect(out.contains("foovar"))
        #expect(out.contains("foo_var"))
    }

    @Test("Unresolved var() with no fallback flattens to placeholder")
    func unresolvedVarFlattens() {
        // No `--missing` definition. With no fallback, `var(--missing)`
        // resolves to empty (per the resolver loop), then the
        // post-pass `_flattenBalancedFunction(out, name: "var", …)`
        // catches anything that survived (e.g. malformed input).
        let svg = """
        <svg><style>:root { --fg: #FF0000; }</style>\
        <rect fill="var(--missing)"/></svg>
        """
        let out = _resolveSvgCssVariables(svg)
        // Either fully empty (resolver path) or flattened to #666666
        // — both are acceptable "no longer var()" outcomes.
        #expect(!out.contains("var(--missing)"))
    }

    @Test("Empty SVG with no <style> block is passed through")
    func emptyVars() {
        let svg = ##"<svg><rect fill="#000"/></svg>"##
        let out = _resolveSvgCssVariables(svg)
        #expect(out == svg)
    }

    // MARK: - Direct walker tests

    @Test("_findFirstBalancedFunction matches name(...) and tracks nested parens")
    func balancedFunctionWalker() {
        let s = "before color-mix(in srgb, var(--fg) 40%, var(--bg)) after"
        let match = _findFirstBalancedFunction(in: s, name: "color-mix")
        #expect(match != nil)
        if let m = match {
            #expect(String(s[m.callRange]) == "color-mix(in srgb, var(--fg) 40%, var(--bg))")
            #expect(String(s[m.bodyRange]) == "in srgb, var(--fg) 40%, var(--bg)")
        }
    }

    @Test("_parseVarBody splits at the first top-level comma only")
    func varBodyTopLevelComma() {
        // The fallback is itself a multi-arg call. The top-level comma
        // is between `--undefined` and `color-mix(...)`, not the
        // commas inside color-mix.
        let parsed = _parseVarBody("--undefined, color-mix(in srgb, var(--fg) 40%, var(--bg))")
        #expect(parsed?.name == "undefined")
        #expect(parsed?.fallback == "color-mix(in srgb, var(--fg) 40%, var(--bg))")
    }

    @Test("_parseVarBody handles name-only (no fallback)")
    func varBodyNameOnly() {
        let parsed = _parseVarBody("--fg")
        #expect(parsed?.name == "fg")
        #expect(parsed?.fallback == nil)
    }
}
#endif

#if canImport(UIKit) || canImport(AppKit)
import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// REVIEW.md §1. Pins `Theme.effective<Token>()` math as canonical:
/// for each built-in theme, the rendered SVG must contain the hex
/// `_hex(theme.effective<Token>())` returns. This prevents the
/// "all tokens collapsed to fg" regression mode the review flagged
/// and runs in <1 s so iteration on Phase 2 fixes is fast.
final class PalettePinTests: XCTestCase {

    /// Canary diagram exercising every color role:
    ///  - node body fill (surface) and outline (border) on A and B
    ///  - edge stroke (line) and arrow head (accent)
    ///  - edge label fill (muted) and node text fill (fg)
    private static let canarySource = """
    flowchart TD
        A[Start] -->|step| B[End]
    """

    func testPalettePinAcrossThemes() async throws {
        var failures: [String] = []
        for (name, theme) in DiagramTheme.allThemes {
            let svg: String
            do {
                svg = try await DiagramEngine.renderSVG(
                    source: Self.canarySource,
                    theme: theme
                )
            } catch {
                failures.append("[\(name)] render threw: \(error)")
                continue
            }

            if let fail = palettePinFailure(svg: svg, themeName: name, theme: theme) {
                failures.append(fail)
            }
            if let fail = structuralFailure(svg: svg, themeName: name) {
                failures.append(fail)
            }
        }
        if !failures.isEmpty {
            XCTFail("palette pin failures:\n  " + failures.joined(separator: "\n  "))
        }
    }

    /// Returns nil on pass, a one-line description on first failure.
    private func palettePinFailure(svg: String, themeName: String, theme: DiagramTheme) -> String? {
        guard let line    = _hex(theme.effectiveLine())    else { return "[\(themeName)] no line hex" }
        guard let muted   = _hex(theme.effectiveMuted())   else { return "[\(themeName)] no muted hex" }
        guard let accent  = _hex(theme.effectiveAccent())  else { return "[\(themeName)] no accent hex" }
        guard let surface = _hex(theme.effectiveSurface()) else { return "[\(themeName)] no surface hex" }
        guard let border  = _hex(theme.effectiveBorder())  else { return "[\(themeName)] no border hex" }

        if !svg.contains(line)    { return "[\(themeName)] expected line=\(line) in SVG" }
        if !svg.contains(muted)   { return "[\(themeName)] expected muted=\(muted) in SVG" }
        if !svg.contains(accent)  { return "[\(themeName)] expected accent=\(accent) in SVG" }
        if !svg.contains(surface) { return "[\(themeName)] expected surface=\(surface) in SVG" }
        if !svg.contains(border)  { return "[\(themeName)] expected border=\(border) in SVG" }
        return nil
    }

    /// Returns nil on pass, a one-line description on first malformed-pattern hit.
    private func structuralFailure(svg: String, themeName: String) -> String? {
        if svg.contains("var(--") {
            return "[\(themeName)] unresolved var(--…) in SVG"
        }
        if svg.range(of: #"#[0-9A-Fa-f]{6}[^\"]*\)\)"#, options: .regularExpression) != nil {
            return "[\(themeName)] color-mix \"))\" tail after hex"
        }
        if svg.range(of: #"\bNaN\b|\bnan\b"#, options: .regularExpression) != nil {
            return "[\(themeName)] NaN substring in SVG"
        }
        if svg.contains("stroke=\"\"") || svg.contains("fill=\"\"") {
            return "[\(themeName)] empty stroke=\"\" or fill=\"\""
        }
        return nil
    }
}
#endif

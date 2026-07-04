import Testing
import SwiftUI
@testable import DiagramKitSample

@Suite struct EditorRedesignTokenTests {
    @Test func existingAppearancesStillResolve() {
        for appearance in [PlaygroundAppearance.dark, .light, .forest, .neutral] {
            let tokens = PlaygroundTokens.tokens(for: appearance)
            #expect(tokens.appearance == appearance)
            // New redesign fields are populated (not clear) — spot-check a few.
            #expect(tokens.palette.bgCard != tokens.palette.accent)
            #expect(tokens.palette.onAccent != tokens.palette.accent)
        }
    }

    @Test func zedTrekAppearancesResolveCompletePalettes() {
        let zedTrek: [PlaygroundAppearance] =
            [.zedTrekDark, .zedTrekLight, .federation, .redAlert, .sickBay, .borgCube]
        for appearance in zedTrek {
            let t = PlaygroundTokens.tokens(for: appearance)
            #expect(t.appearance == appearance)
            #expect(t.palette.accent != t.palette.bgWindow)
            #expect(t.palette.onAccent != t.palette.accent)
        }
        #expect(PlaygroundAppearance.allCases.count == 10)
        #expect(PlaygroundAppearance.zedTrekFamily.count == 6)
    }

    @Test func lcarsDarkIsTheDefault() {
        #expect(PlaygroundTokensKey.defaultValue.appearance == .zedTrekDark)
        let p = PlaygroundPalette.zedTrekDark
        #expect(p.accent == Color(hex: 0xFF9933))
        #expect(p.bgWindow == Color(hex: 0x05060A))
        #expect(p.bgSheet == Color(hex: 0x0E1421))
        #expect(p.fg1 == Color(hex: 0xF2E7D8))
    }
}

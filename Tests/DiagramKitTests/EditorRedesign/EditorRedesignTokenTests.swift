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

    // MARK: - Zed Trek family (theme × mode) — Task 1

    @Test func zedTrekThemeRoster() {
        #expect(ZedTrekTheme.allCases.count == 10)
        #expect(ZedTrekTheme.allCases.first == .lcars)
        #expect(ZedTrekTheme.lcars.isStarred)
        #expect(!ZedTrekTheme.command.isStarred)
        #expect(ZedTrekTheme.blackAlert.displayName == "Black Alert")
        #expect(ZedTrekTheme.missionControl.displayName == "Mission Control")
    }

    @Test func themeModeResolution() {
        #expect(ThemeMode.system.scheme(system: .dark) == .dark)
        #expect(ThemeMode.system.scheme(system: .light) == .light)
        #expect(ThemeMode.light.scheme(system: .dark) == .light)
        #expect(ThemeMode.dark.scheme(system: .light) == .dark)
    }

    // MARK: - Chrome palettes (Task 3)

    @Test func everyFamilyModeResolvesCompletePalette() {
        for family in ZedTrekTheme.allCases {
            for scheme in [ColorScheme.dark, .light] {
                let p = family.palette(for: scheme)
                #expect(p.accent != p.bgWindow)
                #expect(p.onAccent != p.accent)
                #expect(p.bgCard != p.accent)
                #expect(p.fg1 != p.bgApp)
            }
        }
    }

    @Test func pinnedChromePaletteValues() {
        // LCARS dark keeps the comp-exact values (default appearance).
        let lcarsDark = ZedTrekTheme.lcars.palette(for: .dark)
        #expect(lcarsDark.bgWindow == Color(hex: 0x05060A))
        #expect(lcarsDark.accent == Color(hex: 0xFF9933))
        #expect(lcarsDark.fg1 == Color(hex: 0xF2E7D8))
        #expect(lcarsDark.bgSheet == Color(hex: 0x0E1421))

        // LCARS light keeps its brand (orange) accent, not the focus-ring blue.
        #expect(ZedTrekTheme.lcars.palette(for: .light).accent == Color(hex: 0xC16E1D))

        // Black Alert dark — mapped from zed-trek.json (spec §5).
        let blackDark = ZedTrekTheme.blackAlert.palette(for: .dark)
        #expect(blackDark.bgApp == Color(hex: 0x020204))      // background
        #expect(blackDark.bgField == Color(hex: 0x010204))    // editor.background
        #expect(blackDark.accent == Color(hex: 0x7EC8DE))     // brand accent
        #expect(blackDark.fg1 == Color(hex: 0xDFE7F1))        // text
        #expect(blackDark.statusError == Color(hex: 0xFF7373))// error
    }

    // MARK: - Legacy migration (Task 5)

    @Test func legacyMigrationTable() {
        typealias P = PlaygroundChromePersistence
        #expect(P.migratedSelection(fromLegacy: "zedTrekDark") == (.lcars, .dark))
        #expect(P.migratedSelection(fromLegacy: "zedTrekLight") == (.lcars, .light))
        #expect(P.migratedSelection(fromLegacy: "federation") == (.federation, .dark))
        #expect(P.migratedSelection(fromLegacy: "redAlert") == (.redAlert, .dark))
        #expect(P.migratedSelection(fromLegacy: "sickBay") == (.sickBay, .dark))
        #expect(P.migratedSelection(fromLegacy: "borgCube") == (.borgCube, .dark))
        #expect(P.migratedSelection(fromLegacy: "light") == (.lcars, .light))
        #expect(P.migratedSelection(fromLegacy: "forest") == (.lcars, .dark))
        #expect(P.migratedSelection(fromLegacy: nil) == (.lcars, .dark))
        #expect(P.migratedSelection(fromLegacy: "garbage") == (.lcars, .dark))
    }
}

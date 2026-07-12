import Testing
import SwiftUI
import DiagramKitSampleDesignSystem
@testable import DiagramKitSample

@Suite struct EditorRedesignTokenTests {
    @Test func lcarsDarkIsTheDefault() {
        // The environment default resolves to LCARS dark (comp-exact values).
        let p = PlaygroundTokensKey.defaultValue.palette
        #expect(p.accent == Color(hex: 0xFF9933))
        #expect(p.bgWindow == Color(hex: 0x05060A))
        #expect(p.bgSheet == Color(hex: 0x111827))
        #expect(p.fg1 == Color(hex: 0xF2E7D8))
        // Same as resolving the LCARS family in the dark scheme.
        #expect(PlaygroundTokensKey.defaultValue == PlaygroundTokens(dsTheme: .lcarsDark))
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

    @Test func persistedThemesMapOneToOneToGeneratedFamilies() {
        let mapped = ZedTrekTheme.allCases.map(\.dsFamily.rawValue).sorted()
        let generated = DSThemeFamily.allCases.map(\.rawValue).sorted()

        #expect(mapped == generated)
        #expect(ZedTrekTheme.lcars.dsFamily == .lcars)
        #expect(ZedTrekTheme.blackAlert.dsFamily == .blackAlert)
        #expect(ZedTrekTheme.missionControl.dsFamily == .missionControl)
    }

    @Test func persistedModesMapToGeneratedModes() {
        #expect(ThemeMode.system.dsMode == .system)
        #expect(ThemeMode.light.dsMode == .light)
        #expect(ThemeMode.dark.dsMode == .dark)
        #expect(DSTheme.theme(family: .lcars, mode: .dark) == .lcarsDark)
    }

    // MARK: - Chrome palettes (Task 3)

    @Test func everyFamilyModeResolvesCompletePalette() {
        for family in ZedTrekTheme.allCases {
            for scheme in [ColorScheme.dark, .light] {
                let mode: DSThemeMode = scheme == .dark ? .dark : .light
                let p = PlaygroundTokens(
                    dsTheme: DSTheme.theme(family: family.dsFamily, mode: mode)
                ).palette
                #expect(p.accent != p.bgWindow)
                #expect(p.onAccent != p.accent)
                #expect(p.bgCard != p.accent)
                #expect(p.fg1 != p.bgApp)
            }
        }
    }

    @Test func pinnedChromePaletteValues() {
        // LCARS dark keeps the comp-exact values (default appearance).
        let lcarsDark = PlaygroundTokens(dsTheme: .lcarsDark).palette
        #expect(lcarsDark.bgWindow == Color(hex: 0x05060A))
        #expect(lcarsDark.accent == Color(hex: 0xFF9933))
        #expect(lcarsDark.fg1 == Color(hex: 0xF2E7D8))
        #expect(lcarsDark.bgSheet == Color(hex: 0x111827))

        // LCARS light keeps its brand (orange) accent, not the focus-ring blue.
        #expect(PlaygroundTokens(dsTheme: .lcarsLight).palette.accent == Color(hex: 0xE06600))

        // Black Alert dark — mapped from zed-trek.json (spec §5).
        let blackDark = PlaygroundTokens(dsTheme: .blackAlertDark).palette
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

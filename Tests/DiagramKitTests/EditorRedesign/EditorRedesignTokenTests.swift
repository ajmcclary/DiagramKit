import Testing
import SwiftUI
import DiagramKitSampleDesignSystem
@testable import DiagramKitSample

@Suite struct EditorRedesignTokenTests {
    @Test func lcarsDarkIsTheDefault() {
        let theme = DSTheme.lcarsDark
        #expect(theme.colors.accent.hex == "#FF9933")
        #expect(theme.colors.windowBackground.hex == "#05060A")
        #expect(theme.colors.elevatedSurfaceBackground.hex == "#111827")
        #expect(theme.colors.textPrimary.hex == "#F2E7D8")
        #expect(theme == DSTheme.theme(family: .lcars, mode: .dark))
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

    // MARK: - Generated theme colors (Task 3)

    @Test func everyFamilyModeResolvesCompleteTheme() {
        for family in ZedTrekTheme.allCases {
            for scheme in [ColorScheme.dark, .light] {
                let mode: DSThemeMode = scheme == .dark ? .dark : .light
                let colors = DSTheme.theme(family: family.dsFamily, mode: mode).colors
                #expect(colors.accent != colors.windowBackground)
                #expect(colors.onAccent != colors.accent)
                #expect(colors.surfaceBackground != colors.accent)
                #expect(colors.textPrimary != colors.windowBackground)
            }
        }
    }

    @Test func pinnedGeneratedThemeValues() {
        // LCARS dark keeps the comp-exact values (default appearance).
        let lcarsDark = DSTheme.lcarsDark.colors
        #expect(lcarsDark.windowBackground.hex == "#05060A")
        #expect(lcarsDark.accent.hex == "#FF9933")
        #expect(lcarsDark.textPrimary.hex == "#F2E7D8")
        #expect(lcarsDark.elevatedSurfaceBackground.hex == "#111827")

        // LCARS light keeps its brand (orange) accent, not the focus-ring blue.
        #expect(DSTheme.lcarsLight.colors.accent.hex == "#E06600")

        // Black Alert dark — mapped from zed-trek.json (spec §5).
        let blackDark = DSTheme.blackAlertDark.colors
        #expect(blackDark.windowBackground.hex == "#020204")
        #expect(blackDark.editorBackground.hex == "#010204")
        #expect(blackDark.accent.hex == "#7EC8DE")
        #expect(blackDark.textPrimary.hex == "#DFE7F1")
        #expect(blackDark.error.hex == "#FF7373")
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

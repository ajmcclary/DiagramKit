import Testing
import SwiftUI
import DesignKitThemes
@testable import DiagramKitSample

@Suite struct EditorRedesignTokenTests {
    @Test func lcarsDarkIsTheDefault() {
        let theme = Theme.lcarsDark
        #expect(theme.colors.accent.hexString == "#FF9933")
        #expect(theme.colors.windowBackground.hexString == "#05060A")
        // Canonical (CodeEditorPlugin zed-trek.json) value; DiagramKit's
        // drifted copy had #111827.
        #expect(theme.colors.elevatedSurfaceBackground.hexString == "#1D2A43")
        #expect(theme.colors.textPrimary.hexString == "#F2E7D8")
        #expect(theme == Theme.Family.lcars.theme(for: .dark))
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
        // DesignKit carries 12 families (adds classic + lcarsHighContrast);
        // the picker's 10 Zed Trek families must map into them 1:1.
        let mapped = ZedTrekTheme.allCases.map(\.dsFamily)
        #expect(Set(mapped).count == ZedTrekTheme.allCases.count)
        #expect(Set(mapped).isSubset(of: Set(Theme.Family.allCases)))
        #expect(ZedTrekTheme.lcars.dsFamily == .lcars)
        #expect(ZedTrekTheme.blackAlert.dsFamily == .blackAlert)
        #expect(ZedTrekTheme.missionControl.dsFamily == .missionControl)
    }

    @Test func persistedModesMapToGeneratedModes() {
        #expect(ThemeMode.system.dsMode == .system)
        #expect(ThemeMode.light.dsMode == .light)
        #expect(ThemeMode.dark.dsMode == .dark)
        #expect(Theme.Family.lcars.theme(for: .dark) == .lcarsDark)
    }

    // MARK: - Generated theme colors (Task 3)

    @Test func everyFamilyModeResolvesCompleteTheme() {
        for family in ZedTrekTheme.allCases {
            for scheme in [ColorScheme.dark, .light] {
                let appearance: Theme.Appearance = scheme == .dark ? .dark : .light
                let colors = family.dsFamily.theme(for: appearance).colors
                #expect(colors.accent != colors.windowBackground)
                #expect(colors.onAccent != colors.accent)
                #expect(colors.surfaceBackground != colors.accent)
                #expect(colors.textPrimary != colors.windowBackground)
            }
        }
    }

    @Test func pinnedGeneratedThemeValues() {
        // LCARS dark keeps the comp-exact values (default appearance).
        let lcarsDark = Theme.lcarsDark.colors
        #expect(lcarsDark.windowBackground.hexString == "#05060A")
        #expect(lcarsDark.accent.hexString == "#FF9933")
        #expect(lcarsDark.textPrimary.hexString == "#F2E7D8")
        #expect(lcarsDark.elevatedSurfaceBackground.hexString == "#1D2A43")  // canonical; was #111827 in the drifted copy

        // LCARS light keeps its brand (orange) accent, not the focus-ring blue.
        #expect(Theme.lcarsLight.colors.accent.hexString == "#C16E1D")  // canonical; was #E06600 in the drifted copy

        // Black Alert dark — mapped from zed-trek.json (spec §5).
        let blackDark = Theme.blackAlertDark.colors
        #expect(blackDark.windowBackground.hexString == "#020204")
        #expect(blackDark.editorBackground.hexString == "#010204")
        #expect(blackDark.accent.hexString == "#7EC8DE")
        #expect(blackDark.textPrimary.hexString == "#DFE7F1")
        #expect(blackDark.error.hexString == "#FF7373")
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

import DesignKitThemes
@testable import DiagramKitModel
@testable import DiagramKitSample
import Testing

/// Value-equivalence + wiring contract for the DesignKit migration.
@Suite("DesignKit migration contract")
struct DesignKitMigrationContractTests {
    @Test("every ZedTrekTheme family resolves both appearances in DesignKit")
    func familiesResolve() {
        for family in ZedTrekTheme.allCases {
            let dark = family.dsFamily.theme(for: .dark)
            let light = family.dsFamily.theme(for: .light)
            #expect(dark.appearance == .dark, "\(family.rawValue)")
            #expect(light.appearance == .light, "\(family.rawValue)")
        }
    }

    @Test("canvas-follows-chrome name lookup stays aligned")
    func canvasNameSync() {
        // LiveEditorStore.syncCanvasToApp looks up canvas themes by
        // "\(displayName) Dark/Light". Pin that both sides keep those names.
        let canvasNames = Set(DiagramTheme.allThemes.map(\.name))
        for family in ZedTrekTheme.allCases {
            for suffix in ["Dark", "Light"] {
                let name = "\(family.displayName) \(suffix)"
                #expect(canvasNames.contains(name), "canvas missing \(name)")
                #expect(Theme.all.contains { $0.name == name }, "DesignKit missing \(name)")
            }
        }
    }

    @Test("spot values match the retired generated tables (Black Alert Dark)")
    func spotValues() {
        let theme = Theme.blackAlertDark
        // design.accent == icon.accent (#7EC8DE) in the retired tables.
        #expect(theme.colors.accent.hexString == "#7EC8DE")
        #expect(theme.colors.windowBackground.hexString == "#020204")
        #expect(theme.colors.textPrimary.hexString == "#DFE7F1")
        #expect(theme.colors.textSecondary.hexString == "#8E9CAD")  // canonical; was #8B99AB in the drifted copy
        #expect(theme.colors.borderFocused.hexString == "#7EC8DE")
        #expect(theme.colors.element.hexString == "#10121C")
        #expect(theme.colors.success.hexString == "#4EE6A6")
        #expect(theme.colors.value("error.background").hexString == "#341519")
        #expect(theme.colors.accents.count == 5)
    }

    @Test("bridge accessors cover the roles views actually use")
    func bridgeSurface() {
        let colors = Theme.default.colors
        _ = colors.textSecondary
        _ = colors.elementHover
        _ = colors.ghostElementActive
        _ = colors.searchMatchBackground
        _ = colors.value("editor.active_line.background")
        _ = colors.value("editor.line_number")
    }
}

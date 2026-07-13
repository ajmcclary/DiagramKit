import DesignKitThemes
@testable import DiagramKitSample
import Testing

@Suite("Design-system shell theming")
struct DSShellThemeTests {
    @Test("chrome roles are derived only from the application theme")
    func canvasThemeBoundary() {
        let dark = DSShellChromeResolution.resolve(
            theme: .blackAlertDark,
            width: .compact
        )
        let light = DSShellChromeResolution.resolve(
            theme: .blackAlertLight,
            width: .compact
        )

        #expect(dark.navigation == Theme.blackAlertDark.colors.titleBarBackground)
        #expect(dark.toolbar == Theme.blackAlertDark.colors.toolbarBackground)
        #expect(dark.panel == Theme.blackAlertDark.colors.panelBackground)
        #expect(dark.status == Theme.blackAlertDark.colors.statusBarBackground)
        #expect(dark.sheet == Theme.blackAlertDark.colors.surfaceBackground)
        #expect(dark != light)
    }

    @Test(arguments: DSShellWidth.allCases)
    func actionsRemainReachable(width: DSShellWidth) {
        let resolution = DSShellChromeResolution.resolve(
            theme: .lcarsDark,
            width: width
        )

        #expect(resolution.reachableActions.contains(.settings))
        #expect(resolution.reachableActions.contains(.inspector))
        #expect(resolution.reachableActions.contains(.export))
        #expect(resolution.reachableActions.contains(.convert))
    }

    @Test("layout changes without changing semantic chrome roles")
    func adaptiveLayout() {
        let compact = DSShellChromeResolution.resolve(theme: .lcarsDark, width: .compact)
        let regular = DSShellChromeResolution.resolve(theme: .lcarsDark, width: .regular)
        let wide = DSShellChromeResolution.resolve(theme: .lcarsDark, width: .wide)

        #expect(compact.layout == .singleColumn)
        #expect(regular.layout == .splitColumns)
        #expect(wide.layout == .splitColumns)
        #expect(!compact.showsInspectorColumn)
        #expect(regular.showsInspectorColumn)
        #expect(wide.showsInspectorColumn)
        #expect(compact.navigation == regular.navigation)
        #expect(regular.navigation == wide.navigation)
    }
}

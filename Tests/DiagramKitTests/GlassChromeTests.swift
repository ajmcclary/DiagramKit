import Testing
import SwiftUI
@testable import DiagramKitSample

@Suite("Glass chrome tint resolution")
struct GlassChromeTests {
    @Test("Toolbar tint uses the chrome token")
    func toolbarTint() {
        let p = ZedTrekTheme.lcars.palette(for: .dark)
        #expect(playgroundGlassTint(role: .toolbar, palette: p) == p.bgChrome)
    }

    @Test("HUD tint uses the accent token")
    func hudTint() {
        let p = ZedTrekTheme.lcars.palette(for: .dark)
        #expect(playgroundGlassTint(role: .hud, palette: p) == p.accent)
    }

    @Test("Popover card tint uses the panel token")
    func popoverTint() {
        let p = ZedTrekTheme.lcars.palette(for: .dark)
        #expect(playgroundGlassTint(role: .popoverCard, palette: p) == p.bgPanel)
    }
}

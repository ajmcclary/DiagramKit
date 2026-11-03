// `allThemes` / `theme(named:)` are Apple-only (BMColor); the Linux job compiles this file too.
#if canImport(AppKit) || canImport(UIKit)
import Testing
@testable import DiagramKitModel

@Suite("DiagramTheme catalog")
struct DiagramThemeCatalogTests {
    @Test func catalogIsTheSeventeenNeutralThemes() {
        #expect(DiagramTheme.allThemes.count == 17)
        #expect(DiagramTheme.allThemes.first?.name == "Zinc Light")
        #expect(DiagramTheme.theme(named: "LCARS Dark") == nil)
        #expect(DiagramTheme.theme(named: "zinc-dark") == DiagramTheme.zincDark)
        #expect(DiagramTheme.default == DiagramTheme.zincLight)
    }
}
#endif

import Testing
@testable import DiagramKit
@testable import DiagramKitModel
@testable import DiagramKitSample

@Suite struct DefaultDiagramThemeTests {
    /// The sample's default diagram theme must resolve to the dark Zed Trek
    /// palette. A name mismatch would silently fall back to zincLight
    /// (LiveEditorStore.theme: `theme(named:) ?? .default`), rendering light.
    @Test func sampleDefaultResolvesToZedTrekDark() {
        let resolved = DiagramTheme.theme(named: LiveEditorState.defaultThemeName)
        #expect(resolved != nil, "default theme name did not resolve — would fall back to light")
        #expect(resolved == DiagramTheme.zedTrekDark)
        #expect(resolved != DiagramTheme.default)
    }
}

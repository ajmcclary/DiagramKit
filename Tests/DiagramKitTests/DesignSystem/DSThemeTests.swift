import DiagramKitSampleDesignSystem
import Testing

@Suite("Generated design-system API")
struct DSThemeTests {
    @Test("all Zed Trek variants are generated")
    func variantRoster() {
        #expect(DSThemeFamily.allCases.count == 10)
        #expect(DSThemeVariant.allCases.count == 20)
        #expect(DSTheme.lcarsDark.name == "LCARS Dark")
        #expect(DSTheme.lcarsDark.colors.accent.hex == "#FF9933")
        #expect(DSThemeFamily.blackAlert.rawValue == "Black Alert")
        #expect(DSThemeVariant.lcarsDark.rawValue == "LCARS Dark")
    }

    @Test("canonical metrics are pinned")
    func metrics() {
        #expect(DSTokens.Control.switchWidth == 38)
        #expect(DSTokens.Control.switchHeight == 22)
        #expect(DSTokens.Control.switchKnob == 18)
        #expect(DSTokens.Opacity.disabled == 0.30)
        #expect(DSTokens.Interaction.pressedScale == 1)
    }

    @Test("semantic icons resolve")
    func icons() {
        #expect(DSIcon.close.systemName == "xmark")
        #expect(DSIcon.diagnostics.systemName == "exclamationmark.bubble")
    }
}

import DiagramKitSampleDesignSystem
import Testing

@Suite("Design-system primitives")
struct DSPrimitiveTests {
    @Test("pressed state changes fill without scaling")
    func pressedButton() {
        let state = DSButtonVisualState.resolve(
            role: .secondary,
            isHovered: false,
            isPressed: true,
            isFocused: false,
            isEnabled: true
        )

        #expect(state.fillRole == .elementActive)
        #expect(state.scale == 1)
        #expect(state.opacity == 1)
    }

    @Test("disabled state uses contract opacity")
    func disabledButton() {
        let state = DSButtonVisualState.resolve(
            role: .ghost,
            isHovered: true,
            isPressed: false,
            isFocused: false,
            isEnabled: false
        )

        #expect(state.opacity == 0.30)
        #expect(state.fillRole == .ghost)
        #expect(!state.showsFocusRing)
    }

    @Test("focus and hover resolve independently")
    func focusAndHover() {
        let state = DSButtonVisualState.resolve(
            role: .secondary,
            isHovered: true,
            isPressed: false,
            isFocused: true,
            isEnabled: true
        )

        #expect(state.fillRole == .elementHover)
        #expect(state.showsFocusRing)
    }

    @Test("toggle uses canonical metrics")
    func toggleMetrics() {
        #expect(DSToggleMetrics.track == .init(width: 38, height: 22))
        #expect(DSToggleMetrics.knob == 18)
        #expect(DSToggleMetrics.onKnobRole == .onAccent)
    }
}

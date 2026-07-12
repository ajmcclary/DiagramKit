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

    @Test("selected segments use the selected element role")
    func selectedSegment() {
        let state = DSSegmentVisualState.resolve(
            isSelected: true,
            isHovered: false,
            isEnabled: true
        )

        #expect(state.fillRole == .elementSelected)
        #expect(state.opacity == 1)
    }

    @Test("only popovers receive elevation")
    func elevation() {
        #expect(DSSurfaceRole.card.elevation == .none)
        #expect(DSSurfaceRole.panel.elevation == .none)
        #expect(DSSurfaceRole.tabBar.elevation == .none)
        #expect(DSSurfaceRole.titleBar.elevation == .none)
        #expect(DSSurfaceRole.toolbar.elevation == .none)
        #expect(DSSurfaceRole.statusBar.elevation == .none)
        #expect(DSSurfaceRole.popover.elevation == .popover)
    }

    @Test("reduce transparency resolves glass to opaque")
    func opaqueGlass() {
        let environment = DSResolvedEnvironment.resolve(
            theme: .lcarsDark,
            platform: .macOS,
            preferences: .init(reduceTransparency: true)
        )
        let resolution = DSGlassResolution.resolve(
            role: .popover,
            environment: environment
        )

        #expect(!resolution.usesMaterial)
        #expect(resolution.elevation == .popover)
    }

    @Test("differentiate without color adds status text")
    func differentiatedStatus() {
        let environment = DSResolvedEnvironment.resolve(
            theme: .lcarsDark,
            platform: .iOS,
            preferences: .init(differentiateWithoutColor: true)
        )
        let state = DSStatusVisualState.resolve(
            kind: .warning,
            environment: environment
        )

        #expect(state.icon == .warning)
        #expect(state.includesText)
    }
}

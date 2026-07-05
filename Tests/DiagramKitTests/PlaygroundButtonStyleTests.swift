import Testing
@testable import DiagramKitSample

@Suite("PlaygroundButtonStyle state mapping")
struct PlaygroundButtonStyleTests {
    @Test("Idle enabled is full opacity, full scale")
    func idle() {
        let s = playgroundButtonVisualState(isPressed: false, isEnabled: true)
        #expect(s.opacity == 1.0)
        #expect(s.scale == 1.0)
    }

    @Test("Pressed dips opacity and scale")
    func pressed() {
        let s = playgroundButtonVisualState(isPressed: true, isEnabled: true)
        #expect(s.opacity == 0.6)
        #expect(s.scale == 0.97)
    }

    @Test("Disabled dims regardless of press")
    func disabled() {
        let s = playgroundButtonVisualState(isPressed: false, isEnabled: false)
        #expect(s.opacity == 0.4)
        #expect(s.scale == 1.0)
    }

    @Test("Disabled wins over pressed for opacity")
    func disabledPressed() {
        let s = playgroundButtonVisualState(isPressed: true, isEnabled: false)
        #expect(s.opacity == 0.4)
    }
}

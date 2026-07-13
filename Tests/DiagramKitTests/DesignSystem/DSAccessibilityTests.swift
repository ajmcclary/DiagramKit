import DesignKitThemes
import Testing

@Suite("Design-system accessibility resolution")
struct DSAccessibilityTests {
    @Test("accessibility preferences resolve deterministic behavior")
    func preferenceResolution() {
        let resolved = DSResolvedEnvironment.resolve(
            theme: .lcarsDark,
            platform: .iOS,
            preferences: .init(
                increasedContrast: true,
                reduceMotion: true,
                differentiateWithoutColor: true,
                reduceTransparency: true
            )
        )

        #expect(resolved.minimumTarget == 44)
        #expect(resolved.motion == .reduced)
        #expect(resolved.usesOpaqueChrome)
        #expect(resolved.statusPresentation == .iconAndText)
        #expect(resolved.theme.isHighContrast)
        #expect(resolved.font(.body).usesRelativeTextStyle)
        #expect(resolved.font(.code).isMonospaced)
    }

    @Test("macOS uses dense metrics without accessibility overrides")
    func macOSDefaults() {
        let resolved = DSResolvedEnvironment.resolve(
            theme: .lcarsDark,
            platform: .macOS,
            preferences: .init()
        )

        #expect(resolved.minimumTarget == 28)
        #expect(resolved.motion == .standard)
        #expect(!resolved.usesOpaqueChrome)
        #expect(resolved.statusPresentation == .colorAndIcon)
        #expect(!resolved.theme.isHighContrast)
        #expect(!resolved.font(.body).usesRelativeTextStyle)
        #expect(resolved.font(.body).pointSize == DSTokens.Typography.body)
    }

    @Test("typography is semantic and constrained")
    func typography() {
        let environment = DSResolvedEnvironment.resolve(
            theme: .lcarsLight,
            platform: .iOS,
            preferences: .init()
        )

        #expect(environment.font(.overline).tracking == DSTokens.Typography.overlineTracking)
        #expect(environment.font(.overline).weight == .semibold)
        #expect(environment.font(.metric).isMonospaced)
        #expect(environment.font(.caption2).textStyle == .caption2)
    }
}

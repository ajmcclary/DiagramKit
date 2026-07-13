import DesignKitThemes
@testable import DiagramKitSample
import Foundation
import Testing

@Suite("Design-system accessibility resolution")
struct DSAccessibilityTests {
    @Test("accessibility preferences resolve deterministic behavior")
    func preferenceResolution() {
        let preferences = DSAccessibilityPreferences(
            increasedContrast: true,
            reduceMotion: true,
            differentiateWithoutColor: true,
            reduceTransparency: true
        )
        let resolved = DSContext.resolve(platform: .iOS, preferences: preferences)

        #expect(resolved.minimumTarget == 44)
        #expect(resolved.motion == .reduced)
        #expect(resolved.usesOpaqueChrome)
        #expect(resolved.statusPresentation == .iconAndText)
        #expect(resolved.font(.body).usesRelativeTextStyle)
        #expect(resolved.font(.code).isMonospaced)

        // Color hardening now happens in DesignKit's theme resolution.
        let hardened = Theme.lcarsDark.resolved(for: preferences.designKitPreferences)
        let bg = hardened.style.background
        #expect(WCAG.contrastRatio(hardened.style.text.muted, bg) >= 4.5)
        #expect(hardened.glass.glass.opacity == 1.0)
    }

    @Test("macOS uses dense metrics without accessibility overrides")
    func macOSDefaults() {
        let resolved = DSContext.resolve(platform: .macOS, preferences: .init())

        #expect(resolved.minimumTarget == 28)
        #expect(resolved.motion == .standard)
        #expect(!resolved.usesOpaqueChrome)
        #expect(resolved.statusPresentation == .colorAndIcon)
        #expect(!resolved.font(.body).usesRelativeTextStyle)
        #expect(resolved.font(.body).pointSize == CGFloat(Tokens.Typography.Size.bodyLG))

        // No preferences → theme resolution is the identity.
        #expect(Theme.lcarsDark.resolved(for: .none) == Theme.lcarsDark)
    }

    @Test("typography is semantic and constrained")
    func typography() {
        let environment = DSContext.resolve(platform: .iOS, preferences: .init())

        #expect(environment.font(.overline).tracking == CGFloat(Tokens.Typography.Tracking.caps))
        #expect(environment.font(.overline).weight == .semibold)
        #expect(environment.font(.metric).isMonospaced)
        #expect(environment.font(.caption2).textStyle == .caption2)
    }
}

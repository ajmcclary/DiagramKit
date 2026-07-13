import Foundation

public enum DSPlatform: Equatable, Sendable {
    case macOS
    case iOS
}

public struct DSAccessibilityPreferences: Equatable, Sendable {
    public var increasedContrast: Bool
    public var reduceMotion: Bool
    public var differentiateWithoutColor: Bool
    public var reduceTransparency: Bool

    public init(
        increasedContrast: Bool = false,
        reduceMotion: Bool = false,
        differentiateWithoutColor: Bool = false,
        reduceTransparency: Bool = false
    ) {
        self.increasedContrast = increasedContrast
        self.reduceMotion = reduceMotion
        self.differentiateWithoutColor = differentiateWithoutColor
        self.reduceTransparency = reduceTransparency
    }
}

public enum DSMotionMode: Equatable, Sendable {
    case standard
    case reduced

    public func duration(milliseconds: CGFloat) -> TimeInterval {
        self == .reduced ? 0 : TimeInterval(milliseconds / 1_000)
    }
}

public enum DSStatusPresentation: Equatable, Sendable {
    case colorAndIcon
    case iconAndText
}

public struct DSResolvedEnvironment: Equatable, Sendable {
    public let theme: DSTheme
    public let platform: DSPlatform
    public let preferences: DSAccessibilityPreferences
    public let minimumTarget: CGFloat
    public let motion: DSMotionMode
    public let usesOpaqueChrome: Bool
    public let statusPresentation: DSStatusPresentation

    public static func resolve(
        theme: DSTheme,
        platform: DSPlatform,
        preferences: DSAccessibilityPreferences
    ) -> Self {
        Self(
            theme: preferences.increasedContrast ? theme.increasedContrast : theme,
            platform: platform,
            preferences: preferences,
            minimumTarget: platform == .iOS ? DSTokens.Touch.iOS : DSTokens.Touch.macOS,
            motion: preferences.reduceMotion ? .reduced : .standard,
            usesOpaqueChrome: preferences.reduceTransparency,
            statusPresentation: preferences.differentiateWithoutColor ? .iconAndText : .colorAndIcon
        )
    }

    public func font(_ role: DSFontRole) -> DSResolvedFont {
        DSTypography.resolve(role, platform: platform)
    }
}

private extension DSTheme {
    var increasedContrast: DSTheme {
        var values = colors.values
        values["border"] = colors.borderFocused
        values["border.variant"] = colors.borderFocused
        values["text.muted"] = colors.textPrimary
        values["icon.muted"] = colors.iconPrimary
        let colors = DSThemeColors(
            accents: colors.accents,
            values: values,
            syntax: colors.syntax
        )
        return DSTheme(
            name: name,
            family: family,
            mode: mode,
            colors: colors,
            isHighContrast: true
        )
    }
}

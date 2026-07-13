import DesignKitThemes
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

    /// DesignKit equivalent — color hardening and opaque-chrome resolution
    /// happen inside `Theme.resolved(for:)`.
    var designKitPreferences: AccessibilityPreferences {
        AccessibilityPreferences(
            increaseContrast: increasedContrast,
            reduceTransparency: reduceTransparency,
            reduceMotion: reduceMotion
        )
    }
}

public enum DSMotionMode: Equatable, Sendable {
    case standard
    case reduced

    public func duration(milliseconds: CGFloat) -> TimeInterval {
        self == .reduced ? 0 : TimeInterval(milliseconds / 1_000)
    }

    /// Duration-token overload (DesignKit durations are `Duration` values).
    public func duration(_ duration: Duration) -> TimeInterval {
        guard self == .standard else { return 0 }
        return TimeInterval(duration.components.seconds)
            + TimeInterval(duration.components.attoseconds) / 1e18
    }
}

public enum DSStatusPresentation: Equatable, Sendable {
    case colorAndIcon
    case iconAndText
}

/// Platform + accessibility context that accompanies the DesignKit theme.
/// The theme itself travels in `\.designTheme` (already hardened by
/// `Theme.resolved(for:)`); this carries everything that isn't a color.
public struct DSContext: Equatable, Sendable {
    public let platform: DSPlatform
    public let preferences: DSAccessibilityPreferences
    public let minimumTarget: CGFloat
    public let motion: DSMotionMode
    public let usesOpaqueChrome: Bool
    public let statusPresentation: DSStatusPresentation

    public static func resolve(
        platform: DSPlatform,
        preferences: DSAccessibilityPreferences
    ) -> Self {
        Self(
            platform: platform,
            preferences: preferences,
            minimumTarget: platform == .iOS
                ? CGFloat(Tokens.Size.Touch.min)
                : CGFloat(Tokens.Size.Touch.minimumMacOS),
            motion: preferences.reduceMotion ? .reduced : .standard,
            usesOpaqueChrome: preferences.reduceTransparency,
            statusPresentation: preferences.differentiateWithoutColor ? .iconAndText : .colorAndIcon
        )
    }

    public func font(_ role: DSFontRole) -> DSResolvedFont {
        DSTypography.resolve(role, platform: platform)
    }
}

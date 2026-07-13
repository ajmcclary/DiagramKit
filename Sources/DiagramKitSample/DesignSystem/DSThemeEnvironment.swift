import DesignKitThemes
import SwiftUI

/// Light/dark selection for `.dsTheme`; `.system` follows `\.colorScheme`.
public enum DSThemeMode: String, CaseIterable, Hashable, Codable, Sendable {
    case system
    case dark
    case light
}

private struct DSContextKey: EnvironmentKey {
    static let defaultValue = DSContext.resolve(platform: .macOS, preferences: .init())
}

public extension EnvironmentValues {
    /// Platform + accessibility context. The theme itself lives in
    /// `\.designTheme` (DesignKit).
    var dsContext: DSContext {
        get { self[DSContextKey.self] }
        set { self[DSContextKey.self] = newValue }
    }
}

public extension View {
    func dsTheme(family: Theme.Family, mode: DSThemeMode) -> some View {
        modifier(DSThemeEnvironmentModifier(family: family, mode: mode))
    }

    func dsFont(_ role: DSFontRole) -> some View {
        modifier(DSFontModifier(role: role))
    }
}

private struct DSThemeEnvironmentModifier: ViewModifier {
    let family: Theme.Family
    let mode: DSThemeMode

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let context = DSContext.resolve(
            platform: platform,
            preferences: DSAccessibilityPreferences(
                increasedContrast: colorSchemeContrast == .increased,
                reduceMotion: reduceMotion,
                differentiateWithoutColor: differentiateWithoutColor,
                reduceTransparency: reduceTransparency
            )
        )
        content
            // `.designTheme` folds the same accessibility environment into
            // the theme (hardened colors, opaque glass) and sets `.tint`.
            .designTheme(family.theme(for: appearance))
            .environment(\.dsContext, context)
            .dynamicTypeSize(dynamicTypeSize)
    }

    private var appearance: Theme.Appearance {
        switch mode {
        case .dark: .dark
        case .light: .light
        case .system: colorScheme == .dark ? .dark : .light
        }
    }

    private var platform: DSPlatform {
        #if canImport(UIKit)
        .iOS
        #else
        .macOS
        #endif
    }
}

private struct DSFontModifier: ViewModifier {
    let role: DSFontRole
    @Environment(\.dsContext) private var context

    func body(content: Content) -> some View {
        let font = context.font(role)
        content
            .font(font.swiftUIFont)
            .tracking(font.tracking)
    }
}

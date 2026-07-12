import SwiftUI

private struct DSResolvedEnvironmentKey: EnvironmentKey {
    static let defaultValue = DSResolvedEnvironment.resolve(
        theme: .lcarsDark,
        platform: .macOS,
        preferences: .init()
    )
}

public extension EnvironmentValues {
    var dsEnvironment: DSResolvedEnvironment {
        get { self[DSResolvedEnvironmentKey.self] }
        set { self[DSResolvedEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func dsTheme(family: DSThemeFamily, mode: DSThemeMode) -> some View {
        modifier(DSThemeEnvironmentModifier(family: family, mode: mode))
    }

    func dsFont(_ role: DSFontRole) -> some View {
        modifier(DSFontModifier(role: role))
    }
}

public extension DSColorValue {
    var color: Color {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
        return Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: alpha
        )
    }
}

private struct DSThemeEnvironmentModifier: ViewModifier {
    let family: DSThemeFamily
    let mode: DSThemeMode

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let environment = DSResolvedEnvironment.resolve(
            theme: DSTheme.theme(family: family, mode: resolvedMode),
            platform: platform,
            preferences: DSAccessibilityPreferences(
                increasedContrast: colorSchemeContrast == .increased,
                reduceMotion: reduceMotion,
                differentiateWithoutColor: differentiateWithoutColor,
                reduceTransparency: reduceTransparency
            )
        )
        content
            .environment(\.dsEnvironment, environment)
            .tint(environment.theme.colors.accent.color)
            .dynamicTypeSize(dynamicTypeSize)
    }

    private var resolvedMode: DSThemeMode {
        guard mode == .system else { return mode }
        return colorScheme == .dark ? .dark : .light
    }

    private var platform: DSPlatform {
        #if os(iOS)
        .iOS
        #else
        .macOS
        #endif
    }
}

private struct DSFontModifier: ViewModifier {
    let role: DSFontRole
    @Environment(\.dsEnvironment) private var environment

    func body(content: Content) -> some View {
        let font = environment.font(role)
        content
            .font(font.swiftUIFont)
            .tracking(font.tracking)
    }
}

//
//  Environment+PlaygroundTokens.swift
//  DiagramPlayground
//
//  EnvironmentValues + view modifier for `PlaygroundTokens` so any view
//  can read chrome tokens via `@Environment(\.playgroundTokens)`.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct PlaygroundTokensKey: EnvironmentKey {
    static let defaultValue = PlaygroundTokens(dsTheme: .lcarsDark)
}

extension EnvironmentValues {
    var playgroundTokens: PlaygroundTokens {
        get { self[PlaygroundTokensKey.self] }
        set { self[PlaygroundTokensKey.self] = newValue }
    }
}

extension View {
    /// Install Zed Trek chrome tokens for a (family, mode) pair. In `.system`
    /// mode the palette follows the OS color scheme; otherwise the scheme is
    /// forced. `onEffectiveScheme` fires with the resolved scheme (used to keep
    /// the diagram canvas in sync when "Match app theme" is on).
    @available(*, deprecated, message: "Install dsTheme(family:mode:) and playgroundCompatibilityTheme during migration")
    func playgroundTheme(
        family: ZedTrekTheme,
        mode: ThemeMode,
        onEffectiveScheme: @escaping (ColorScheme) -> Void = { _ in }
    ) -> some View {
        playgroundCompatibilityTheme(
            family: family,
            mode: mode,
            onEffectiveScheme: onEffectiveScheme
        )
        .dsTheme(family: family.dsFamily, mode: mode.dsMode)
    }

    func playgroundCompatibilityTheme(
        family: ZedTrekTheme,
        mode: ThemeMode,
        onEffectiveScheme: @escaping (ColorScheme) -> Void = { _ in }
    ) -> some View {
        PlaygroundThemeHost(
            family: family,
            mode: mode,
            onEffectiveScheme: onEffectiveScheme
        ) { self }
    }
}

/// Resolves (family, mode) → chrome tokens, reading the OS color scheme so
/// `.system` mode follows the system appearance live.
struct PlaygroundThemeHost<Content: View>: View {
    let family: ZedTrekTheme
    let mode: ThemeMode
    var onEffectiveScheme: (ColorScheme) -> Void = { _ in }
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        let effective = mode.scheme(system: systemScheme)
        let dsMode: DSThemeMode = effective == .dark ? .dark : .light
        let theme = DSTheme.theme(family: family.dsFamily, mode: dsMode)
        content()
            .environment(\.playgroundTokens, PlaygroundTokens(dsTheme: theme))
            .preferredColorScheme(mode == .system ? nil : effective)
            .onChange(of: effective, initial: true) { _, newScheme in
                onEffectiveScheme(newScheme)
            }
    }
}

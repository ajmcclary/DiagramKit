//
//  Environment+PlaygroundTokens.swift
//  DiagramPlayground
//
//  EnvironmentValues + view modifier for `PlaygroundTokens` so any view
//  can read chrome tokens via `@Environment(\.playgroundTokens)`.
//

import SwiftUI

struct PlaygroundTokensKey: EnvironmentKey {
    static let defaultValue: PlaygroundTokens = .zedTrekDark
}

extension EnvironmentValues {
    var playgroundTokens: PlaygroundTokens {
        get { self[PlaygroundTokensKey.self] }
        set { self[PlaygroundTokensKey.self] = newValue }
    }
}

extension View {
    /// Install chrome tokens + matching color scheme so descendants
    /// can read `@Environment(\.playgroundTokens)`.
    func playgroundTokens(_ tokens: PlaygroundTokens) -> some View {
        environment(\.playgroundTokens, tokens)
            .preferredColorScheme(tokens.appearance.preferredColorScheme)
    }

    /// Convenience: install tokens for a named appearance.
    func playgroundAppearance(_ appearance: PlaygroundAppearance) -> some View {
        playgroundTokens(.tokens(for: appearance))
    }

    /// Install Zed Trek chrome tokens for a (family, mode) pair. In `.system`
    /// mode the palette follows the OS color scheme; otherwise the scheme is
    /// forced. `onEffectiveScheme` fires with the resolved scheme (used to keep
    /// the diagram canvas in sync when "Match app theme" is on).
    func playgroundTheme(family: ZedTrekTheme, mode: ThemeMode,
                         onEffectiveScheme: @escaping (ColorScheme) -> Void = { _ in }) -> some View {
        PlaygroundThemeHost(family: family, mode: mode, onEffectiveScheme: onEffectiveScheme) { self }
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
        content()
            .environment(\.playgroundTokens, PlaygroundTokens(family: family, scheme: effective))
            .preferredColorScheme(mode == .system ? nil : effective)
            .onChange(of: effective, initial: true) { _, newScheme in
                onEffectiveScheme(newScheme)
            }
    }
}

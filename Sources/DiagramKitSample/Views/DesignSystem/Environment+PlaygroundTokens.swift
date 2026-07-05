//
//  Environment+PlaygroundTokens.swift
//  DiagramPlayground
//
//  EnvironmentValues + view modifier for `PlaygroundTokens` so any view
//  can read chrome tokens via `@Environment(\.playgroundTokens)`.
//

import SwiftUI

struct PlaygroundTokensKey: EnvironmentKey {
    static let defaultValue = PlaygroundTokens(family: .lcars, scheme: .dark)
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

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
}

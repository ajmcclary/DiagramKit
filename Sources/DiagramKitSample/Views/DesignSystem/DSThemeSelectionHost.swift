import SwiftUI
import DiagramKitSampleDesignSystem

extension View {
    /// Installs the generated design-system theme while preserving the sample's
    /// persisted family/mode selection and canvas-follow callback.
    func dsThemeSelection(
        family: ZedTrekTheme,
        mode: ThemeMode,
        onEffectiveScheme: @escaping (ColorScheme) -> Void = { _ in }
    ) -> some View {
        DSThemeSelectionHost(
            family: family,
            mode: mode,
            onEffectiveScheme: onEffectiveScheme
        ) { self }
    }
}

private struct DSThemeSelectionHost<Content: View>: View {
    let family: ZedTrekTheme
    let mode: ThemeMode
    let onEffectiveScheme: (ColorScheme) -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        let effectiveScheme = mode.scheme(system: systemScheme)
        content()
            .dsTheme(family: family.dsFamily, mode: mode.dsMode)
            .preferredColorScheme(mode == .system ? nil : effectiveScheme)
            .onChange(of: effectiveScheme, initial: true) { _, newScheme in
                onEffectiveScheme(newScheme)
            }
    }
}

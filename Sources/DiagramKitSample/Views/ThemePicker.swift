//
//  ThemePicker.swift
//  DiagramPlayground
//
//  Theme selection UI with quick-access buttons and full menu.
//  Bound to LiveEditorStore instead of the legacy PlaygroundConfiguration.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import DiagramKitSampleDesignSystem

struct ThemePicker: View {
    let store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    /// Quick-access theme names (shown as separate buttons)
    private let quickAccessThemes = ["Zinc Light", "Dracula", "Solarized Light"]

    var body: some View {
        VStack(spacing: DSTokens.Spacing.sm) {
            // Source-pinned indicator (visual editor plan 6): a theme
            // in the diagram source's frontmatter overrides this picker.
            if let pinned = store.sourcePinnedThemeName {
                Text("Source-pinned: \(pinned)")
                    .dsFont(.caption2)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                    .help("The diagram source's frontmatter pins this theme; it overrides the app theme.")
            }

            // Quick-access theme buttons
            HStack(spacing: DSTokens.Spacing.xs) {
                ForEach(quickAccessThemes, id: \.self) { themeName in
                    if let theme = DiagramTheme.theme(named: themeName) {
                        QuickThemeButton(
                            themeName: themeName,
                            theme: theme,
                            isSelected: isThemeSelected(themeName)
                        ) {
                            store.setTheme(named: themeName)
                        }
                    }
                }
            }

            // More themes menu button
            Menu {
                ForEach(DiagramTheme.allThemes, id: \.name) { name, theme in
                    Button {
                        store.setTheme(named: name)
                    } label: {
                        HStack {
                            ThemeCircle(theme: theme, size: 24)
                            Text(name)
                            if isThemeSelected(name) {
                                Spacer()
                                DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: DSTokens.Spacing.xs) {
                    DSIconView(.theme, size: DSTokens.Icon.micro, colorRole: .muted)
                    Text("All \(DiagramTheme.allThemes.count) themes")
                        .dsFont(.badge)
                    Spacer(minLength: DSTokens.Spacing.xxs)
                    DSIconView(.disclosureDown, size: DSTokens.Icon.indicator, colorRole: .muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.ds(role: .secondary, size: .regular))
            .foregroundStyle(environment.theme.colors.textPrimary.color)
            .a11y(
                label: "All themes",
                hint: "Opens the full theme list",
                id: A11yID.Pickers.themeMenu
            )
        }
    }

    private func isThemeSelected(_ name: String) -> Bool {
        store.state.selectedThemeName == name
    }
}

struct QuickThemeButton: View {
    let themeName: String
    let theme: DiagramTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSTokens.Spacing.xs) {
                ThemeCircle(theme: theme, size: 14)
                Text(shortThemeName)
                    .dsFont(.badge)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.ds(role: isSelected ? .secondary : .ghost, size: .compact))
        .help(themeName)
    }

    private var shortThemeName: String {
        switch themeName {
        case "Zinc Light": return "Default"
        case "Solarized Light": return "Solar"
        default: return themeName
        }
    }
}

struct ThemeCircle: View {
    let theme: DiagramTheme
    let size: CGFloat
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        Circle()
            .fill(Color(theme.background))
            .frame(width: size - 2, height: size - 2)
            .overlay(
                Circle()
                    .stroke(
                        environment.theme.colors.borderVariant.color,
                        lineWidth: DSTokens.Stroke.thin
                    )
            )
    }
}

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

struct ThemePicker: View {
    let store: LiveEditorStore

    /// Quick-access theme names (shown as separate buttons)
    private let quickAccessThemes = ["Zinc Light", "Dracula", "Solarized Light"]

    var body: some View {
        VStack(spacing: 8) {
            // Source-pinned indicator (visual editor plan 6): a theme
            // in the diagram source's frontmatter overrides this picker.
            if let pinned = store.sourcePinnedThemeName {
                Text("Source-pinned: \(pinned)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .help("The diagram source's frontmatter pins this theme; it overrides the app theme.")
            }

            // Quick-access theme buttons
            HStack(spacing: 6) {
                ForEach(quickAccessThemes, id: \.self) { themeName in
                    if let theme = DiagramTheme.theme(named: themeName) {
                        QuickThemeButton(
                            themeName: themeName,
                            theme: theme,
                            isSelected: isThemeSelected(themeName),
                            currentTheme: store.theme
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
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                        .accessibilityHidden(true)
                    Text("All \(DiagramTheme.allThemes.count) themes")
                        .font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(store.theme.effectiveLine()).opacity(0.35), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(Color(store.theme.foreground))
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
    let currentTheme: DiagramTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ThemeCircle(theme: theme, size: 14)
                Text(shortThemeName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected
                        ? Color(currentTheme.effectiveAccent()).opacity(0.12)
                        : Color(currentTheme.foreground).opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        Color(currentTheme.effectiveLine()).opacity(isSelected ? 0.7 : 0.25),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(Color(currentTheme.foreground))
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

    var body: some View {
        Circle()
            .fill(Color(theme.background))
            .frame(width: size - 2, height: size - 2)
            .overlay(
                Circle()
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
            )
    }
}

//
//  ThemeSwatchPicker.swift
//  DiagramPlayground
//
//  Toolbar theme picker (visual editor plan 6): swatches for every
//  DiagramTheme, applied via frontmatter so the theme travels with
//  the source. "Default" clears the pin.
//

import SwiftUI
import DiagramKitModel
import DesignKitThemes

struct ThemeSwatchPicker: View {
    @Bindable var store: LiveEditorStore
    let dismiss: () -> Void
    @Environment(\.dsEnvironment) private var environment

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: DSTokens.Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            HStack {
                Text("Theme (saved in source)")
                    .dsFont(.headline)
                Spacer()
                Button("Default") {
                    dismiss()
                    Task { await store.applyThemeFromToolbar(named: nil) }
                }
                .buttonStyle(.ds(role: .ghost, size: .compact))
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: DSTokens.Spacing.sm) {
                    ForEach(DiagramTheme.allThemes, id: \.name) { entry in
                        swatch(name: entry.name, theme: entry.theme)
                    }
                }
            }
        }
        .padding(DSTokens.Spacing.md)
        .frame(width: 320, height: 360)
        .accessibilityIdentifier(A11yID.Visual.themePicker)
    }

    private func swatch(name: String, theme: DiagramTheme) -> some View {
        let isPinned = store.sourcePinnedThemeName == name
        return Button {
            dismiss()
            Task { await store.applyThemeFromToolbar(named: name) }
        } label: {
            VStack(spacing: DSTokens.Spacing.xxs) {
                HStack(spacing: DSTokens.Spacing.xxxs) {
                    Color(theme.background)
                    Color(theme.foreground)
                    Color(theme.effectiveAccent())
                }
                .frame(height: 22)
                .clipShape(RoundedRectangle(cornerRadius: DSTokens.Radius.xs))
                .overlay(
                    RoundedRectangle(cornerRadius: DSTokens.Radius.xs)
                        .stroke(
                            isPinned
                                ? environment.theme.colors.borderFocused.color
                                : environment.theme.colors.borderVariant.color,
                            lineWidth: isPinned ? DSTokens.Stroke.medium : DSTokens.Stroke.thin
                        )
                )
                Text(name)
                    .dsFont(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 88)
        }
        .buttonStyle(.ds(role: isPinned ? .secondary : .ghost, size: .compact))
        .help(name)
        .accessibilityIdentifier(A11yID.Visual.themeSwatch(name))
    }
}

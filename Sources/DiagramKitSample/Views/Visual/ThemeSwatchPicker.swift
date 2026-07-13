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
    @Environment(\.designTheme) private var appTheme

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: Tokens.Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
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
                LazyVGrid(columns: columns, spacing: Tokens.Spacing.sm) {
                    ForEach(DiagramTheme.allThemes, id: \.name) { entry in
                        swatch(name: entry.name, theme: entry.theme)
                    }
                }
            }
        }
        .padding(Tokens.Spacing.md)
        .frame(width: 320, height: 360)
        .accessibilityIdentifier(A11yID.Visual.themePicker)
    }

    private func swatch(name: String, theme: DiagramTheme) -> some View {
        let isPinned = store.sourcePinnedThemeName == name
        return Button {
            dismiss()
            Task { await store.applyThemeFromToolbar(named: name) }
        } label: {
            VStack(spacing: Tokens.Spacing.xxs) {
                HStack(spacing: Tokens.Spacing.xxxs) {
                    Color(theme.background)
                    Color(theme.foreground)
                    Color(theme.effectiveAccent())
                }
                .frame(height: 22)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS)
                        .stroke(
                            isPinned
                                ? appTheme.colors.borderFocused.color
                                : appTheme.colors.borderVariant.color,
                            lineWidth: isPinned ? Tokens.Shape.strokeMedium : Tokens.Shape.strokeThin
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

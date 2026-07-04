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

struct ThemeSwatchPicker: View {
    @Bindable var store: LiveEditorStore
    let dismiss: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Theme (saved in source)")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button("Default") {
                    dismiss()
                    Task { await store.applyThemeFromToolbar(named: nil) }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(DiagramTheme.allThemes, id: \.name) { entry in
                        swatch(name: entry.name, theme: entry.theme)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 320, height: 360)
        .accessibilityIdentifier(A11yID.Visual.themePicker)
    }

    private func swatch(name: String, theme: DiagramTheme) -> some View {
        let isPinned = store.sourcePinnedThemeName == name
        return Button {
            dismiss()
            Task { await store.applyThemeFromToolbar(named: name) }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Color(theme.background)
                    Color(theme.foreground)
                    Color(theme.effectiveAccent())
                }
                .frame(height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isPinned ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isPinned ? 2 : 1)
                )
                Text(name)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(width: 88)
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityIdentifier(A11yID.Visual.themeSwatch(name))
    }
}

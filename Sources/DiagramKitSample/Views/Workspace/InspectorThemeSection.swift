//
//  InspectorThemeSection.swift
//  DiagramPlayground
//
//  THEME section of the v2.1 inspector. The four chrome appearances
//  (Dark / Light / Forest / Neutral) render as SwatchTiles and write
//  to a shared @AppStorage that LiveEditorView reads to apply the
//  global PlaygroundTokens.
//
//  The existing ThemePicker (diagram-side palette) and ThemeBuilder
//  card stay available behind disclosures so the 17 DiagramTheme
//  entries remain reachable.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct InspectorThemeSection: View {
    @Bindable var store: LiveEditorStore

    @AppStorage(PlaygroundChromePersistence.appearanceKey)
    private var chromeAppearanceRaw: String = PlaygroundAppearance.dark.rawValue

    @SwiftUI.State private var showDiagramPalette = false
    @SwiftUI.State private var showThemeBuilder = false

    @Environment(\.playgroundTokens) private var tokens

    private var chromeAppearance: PlaygroundAppearance {
        PlaygroundAppearance(rawValue: chromeAppearanceRaw) ?? .dark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PlaygroundSpacing.sm) {
            SectionHeader("Theme", systemImage: "paintpalette") {
                Text("%%{init:{theme}}%%")
                    .font(PlaygroundFont.codeChip)
                    .foregroundStyle(tokens.palette.fg3)
            }
            Surface(.card, padding: PlaygroundSpacing.md) {
                VStack(alignment: .leading, spacing: PlaygroundSpacing.md) {
                    chromeTiles
                    Divider().overlay(tokens.palette.borderHairline)
                    diagramPaletteDisclosure
                    themeBuilderDisclosure
                }
            }
        }
        .accessibilityIdentifier(A11yID.Inspector.themeSection)
        .accessibilityElement(children: .contain)
    }

    private var chromeTiles: some View {
        HStack(spacing: PlaygroundSpacing.sm) {
            ForEach(PlaygroundAppearance.allCases, id: \.self) { appearance in
                let palette = PlaygroundTokens.tokens(for: appearance).palette
                SwatchTile(
                    title: appearance.displayName,
                    background: palette.bgApp,
                    swatches: [palette.accent, palette.bgSurface, palette.fg2],
                    isSelected: appearance == chromeAppearance
                ) {
                    chromeAppearanceRaw = appearance.rawValue
                }
            }
        }
    }

    @ViewBuilder
    private var diagramPaletteDisclosure: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                showDiagramPalette.toggle()
            }
        } label: {
            HStack {
                Image(systemName: showDiagramPalette ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tokens.palette.fg2)
                    .frame(width: 14)
                Text("Diagram palette")
                    .font(PlaygroundFont.body)
                    .foregroundStyle(tokens.palette.fg1)
                Spacer()
                Text(store.state.selectedThemeName)
                    .font(PlaygroundFont.badge)
                    .foregroundStyle(tokens.palette.fg3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if showDiagramPalette {
            ThemePicker(store: store)
                .padding(.leading, 16)
        }
    }

    @ViewBuilder
    private var themeBuilderDisclosure: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                showThemeBuilder.toggle()
            }
        } label: {
            HStack {
                Image(systemName: showThemeBuilder ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tokens.palette.fg2)
                    .frame(width: 14)
                Text("Edit theme")
                    .font(PlaygroundFont.body)
                    .foregroundStyle(tokens.palette.fg1)
                Spacer()
                Text("DiagramColors")
                    .font(PlaygroundFont.codeChip)
                    .foregroundStyle(tokens.palette.fg3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if showThemeBuilder {
            ThemeBuilderCard(store: store)
                .padding(.leading, 16)
        }
    }
}

// MARK: - Shared persistence keys

enum PlaygroundChromePersistence {
    static let appearanceKey = "playground.chromeAppearance"
}

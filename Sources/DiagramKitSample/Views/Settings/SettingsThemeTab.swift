//
//  SettingsThemeTab.swift
//  DiagramPlayground
//
//  Settings ▸ Theme — the six real Zed Trek appearances + diagram palette +
//  theme builder (transcription §5.4).
//

import SwiftUI
import DiagramKit

struct SettingsThemeTab: View {
    @Bindable var store: LiveEditorStore
    @AppStorage(PlaygroundChromePersistence.appearanceKey)
    private var chromeAppearanceRaw = PlaygroundAppearance.zedTrekDark.rawValue
    @State private var showThemeBuilder = false
    @Environment(\.playgroundTokens) private var tokens

    private var chromeAppearance: PlaygroundAppearance {
        PlaygroundAppearance(rawValue: chromeAppearanceRaw) ?? .zedTrekDark
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Theme",
                subtitle: "Zed Trek — \(PlaygroundAppearance.zedTrekFamily.count) variants. \(chromeAppearance.displayName) is active.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(PlaygroundAppearance.zedTrekFamily, id: \.self) { appearance in
                    let p = PlaygroundTokens.tokens(for: appearance).palette
                    ThemeSwatchCard(name: appearance.displayName, background: p.bgWindow,
                                    bars: [p.accent, p.catCyan, p.accentSecondary],
                                    isActive: appearance == chromeAppearance) {
                        chromeAppearanceRaw = appearance.rawValue
                    }
                }
            }.padding(.bottom, 18)
            SettingsGroupCard {
                MenuRow(title: "Appearance", value: "Match system") {
                    Button("Match system") {}
                    Button("Always dark") {}
                    Button("Always light") {}
                }
                MenuRow(title: "Diagram palette", value: store.state.selectedThemeName,
                        leadingSwatch: AnyView(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(colors: [tokens.palette.fg1, tokens.palette.fg3],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 12, height: 12))) {
                    ForEach(DiagramTheme.allThemes, id: \.name) { theme in
                        Button(theme.name) { store.setTheme(named: theme.name) }
                    }
                }
                Button { showThemeBuilder = true } label: {
                    HStack {
                        Text("Edit theme…").font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(tokens.palette.fg3)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showThemeBuilder) {
            ThemeBuilderCard(store: store).padding().frame(minWidth: 340, minHeight: 380)
        }
    }
}

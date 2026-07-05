//
//  SettingsThemeTab.swift
//  DiagramPlayground
//
//  Settings ▸ Theme — the 10 Zed Trek families (light/dark specimens) + a
//  Light/Dark/System mode control, plus the diagram palette + theme builder.
//

import SwiftUI
import DiagramKit

struct SettingsThemeTab: View {
    @Bindable var store: LiveEditorStore

    @AppStorage(PlaygroundChromePersistence.themeKey)
    private var familyRaw = ZedTrekTheme.lcars.rawValue
    @AppStorage(PlaygroundChromePersistence.modeKey)
    private var modeRaw = ThemeMode.dark.rawValue
    @AppStorage(PlaygroundChromePersistence.canvasFollowsKey)
    private var canvasFollows = true

    @State private var showThemeBuilder = false
    @Environment(\.playgroundTokens) private var tokens
    @Environment(\.colorScheme) private var scheme

    private var family: ZedTrekTheme { ZedTrekTheme(rawValue: familyRaw) ?? .lcars }
    private var mode: ThemeMode { ThemeMode(rawValue: modeRaw) ?? .dark }

    private var modeBinding: Binding<ThemeMode> {
        Binding(get: { mode }, set: { modeRaw = $0.rawValue })
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Theme",
                subtitle: "Zed Trek — \(ZedTrekTheme.allCases.count) themes. \(family.displayName) · \(mode.displayName).")

            SegmentedFormatControl(segments: [
                .init(value: ThemeMode.system, label: "System", systemImage: "circle.lefthalf.filled"),
                .init(value: ThemeMode.light, label: "Light", systemImage: "sun.max"),
                .init(value: ThemeMode.dark, label: "Dark", systemImage: "moon"),
            ], selection: modeBinding)
            .padding(.bottom, 14)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ZedTrekTheme.allCases, id: \.self) { theme in
                    ThemeSwatchCard(name: theme.displayName,
                                    specimen: theme.specimen(for: scheme),
                                    isStarred: theme.isStarred,
                                    isActive: theme == family) {
                        familyRaw = theme.rawValue
                    }
                }
            }
            .padding(.bottom, 18)

            SettingsGroupCard {
                ToggleRow(title: "Match app theme",
                          description: "Recolor the diagram canvas to the selected theme",
                          isOn: $canvasFollows)
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
                .disabled(canvasFollows)
                .opacity(canvasFollows ? 0.5 : 1)
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

//
//  SettingsThemeTab.swift
//  DiagramPlayground
//
//  Settings ▸ Theme — the 10 Zed Trek families (light/dark specimens) + a
//  Light/Dark/System mode control, plus the diagram palette + theme builder.
//

import SwiftUI
import DiagramKit
import DesignKitThemes

struct SettingsThemeTab: View {
    @Bindable var store: LiveEditorStore

    @AppStorage(PlaygroundChromePersistence.themeKey)
    private var familyRaw = ZedTrekTheme.lcars.rawValue
    @AppStorage(PlaygroundChromePersistence.modeKey)
    private var modeRaw = ThemeMode.dark.rawValue
    @AppStorage(PlaygroundChromePersistence.canvasFollowsKey)
    private var canvasFollows = true

    @State private var showThemeBuilder = false
    @Environment(\.designTheme) private var theme
    @Environment(\.colorScheme) private var scheme

    private var family: ZedTrekTheme { ZedTrekTheme(rawValue: familyRaw) ?? .lcars }
    private var mode: ThemeMode { ThemeMode(rawValue: modeRaw) ?? .dark }

    private var modeBinding: Binding<ThemeMode> {
        Binding(get: { mode }, set: { modeRaw = $0.rawValue })
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.md), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Theme",
                subtitle: "Zed Trek — \(ZedTrekTheme.allCases.count) themes. \(family.displayName) · \(mode.displayName).")

            DSSegmentedControl(ThemeMode.allCases, selection: modeBinding) { mode in
                Text(mode.displayName)
            }
            .padding(.bottom, Tokens.Spacing.lg)

            LazyVGrid(columns: columns, spacing: Tokens.Spacing.md) {
                ForEach(ZedTrekTheme.allCases, id: \.self) { theme in
                    ThemeSwatchCard(name: theme.displayName,
                                    specimen: theme.dsSpecimen(for: scheme),
                                    isStarred: theme.isStarred,
                                    isActive: theme == family) {
                        familyRaw = theme.rawValue
                    }
                }
            }
            .padding(.bottom, Tokens.Spacing.xl)

            DSSettingGroup {
                DSSettingRow(
                    "Match app theme",
                    detail: "Recolor the diagram canvas to the selected theme"
                ) {
                    Toggle("Match app theme", isOn: $canvasFollows)
                        .labelsHidden()
                        .toggleStyle(.dsSwitchOnly)
                }
                .padding(.horizontal, Tokens.Spacing.lg)
                .contentShape(Rectangle())
                MenuRow(title: "Diagram palette", value: store.state.selectedThemeName,
                        leadingSwatch: AnyView(
                            RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS)
                                .fill(LinearGradient(colors: [theme.colors.textPrimary.color, theme.colors.textSecondary.color],
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
                        Text("Edit theme…").dsFont(.body).foregroundStyle(theme.colors.textPrimary.color)
                        Spacer()
                        DSIconView(.disclosureRight, size: Tokens.Size.Icon.micro, colorRole: .muted)
                    }
                    .padding(.horizontal, Tokens.Spacing.lg).contentShape(Rectangle())
                }.buttonStyle(.ds(role: .ghost, size: .regular))
            }
            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showThemeBuilder) {
            ThemeBuilderCard(store: store).padding().frame(minWidth: 340, minHeight: 380)
        }
    }
}

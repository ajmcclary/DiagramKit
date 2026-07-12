//
//  InspectorThemeSection.swift
//  DiagramPlayground
//
//  THEME section of the v2.1 inspector. The four chrome appearances
//  (Dark / Light / Forest / Neutral) render as SwatchTiles and write
//  to a shared @AppStorage that LiveEditorView reads to apply the
//  global generated design-system theme.
//
//  The existing ThemePicker (diagram-side palette) and ThemeBuilder
//  card stay available behind disclosures so the 17 DiagramTheme
//  entries remain reachable.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct InspectorThemeSection: View {
    @Bindable var store: LiveEditorStore

    @AppStorage(PlaygroundChromePersistence.themeKey)
    private var familyRaw = ZedTrekTheme.lcars.rawValue
    @AppStorage(PlaygroundChromePersistence.modeKey)
    private var modeRaw = ThemeMode.dark.rawValue
    @AppStorage(PlaygroundChromePersistence.canvasFollowsKey)
    private var canvasFollows = true

    @SwiftUI.State private var showDiagramPalette = false
    @SwiftUI.State private var showThemeBuilder = false

    @Environment(\.dsEnvironment) private var environment
    @Environment(\.colorScheme) private var scheme

    private var family: ZedTrekTheme { ZedTrekTheme(rawValue: familyRaw) ?? .lcars }
    private var mode: ThemeMode { ThemeMode(rawValue: modeRaw) ?? .dark }
    private var modeBinding: Binding<ThemeMode> {
        Binding(get: { mode }, set: { modeRaw = $0.rawValue })
    }

    private let tileColumns = [GridItem(.adaptive(minimum: 72), spacing: DSTokens.Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            DSSectionHeader("Theme")
            DSSurface(role: .card) {
                VStack(alignment: .leading, spacing: DSTokens.Spacing.md) {
                    modeControl
                    chromeTiles
                    matchAppThemeToggle
                    separator
                    diagramPaletteDisclosure
                    themeBuilderDisclosure
                }
                .padding(DSTokens.Spacing.md)
            }
        }
        .accessibilityIdentifier(A11yID.Inspector.themeSection)
        .accessibilityElement(children: .contain)
    }

    private var modeControl: some View {
        DSSegmentedControl(ThemeMode.allCases, selection: modeBinding) { mode in
            Text(mode.displayName)
        }
    }

    private var chromeTiles: some View {
        LazyVGrid(columns: tileColumns, spacing: DSTokens.Spacing.sm) {
            ForEach(ZedTrekTheme.allCases, id: \.self) { theme in
                let specimen = theme.dsSpecimen(for: scheme)
                SwatchTile(
                    title: theme.displayName,
                    background: specimen.cardBackground,
                    swatches: Array(specimen.accents.prefix(3)),
                    isSelected: theme == family
                ) {
                    familyRaw = theme.rawValue
                }
            }
        }
    }

    private var matchAppThemeToggle: some View {
        HStack {
            Text("Match app theme").dsFont(.body).foregroundStyle(environment.theme.colors.textPrimary.color)
            Spacer()
            Toggle("Match app theme", isOn: $canvasFollows)
                .labelsHidden()
                .toggleStyle(.ds)
        }
    }

    @ViewBuilder
    private var diagramPaletteDisclosure: some View {
        Button {
            withAnimation(disclosureAnimation) {
                showDiagramPalette.toggle()
            }
        } label: {
            HStack {
                DSIconView(showDiagramPalette ? .disclosureDown : .disclosureRight, size: DSTokens.Icon.micro, colorRole: .muted)
                Text("Diagram palette")
                    .dsFont(.body)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                Spacer()
                Text(store.state.selectedThemeName)
                    .dsFont(.badge)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))

        if showDiagramPalette {
            ThemePicker(store: store)
                .padding(.leading, DSTokens.Spacing.lg)
        }
    }

    @ViewBuilder
    private var themeBuilderDisclosure: some View {
        Button {
            withAnimation(disclosureAnimation) {
                showThemeBuilder.toggle()
            }
        } label: {
            HStack {
                DSIconView(showThemeBuilder ? .disclosureDown : .disclosureRight, size: DSTokens.Icon.micro, colorRole: .muted)
                Text("Edit theme")
                    .dsFont(.body)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                Spacer()
                Text("DiagramColors")
                    .dsFont(.code)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))

        if showThemeBuilder {
            ThemeBuilderCard(store: store)
                .padding(.leading, DSTokens.Spacing.lg)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(height: DSTokens.Stroke.hairline)
            .accessibilityHidden(true)
    }

    private var disclosureAnimation: Animation? {
        guard environment.motion == .standard else { return nil }
        return .easeInOut(
            duration: environment.motion.duration(
                milliseconds: DSTokens.DurationMilliseconds.fast
            )
        )
    }
}

// MARK: - Shared persistence keys

enum PlaygroundChromePersistence {
    /// Legacy single-key appearance (migration source only).
    static let appearanceKey = "playground.chromeAppearance"
    /// Selected Zed Trek family (rawValue), default `lcars`.
    static let themeKey = "playground.zedTrekTheme"
    /// Selected light/dark/system mode (rawValue), default `dark`.
    static let modeKey = "playground.themeMode"
    /// Whether the diagram canvas follows the app theme. Default `true`.
    static let canvasFollowsKey = "playground.canvasFollowsAppTheme"

    /// Map a legacy `chromeAppearance` value onto the (family, mode) model.
    static func migratedSelection(fromLegacy raw: String?) -> (theme: ZedTrekTheme, mode: ThemeMode) {
        switch raw {
        case "zedTrekDark", "dark", "forest":     return (.lcars, .dark)
        case "zedTrekLight", "light", "neutral":  return (.lcars, .light)
        case "federation":                        return (.federation, .dark)
        case "redAlert":                          return (.redAlert, .dark)
        case "sickBay":                           return (.sickBay, .dark)
        case "borgCube":                          return (.borgCube, .dark)
        default:                                  return (.lcars, .dark)
        }
    }

    /// One-time migration: if the new theme key is unset but a legacy appearance
    /// exists, seed the (family, mode) keys from it. Idempotent.
    static func migrateLegacyIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: themeKey) == nil,
              let legacy = defaults.string(forKey: appearanceKey) else { return }
        let (theme, mode) = migratedSelection(fromLegacy: legacy)
        defaults.set(theme.rawValue, forKey: themeKey)
        defaults.set(mode.rawValue, forKey: modeKey)
    }
}

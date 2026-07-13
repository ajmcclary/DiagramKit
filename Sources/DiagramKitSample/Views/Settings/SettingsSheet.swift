//
//  SettingsSheet.swift
//  DiagramPlayground
//
//  The redesign Settings sheet (⌘,): 748×520 header + 196px nav + content pane
//  (transcription §4). Presented as a dimmed/blurred overlay by PlaygroundShell.
//

import SwiftUI
import DesignKitThemes

struct SettingsSheet: View {
    @Bindable var store: LiveEditorStore
    @State private var searchText = ""
    @Environment(\.dsEnvironment) private var environment
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            compactBody
        } else {
            framedBody
        }
        #else
        framedBody
        #endif
    }

    /// Fixed 748×520 window-chrome layout used on macOS and iPad-regular, where
    /// SettingsSheet is presented as a centered overlay/sheet.
    private var framedBody: some View {
        VStack(spacing: 0) {
            header
            separator
            HStack(spacing: 0) {
                nav
                verticalSeparator
                content
            }
        }
        .frame(width: 748, height: 520)
        .background(environment.theme.colors.surfaceBackground.color)
        // Card chrome (clip / stroke / shadow) is now supplied by the enclosing
        // `.sheet`; framedBody just provides the sized two-column content.
    }

    /// Single-column layout for iPhone-compact: the two-column nav/content of
    /// `framedBody` won't fit a phone width, so the section list collapses into a
    /// menu picker above the content. The enclosing `.sheet` supplies the chrome
    /// and the Done button, so no fixed frame / traffic-light close here.
    private var compactBody: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: Binding(
                get: { store.state.settingsTab },
                set: { store.setSettingsTab($0) }
            )) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.displayName).tag(tab)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, DSTokens.Spacing.lg)
            .padding(.vertical, DSTokens.Spacing.sm)
            separator
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(environment.theme.colors.surfaceBackground.color)
    }

    private var header: some View {
        HStack(spacing: DSTokens.Spacing.md) {
            DSIconButton(.close, label: "Close") { store.dismissSettings() }
                .keyboardShortcut(.cancelAction)
            Text("Settings")
                .dsFont(.headline)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
            Spacer()
            HStack(spacing: DSTokens.Spacing.xs) {
                DSIconView(.search, size: DSTokens.Icon.micro, colorRole: .muted)
                TextField("Search settings…", text: $searchText).textFieldStyle(.plain)
                    .dsFont(.caption)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
            }
            .padding(.horizontal, DSTokens.Spacing.smMd)
            .frame(width: 180)
            .frame(minHeight: max(DSTokens.Control.rowCompact, environment.minimumTarget))
            .background(environment.theme.colors.element.color)
            .overlay(
                RoundedRectangle(cornerRadius: DSTokens.Radius.sm)
                    .stroke(environment.theme.colors.borderVariant.color, lineWidth: DSTokens.Stroke.thin)
            )
            .clipShape(RoundedRectangle(cornerRadius: DSTokens.Radius.sm))
        }
        .padding(.horizontal, DSTokens.Spacing.lg).frame(minHeight: 52)
    }

    private var nav: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                let isActive = store.state.settingsTab == tab
                Button { store.setSettingsTab(tab) } label: {
                    HStack(spacing: DSTokens.Spacing.sm) {
                        DSIconView(tab.icon, size: DSTokens.Icon.micro, colorRole: isActive ? .primary : .muted)
                        Text(tab.displayName).dsFont(.caption)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DSTokens.Spacing.smMd)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.ds(role: isActive ? .secondary : .ghost, size: .regular))
            }
            Spacer()
        }
        .padding(.horizontal, DSTokens.Spacing.smMd).padding(.vertical, DSTokens.Spacing.md).frame(width: 196)
        .background(environment.theme.colors.panelBackground.color)
    }

    private var content: some View {
        ScrollView {
            Group {
                switch store.state.settingsTab {
                case .general: SettingsGeneralTab(store: store)
                case .editor: SettingsEditorTab(store: store)
                case .renderBackend: SettingsRenderBackendTab(store: store)
                case .theme: SettingsThemeTab(store: store)
                case .platformParity: SettingsPlatformParityTab()
                case .mutationsCatalog: SettingsMutationsCatalogTab()
                case .fonts: SettingsFontsTab()
                }
            }
            .padding(.horizontal, DSTokens.Spacing.xxl).padding(.vertical, DSTokens.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var separator: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(height: DSTokens.Stroke.hairline)
    }

    private var verticalSeparator: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(width: DSTokens.Stroke.hairline)
    }
}

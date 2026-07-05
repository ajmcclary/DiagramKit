//
//  SettingsSheet.swift
//  DiagramPlayground
//
//  The redesign Settings sheet (⌘,): 748×520 header + 196px nav + content pane
//  (transcription §4). Presented as a dimmed/blurred overlay by PlaygroundShell.
//

import SwiftUI

struct SettingsSheet: View {
    @Bindable var store: LiveEditorStore
    @State private var searchText = ""
    @Environment(\.playgroundTokens) private var tokens
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
            Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5)
            HStack(spacing: 0) {
                nav
                Rectangle().fill(tokens.palette.borderHairline).frame(width: 0.5)
                content
            }
        }
        .frame(width: 748, height: 520)
        .background(tokens.palette.bgSheet)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(tokens.palette.borderWarm, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.55), radius: 35, y: 30)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tokens.palette.bgSheet)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle().fill(tokens.palette.trafficRed).frame(width: 11, height: 11)
                .onTapGesture { store.dismissSettings() }
            Text("Settings").font(PlaygroundFont.sans(14, weight: .semibold)).foregroundStyle(tokens.palette.fg1)
            Spacer()
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(tokens.palette.textFaint)
                TextField("Search settings…", text: $searchText).textFieldStyle(.plain)
                    .font(PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.fg1)
            }
            .padding(.horizontal, 10).frame(width: 180, height: 30)
            .background(tokens.palette.bgField)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.palette.borderWarm, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16).frame(height: 52)
    }

    private var nav: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                SidebarNavItem(title: tab.displayName, systemImage: tab.systemImage,
                               isActive: store.state.settingsTab == tab) { store.setSettingsTab(tab) }
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 12).frame(width: 196)
        .background(tokens.palette.bgSidebarNav)
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
            .padding(.horizontal, 22).padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

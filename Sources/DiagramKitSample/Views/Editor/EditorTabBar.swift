//
//  EditorTabBar.swift
//  DiagramPlayground
//
//  Phase 2 / Task 2.1 — chrome above NativeCodeEditor. One pill per
//  open tab; a trailing `+` opens a sample picker. Wired to
//  LiveEditorStore.openTab / activateTab / closeTab.
//

import SwiftUI
import DesignKitThemes

struct EditorTabBar: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        DSSurface(role: .tabBar) {
            HStack(spacing: DSTokens.Spacing.xxs) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSTokens.Spacing.xxs) {
                        ForEach(store.state.openTabs, id: \.self) { tabId in
                            tabPill(for: tabId)
                        }
                    }
                    .padding(.horizontal, DSTokens.Stroke.medium)
                }
                addMenu
            }
            .padding(.horizontal, DSTokens.Spacing.xs)
            .frame(
                height: max(DSTokens.Control.tabStrip, environment.minimumTarget)
            )
        }
    }

    private func tabPill(for tabId: String) -> some View {
        let isActive = store.state.activeTabId == tabId
        return HStack(spacing: DSTokens.Spacing.xxs) {
            Button {
                store.activateTab(tabId)
            } label: {
                HStack(spacing: DSTokens.Spacing.xxs) {
                    DSIconView(.code, size: DSTokens.Icon.micro, colorRole: .muted)
                    Text(displayName(for: tabId))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if environment.preferences.differentiateWithoutColor {
                        Text(categoryName(for: tabId))
                            .dsFont(.caption2)
                    }
                }
            }
            .buttonStyle(.ds(role: isActive ? .secondary : .ghost, size: .compact))
            DSIconButton(.close, label: "Close tab") {
                store.closeTab(tabId)
            }
            .fixedSize()
            .a11y(label: "Close tab", id: "editor.tab.close.\(tabId)")
        }
        .accessibilityIdentifier("editor.tab.\(tabId)")
    }

    private var addMenu: some View {
        Menu {
            ForEach(suggestedSamples) { entry in
                Button(entry.name) {
                    store.openTab(entry.id)
                }
            }
        } label: {
            DSIconView(.add, size: DSTokens.Icon.xs, colorRole: .muted)
                .frame(
                    minWidth: environment.minimumTarget,
                    minHeight: environment.minimumTarget
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .a11y(label: "Open new tab", id: "editor.tab.add")
    }

    private var suggestedSamples: [TestDiagram] {
        Array(TestDiagrams.all.prefix(12))
    }

    private func displayName(for tabId: String) -> String {
        TestDiagrams.all.first(where: { $0.id == tabId })?.name ?? tabId
    }

    private func categoryName(for tabId: String) -> String {
        TestDiagrams.all.first(where: { $0.id == tabId })?.category ?? "Diagram"
    }
}

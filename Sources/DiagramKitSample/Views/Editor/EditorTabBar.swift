//
//  EditorTabBar.swift
//  DiagramPlayground
//
//  Phase 2 / Task 2.1 — chrome above the code editor. One pill per
//  open tab; a trailing `+` opens a sample picker. Wired to
//  LiveEditorStore.openTab / activateTab / closeTab.
//

import SwiftUI
import DesignKitThemes

struct EditorTabBar: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context

    var body: some View {
        DSSurface(role: .tabBar) {
            HStack(spacing: Tokens.Spacing.xxs) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Tokens.Spacing.xxs) {
                        ForEach(store.state.openTabs, id: \.self) { tabId in
                            tabPill(for: tabId)
                        }
                    }
                    .padding(.horizontal, Tokens.Shape.strokeMedium)
                }
                addMenu
            }
            .padding(.horizontal, Tokens.Spacing.xs)
            .frame(
                height: max(Tokens.Size.Control.tabStrip, context.minimumTarget)
            )
        }
    }

    private func tabPill(for tabId: String) -> some View {
        let isActive = store.state.activeTabId == tabId
        return HStack(spacing: Tokens.Spacing.xxs) {
            Button {
                store.activateTab(tabId)
            } label: {
                HStack(spacing: Tokens.Spacing.xxs) {
                    DSIconView(.code, size: Tokens.Size.Icon.micro, colorRole: .muted)
                    Text(displayName(for: tabId))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if context.preferences.differentiateWithoutColor {
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
            DSIconView(.add, size: Tokens.Size.Icon.xs, colorRole: .muted)
                .frame(
                    minWidth: context.minimumTarget,
                    minHeight: context.minimumTarget
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

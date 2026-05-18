//
//  EditorTabBar.swift
//  DiagramPlayground
//
//  Phase 2 / Task 2.1 — chrome above NativeCodeEditor. One pill per
//  open tab; a trailing `+` opens a sample picker. Wired to
//  LiveEditorStore.openTab / activateTab / closeTab.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct EditorTabBar: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(store.state.openTabs, id: \.self) { tabId in
                        tabPill(for: tabId)
                    }
                }
                .padding(.horizontal, 2)
            }
            addMenu
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(store.theme.foreground).opacity(0.04))
    }

    private func tabPill(for tabId: String) -> some View {
        let isActive = store.state.activeTabId == tabId
        return HStack(spacing: 4) {
            Circle()
                .fill(formatColor(for: tabId))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Button {
                store.activateTab(tabId)
            } label: {
                Text(displayName(for: tabId))
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .buttonStyle(.plain)
            Button {
                store.closeTab(tabId)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .a11y(label: "Close tab", id: "editor.tab.close.\(tabId)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.08))
        )
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
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
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

    private func formatColor(for tabId: String) -> Color {
        guard let entry = TestDiagrams.all.first(where: { $0.id == tabId }) else {
            return .secondary
        }
        return categoryColor(entry.category)
    }

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "flowchart": return .blue
        case "sequence":  return .pink
        case "class":     return .green
        case "state":     return .orange
        case "er":        return .purple
        case "timeline":  return .teal
        case "gantt":     return .red
        case "mindmap":   return .indigo
        default:          return .gray
        }
    }
}

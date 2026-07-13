//
//  OrganizePanel.swift
//  DiagramPlayground
//
//  Activity-rail Organize panel: a hierarchical tree of the current flowchart —
//  subgraphs nesting their member nodes + child subgraphs, then loose nodes, then
//  an edges group. Rows are filterable, expand/collapse, and select the node in
//  the editor on tap (transcription §3.1 / §6.1).
//

import SwiftUI
import DiagramKit
import DesignKitThemes

struct OrganizePanel: View {
    @Bindable var store: LiveEditorStore
    @SwiftUI.State private var filter = ""
    @SwiftUI.State private var collapsed: Set<String> = []
    @SwiftUI.State private var edgesCollapsed = false
    @Environment(\.designTheme) private var theme

    private var tree: OutlineTree { OutlineTree.from(store) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Organize") {
                DSIconView(.add, size: Tokens.Size.Icon.micro, colorRole: .muted)
            }
            PanelFilterField(placeholder: "Filter nodes…", text: $filter)
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Shape.strokeThin) {
                    ForEach(rows) { row in rowView(row) }
                    if filter.isEmpty && !tree.edges.isEmpty { edgesSection }
                    if tree.roots.isEmpty {
                        Text("No flowchart elements")
                            .dsFont(.caption)
                            .foregroundStyle(theme.colors.textSecondary.color)
                            .padding(Tokens.Spacing.md)
                    }
                }
                .padding(.horizontal, Tokens.Spacing.sm)
                .padding(.bottom, Tokens.Spacing.md)
            }
        }
    }

    // MARK: - Rows

    private struct FlatRow: Identifiable { let id: String; let node: OutlineNode; let depth: Int }

    private var rows: [FlatRow] {
        var out: [FlatRow] = []
        let f = filter.trimmingCharacters(in: .whitespaces)
        func matches(_ n: OutlineNode) -> Bool {
            f.isEmpty || n.display.localizedCaseInsensitiveContains(f) || n.id.localizedCaseInsensitiveContains(f)
        }
        func walk(_ nodes: [OutlineNode], _ depth: Int) {
            for n in nodes {
                let rowID = (n.kind == .subgraph ? "sg:" : "nd:") + n.id
                if f.isEmpty {
                    out.append(FlatRow(id: rowID, node: n, depth: depth))
                    if n.kind == .subgraph && !collapsed.contains(n.id) { walk(n.children, depth + 1) }
                } else if n.kind == .node {
                    if matches(n) { out.append(FlatRow(id: rowID, node: n, depth: depth)) }
                } else {
                    let before = out.count
                    walk(n.children, depth + 1)
                    if matches(n) || out.count > before {
                        out.insert(FlatRow(id: rowID, node: n, depth: depth), at: before)
                    }
                }
            }
        }
        walk(tree.roots, 0)
        return out
    }

    @ViewBuilder private func rowView(_ row: FlatRow) -> some View {
        if row.node.kind == .subgraph { subgraphRow(row) } else { nodeRow(row) }
    }

    private func subgraphRow(_ row: FlatRow) -> some View {
        let isCollapsed = collapsed.contains(row.node.id)
        return Button {
            if isCollapsed { collapsed.remove(row.node.id) } else { collapsed.insert(row.node.id) }
        } label: {
            HStack(spacing: Tokens.Spacing.xs) {
                DSIconView(
                    isCollapsed ? .disclosureRight : .disclosureDown,
                    size: Tokens.Size.Icon.indicator,
                    colorRole: .muted
                )
                DSIconView(.subgraph, size: Tokens.Size.Icon.micro)
                Text(row.node.display)
                    .dsFont(.footnote)
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                Spacer(minLength: Tokens.Spacing.xxs)
                Text(row.node.id)
                    .dsFont(.code)
                    .foregroundStyle(theme.colors.textDisabled.color)
            }
            .padding(.leading, Tokens.Spacing.sm + CGFloat(row.depth) * Tokens.Spacing.lg)
            .padding(.trailing, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
    }

    private func nodeRow(_ row: FlatRow) -> some View {
        let isSelected = store.editor?.selection?.elementID == "node:\(row.node.id)"
        return Button {
            selectNode(row.node.id)
        } label: {
            HStack(spacing: Tokens.Spacing.sm) {
                DSIconView(
                    .node,
                    size: Tokens.Size.Icon.indicator,
                    colorRole: isSelected ? .primary : .muted
                )
                Text(row.node.display)
                    .dsFont(.caption)
                    .foregroundStyle(
                        isSelected
                            ? theme.colors.accent.color
                            : theme.colors.textPrimary.color
                    )
                    .lineLimit(1)
                Spacer(minLength: Tokens.Spacing.xxs)
                Text(row.node.id)
                    .dsFont(.code)
                    .foregroundStyle(
                        isSelected
                            ? theme.colors.accent.color
                            : theme.colors.textDisabled.color
                    )
            }
            .padding(.leading, Tokens.Spacing.xxl + CGFloat(row.depth) * Tokens.Spacing.lg)
            .padding(.trailing, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(isSelected ? theme.colors.elementSelected.color : .clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle()
                        .fill(theme.colors.accent.color)
                        .frame(width: Tokens.Size.Control.accentBar)
                        .padding(.leading, CGFloat(row.depth) * Tokens.Spacing.lg)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS))
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: isSelected ? .secondary : .ghost, size: .compact))
    }

    private var edgesSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Shape.strokeThin) {
            Button { edgesCollapsed.toggle() } label: {
                HStack(spacing: Tokens.Spacing.xs) {
                    DSIconView(
                        edgesCollapsed ? .disclosureRight : .disclosureDown,
                        size: Tokens.Size.Icon.indicator,
                        colorRole: .muted
                    )
                    DSIconView(.convert, size: Tokens.Size.Icon.micro, colorRole: .info)
                    DSSectionHeader("Edges")
                    Spacer(minLength: Tokens.Spacing.xxs)
                    Text("\(tree.edges.count)")
                        .dsFont(.code)
                        .foregroundStyle(theme.colors.textDisabled.color)
                }
                .padding(.leading, Tokens.Spacing.sm)
                .padding(.trailing, Tokens.Spacing.sm)
                .padding(.top, Tokens.Spacing.smMd)
                .padding(.bottom, Tokens.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            if !edgesCollapsed {
                ForEach(tree.edges) { e in
                    Text("\(e.from) → \(e.to)")
                        .dsFont(.code)
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .padding(.leading, Tokens.Size.Control.rowCompact)
                        .padding(.vertical, Tokens.Shape.strokeThick)
                }
            }
        }
    }

    private func selectNode(_ id: String) {
        guard let type = store.editor?.document.type else { return }
        store.setSelection(DiagramSelection(diagramType: type, elementID: "node:\(id)"))
    }
}

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
    @Environment(\.dsEnvironment) private var environment

    private var tree: OutlineTree { OutlineTree.from(store) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Organize") {
                DSIconView(.add, size: DSTokens.Icon.micro, colorRole: .muted)
            }
            PanelFilterField(placeholder: "Filter nodes…", text: $filter)
            ScrollView {
                VStack(alignment: .leading, spacing: DSTokens.Stroke.thin) {
                    ForEach(rows) { row in rowView(row) }
                    if filter.isEmpty && !tree.edges.isEmpty { edgesSection }
                    if tree.roots.isEmpty {
                        Text("No flowchart elements")
                            .dsFont(.caption)
                            .foregroundStyle(environment.theme.colors.textSecondary.color)
                            .padding(DSTokens.Spacing.md)
                    }
                }
                .padding(.horizontal, DSTokens.Spacing.sm)
                .padding(.bottom, DSTokens.Spacing.md)
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
            HStack(spacing: DSTokens.Spacing.xs) {
                DSIconView(
                    isCollapsed ? .disclosureRight : .disclosureDown,
                    size: DSTokens.Icon.indicator,
                    colorRole: .muted
                )
                DSIconView(.subgraph, size: DSTokens.Icon.micro)
                Text(row.node.display)
                    .dsFont(.footnote)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                    .lineLimit(1)
                Spacer(minLength: DSTokens.Spacing.xxs)
                Text(row.node.id)
                    .dsFont(.code)
                    .foregroundStyle(environment.theme.colors.textDisabled.color)
            }
            .padding(.leading, DSTokens.Spacing.sm + CGFloat(row.depth) * DSTokens.Spacing.lg)
            .padding(.trailing, DSTokens.Spacing.sm)
            .padding(.vertical, DSTokens.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
    }

    private func nodeRow(_ row: FlatRow) -> some View {
        let isSelected = store.editor?.selection?.elementID == "node:\(row.node.id)"
        return Button {
            selectNode(row.node.id)
        } label: {
            HStack(spacing: DSTokens.Spacing.sm) {
                DSIconView(
                    .node,
                    size: DSTokens.Icon.indicator,
                    colorRole: isSelected ? .primary : .muted
                )
                Text(row.node.display)
                    .dsFont(.caption)
                    .foregroundStyle(
                        isSelected
                            ? environment.theme.colors.accent.color
                            : environment.theme.colors.textPrimary.color
                    )
                    .lineLimit(1)
                Spacer(minLength: DSTokens.Spacing.xxs)
                Text(row.node.id)
                    .dsFont(.code)
                    .foregroundStyle(
                        isSelected
                            ? environment.theme.colors.accent.color
                            : environment.theme.colors.textDisabled.color
                    )
            }
            .padding(.leading, DSTokens.Spacing.xxl + CGFloat(row.depth) * DSTokens.Spacing.lg)
            .padding(.trailing, DSTokens.Spacing.sm)
            .padding(.vertical, DSTokens.Spacing.xxs)
            .background(isSelected ? environment.theme.colors.elementSelected.color : .clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle()
                        .fill(environment.theme.colors.accent.color)
                        .frame(width: DSTokens.Control.accentBar)
                        .padding(.leading, CGFloat(row.depth) * DSTokens.Spacing.lg)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DSTokens.Radius.xs))
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: isSelected ? .secondary : .ghost, size: .compact))
    }

    private var edgesSection: some View {
        VStack(alignment: .leading, spacing: DSTokens.Stroke.thin) {
            Button { edgesCollapsed.toggle() } label: {
                HStack(spacing: DSTokens.Spacing.xs) {
                    DSIconView(
                        edgesCollapsed ? .disclosureRight : .disclosureDown,
                        size: DSTokens.Icon.indicator,
                        colorRole: .muted
                    )
                    DSIconView(.convert, size: DSTokens.Icon.micro, colorRole: .info)
                    DSSectionHeader("Edges")
                    Spacer(minLength: DSTokens.Spacing.xxs)
                    Text("\(tree.edges.count)")
                        .dsFont(.code)
                        .foregroundStyle(environment.theme.colors.textDisabled.color)
                }
                .padding(.leading, DSTokens.Spacing.sm)
                .padding(.trailing, DSTokens.Spacing.sm)
                .padding(.top, DSTokens.Spacing.smMd)
                .padding(.bottom, DSTokens.Spacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            if !edgesCollapsed {
                ForEach(tree.edges) { e in
                    Text("\(e.from) → \(e.to)")
                        .dsFont(.code)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                        .padding(.leading, DSTokens.Control.rowCompact)
                        .padding(.vertical, DSTokens.Stroke.thick)
                }
            }
        }
    }

    private func selectNode(_ id: String) {
        guard let type = store.editor?.document.type else { return }
        store.setSelection(DiagramSelection(diagramType: type, elementID: "node:\(id)"))
    }
}

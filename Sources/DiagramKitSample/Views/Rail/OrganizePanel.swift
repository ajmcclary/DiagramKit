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

struct OrganizePanel: View {
    @Bindable var store: LiveEditorStore
    @SwiftUI.State private var filter = ""
    @SwiftUI.State private var collapsed: Set<String> = []
    @SwiftUI.State private var edgesCollapsed = false
    @Environment(\.playgroundTokens) private var tokens

    private var tree: OutlineTree { OutlineTree.from(store) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Organize") {
                Image(systemName: "plus").font(.system(size: 12)).foregroundStyle(tokens.palette.fg3)
            }
            PanelFilterField(placeholder: "Filter nodes…", text: $filter)
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(rows) { row in rowView(row) }
                    if filter.isEmpty && !tree.edges.isEmpty { edgesSection }
                    if tree.roots.isEmpty {
                        Text("No flowchart elements").font(PlaygroundFont.sans(12))
                            .foregroundStyle(tokens.palette.textFaint).padding(12)
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 12)
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
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(tokens.palette.fg3).frame(width: 10)
                Image(systemName: "curlybraces").font(.system(size: 12)).foregroundStyle(tokens.palette.accentSecondary)
                Text(row.node.display).font(PlaygroundFont.sans(12.5, weight: .semibold))
                    .foregroundStyle(tokens.palette.fg1).lineLimit(1)
                Spacer(minLength: 4)
                Text(row.node.id).font(PlaygroundFont.mono(10.5)).foregroundStyle(tokens.palette.textFaintest)
            }
            .padding(.leading, 8 + CGFloat(row.depth) * 14).padding(.trailing, 8).padding(.vertical, 4)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func nodeRow(_ row: FlatRow) -> some View {
        let isSelected = store.editor?.selection?.elementID == "node:\(row.node.id)"
        return Button {
            selectNode(row.node.id)
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? tokens.palette.accent : tokens.palette.fg3.opacity(0.55))
                    .frame(width: 11, height: 8)
                Text(row.node.display).font(PlaygroundFont.sans(12.5))
                    .foregroundStyle(isSelected ? tokens.palette.accentSecondary : tokens.palette.fg1).lineLimit(1)
                Spacer(minLength: 4)
                Text(row.node.id).font(PlaygroundFont.mono(10.5))
                    .foregroundStyle(isSelected ? tokens.palette.accentSecondary : tokens.palette.textFaintest)
            }
            .padding(.leading, 8 + CGFloat(row.depth) * 14 + 16).padding(.trailing, 8).padding(.vertical, 4)
            .background(isSelected ? tokens.palette.accentTint16 : .clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle().fill(tokens.palette.accent).frame(width: 2)
                        .padding(.leading, CGFloat(row.depth) * 14)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var edgesSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button { edgesCollapsed.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: edgesCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(tokens.palette.fg3).frame(width: 10)
                    Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(tokens.palette.catCyan)
                    Text("EDGES").font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6).foregroundStyle(tokens.palette.fg3)
                    Spacer(minLength: 4)
                    Text("\(tree.edges.count)").font(PlaygroundFont.mono(10.5)).foregroundStyle(tokens.palette.textFaintest)
                }
                .padding(.leading, 8).padding(.trailing, 8).padding(.top, 10).padding(.bottom, 4)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
            if !edgesCollapsed {
                ForEach(tree.edges) { e in
                    Text("\(e.from) → \(e.to)").font(PlaygroundFont.mono(12))
                        .foregroundStyle(tokens.palette.fg3)
                        .padding(.leading, 28).padding(.vertical, 3)
                }
            }
        }
    }

    private func selectNode(_ id: String) {
        guard let type = store.editor?.document.type else { return }
        store.setSelection(DiagramSelection(diagramType: type, elementID: "node:\(id)"))
    }
}

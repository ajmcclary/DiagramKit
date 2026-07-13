//
//  SearchPanel.swift
//  DiagramPlayground
//
//  Activity-rail Search panel: find nodes / edges / labels in the current
//  flowchart with filter chips (transcription §6.3).
//

import SwiftUI
import DesignKitThemes

struct SearchPanel: View {
    @Bindable var store: LiveEditorStore
    @State private var query = ""
    @Environment(\.designTheme) private var theme

    private var elements: OutlineElements { OutlineElements.from(store) }
    private var nodeMatches: [OutlineItem] {
        guard !query.isEmpty else { return [] }
        return elements.nodes.filter { $0.label.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query) }
    }
    private var edgeMatches: [OutlineEdge] {
        guard !query.isEmpty else { return [] }
        return elements.edges.filter { ($0.label ?? "").localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Search")
            PanelFilterField(placeholder: "Search nodes & labels…", text: $query, focused: !query.isEmpty)
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.smMd) {
                    if query.isEmpty {
                        Text("Type to search nodes, edges, and labels.")
                            .dsFont(.caption)
                            .foregroundStyle(theme.colors.textSecondary.color)
                            .padding(Tokens.Spacing.md)
                    } else {
                        if !nodeMatches.isEmpty {
                            section("Nodes", nodeMatches.map { ($0.display, "node:\($0.id)", DSIcon.node, DSIconColorRole.primary) })
                        }
                        if !edgeMatches.isEmpty {
                            section("Labels", edgeMatches.map { (($0.label ?? ""), "\($0.from)→\($0.to)", DSIcon.convert, DSIconColorRole.info) })
                        }
                        if nodeMatches.isEmpty && edgeMatches.isEmpty {
                            Text("No matches for “\(query)”.")
                                .dsFont(.caption)
                                .foregroundStyle(theme.colors.textSecondary.color)
                                .padding(Tokens.Spacing.md)
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.smMd)
                .padding(.bottom, Tokens.Spacing.md)
            }
        }
    }

    private func section(
        _ title: String,
        _ rows: [(String, String, DSIcon, DSIconColorRole)]
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            DSSectionHeader(title)
                .padding(.horizontal, Tokens.Spacing.xxs)
                .padding(.top, Tokens.Spacing.xxs)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                DSSurface(role: .card) {
                    HStack(spacing: Tokens.Spacing.smMd) {
                        DSIconView(r.2, size: Tokens.Size.Icon.micro, colorRole: r.3)
                        Text(r.0)
                            .dsFont(.caption)
                            .foregroundStyle(theme.colors.textPrimary.color)
                            .lineLimit(1)
                        Spacer(minLength: Tokens.Spacing.xxs)
                        Text(r.1)
                            .dsFont(.code)
                            .foregroundStyle(theme.colors.textDisabled.color)
                    }
                    .padding(Tokens.Spacing.smMd)
                }
            }
        }
    }
}

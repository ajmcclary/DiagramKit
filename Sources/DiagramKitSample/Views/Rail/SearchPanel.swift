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
    @Environment(\.dsEnvironment) private var environment

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
                VStack(alignment: .leading, spacing: DSTokens.Spacing.smMd) {
                    if query.isEmpty {
                        Text("Type to search nodes, edges, and labels.")
                            .dsFont(.caption)
                            .foregroundStyle(environment.theme.colors.textSecondary.color)
                            .padding(DSTokens.Spacing.md)
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
                                .foregroundStyle(environment.theme.colors.textSecondary.color)
                                .padding(DSTokens.Spacing.md)
                        }
                    }
                }
                .padding(.horizontal, DSTokens.Spacing.smMd)
                .padding(.bottom, DSTokens.Spacing.md)
            }
        }
    }

    private func section(
        _ title: String,
        _ rows: [(String, String, DSIcon, DSIconColorRole)]
    ) -> some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            DSSectionHeader(title)
                .padding(.horizontal, DSTokens.Spacing.xxs)
                .padding(.top, DSTokens.Spacing.xxs)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                DSSurface(role: .card) {
                    HStack(spacing: DSTokens.Spacing.smMd) {
                        DSIconView(r.2, size: DSTokens.Icon.micro, colorRole: r.3)
                        Text(r.0)
                            .dsFont(.caption)
                            .foregroundStyle(environment.theme.colors.textPrimary.color)
                            .lineLimit(1)
                        Spacer(minLength: DSTokens.Spacing.xxs)
                        Text(r.1)
                            .dsFont(.code)
                            .foregroundStyle(environment.theme.colors.textDisabled.color)
                    }
                    .padding(DSTokens.Spacing.smMd)
                }
            }
        }
    }
}

//
//  SearchPanel.swift
//  DiagramPlayground
//
//  Activity-rail Search panel: find nodes / edges / labels in the current
//  flowchart with filter chips (transcription §6.3).
//

import SwiftUI

struct SearchPanel: View {
    @Bindable var store: LiveEditorStore
    @State private var query = ""
    @Environment(\.playgroundTokens) private var tokens

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
                VStack(alignment: .leading, spacing: 10) {
                    if query.isEmpty {
                        Text("Type to search nodes, edges, and labels.")
                            .font(PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.textFaint).padding(12)
                    } else {
                        if !nodeMatches.isEmpty { section("Nodes", nodeMatches.map { ($0.display, "node:\($0.id)", "rectangle", tokens.palette.accentSecondary) }) }
                        if !edgeMatches.isEmpty {
                            section("Labels", edgeMatches.map { (($0.label ?? ""), "\($0.from)→\($0.to)", "arrow.right", tokens.palette.catCyan) })
                        }
                        if nodeMatches.isEmpty && edgeMatches.isEmpty {
                            Text("No matches for “\(query)”.").font(PlaygroundFont.sans(12))
                                .foregroundStyle(tokens.palette.textFaint).padding(12)
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.bottom, 12)
            }
        }
    }

    private func section(_ title: String, _ rows: [(String, String, String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
                .foregroundStyle(tokens.palette.fg3).padding(.horizontal, 4).padding(.top, 4)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 9) {
                    Image(systemName: r.2).font(.system(size: 13)).foregroundStyle(r.3).frame(width: 16)
                    Text(r.0).font(PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.fg1).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(r.1).font(PlaygroundFont.mono(10.5)).foregroundStyle(tokens.palette.textFaintest)
                }
                .padding(9)
                .background(tokens.palette.bgCard)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
    }
}

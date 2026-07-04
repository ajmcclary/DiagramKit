//
//  OrganizePanel.swift
//  DiagramPlayground
//
//  Activity-rail Organize panel: subgraph / node / edge outline of the current
//  flowchart, with a filter (transcription §3.1 / §6.1).
//

import SwiftUI

struct OrganizePanel: View {
    @Bindable var store: LiveEditorStore
    @State private var filter = ""
    @Environment(\.playgroundTokens) private var tokens

    private var elements: OutlineElements { OutlineElements.from(store) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Organize") {
                Image(systemName: "plus").font(.system(size: 12)).foregroundStyle(tokens.palette.fg3)
            }
            PanelFilterField(placeholder: "Filter nodes…", text: $filter)
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(filtered(elements.subgraphs)) { sg in
                        row(icon: "square.on.square", iconColor: tokens.palette.accentSecondary,
                            label: sg.display, mono: sg.id, bold: true)
                    }
                    ForEach(filtered(elements.nodes)) { node in
                        row(icon: "rectangle", iconColor: tokens.palette.fg3,
                            label: node.display, mono: node.id, indent: 14)
                    }
                    if !elements.edges.isEmpty && filter.isEmpty {
                        Text("EDGES").font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
                            .foregroundStyle(tokens.palette.fg3)
                            .padding(.horizontal, 8).padding(.top, 10).padding(.bottom, 4)
                        ForEach(elements.edges) { e in
                            Text("\(e.from) → \(e.to)").font(PlaygroundFont.mono(12))
                                .foregroundStyle(tokens.palette.fg3)
                                .padding(.leading, 22).padding(.vertical, 3)
                        }
                    }
                    if elements.nodes.isEmpty && elements.subgraphs.isEmpty {
                        Text("No flowchart elements").font(PlaygroundFont.sans(12))
                            .foregroundStyle(tokens.palette.textFaint).padding(12)
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 12)
            }
        }
    }

    private func filtered(_ items: [OutlineItem]) -> [OutlineItem] {
        filter.isEmpty ? items
            : items.filter { $0.label.localizedCaseInsensitiveContains(filter) || $0.id.localizedCaseInsensitiveContains(filter) }
    }

    private func row(icon: String, iconColor: Color, label: String, mono: String, bold: Bool = false, indent: CGFloat = 0) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(iconColor).frame(width: 14)
            Text(label).font(PlaygroundFont.sans(12.5, weight: bold ? .semibold : .regular))
                .foregroundStyle(tokens.palette.fg1).lineLimit(1)
            Spacer(minLength: 4)
            Text(mono).font(PlaygroundFont.mono(10.5)).foregroundStyle(tokens.palette.textFaintest)
        }
        .padding(.leading, 8 + indent).padding(.trailing, 8).padding(.vertical, 4)
    }
}

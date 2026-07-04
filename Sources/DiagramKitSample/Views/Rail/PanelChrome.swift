//
//  PanelChrome.swift
//  DiagramPlayground
//
//  Shared chrome for activity-rail panels: header + filter field + a flowchart
//  outline reader used by Organize / Search (transcription §3.1 / turn 2).
//

import SwiftUI
import DiagramKit

struct PanelHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.playgroundTokens) private var tokens

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title.uppercased()).font(PlaygroundFont.sans(11, weight: .bold)).tracking(0.6)
                .foregroundStyle(tokens.palette.fg1)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 15).padding(.top, 14).padding(.bottom, 8)
    }
}

struct PanelFilterField: View {
    let placeholder: String
    @Binding var text: String
    var focused: Bool = false
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 12))
                .foregroundStyle(focused ? tokens.palette.accent : tokens.palette.textFaint)
            TextField(placeholder, text: $text).textFieldStyle(.plain)
                .font(PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.fg1)
        }
        .padding(.horizontal, 10).frame(height: 28)
        .background(tokens.palette.bgField)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(focused ? tokens.palette.accent : tokens.palette.borderWarm, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 12).padding(.bottom, 8)
    }
}

struct OutlineItem: Identifiable, Hashable {
    let id: String
    let label: String
    var display: String { label.isEmpty ? id : label }
}

struct OutlineEdge: Identifiable, Hashable {
    let id: String
    let from: String
    let to: String
    let label: String?
}

/// A flattened outline of the current flowchart document, for the Organize and
/// Search panels. Empty for non-flowchart families or before the first render.
struct OutlineElements {
    var subgraphs: [OutlineItem]
    var nodes: [OutlineItem]
    var edges: [OutlineEdge]

    @MainActor static func from(_ store: LiveEditorStore) -> OutlineElements {
        guard let doc = store.editor?.document else { return .init(subgraphs: [], nodes: [], edges: []) }
        if case .flowchart(let model) = doc.payload {
            let edges = model.edges.enumerated().map { i, e in
                OutlineEdge(id: "\(e.source)->\(e.target)#\(i)", from: e.source, to: e.target, label: e.label)
            }
            return .init(
                subgraphs: model.subgraphs.map { OutlineItem(id: $0.id, label: $0.label) },
                nodes: model.nodesInOrder.map { OutlineItem(id: $0.id, label: $0.node.label) },
                edges: edges
            )
        }
        return .init(subgraphs: [], nodes: [], edges: [])
    }
}

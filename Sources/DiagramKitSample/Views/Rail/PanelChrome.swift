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
                .font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
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

// MARK: - Hierarchical outline (Organize tree)

enum OutlineNodeKind: Hashable { case subgraph, node }

struct OutlineNode: Identifiable, Hashable {
    let id: String
    let label: String
    let kind: OutlineNodeKind
    var children: [OutlineNode]
    var display: String { label.isEmpty ? id : label }
}

/// The document as a tree: subgraphs nesting their member nodes + child subgraphs,
/// then loose nodes, plus the edge list. Built from the flowchart model so it
/// reflects real structure (used by the Organize panel).
struct OutlineTree {
    var roots: [OutlineNode]
    var edges: [OutlineEdge]

    @MainActor static func from(_ store: LiveEditorStore) -> OutlineTree {
        guard let doc = store.editor?.document, case .flowchart(let model) = doc.payload else {
            return .init(roots: [], edges: [])
        }
        return fromGraph(model)
    }

    static func fromGraph(_ model: original_src_types.MermaidGraph) -> OutlineTree {
        var nodeLabels: [String: String] = [:]
        for (id, node) in model.nodesInOrder { nodeLabels[id] = node.label }

        var nestedSubgraphIDs = Set<String>()
        var memberNodeIDs = Set<String>()
        func collect(_ sg: original_src_types.MermaidSubgraph) {
            for child in sg.children { nestedSubgraphIDs.insert(child.id); collect(child) }
            for nid in sg.nodeIds { memberNodeIDs.insert(nid) }
        }
        for sg in model.subgraphs { collect(sg) }

        func build(_ sg: original_src_types.MermaidSubgraph) -> OutlineNode {
            var children: [OutlineNode] = sg.children.map(build)
            for nid in sg.nodeIds {
                children.append(OutlineNode(id: nid, label: nodeLabels[nid] ?? nid, kind: .node, children: []))
            }
            return OutlineNode(id: sg.id, label: sg.label, kind: .subgraph, children: children)
        }

        var roots: [OutlineNode] = []
        for sg in model.subgraphs where !nestedSubgraphIDs.contains(sg.id) {
            roots.append(build(sg))
        }
        for (id, node) in model.nodesInOrder where !memberNodeIDs.contains(id) {
            roots.append(OutlineNode(id: id, label: node.label, kind: .node, children: []))
        }
        let edges = model.edges.enumerated().map { i, e in
            OutlineEdge(id: "\(e.source)->\(e.target)#\(i)", from: e.source, to: e.target, label: e.label)
        }
        return .init(roots: roots, edges: edges)
    }
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

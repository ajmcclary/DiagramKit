//
//  SettingsMutationsCatalogTab.swift
//  DiagramPlayground
//
//  Settings ▸ Mutations Catalog — real MutationCatalog data grouped
//  Node/Edge/Subgraph (transcription §5.6). `entry.label` is the mono API string.
//

import SwiftUI

struct SettingsMutationsCatalogTab: View {
    @Environment(\.playgroundTokens) private var tokens
    private let groups: [MutationCatalogEntry.Group] = [.node, .edge, .subgraph]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Mutations Catalog", subtitle: "Searchable, grouped reference.")
            ForEach(groups, id: \.self) { group in
                let entries = MutationCatalog.all.filter { $0.group == group }
                if !entries.isEmpty {
                    Text(group.label.uppercased()).font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
                        .foregroundStyle(color(for: group)).padding(.top, 6).padding(.bottom, 8)
                    SettingsGroupCard {
                        ForEach(entries) { entry in
                            HStack(spacing: 10) {
                                Image(systemName: icon(for: entry)).font(.system(size: 13))
                                    .foregroundStyle(color(for: group)).frame(width: 16)
                                Text(displayName(entry)).font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg1)
                                Spacer()
                                Text(entry.label).font(PlaygroundFont.mono(11.5)).foregroundStyle(tokens.palette.catCyan)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                        }
                    }.padding(.bottom, 12)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func color(for group: MutationCatalogEntry.Group) -> Color {
        switch group {
        case .edge: return tokens.palette.catCyan
        default: return tokens.palette.accentSecondary
        }
    }

    private func displayName(_ e: MutationCatalogEntry) -> String {
        switch e.id {
        case "insertNode": return "Add node"
        case "setLabel": return "Edit label"
        case "deleteElement": return "Remove node"
        case "insertEdge": return "Add edge"
        case "groupIntoSubgraph": return "Create / move subgraph"
        default: return e.id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func icon(for e: MutationCatalogEntry) -> String {
        switch e.id {
        case "insertNode", "insertEdge": return "plus.circle"
        case "deleteElement": return "minus.circle"
        case "setLabel": return "pencil"
        case "groupIntoSubgraph": return "square.on.square"
        default: return "circle"
        }
    }
}

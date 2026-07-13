//
//  SettingsMutationsCatalogTab.swift
//  DiagramPlayground
//
//  Settings ▸ Mutations Catalog — real MutationCatalog data grouped
//  Node/Edge/Subgraph (transcription §5.6). `entry.label` is the mono API string.
//

import SwiftUI
import DesignKitThemes

struct SettingsMutationsCatalogTab: View {
    @Environment(\.designTheme) private var theme
    private let groups: [MutationCatalogEntry.Group] = [.node, .edge, .subgraph]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Mutations Catalog", subtitle: "Searchable, grouped reference.")
            ForEach(groups, id: \.self) { group in
                let entries = MutationCatalog.all.filter { $0.group == group }
                if !entries.isEmpty {
                    DSSectionHeader(group.label)
                        .padding(.top, Tokens.Spacing.xs).padding(.bottom, Tokens.Spacing.sm)
                    DSSettingGroup {
                        ForEach(entries) { entry in
                            HStack(spacing: Tokens.Spacing.smMd) {
                                DSIconView(icon(for: entry), size: Tokens.Size.Icon.micro, colorRole: group == .edge ? .info : .primary)
                                Text(displayName(entry)).dsFont(.caption).foregroundStyle(theme.colors.textPrimary.color)
                                Spacer()
                                Text(entry.label).dsFont(.code).foregroundStyle(theme.colors.info.color)
                            }
                            .padding(.horizontal, Tokens.Spacing.lg).padding(.vertical, Tokens.Spacing.sm)
                        }
                    }.padding(.bottom, 12)
                }
            }
            Spacer(minLength: 0)
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

    private func icon(for e: MutationCatalogEntry) -> DSIcon {
        switch e.id {
        case "insertNode", "insertEdge": return .add
        case "deleteElement": return .remove
        case "setLabel": return .node
        case "groupIntoSubgraph": return .subgraph
        default: return .diagram
        }
    }
}

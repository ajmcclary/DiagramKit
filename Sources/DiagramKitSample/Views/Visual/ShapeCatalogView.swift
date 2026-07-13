//
//  ShapeCatalogView.swift
//  DiagramPlayground
//
//  Searchable shape catalog grid, grouped Basic / Process /
//  Technical. Reused by the center toolbar (insert) and the node
//  menu (change shape) via the onSelect callback.
//

import SwiftUI
import DiagramKitModel
import DesignKitThemes

struct ShapeCatalogView: View {
    let theme: DiagramTheme
    let onSelect: (String) -> Void

    @SwiftUI.State private var query: String = ""
    @Environment(\.dsEnvironment) private var environment

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: DSTokens.Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            DSField("Search shapes", text: $query)
                .accessibilityIdentifier(A11yID.Visual.shapeCatalogSearch)

            ScrollView {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ForEach(ShapeCatalogCategory.allCases) { category in
                        section(title: category.title, items: category.items)
                    }
                } else {
                    let hits = ShapeCatalog.search(query)
                    if hits.isEmpty {
                        Text("No shapes match “\(query)”")
                            .dsFont(.caption2)
                            .foregroundStyle(environment.theme.colors.textSecondary.color)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, DSTokens.Spacing.xxl)
                    } else {
                        section(title: "Results", items: hits)
                    }
                }
            }
        }
        .padding(DSTokens.Spacing.md)
        .frame(width: 380, height: 420)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.shapeCatalog)
    }

    @ViewBuilder
    private func section(title: String, items: [ShapeCatalogItem]) -> some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.xs) {
            Text(title)
                .dsFont(.overline)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .padding(.top, DSTokens.Spacing.xs)
            LazyVGrid(columns: columns, spacing: DSTokens.Spacing.sm) {
                ForEach(items) { item in
                    cell(for: item)
                }
            }
        }
    }

    private func cell(for item: ShapeCatalogItem) -> some View {
        Button {
            onSelect(item.alias)
        } label: {
            VStack(spacing: DSTokens.Spacing.xxs) {
                ShapeThumbnail(alias: item.alias, theme: theme)
                Text(item.name)
                    .dsFont(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 76, height: 56)
            .background(
                RoundedRectangle(cornerRadius: DSTokens.Radius.sm, style: .continuous)
                    .fill(environment.theme.colors.element.color)
            )
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .help("\(item.name) (\(item.alias))")
        .accessibilityIdentifier(A11yID.Visual.shapeCell(item.alias))
    }
}

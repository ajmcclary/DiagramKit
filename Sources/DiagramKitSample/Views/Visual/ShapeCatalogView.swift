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
    @Environment(\.designTheme) private var appTheme

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: Tokens.Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
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
                            .foregroundStyle(appTheme.colors.textSecondary.color)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, Tokens.Spacing.xxl)
                    } else {
                        section(title: "Results", items: hits)
                    }
                }
            }
        }
        .padding(Tokens.Spacing.md)
        .frame(width: 380, height: 420)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.shapeCatalog)
    }

    @ViewBuilder
    private func section(title: String, items: [ShapeCatalogItem]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text(title)
                .dsFont(.overline)
                .foregroundStyle(appTheme.colors.textSecondary.color)
                .padding(.top, Tokens.Spacing.xs)
            LazyVGrid(columns: columns, spacing: Tokens.Spacing.sm) {
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
            VStack(spacing: Tokens.Spacing.xxs) {
                ShapeThumbnail(alias: item.alias, theme: theme)
                Text(item.name)
                    .dsFont(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 76, height: 56)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM, style: .continuous)
                    .fill(appTheme.colors.element.color)
            )
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .help("\(item.name) (\(item.alias))")
        .accessibilityIdentifier(A11yID.Visual.shapeCell(item.alias))
    }
}

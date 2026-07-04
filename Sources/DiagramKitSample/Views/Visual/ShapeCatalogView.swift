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

struct ShapeCatalogView: View {
    let theme: DiagramTheme
    let onSelect: (String) -> Void

    @SwiftUI.State private var query: String = ""

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search shapes", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
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
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        section(title: "Results", items: hits)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 380, height: 420)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.shapeCatalog)
    }

    @ViewBuilder
    private func section(title: String, items: [ShapeCatalogItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            LazyVGrid(columns: columns, spacing: 8) {
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
            VStack(spacing: 4) {
                ShapeThumbnail(alias: item.alias, theme: theme)
                Text(item.name)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 76, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .help("\(item.name) (\(item.alias))")
        .accessibilityIdentifier(A11yID.Visual.shapeCell(item.alias))
    }
}

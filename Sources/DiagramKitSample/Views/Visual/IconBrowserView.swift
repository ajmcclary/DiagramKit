//
//  IconBrowserView.swift
//  DiagramPlayground
//
//  Searchable Font Awesome icon grid (SF Symbol previews — the same
//  glyphs the CG renderer draws). onSelect receives the FA name.
//

import SwiftUI
import DesignKitThemes

struct IconBrowserView: View {
    let onSelect: (String) -> Void

    @SwiftUI.State private var query: String = ""
    @Environment(\.designTheme) private var theme

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: Tokens.Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            DSField("Search icons", text: $query)
                .accessibilityIdentifier(A11yID.Visual.iconBrowserSearch)

            ScrollView {
                let hits = IconCatalog.search(query)
                if hits.isEmpty {
                    Text("No icons match “\(query)”")
                        .dsFont(.caption2)
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Tokens.Spacing.xxl)
                } else {
                    LazyVGrid(columns: columns, spacing: Tokens.Spacing.sm) {
                        ForEach(hits) { item in
                            Button {
                                onSelect(item.faName)
                            } label: {
                                VStack(spacing: Tokens.Spacing.xxs) {
                                    Label(item.faName, systemImage: item.sfSymbol)
                                        .labelStyle(.iconOnly)
                                        .dsFont(.headline)
                                        .frame(height: Tokens.Size.Icon.md)
                                    Text(item.faName)
                                        .dsFont(.caption2)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(width: 64, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM, style: .continuous)
                                        .fill(theme.colors.element.color)
                                )
                            }
                            .buttonStyle(.ds(role: .ghost, size: .compact))
                            .help(item.faName)
                            .accessibilityIdentifier(A11yID.Visual.iconCell(item.faName))
                        }
                    }
                }
            }
        }
        .padding(Tokens.Spacing.md)
        .frame(width: 340, height: 400)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.iconBrowser)
    }
}

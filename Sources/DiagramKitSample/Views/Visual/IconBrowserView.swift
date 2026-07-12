//
//  IconBrowserView.swift
//  DiagramPlayground
//
//  Searchable Font Awesome icon grid (SF Symbol previews — the same
//  glyphs the CG renderer draws). onSelect receives the FA name.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct IconBrowserView: View {
    let onSelect: (String) -> Void

    @SwiftUI.State private var query: String = ""
    @Environment(\.dsEnvironment) private var environment

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: DSTokens.Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            DSField("Search icons", text: $query)
                .accessibilityIdentifier(A11yID.Visual.iconBrowserSearch)

            ScrollView {
                let hits = IconCatalog.search(query)
                if hits.isEmpty {
                    Text("No icons match “\(query)”")
                        .dsFont(.caption2)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, DSTokens.Spacing.xxl)
                } else {
                    LazyVGrid(columns: columns, spacing: DSTokens.Spacing.sm) {
                        ForEach(hits) { item in
                            Button {
                                onSelect(item.faName)
                            } label: {
                                VStack(spacing: DSTokens.Spacing.xxs) {
                                    Label(item.faName, systemImage: item.sfSymbol)
                                        .labelStyle(.iconOnly)
                                        .dsFont(.headline)
                                        .frame(height: DSTokens.Icon.md)
                                    Text(item.faName)
                                        .dsFont(.caption2)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(width: 64, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: DSTokens.Radius.sm, style: .continuous)
                                        .fill(environment.theme.colors.element.color)
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
        .padding(DSTokens.Spacing.md)
        .frame(width: 340, height: 400)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.iconBrowser)
    }
}

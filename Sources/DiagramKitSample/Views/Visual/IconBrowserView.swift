//
//  IconBrowserView.swift
//  DiagramPlayground
//
//  Searchable Font Awesome icon grid (SF Symbol previews — the same
//  glyphs the CG renderer draws). onSelect receives the FA name.
//

import SwiftUI

struct IconBrowserView: View {
    let onSelect: (String) -> Void

    @SwiftUI.State private var query: String = ""

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search icons", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .accessibilityIdentifier(A11yID.Visual.iconBrowserSearch)

            ScrollView {
                let hits = IconCatalog.search(query)
                if hits.isEmpty {
                    Text("No icons match “\(query)”")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(hits) { item in
                            Button {
                                onSelect(item.faName)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: item.sfSymbol)
                                        .font(.system(size: 18))
                                        .frame(height: 24)
                                    Text(item.faName)
                                        .font(.system(size: 8))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(width: 64, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.gray.opacity(0.06))
                                )
                            }
                            .buttonStyle(.plain)
                            .help(item.faName)
                            .accessibilityIdentifier(A11yID.Visual.iconCell(item.faName))
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 340, height: 400)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.iconBrowser)
    }
}

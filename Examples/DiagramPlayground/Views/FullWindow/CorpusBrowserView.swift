//
//  CorpusBrowserView.swift
//  DiagramPlayground
//
//  Phase 8 / Task 8.5 — full-window corpus browser. Header subhead
//  + search field + four facet rows (Family / Format / Diagnostic
//  / Linux) above a LazyVGrid of CorpusThumbnail cards. Clicking a
//  card calls store.openCorpusEntry(_:) which sets the source +
//  format and switches workspaceMode back to .split.
//

import SwiftUI
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct CorpusBrowserView: View {
    @Bindable var store: LiveEditorStore

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 180), spacing: 12)
    ]

    var body: some View {
        let index = CorpusIndex.shared
        let filtered = index.filtered(
            search: store.corpusSearch,
            category: store.corpusCategoryFilter,
            format: store.corpusFormatFilter,
            diagnostic: store.corpusDiagnosticFilter,
            linux: store.corpusLinuxFilter
        )
        VStack(spacing: 0) {
            header(index: index)
            Divider()
            searchField
            facetRows(index: index)
            Divider()
            grid(filtered: filtered)
                .frame(maxHeight: .infinity)
        }
        .background(Color(store.theme.background))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("corpus.browser.grid")
    }

    // MARK: - Header

    private func header(index: CorpusIndex) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "books.vertical")
                .foregroundStyle(.tint)
            Text("Corpus")
                .font(.system(size: 13, weight: .semibold))
            Text("· \(index.entries.count) entries · \(index.categoryCounts.keys.count) families")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                store.dismissFullScreen()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Filter corpus by id, name, or category", text: Binding(
                get: { store.corpusSearch },
                set: { store.setCorpusSearch($0) }
            ))
            .textFieldStyle(.plain)
            .accessibilityIdentifier("corpus.browser.search")
            if !store.corpusSearch.isEmpty {
                Button {
                    store.setCorpusSearch("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Facet rows

    private func facetRows(index: CorpusIndex) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            facetRow(label: "Family") {
                allChip(isOn: store.corpusCategoryFilter == nil) {
                    store.setCorpusCategoryFilter(nil)
                }
                ForEach(topCategories(index: index), id: \.self) { category in
                    chip(
                        text: "\(category) · \(index.categoryCounts[category] ?? 0)",
                        isOn: store.corpusCategoryFilter == category,
                        id: "corpus.facet.family.\(category)"
                    ) {
                        store.setCorpusCategoryFilter(
                            store.corpusCategoryFilter == category ? nil : category
                        )
                    }
                }
            }
            facetRow(label: "Format") {
                allChip(isOn: store.corpusFormatFilter == nil) {
                    store.setCorpusFormatFilter(nil)
                }
                ForEach(Array(index.formatCounts.keys.sorted()), id: \.self) { format in
                    chip(
                        text: "\(format) · \(index.formatCounts[format] ?? 0)",
                        isOn: store.corpusFormatFilter == format,
                        id: "corpus.facet.format.\(format)"
                    ) {
                        store.setCorpusFormatFilter(
                            store.corpusFormatFilter == format ? nil : format
                        )
                    }
                }
            }
            facetRow(label: "Diag") {
                allChip(isOn: store.corpusDiagnosticFilter == nil) {
                    store.setCorpusDiagnosticFilter(nil)
                }
                ForEach(CorpusEntry.DiagnosticFacet.allCases, id: \.self) { facet in
                    chip(
                        text: "\(facet.label) · \(index.diagnosticFacetCounts[facet] ?? 0)",
                        isOn: store.corpusDiagnosticFilter == facet,
                        id: "corpus.facet.diag.\(facet.rawValue)"
                    ) {
                        store.setCorpusDiagnosticFilter(
                            store.corpusDiagnosticFilter == facet ? nil : facet
                        )
                    }
                }
            }
            facetRow(label: "Linux") {
                allChip(isOn: store.corpusLinuxFilter == nil) {
                    store.setCorpusLinuxFilter(nil)
                }
                ForEach(CorpusEntry.LinuxFacet.allCases, id: \.self) { facet in
                    chip(
                        text: "\(facet.label) · \(index.linuxFacetCounts[facet] ?? 0)",
                        isOn: store.corpusLinuxFilter == facet,
                        id: "corpus.facet.linux.\(facet.rawValue)"
                    ) {
                        store.setCorpusLinuxFilter(
                            store.corpusLinuxFilter == facet ? nil : facet
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func facetRow<Chips: View>(label: String, @ViewBuilder chips: () -> Chips) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) { chips() }
            }
        }
    }

    private func allChip(isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("All")
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(isOn ? Color.accentColor.opacity(0.22) : Color.gray.opacity(0.12))
                )
                .foregroundStyle(isOn ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    private func chip(text: String, isOn: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(isOn ? Color.accentColor.opacity(0.22) : Color.gray.opacity(0.12))
                )
                .foregroundStyle(isOn ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .a11yToggle(label: LocalizedStringKey(text), isOn: isOn, id: id)
    }

    private func topCategories(index: CorpusIndex) -> [String] {
        Array(
            index.categoryCounts
                .sorted { $0.value > $1.value }
                .prefix(12)
                .map(\.key)
        )
    }

    // MARK: - Grid

    private func grid(filtered: [CorpusEntry]) -> some View {
        ScrollView {
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No corpus entries match the current filters")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(filtered) { entry in
                        Button {
                            store.openCorpusEntry(entry)
                        } label: {
                            CorpusThumbnail(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
        }
    }
}

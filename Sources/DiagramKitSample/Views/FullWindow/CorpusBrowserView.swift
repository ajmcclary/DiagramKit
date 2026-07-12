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
import DiagramKitSampleDesignSystem

struct CorpusBrowserView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

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
            separator
            searchField
            facetRows(index: index)
            separator
            grid(filtered: filtered)
                .frame(maxHeight: .infinity)
        }
        .background(environment.theme.colors.windowBackground.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("corpus.browser.grid")
    }

    // MARK: - Header

    private func header(index: CorpusIndex) -> some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            DSIconView(.diagram)
            Text("Corpus")
                .dsFont(.headline)
            Text("· \(index.entries.count) entries · \(index.categoryCounts.keys.count) families")
                .dsFont(.caption2)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
            Spacer()
            HeaderCloseButton { store.dismissFullScreen() }
        }
        .padding(.horizontal, DSTokens.Spacing.lg)
        .padding(.vertical, DSTokens.Spacing.sm)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: DSTokens.Spacing.xs) {
            DSIconView(.search, size: DSTokens.Icon.micro, colorRole: .muted)
            TextField("Filter corpus by id, name, or category", text: Binding(
                get: { store.corpusSearch },
                set: { store.setCorpusSearch($0) }
            ))
            .textFieldStyle(.plain)
            .accessibilityIdentifier("corpus.browser.search")
            if !store.corpusSearch.isEmpty {
                DSIconButton(.close, label: "Clear corpus search") {
                    store.setCorpusSearch("")
                }
            }
        }
        .padding(.horizontal, DSTokens.Spacing.sm)
        .padding(.vertical, DSTokens.Spacing.xs)
        .background(environment.theme.colors.element.color, in: RoundedRectangle(cornerRadius: DSTokens.Radius.sm))
        .padding(.horizontal, DSTokens.Spacing.lg)
        .padding(.vertical, DSTokens.Spacing.xs)
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
        .padding(.horizontal, DSTokens.Spacing.lg)
        .padding(.bottom, DSTokens.Spacing.sm)
    }

    @ViewBuilder
    private func facetRow<Chips: View>(label: String, @ViewBuilder chips: () -> Chips) -> some View {
        HStack(alignment: .center, spacing: DSTokens.Spacing.sm) {
            Text(label)
                .dsFont(.overline)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .frame(width: 48, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSTokens.Spacing.xxs) { chips() }
            }
        }
    }

    private func allChip(isOn: Bool, action: @escaping () -> Void) -> some View {
        DSChip(isSelected: isOn, action: action) {
            Text("All").dsFont(.badge)
        }
    }

    private func chip(text: String, isOn: Bool, id: String, action: @escaping () -> Void) -> some View {
        DSChip(isSelected: isOn, action: action) {
            Text(text).dsFont(.badge)
        }
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
                ContentUnavailableView {
                    Label { Text("No Matches") } icon: { DSIconView(.search) }
                } description: {
                    Text("Adjust or clear the corpus filters to see diagrams.")
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
                        .buttonStyle(.ds(role: .ghost, size: .compact))
                    }
                }
                .padding(14)
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(height: DSTokens.Stroke.hairline)
    }
}

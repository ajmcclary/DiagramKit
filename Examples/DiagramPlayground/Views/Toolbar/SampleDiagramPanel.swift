//
//  SampleDiagramPanel.swift
//  DiagramPlayground
//
//  Compact searchable sample diagram picker.
//  Shows sample diagrams grouped by category with a search field,
//  matching Live Editor ergonomics in a popover/sheet.
//

import SwiftUI
import DiagramKit

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SampleDiagramPanel: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var searchText: String = ""
    @SwiftUI.State private var expandedCategories: Set<String> = []
    @SwiftUI.State private var selectedDiagramID: String?

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Diagram list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if searchText.isEmpty {
                        // Categorized view
                        categoryList
                    } else {
                        // Flat search results
                        searchResults
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(store.theme.background))
        .onAppear {
            // Auto-expand first few categories
            let firstCategories = TestDiagrams.orderedCategories.prefix(4)
            expandedCategories = Set(firstCategories.map(\.id))
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(store.theme.effectiveMuted()))
                .font(.system(size: 14))
                .accessibilityHidden(true)

            TextField("Search samples...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(Color(store.theme.foreground))
                .a11yIdentifier(A11yID.Pickers.sampleSearch)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .a11y(label: "Clear search", id: A11yID.Pickers.sampleSearchClear)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(store.theme.foreground).opacity(0.06))
        )
    }

    // MARK: - Category list

    private var categoryList: some View {
        ForEach(TestDiagrams.orderedCategories) { category in
            let diagrams = TestDiagrams.diagrams(for: category.id)
            if !diagrams.isEmpty {
                categorySection(category: category, diagrams: diagrams)
            }
        }
    }

    private func categorySection(
        category: TestDiagramCategory,
        diagrams: [TestDiagram]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header (tappable to expand/collapse)
            Button {
                if expandedCategories.contains(category.id) {
                    expandedCategories.remove(category.id)
                } else {
                    expandedCategories.insert(category.id)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expandedCategories.contains(category.id)
                        ? "chevron.down"
                        : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                        .accessibilityHidden(true)

                    Text(category.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(store.theme.foreground))

                    Text("(\(diagrams.count))")
                        .font(.system(size: 11))
                        .foregroundColor(Color(store.theme.effectiveMuted()))

                    Spacer()
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Diagram items
            if expandedCategories.contains(category.id) {
                VStack(spacing: 2) {
                    ForEach(diagrams) { diagram in
                        diagramRow(diagram)
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 6)
            }
        }
    }

    private func diagramRow(_ diagram: TestDiagram) -> some View {
        let isSelected = selectedDiagramID == diagram.id
        let alternateFormats = Self.alternateFormats(for: diagram)
        let badges = Self.statusBadges(for: diagram)

        return VStack(alignment: .leading, spacing: 4) {
            Button {
                loadDiagram(diagram, format: .mermaid)
            } label: {
                HStack(spacing: 8) {
                    Text(diagram.name)
                        .font(.system(size: 13))
                        .foregroundColor(
                            isSelected
                                ? Color(store.theme.effectiveAccent())
                                : Color(store.theme.foreground)
                        )
                        .lineLimit(1)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(store.theme.effectiveAccent()))
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected
                            ? Color(store.theme.effectiveAccent()).opacity(0.08)
                            : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !alternateFormats.isEmpty || !badges.isEmpty {
                HStack(spacing: 4) {
                    ForEach(alternateFormats, id: \.self) { format in
                        formatChip(diagram: diagram, format: format)
                    }
                    ForEach(badges, id: \.text) { badge in
                        statusChip(badge)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 12)
            }
        }
    }

    private func statusChip(_ badge: SampleStatusBadge) -> some View {
        HStack(spacing: 3) {
            Image(systemName: badge.systemImage)
                .font(.system(size: 9, weight: .medium))
                .accessibilityHidden(true)
            Text(badge.text)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundColor(badge.role.foreground)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(badge.role.background)
        )
        .help(badge.tooltip)
    }

    private func formatChip(diagram: TestDiagram, format: SourceFormat) -> some View {
        Button {
            loadDiagram(diagram, format: format)
        } label: {
            Text(format.shortName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(store.theme.effectiveAccent()))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(store.theme.effectiveAccent()).opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private func loadDiagram(_ diagram: TestDiagram, format: SourceFormat) {
        guard let source = diagram.source(for: format.rawValue) else { return }
        selectedDiagramID = diagram.id
        // Surface the corpus annotations so the editor pane can show
        // expected vs actual diagnostics and any unsupportedNote. Set
        // BEFORE setSource — the .system-origin setSource preserves
        // metadata; .user/.loader paths clear it.
        store.setLoadedCorpusMetadata(CorpusMetadata(
            expectedDiagnostics: diagram.expectedDiagnostics,
            unsupportedNote: diagram.unsupportedNote
        ))
        store.setSource(source, format: format, origin: .system)
    }

    /// Format keys present in the corpus entry beyond the implicit
    /// top-level Mermaid source.
    private static func alternateFormats(for diagram: TestDiagram) -> [SourceFormat] {
        guard let keys = diagram.sources?.keys else { return [] }
        return keys
            .compactMap { SourceFormat(rawValue: $0) }
            .filter { $0 != .mermaid }
            .sorted { $0.shortName < $1.shortName }
    }

    /// Corpus-status chips surfaced beside the diagram name: missing
    /// snapshot baselines, expected diagnostics, or unsupported-note
    /// annotations from `test-diagrams.json`.
    private static func statusBadges(for diagram: TestDiagram) -> [SampleStatusBadge] {
        var badges: [SampleStatusBadge] = []

        if let skips = diagram.skipSnapshots, !skips.isEmpty {
            badges.append(SampleStatusBadge(
                text: "no \(skips.joined(separator: "/"))",
                systemImage: "camera.metering.unknown",
                role: .warning,
                tooltip: "Snapshot baselines skipped for: \(skips.joined(separator: ", "))"
            ))
        }

        if let diagnostics = diagram.expectedDiagnostics, !diagnostics.isEmpty {
            badges.append(SampleStatusBadge(
                text: "\(diagnostics.count) diag",
                systemImage: "exclamationmark.bubble",
                role: .info,
                tooltip: "Expected importer diagnostics: \(diagnostics.count)"
            ))
        }

        if diagram.unsupportedNote != nil {
            badges.append(SampleStatusBadge(
                text: "unsupported",
                systemImage: "minus.circle",
                role: .muted,
                tooltip: diagram.unsupportedNote ?? "Partially supported by importers"
            ))
        }

        return badges
    }

    // MARK: - Search results

    private var searchResults: some View {
        let results = TestDiagrams.all.filter { diagram in
            let query = searchText.lowercased()
            return diagram.name.lowercased().contains(query)
                || diagram.id.lowercased().contains(query)
                || diagram.category.lowercased().contains(query)
        }

        return Group {
            if results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                        .accessibilityHidden(true)
                    Text("No samples match \"\(searchText)\"")
                        .font(.system(size: 13))
                        .foregroundColor(Color(store.theme.effectiveMuted()))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(results) { diagram in
                    diagramRow(diagram)
                }
            }
        }
    }
}

// MARK: - Status badge

/// Small chip metadata for the corpus indicators next to each sample row.
struct SampleStatusBadge {
    let text: String
    let systemImage: String
    let role: Role
    let tooltip: String

    enum Role {
        case warning
        case info
        case muted

        var foreground: Color {
            switch self {
            case .warning: return .orange
            case .info:    return .blue
            case .muted:   return .gray
            }
        }

        var background: Color {
            switch self {
            case .warning: return .orange.opacity(0.12)
            case .info:    return .blue.opacity(0.12)
            case .muted:   return .gray.opacity(0.12)
            }
        }
    }
}

#if DEBUG && !DIAGRAMKIT_SWIFTPM
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
#Preview {
    let store = LiveEditorStore()
    return SampleDiagramPanel(store: store)
        .frame(width: 360, height: 480)
}
#endif

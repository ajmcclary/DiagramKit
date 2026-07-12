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
import DiagramKitSampleDesignSystem

struct SampleDiagramPanel: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var searchText: String = ""
    @SwiftUI.State private var expandedCategories: Set<String> = []
    @SwiftUI.State private var selectedDiagramID: String?
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        DSSurface(role: .panel) {
            VStack(spacing: 0) {
            // Search field
            searchField
                .padding(.horizontal, DSTokens.Spacing.md)
                .padding(.top, DSTokens.Spacing.md)
                .padding(.bottom, DSTokens.Spacing.sm)

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
                .padding(.horizontal, DSTokens.Spacing.md)
                .padding(.bottom, DSTokens.Spacing.md)
            }
            }
        }
        .onAppear {
            // Auto-expand first few categories
            let firstCategories = TestDiagrams.orderedCategories.prefix(4)
            expandedCategories = Set(firstCategories.map(\.id))
        }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            DSIconView(.search, size: DSTokens.Icon.micro, colorRole: .muted)

            TextField("Search samples...", text: $searchText)
                .textFieldStyle(.plain)
                .dsFont(.footnote)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
                .a11yIdentifier(A11yID.Pickers.sampleSearch)

            if !searchText.isEmpty {
                DSIconButton(.close, label: "Clear search") {
                    searchText = ""
                }
                .a11y(label: "Clear search", id: A11yID.Pickers.sampleSearchClear)
            }
        }
        .padding(DSTokens.Spacing.sm)
        .background { DSSurface(role: .sunken) { Color.clear } }
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
                HStack(spacing: DSTokens.Spacing.xs) {
                    DSIconView(
                        expandedCategories.contains(category.id)
                            ? .disclosureDown
                            : .disclosureRight,
                        size: DSTokens.Icon.indicator,
                        colorRole: .muted
                    )

                    Text(category.title)
                        .dsFont(.badge)
                        .foregroundStyle(environment.theme.colors.textPrimary.color)

                    Text("(\(diagrams.count))")
                        .dsFont(.caption2)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)

                    Spacer()
                }
                .padding(.vertical, DSTokens.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))

            // Diagram items
            if expandedCategories.contains(category.id) {
                VStack(spacing: DSTokens.Spacing.xxxs) {
                    ForEach(diagrams) { diagram in
                        diagramRow(diagram)
                    }
                }
                .padding(.leading, DSTokens.Spacing.lg)
                .padding(.bottom, DSTokens.Spacing.xs)
            }
        }
    }

    private func diagramRow(_ diagram: TestDiagram) -> some View {
        let isSelected = selectedDiagramID == diagram.id
        let alternateFormats = Self.alternateFormats(for: diagram)
        let badges = Self.statusBadges(for: diagram)

        return VStack(alignment: .leading, spacing: DSTokens.Spacing.xxs) {
            Button {
                loadDiagram(diagram, format: .mermaid)
            } label: {
                HStack(spacing: DSTokens.Spacing.sm) {
                    Text(diagram.name)
                        .dsFont(.footnote)
                        .foregroundStyle(
                            isSelected
                                ? environment.theme.colors.accent.color
                                : environment.theme.colors.textPrimary.color
                        )
                        .lineLimit(1)

                    Spacer()

                    if isSelected {
                        DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
                    }
                }
                .padding(.vertical, DSTokens.Spacing.xxs)
                .padding(.horizontal, DSTokens.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DSTokens.Radius.xs)
                        .fill(isSelected
                            ? environment.theme.colors.elementSelected.color
                            : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.ds(role: isSelected ? .secondary : .ghost, size: .compact))

            if !alternateFormats.isEmpty || !badges.isEmpty {
                HStack(spacing: DSTokens.Spacing.xxs) {
                    ForEach(alternateFormats, id: \.self) { format in
                        formatChip(diagram: diagram, format: format)
                    }
                    ForEach(badges, id: \.text) { badge in
                        statusChip(badge)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, DSTokens.Spacing.md)
            }
        }
    }

    private func statusChip(_ badge: SampleStatusBadge) -> some View {
        HStack(spacing: DSTokens.Stroke.thick) {
            DSIconView(
                badge.role.icon,
                size: DSTokens.Icon.indicator,
                colorRole: badge.role.iconColorRole
            )
            Text(badge.text)
                .dsFont(.badge)
        }
        .padding(.horizontal, DSTokens.Spacing.xs)
        .padding(.vertical, DSTokens.Spacing.xxxs)
        .foregroundStyle(badge.role.color(in: environment.theme))
        .background(
            RoundedRectangle(cornerRadius: DSTokens.Radius.xs)
                .fill(environment.theme.colors.element.color)
        )
        .help(badge.tooltip)
    }

    private func formatChip(diagram: TestDiagram, format: SourceFormat) -> some View {
        DSChip {
            loadDiagram(diagram, format: format)
        } label: {
            Text(format.shortName)
                .dsFont(.badge)
                .foregroundStyle(environment.theme.colors.accent.color)
        }
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
                role: .warning,
                tooltip: "Snapshot baselines skipped for: \(skips.joined(separator: ", "))"
            ))
        }

        if let diagnostics = diagram.expectedDiagnostics, !diagnostics.isEmpty {
            badges.append(SampleStatusBadge(
                text: "\(diagnostics.count) diag",
                role: .info,
                tooltip: "Expected importer diagnostics: \(diagnostics.count)"
            ))
        }

        if diagram.unsupportedNote != nil {
            badges.append(SampleStatusBadge(
                text: "unsupported",
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
                VStack(spacing: DSTokens.Spacing.sm) {
                    DSIconView(.search, size: DSTokens.Icon.md, colorRole: .muted)
                    Text("No samples match \"\(searchText)\"")
                        .dsFont(.footnote)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSTokens.Spacing.xxxl)
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
    let role: Role
    let tooltip: String

    enum Role {
        case warning
        case info
        case muted

        var icon: DSIcon {
            switch self {
            case .warning: .warning
            case .info: .diagnostics
            case .muted: .remove
            }
        }

        var iconColorRole: DSIconColorRole {
            switch self {
            case .warning: .warning
            case .info: .info
            case .muted: .muted
            }
        }

        func color(in theme: DSTheme) -> Color {
            switch self {
            case .warning: theme.colors.warning.color
            case .info: theme.colors.info.color
            case .muted: theme.colors.textSecondary.color
            }
        }
    }
}

#if DEBUG && !DIAGRAMKIT_SWIFTPM
#Preview {
    let store = LiveEditorStore()
    return SampleDiagramPanel(store: store)
        .frame(width: 360, height: 480)
}
#endif

//
//  DiagnosticsDrawer.swift
//  DiagramPlayground
//
//  Phase 6 / Task 6.2 — bottom drawer with four facet rows
//  (severity, tier, paired, category) plus a two-column body
//  (category list grouped by severity on the left, scrollable row
//  list on the right). Per-row Explain button triggers
//  DiagnosticExplainPopover via store.diagnosticExplainTarget.
//

import SwiftUI
import DiagramKitCommon
import DiagramKitSampleDesignSystem

struct DiagnosticsDrawer: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            facetRows
            separator
            body2col
        }
        .frame(height: 360)
        .background(environment.theme.colors.panelBackground.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Diagnostics.drawer)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            DSIconView(.diagnostics)
            Text("Diagnostics")
                .dsFont(.headline)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
            Text("· \(store.allDiagnostics.count)")
                .dsFont(.metric)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
            Spacer()
            DSIconButton(.disclosureDown, label: "Close diagnostics") {
                store.setDiagnosticsDrawerOpen(false)
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, DSTokens.Spacing.md)
        .padding(.vertical, DSTokens.Spacing.xs)
    }

    // MARK: - Facet rows

    private var facetRows: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.xxs) {
            facetRow(label: "Severity") {
                ForEach(DiagnosticsDrawerState.SeverityFilter.allCases, id: \.self) { value in
                    chip(
                        text: value.label,
                        isOn: store.state.diagDrawer.severity == value,
                        id: A11yID.Diagnostics.severityChip(value.rawValue)
                    ) {
                        store.setDiagnosticSeverityFilter(value)
                    }
                }
            }
            facetRow(label: "Tier") {
                ForEach(DiagnosticsDrawerState.TierFilter.allCases, id: \.self) { value in
                    chip(
                        text: value.label,
                        isOn: store.state.diagDrawer.tier == value,
                        id: A11yID.Diagnostics.tierChip(value.rawValue)
                    ) {
                        store.setDiagnosticTierFilter(value)
                    }
                }
            }
            facetRow(label: "Paired") {
                ForEach(DiagnosticsDrawerState.PairedFilter.allCases, id: \.self) { value in
                    chip(
                        text: value.label,
                        isOn: store.state.diagDrawer.paired == value,
                        id: A11yID.Diagnostics.pairedChip(value.rawValue)
                    ) {
                        store.setDiagnosticPairedFilter(value)
                    }
                }
            }
        }
        .padding(.horizontal, DSTokens.Spacing.md)
        .padding(.vertical, DSTokens.Spacing.xs)
    }

    @ViewBuilder
    private func facetRow<Chips: View>(label: String, @ViewBuilder chips: () -> Chips) -> some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            Text(label)
                .dsFont(.overline)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .frame(width: 56, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSTokens.Spacing.xxs) { chips() }
            }
        }
    }

    private func chip(text: String, isOn: Bool, id: String, action: @escaping () -> Void) -> some View {
        DSChip(isSelected: isOn, action: action) {
            Text(text).dsFont(.badge)
        }
        .a11yToggle(label: LocalizedStringKey(text), isOn: isOn, id: id)
    }

    // MARK: - 2-column body

    private var body2col: some View {
        HStack(spacing: 0) {
            categoryList
                .frame(width: 200)
            verticalSeparator
            rowList
        }
    }

    // MARK: - Category list (left)

    private var categoryList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                section(title: "Lossy transform (.warning)", categories: warningCategories)
                section(title: "Feature dropped (.unsupported)", categories: unsupportedCategories)
                section(title: "Informational (.info)", categories: infoCategories)
            }
            .padding(.vertical, DSTokens.Spacing.xs)
        }
        .accessibilityIdentifier(A11yID.Diagnostics.categoryList)
    }

    private var warningCategories: [DiagnosticCategory] {
        DiagnosticCategory.allCases.filter { $0.severity == .warning }
    }

    private var unsupportedCategories: [DiagnosticCategory] {
        DiagnosticCategory.allCases.filter { $0.severity == .unsupported }
    }

    private var infoCategories: [DiagnosticCategory] {
        DiagnosticCategory.allCases.filter { $0.severity == .info }
    }

    private func section(title: String, categories: [DiagnosticCategory]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .dsFont(.overline)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .padding(.horizontal, DSTokens.Spacing.sm)
                .padding(.vertical, DSTokens.Spacing.xxs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(environment.theme.colors.element.color)
            ForEach(categories, id: \.self) { cat in
                categoryButton(cat)
            }
        }
    }

    private func categoryButton(_ cat: DiagnosticCategory) -> some View {
        let isOn = store.state.diagDrawer.category == cat
        return Button {
            store.setDiagnosticCategoryFilter(isOn ? nil : cat)
        } label: {
            HStack {
                Text(cat.rawValue)
                    .dsFont(.caption2)
                Spacer()
                Text("\(count(for: cat))")
                    .dsFont(.metric)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            }
            .padding(.horizontal, DSTokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.ds(role: isOn ? .secondary : .ghost, size: .compact))
        .a11yToggle(
            label: LocalizedStringKey(cat.rawValue),
            isOn: isOn,
            id: A11yID.Diagnostics.categoryChip(cat.rawValue)
        )
    }

    private func count(for cat: DiagnosticCategory) -> Int {
        store.allDiagnostics.filter { $0.category == cat }.count
    }

    // MARK: - Row list (right)

    private var rowList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let rows = store.filteredDrawerDiagnostics
                if rows.isEmpty {
                    Text("No diagnostics match the current filters")
                        .dsFont(.caption2)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                        .padding(DSTokens.Spacing.md)
                } else {
                    ForEach(rows) { row in
                        rowView(row)
                    }
                }
            }
        }
        .accessibilityIdentifier(A11yID.Diagnostics.rowList)
    }

    private func rowView(_ row: DrawerDiagnostic) -> some View {
        HStack(alignment: .top, spacing: DSTokens.Spacing.sm) {
            DSIconView(
                row.editor.severity.dsIcon,
                size: DSTokens.Icon.micro,
                colorRole: row.editor.severity.dsIconColorRole
            )
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                Text(row.editor.message)
                    .dsFont(.caption2)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                    .lineLimit(2)
                HStack(spacing: DSTokens.Spacing.xs) {
                    DSCodeBadge(row.tier.label)
                    if let line = row.editor.line {
                        Text("line \(line)")
                            .dsFont(.metric)
                            .foregroundStyle(environment.theme.colors.textSecondary.color)
                    }
                    if let cat = row.category {
                        Text(cat.rawValue)
                            .dsFont(.badge)
                            .foregroundStyle(environment.theme.colors.accent.color)
                    }
                }
            }
            Spacer()
            Button("Explain") {
                store.presentExplain(for: row)
            }
            .buttonStyle(.ds(role: .secondary, size: .compact))
            .a11y(label: "Explain diagnostic", id: A11yID.Diagnostics.explainButton(forRow: row.id.uuidString))
        }
        .padding(.horizontal, DSTokens.Spacing.smMd)
        .padding(.vertical, DSTokens.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var separator: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(height: DSTokens.Stroke.hairline)
    }

    private var verticalSeparator: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(width: DSTokens.Stroke.hairline)
    }
}

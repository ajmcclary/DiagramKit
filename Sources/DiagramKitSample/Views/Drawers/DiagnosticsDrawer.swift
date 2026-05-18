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

struct DiagnosticsDrawer: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            facetRows
            Divider()
            body2col
        }
        .frame(height: 360)
        .background(.regularMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Diagnostics.drawer)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "exclamationmark.bubble")
                .foregroundStyle(.tint)
            Text("Diagnostics")
                .font(.system(size: 12, weight: .semibold))
            Text("· \(store.allDiagnostics.count)")
                .font(.system(size: 11, weight: .regular).monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                store.setDiagnosticsDrawerOpen(false)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Facet rows

    private var facetRows: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func facetRow<Chips: View>(label: String, @ViewBuilder chips: () -> Chips) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) { chips() }
            }
        }
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

    // MARK: - 2-column body

    private var body2col: some View {
        HStack(spacing: 0) {
            categoryList
                .frame(width: 200)
            Divider()
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
            .padding(.vertical, 6)
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
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.08))
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
                    .font(.system(size: 11, weight: isOn ? .semibold : .regular))
                Spacer()
                Text("\(count(for: cat))")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isOn ? Color.accentColor.opacity(0.16) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(12)
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
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: severityIcon(row.editor.severity))
                .foregroundStyle(severityColor(row.editor.severity))
                .font(.system(size: 11, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(row.editor.message)
                    .font(.system(size: 11))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(row.tier.label)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                    if let line = row.editor.line {
                        Text("line \(line)")
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if let cat = row.category {
                        Text(cat.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            Spacer()
            Button("Explain") {
                store.presentExplain(for: row)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .a11y(label: "Explain diagnostic", id: A11yID.Diagnostics.explainButton(forRow: row.id.uuidString))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
    }

    private func severityIcon(_ s: EditorDiagnostic.Severity) -> String {
        switch s {
        case .error:   return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    private func severityColor(_ s: EditorDiagnostic.Severity) -> Color {
        switch s {
        case .error:   return .red
        case .warning: return .orange
        case .info:    return .blue
        }
    }
}

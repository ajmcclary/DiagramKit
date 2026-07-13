//
//  CoverageMatrixView.swift
//  DiagramPlayground
//
//  Phase 8 / Task 8.3 — full-window 28 × 5 exporter-coverage matrix.
//  Column headers carry format chips with a host-star marker; row
//  headers carry the family glyph + display name. Each of the 140
//  cells reports its state via icon + color. Hovering a cell shows
//  CoverageTip with the family → format pair + state blurb.
//

import SwiftUI
import DiagramKitModel
import DesignKitThemes

struct CoverageMatrixView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    @SwiftUI.State private var hoveredCell: CoverageCell?

    private let rowHeight: CGFloat = 30
    private let columnWidth: CGFloat = 92
    private let leadingWidth: CGFloat = 200

    var body: some View {
        let provider = CoverageMatrixProvider()
        VStack(spacing: 0) {
            header(provider: provider)
            separator
            ScrollView([.vertical, .horizontal]) {
                grid(provider: provider)
            }
            .frame(maxHeight: .infinity)
            separator
            footer(provider: provider)
        }
        .background(theme.colors.windowBackground.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coverage.matrix.grid")
    }

    // MARK: - Header

    private func header(provider: CoverageMatrixProvider) -> some View {
        HStack(spacing: Tokens.Spacing.sm) {
            DSIconView(.diagram)
            Text("Coverage matrix")
                .dsFont(.headline)
            Text("· 28 families × 5 formats = 140 cells")
                .dsFont(.caption2)
                .foregroundStyle(theme.colors.textSecondary.color)
            Spacer()
            DSIconButton(.close, label: "Close coverage matrix") {
                store.dismissFullScreen()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.sm)
    }

    // MARK: - Grid

    private func grid(provider: CoverageMatrixProvider) -> some View {
        VStack(spacing: 0) {
            // Column header row
            HStack(spacing: 0) {
                Text("Family")
                    .dsFont(.overline)
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .frame(width: leadingWidth, alignment: .leading)
                    .padding(.leading, 12)
                ForEach(provider.formats) { format in
                    Text(format.shortName)
                        .dsFont(.overline)
                        .foregroundStyle(theme.colors.textSecondary.color)
                        .frame(width: columnWidth)
                }
            }
            .frame(height: 24)
            .background(theme.colors.element.color)

            // Body rows
            ForEach(provider.families, id: \.self) { family in
                row(family: family, provider: provider)
            }
        }
    }

    private func row(family: DiagramType, provider: CoverageMatrixProvider) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: Tokens.Spacing.xs) {
                DSIconView(.diagram, size: Tokens.Size.Icon.micro)
                Text(CoverageMatrixSeed.displayName(for: family))
                    .dsFont(.caption2)
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(1)
                Text("(\(family.rawValue))")
                    .dsFont(.code)
                    .foregroundStyle(theme.colors.textSecondary.color)
                Spacer()
            }
            .frame(width: leadingWidth, alignment: .leading)
            .padding(.leading, 12)
            ForEach(provider.formats) { format in
                cellView(family: family, format: format, provider: provider)
            }
        }
        .frame(height: rowHeight)
    }

    private func cellView(
        family: DiagramType,
        format: SourceFormat,
        provider: CoverageMatrixProvider
    ) -> some View {
        let cell = CoverageCell(family: family, format: format, state: provider.state(family: family, format: format))
        let tint = color(for: cell.state)
        return DSIconView(icon(for: cell.state), size: Tokens.Size.Icon.micro, colorRole: iconRole(for: cell.state))
            .frame(width: columnWidth, height: rowHeight)
            .background(
                Rectangle()
                    .fill(hoveredCell == cell ? tint.opacity(Tokens.Opacity.light) : .clear)
            )
            .contentShape(Rectangle())
            .onHover { isHover in
                hoveredCell = isHover ? cell : nil
            }
            .help("\(CoverageMatrixSeed.displayName(for: family)) → \(format.shortName) · \(cell.state.label)")
            .accessibilityIdentifier("coverage.cell.\(cell.id)")
    }

    private func color(for state: CoverageCellState) -> Color {
        switch state {
        case .ok:          return theme.colors.success.color
        case .lossy:       return theme.colors.warning.color
        case .unsupported: return theme.colors.iconDisabled.color
        case .partial:     return theme.colors.warning.color
        case .host:        return theme.colors.accent.color
        }
    }

    // MARK: - Footer

    private func footer(provider: CoverageMatrixProvider) -> some View {
        HStack(spacing: Tokens.Spacing.sm) {
            ForEach(CoverageCellState.allCases, id: \.self) { state in
                let count = provider.counts[state] ?? 0
                HStack(spacing: Tokens.Spacing.xxs) {
                    DSIconView(icon(for: state), size: Tokens.Size.Icon.micro, colorRole: iconRole(for: state))
                    Text("\(state.label) · \(count)").dsFont(.badge)
                }
            }
            Spacer()
            if let hovered = hoveredCell {
                tip(for: hovered)
            }
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.vertical, Tokens.Spacing.xs)
    }

    private func icon(for state: CoverageCellState) -> DSIcon {
        switch state {
        case .ok: .success
        case .lossy, .partial: .warning
        case .unsupported: .error
        case .host: .diagram
        }
    }

    private func iconRole(for state: CoverageCellState) -> DSIconColorRole {
        switch state {
        case .ok: .success
        case .lossy, .partial: .warning
        case .unsupported: .disabled
        case .host: .primary
        }
    }

    private func tip(for cell: CoverageCell) -> some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            Text("\(CoverageMatrixSeed.displayName(for: cell.family)) → \(cell.format.shortName)")
                .dsFont(.headline)
            Text("·")
                .foregroundStyle(theme.colors.textSecondary.color)
            Text(blurb(for: cell.state))
                .dsFont(.caption2)
                .foregroundStyle(theme.colors.textSecondary.color)
        }
    }

    private func blurb(for state: CoverageCellState) -> String {
        switch state {
        case .host:        return "native source format"
        case .ok:          return "registered exporter, clean round-trip"
        case .lossy:       return "registered exporter — may surface typed losses"
        case .partial:     return "subset of constructs supported"
        case .unsupported: return "exporter does not register this family"
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(theme.colors.borderVariant.color)
            .frame(height: Tokens.Shape.strokeHairline)
    }
}

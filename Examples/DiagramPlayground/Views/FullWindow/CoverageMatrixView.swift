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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct CoverageMatrixView: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var hoveredCell: CoverageCell?

    private let rowHeight: CGFloat = 30
    private let columnWidth: CGFloat = 92
    private let leadingWidth: CGFloat = 200

    var body: some View {
        let provider = CoverageMatrixProvider()
        VStack(spacing: 0) {
            header(provider: provider)
            Divider()
            ScrollView([.vertical, .horizontal]) {
                grid(provider: provider)
            }
            .frame(maxHeight: .infinity)
            Divider()
            footer(provider: provider)
        }
        .background(Color(store.theme.background))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coverage.matrix.grid")
    }

    // MARK: - Header

    private func header(provider: CoverageMatrixProvider) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "tablecells")
                .foregroundStyle(.tint)
            Text("Coverage matrix")
                .font(.system(size: 13, weight: .semibold))
            Text("· 28 families × 5 formats = 140 cells")
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

    // MARK: - Grid

    private func grid(provider: CoverageMatrixProvider) -> some View {
        VStack(spacing: 0) {
            // Column header row
            HStack(spacing: 0) {
                Text("Family")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: leadingWidth, alignment: .leading)
                    .padding(.leading, 12)
                ForEach(provider.formats) { format in
                    Text(format.shortName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: columnWidth)
                }
            }
            .frame(height: 24)
            .background(Color.gray.opacity(0.06))

            // Body rows
            ForEach(provider.families, id: \.self) { family in
                row(family: family, provider: provider)
            }
        }
    }

    private func row(family: DiagramType, provider: CoverageMatrixProvider) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: CoverageMatrixSeed.glyph(for: family))
                    .frame(width: 18)
                    .foregroundStyle(.tint)
                Text(CoverageMatrixSeed.displayName(for: family))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text("(\(family.rawValue))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
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
        return Image(systemName: cell.state.sfSymbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: columnWidth, height: rowHeight)
            .background(
                Rectangle()
                    .fill(hoveredCell == cell ? tint.opacity(0.18) : Color.clear)
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
        case .ok:          return .green
        case .lossy:       return .orange
        case .unsupported: return .secondary
        case .partial:     return .yellow
        case .host:        return Color.accentColor
        }
    }

    // MARK: - Footer

    private func footer(provider: CoverageMatrixProvider) -> some View {
        HStack(spacing: 8) {
            ForEach(CoverageCellState.allCases, id: \.self) { state in
                let count = provider.counts[state] ?? 0
                KPill(
                    text: "\(state.label) · \(count)",
                    systemImage: state.sfSymbol,
                    tone: pillTone(for: state)
                )
            }
            Spacer()
            if let hovered = hoveredCell {
                tip(for: hovered)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func pillTone(for state: CoverageCellState) -> KPillTone {
        switch state {
        case .ok:          return .ok
        case .lossy:       return .warn
        case .unsupported: return .neutral
        case .partial:     return .warn
        case .host:        return .accent
        }
    }

    private func tip(for cell: CoverageCell) -> some View {
        HStack(spacing: 4) {
            Text("\(CoverageMatrixSeed.displayName(for: cell.family)) → \(cell.format.shortName)")
                .font(.system(size: 11, weight: .semibold))
            Text("·")
                .foregroundStyle(.secondary)
            Text(blurb(for: cell.state))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
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
}

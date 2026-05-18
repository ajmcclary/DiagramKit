//
//  ThreeFormatView.swift
//  DiagramPlayground
//
//  Phase 9 / Task 9.1 — full-window cross-format triptych. Three
//  columns (Mermaid / D2 / DOT) each driven by the live store
//  source: header pill, exported source, and per-format
//  diagnostics list. Footer shows a round-trip pill summarising
//  whether all three formats share the same loss surface.
//

import SwiftUI
import DiagramKit
import DiagramKitCommon
import DiagramKitExport
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, *)
struct ThreeFormatView: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var columns: [FormatPane] = []

    private struct FormatPane: Identifiable {
        let format: SourceFormat
        let result: DiagramExportResult?
        let error: String?
        var id: String { format.rawValue }
    }

    private let targets: [SourceFormat] = [.mermaid, .d2, .graphviz]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            triptych
                .frame(maxHeight: .infinity)
            Divider()
            footer
        }
        .background(Color(store.theme.background))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("crossformat.view")
        .task(id: refreshKey) { await refresh() }
    }

    private var refreshKey: String {
        // Re-export whenever the active source or format changes.
        "\(store.state.sourceFormat.rawValue)·\(store.state.source.hashValue)"
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.split.3x1")
                .foregroundStyle(.tint)
            Text("Cross-format")
                .font(.system(size: 13, weight: .semibold))
            Text("· Mermaid / D2 / DOT")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            KPill(text: "parse → export · paired ✓", systemImage: "checkmark.seal.fill", tone: .ok)
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

    // MARK: - Triptych

    private var triptych: some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.element.id) { index, pane in
                column(pane)
                if index < columns.count - 1 {
                    Divider()
                }
            }
        }
    }

    private func column(_ pane: FormatPane) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(pane.format.shortName)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .foregroundStyle(Color.accentColor)
                Text(".\(pane.format.fileExtension)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.06))

            ScrollView([.horizontal, .vertical]) {
                Text(textPayload(for: pane))
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(store.theme.background))

            Divider()

            diagnosticsList(for: pane)
                .frame(height: 96)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("crossformat.column.\(pane.format.rawValue)")
    }

    private func textPayload(for pane: FormatPane) -> String {
        if let error = pane.error {
            return "(error) \(error)"
        }
        if let result = pane.result, !result.source.isEmpty {
            return result.source
        }
        return "(generating …)"
    }

    private func diagnosticsList(for pane: FormatPane) -> some View {
        let diags = pane.result?.diagnostics ?? []
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Diagnostics")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                if !diags.isEmpty {
                    Text("· \(diags.count)")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            ScrollView {
                if diags.isEmpty {
                    Text("✓ No typed losses")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(diags.enumerated()), id: \.offset) { _, d in
                            HStack(spacing: 4) {
                                Image(systemName: severityIcon(d))
                                    .foregroundStyle(severityColor(d))
                                    .font(.system(size: 8, weight: .semibold))
                                if let cat = d.category {
                                    Text(".\(cat.rawValue)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Color.accentColor)
                                }
                                Text(d.message)
                                    .font(.system(size: 10))
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 10)
                        }
                    }
                }
            }
        }
        .background(Color.gray.opacity(0.04))
    }

    private func severityIcon(_ d: DiagramDiagnostic) -> String {
        switch d.severity {
        case .warning:     return "exclamationmark.triangle.fill"
        case .info:        return "info.circle.fill"
        case .unsupported: return "xmark.octagon.fill"
        }
    }

    private func severityColor(_ d: DiagramDiagnostic) -> Color {
        switch d.severity {
        case .warning:     return .orange
        case .info:        return .blue
        case .unsupported: return .red
        }
    }

    // MARK: - Footer

    private var totalLossCount: Int {
        var count = 0
        for pane in columns {
            guard let diagnostics = pane.result?.diagnostics else { continue }
            for diagnostic in diagnostics
            where diagnostic.severity == .warning || diagnostic.severity == .unsupported {
                count += 1
            }
        }
        return count
    }

    private var footer: some View {
        let totalLosses = totalLossCount
        return HStack {
            if totalLosses == 0 {
                KPill(text: "round-trip · paired ✓", systemImage: "checkmark.seal.fill", tone: .ok)
            } else {
                KPill(text: "round-trip · ▲ \(totalLosses) typed losses", systemImage: "exclamationmark.triangle.fill", tone: .warn)
            }
            Spacer()
            Text("Source format: \(store.state.sourceFormat.shortName)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Refresh

    @MainActor
    private func refresh() async {
        var built: [FormatPane] = []
        for target in targets {
            do {
                let result = try await store.exportSource(to: target)
                built.append(FormatPane(format: target, result: result, error: nil))
            } catch {
                built.append(FormatPane(format: target, result: nil, error: error.localizedDescription))
            }
        }
        columns = built
    }
}

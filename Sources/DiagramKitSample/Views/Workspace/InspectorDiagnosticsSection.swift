//
//  InspectorDiagnosticsSection.swift
//  DiagramPlayground
//
//  Phase 1 surface for the existing store.diagnostics list. The full
//  filterable drawer lives in Phase 6; this section is the always-on
//  inspector summary.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct InspectorDiagnosticsSection: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        InspectorSectionHeader(title: "Diagnostics", systemImage: "exclamationmark.bubble")
            .padding(.bottom, 4)
        VStack(alignment: .leading, spacing: 6) {
            if store.diagnostics.isEmpty {
                Text("No diagnostics")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.diagnostics) { diagnostic in
                    row(diagnostic)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.06))
        )
        .accessibilityIdentifier(A11yID.Inspector.diagnosticsSection)
        .accessibilityElement(children: .contain)
    }

    private func row(_ d: EditorDiagnostic) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: severityIcon(d.severity))
                .foregroundStyle(severityColor(d.severity))
                .font(.system(size: 11, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(d.message)
                    .font(.system(size: 11))
                    .lineLimit(3)
                if let line = d.line {
                    Text("line \(line)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
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

//
//  InspectorDiagnosticsSection.swift
//  DiagramPlayground
//
//  Phase 1 surface for the existing store.diagnostics list. The full
//  filterable drawer lives in Phase 6; this section is the always-on
//  inspector summary.
//

import SwiftUI
import DesignKitThemes

struct InspectorDiagnosticsSection: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        DSSectionHeader("Diagnostics")
            .padding(.bottom, Tokens.Spacing.xxs)
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            if store.diagnostics.isEmpty {
                Text("No diagnostics")
                    .dsFont(.caption2)
                    .foregroundStyle(theme.colors.textSecondary.color)
            } else {
                ForEach(store.diagnostics) { diagnostic in
                    row(diagnostic)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.sm)
        .background { DSSurface(role: .card) { Color.clear } }
        .accessibilityIdentifier(A11yID.Inspector.diagnosticsSection)
        .accessibilityElement(children: .contain)
    }

    private func row(_ d: EditorDiagnostic) -> some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.xs) {
            DSIconView(severityIcon(d.severity), size: Tokens.Size.Icon.micro, colorRole: severityRole(d.severity))
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxxs) {
                Text(d.message)
                    .dsFont(.caption2)
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(3)
                if let line = d.line {
                    Text("line \(line)")
                        .dsFont(.metric)
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
            }
            Spacer()
        }
    }

    private func severityIcon(_ s: EditorDiagnostic.Severity) -> DSIcon {
        switch s {
        case .error:   return .error
        case .warning: return .warning
        case .info:    return .info
        }
    }

    private func severityRole(_ s: EditorDiagnostic.Severity) -> DSIconColorRole {
        switch s {
        case .error:   return .error
        case .warning: return .warning
        case .info:    return .info
        }
    }
}

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
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        DSSectionHeader("Diagnostics")
            .padding(.bottom, DSTokens.Spacing.xxs)
        VStack(alignment: .leading, spacing: DSTokens.Spacing.xs) {
            if store.diagnostics.isEmpty {
                Text("No diagnostics")
                    .dsFont(.caption2)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            } else {
                ForEach(store.diagnostics) { diagnostic in
                    row(diagnostic)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSTokens.Spacing.sm)
        .background { DSSurface(role: .card) { Color.clear } }
        .accessibilityIdentifier(A11yID.Inspector.diagnosticsSection)
        .accessibilityElement(children: .contain)
    }

    private func row(_ d: EditorDiagnostic) -> some View {
        HStack(alignment: .top, spacing: DSTokens.Spacing.xs) {
            DSIconView(severityIcon(d.severity), size: DSTokens.Icon.micro, colorRole: severityRole(d.severity))
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                Text(d.message)
                    .dsFont(.caption2)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                    .lineLimit(3)
                if let line = d.line {
                    Text("line \(line)")
                        .dsFont(.metric)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
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

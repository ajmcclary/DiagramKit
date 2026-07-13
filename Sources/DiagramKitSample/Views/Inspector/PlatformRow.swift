//
//  PlatformRow.swift
//  DiagramPlayground
//
//  Phase 10 / Task 10.3 — Inspector row reporting the active
//  document's Linux parity. Green dot + "✓ full parity" by default;
//  amber dot + "⚠ approximate · char-count fallback" for the three
//  CoreText-bound families (ishikawa / treeView / eventModeling).
//

import SwiftUI
import DiagramKitModel
import DesignKitThemes

struct PlatformRow: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        InspectorSectionHeader(title: "Platform parity", systemImage: "laptopcomputer")
            .padding(.bottom, 4)
        VStack(alignment: .leading, spacing: DSTokens.Spacing.xxs) {
            HStack(spacing: DSTokens.Spacing.xs) {
                DSStatusIndicator(
                    isApproximate ? .warning : .success,
                    label: isApproximate ? "Approximate parity" : "Full parity"
                )
                Text(isApproximate ? "approximate · char-count fallback" : "full parity")
                    .dsFont(.badge)
                Spacer()
            }
            HStack(spacing: DSTokens.Spacing.xxs) {
                DSIconView(.code, size: DSTokens.Icon.indicator, colorRole: .muted)
                Text("Sources/DiagramKitCommon/src_text_metrics.swift")
                    .dsFont(.code)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                    .textSelection(.enabled)
            }
            if isApproximate {
                Text("\(currentFamily?.rawValue ?? "this family") falls back to char-count text width on Linux per CLAUDE.md; geometry is valid but not pixel-equivalent to Apple's CoreText measurement.")
                    .dsFont(.caption2)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DSTokens.Spacing.sm)
        .background { DSSurface(role: .card) { Color.clear } }
        .accessibilityIdentifier("inspector.platformRow")
        .accessibilityElement(children: .contain)
    }

    private var currentFamily: DiagramType? {
        store.editor?.document.type
    }

    private var isApproximate: Bool {
        guard let family = currentFamily else { return false }
        switch family {
        case .ishikawa, .treeView, .eventModeling: return true
        default:                                   return false
        }
    }
}

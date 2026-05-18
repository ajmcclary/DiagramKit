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

struct PlatformRow: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        InspectorSectionHeader(title: "Platform parity", systemImage: "laptopcomputer")
            .padding(.bottom, 4)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isApproximate ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(isApproximate ? "⚠ approximate · char-count fallback" : "✓ full parity")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            HStack(spacing: 4) {
                Image(systemName: "doc.text.below.ecg")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Sources/DiagramKitCommon/src_text_metrics.swift")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if isApproximate {
                Text("\(currentFamily?.rawValue ?? "this family") falls back to char-count text width on Linux per CLAUDE.md; geometry is valid but not pixel-equivalent to Apple's CoreText measurement.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.06))
        )
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

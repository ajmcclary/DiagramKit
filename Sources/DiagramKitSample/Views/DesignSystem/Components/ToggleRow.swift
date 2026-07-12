//
//  ToggleRow.swift
//  DiagramPlayground
//
//  Settings row: title (+ optional description) left, a pill switch right.
//  Matches the editor-redesign comp (transcription §1.4).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct ToggleRow: View {
    let title: String
    var description: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        DSSettingRow(title, detail: description) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.ds)
        }
        .padding(.horizontal, DSTokens.Spacing.lg)
        .contentShape(Rectangle())
    }
}

/// Compatibility wrapper around the canonical design-system toggle.
struct PillSwitch: View {
    @Binding var isOn: Bool
    var body: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(.ds)
    }
}

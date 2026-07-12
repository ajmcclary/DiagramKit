//
//  ImageURLSheet.swift
//  DiagramPlayground
//
//  Toolbar image-node sheet (visual editor plan 5): URL, display
//  size, optional title. Commit inserts an image-square node.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct ImageURLSheet: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    @SwiftUI.State private var urlDraft: String = ""
    @SwiftUI.State private var widthDraft: String = "120"
    @SwiftUI.State private var heightDraft: String = "90"
    @SwiftUI.State private var titleDraft: String = ""

    var body: some View {
        DSGlassSurface(role: .popover) {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.md) {
            Text("Add image from URL")
                .dsFont(.headline)
            DSField("Image URL", text: $urlDraft, prompt: "https://example.com/image.png")
                .accessibilityIdentifier(A11yID.Visual.imageURLField)
            HStack(spacing: DSTokens.Spacing.sm) {
                DSField("Width", text: $widthDraft)
                    .frame(width: 70)
                Text("×").foregroundStyle(environment.theme.colors.textSecondary.color)
                DSField("Height", text: $heightDraft)
                    .frame(width: 70)
                Spacer()
            }
            DSField("Title", text: $titleDraft, prompt: "Optional")
            if let error = store.lastMutationError {
                DSStatusIndicator(.error, label: error)
            }
            HStack {
                Button("Cancel") { store.cancelImageSheet() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.ds(role: .ghost, size: .compact))
                Spacer()
                Button("Add") {
                    let title = titleDraft.trimmingCharacters(in: .whitespaces)
                    Task {
                        await store.insertImageFromSheet(
                            urlString: urlDraft.trimmingCharacters(in: .whitespaces),
                            width: Double(widthDraft) ?? 120,
                            height: Double(heightDraft) ?? 90,
                            title: title.isEmpty ? nil : title
                        )
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.ds(role: .primary, size: .compact))
                .disabled(urlDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier(A11yID.Visual.imageCommitButton)
            }
        }
        .padding(DSTokens.Spacing.lg)
        }
        .frame(width: 360)
    }
}

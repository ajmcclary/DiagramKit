//
//  ImageURLSheet.swift
//  DiagramPlayground
//
//  Toolbar image-node sheet (visual editor plan 5): URL, display
//  size, optional title. Commit inserts an image-square node.
//

import SwiftUI

struct ImageURLSheet: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var urlDraft: String = ""
    @SwiftUI.State private var widthDraft: String = "120"
    @SwiftUI.State private var heightDraft: String = "90"
    @SwiftUI.State private var titleDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add image from URL")
                .font(.system(size: 13, weight: .semibold))
            TextField("https://example.com/image.png", text: $urlDraft)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(A11yID.Visual.imageURLField)
            HStack(spacing: 8) {
                TextField("Width", text: $widthDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Text("×").foregroundStyle(.secondary)
                TextField("Height", text: $heightDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Spacer()
            }
            .font(.system(size: 11))
            TextField("Title (optional)", text: $titleDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            if let error = store.lastMutationError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
            HStack {
                Button("Cancel") { store.cancelImageSheet() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
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
                .buttonStyle(.borderedProminent)
                .disabled(urlDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier(A11yID.Visual.imageCommitButton)
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
    }
}

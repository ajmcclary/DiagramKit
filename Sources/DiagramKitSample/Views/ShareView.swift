//
//  ShareView.swift
//  DiagramPlayground
//
//  Displays the serialized editor state for sharing via clipboard
//  and restores state from a pasted share string.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

struct ShareView: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var serializedString: String = ""
    @SwiftUI.State private var pasteInput: String = ""
    @SwiftUI.State private var restoreMessage: String? = nil
    @SwiftUI.State private var restoreIsError: Bool = false
    @SwiftUI.State private var showingCopyFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Share section
                sectionHeader("Share Current State")
                shareCurrentState

                Divider()

                // Restore section
                sectionHeader("Restore State")
                restoreState

                // Copy feedback toast
                if showingCopyFeedback {
                    Text("Copied to clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.85))
                        )
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(16)
        }
        .background(Color(store.theme.background))
        .onAppear {
            serializedString = store.serializedState()
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(store.theme.effectiveMuted()))
            .textCase(.uppercase)
    }

    // MARK: - Share current state

    private var shareCurrentState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Copy the string below to share your editor state. Paste it into another instance to restore the diagram, theme, config, and view settings.")
                .font(.system(size: 12))
                .foregroundColor(Color(store.theme.effectiveMuted()))
                .fixedSize(horizontal: false, vertical: true)

            // Serialized string display
            Text(serializedString.isEmpty ? "(empty state)" : serializedString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(store.theme.foreground))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(store.theme.foreground).opacity(0.06))
                )
                .textSelection(.enabled)

            // Character count
            Text("\(serializedString.count) characters")
                .font(.system(size: 10))
                .foregroundColor(Color(store.theme.effectiveMuted()))

            // Copy button
            Button {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(serializedString, forType: .string)
                #elseif os(iOS)
                UIPasteboard.general.string = serializedString
                #endif
                showCopyFeedback()
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Share String")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(store.theme.effectiveAccent()))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(store.theme.effectiveAccent()).opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Restore state

    private var restoreState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste a previously copied share string here to restore the editor state.")
                .font(.system(size: 12))
                .foregroundColor(Color(store.theme.effectiveMuted()))
                .fixedSize(horizontal: false, vertical: true)

            // Paste input field
            TextEditor(text: $pasteInput)
                .font(.system(size: 10, design: .monospaced))
                .frame(minHeight: 80)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(store.theme.foreground).opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(store.theme.effectiveLine()).opacity(0.3), lineWidth: 1)
                )

            // Restore message
            if let message = restoreMessage {
                HStack(spacing: 6) {
                    Image(systemName: restoreIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(restoreIsError ? .red : .green)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(restoreIsError ? .red : .green)
                }
                .transition(.opacity)
            }

            // Restore button
            Button {
                restoreFromPasted()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Restore State")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(store.theme.effectiveAccent()))
                )
            }
            .buttonStyle(.plain)
            .disabled(pasteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Actions

    private func restoreFromPasted() {
        let trimmed = pasteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try store.restoreFromSerializedState(trimmed)
            withAnimation {
                restoreMessage = "State restored successfully."
                restoreIsError = false
            }
        } catch {
            withAnimation {
                restoreMessage = error.localizedDescription
                restoreIsError = true
            }
        }
    }

    private func showCopyFeedback() {
        withAnimation(.easeOut(duration: 0.2)) {
            showingCopyFeedback = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showingCopyFeedback = false
                }
            }
        }
    }
}

#if DEBUG && !DIAGRAMKIT_SWIFTPM
#Preview {
    let store = LiveEditorStore()
    ShareView(store: store)
        .frame(width: 400, height: 500)
}
#endif

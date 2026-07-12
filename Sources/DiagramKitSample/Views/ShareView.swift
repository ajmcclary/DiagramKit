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
import DiagramKitSampleDesignSystem

struct ShareView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    @SwiftUI.State private var serializedString: String = ""
    @SwiftUI.State private var pasteInput: String = ""
    @SwiftUI.State private var restoreMessage: String? = nil
    @SwiftUI.State private var restoreIsError: Bool = false
    @SwiftUI.State private var showingCopyFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xl) {
                // Share section
                sectionHeader("Share Current State")
                shareCurrentState

                divider

                // Restore section
                sectionHeader("Restore State")
                restoreState

                // Copy feedback toast
                if showingCopyFeedback {
                    DSGlassSurface(role: .popover) {
                        HStack(spacing: DSTokens.Spacing.xs) {
                            DSIconView(.success, size: DSTokens.Icon.micro, colorRole: .success)
                            Text("Copied to clipboard")
                                .dsFont(.badge)
                                .foregroundStyle(environment.theme.colors.textPrimary.color)
                        }
                        .padding(.horizontal, DSTokens.Spacing.md)
                        .padding(.vertical, DSTokens.Spacing.xs)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(DSTokens.Spacing.lg)
        }
        .background(environment.theme.colors.panelBackground.color)
        .onAppear {
            serializedString = store.serializedState()
        }
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        DSSectionHeader(title)
    }

    // MARK: - Share current state

    private var shareCurrentState: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            Text("Copy the string below to share your editor state. Paste it into another instance to restore the diagram, theme, config, and view settings.")
                .dsFont(.caption)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)

            // Serialized string display
            Text(serializedString.isEmpty ? "(empty state)" : serializedString)
                .dsFont(.code)
                .foregroundStyle(environment.theme.colors.editorForeground.color)
                .padding(DSTokens.Spacing.smMd)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { DSSurface(role: .sunken) { Color.clear } }
                .textSelection(.enabled)

            // Character count
            Text("\(serializedString.count) characters")
                .dsFont(.caption2)
                .foregroundStyle(environment.theme.colors.textSecondary.color)

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
                HStack(spacing: DSTokens.Spacing.xs) {
                    DSIconView(.copy, size: DSTokens.Icon.micro)
                    Text("Copy Share String")
                }
            }
            .buttonStyle(.ds(role: .secondary, size: .regular))
        }
    }

    // MARK: - Restore state

    private var restoreState: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            Text("Paste a previously copied share string here to restore the editor state.")
                .dsFont(.caption)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)

            // Paste input field
            TextEditor(text: $pasteInput)
                .dsFont(.code)
                .foregroundStyle(environment.theme.colors.editorForeground.color)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(DSTokens.Spacing.xxs)
                .background { DSSurface(role: .sunken) { Color.clear } }

            // Restore message
            if let message = restoreMessage {
                HStack(spacing: DSTokens.Spacing.xs) {
                    DSStatusIndicator(
                        restoreIsError ? .error : .success,
                        label: restoreIsError ? "Restore failed" : "Restore succeeded"
                    )
                    Text(message)
                        .dsFont(.caption)
                        .foregroundStyle(
                            restoreIsError
                                ? environment.theme.colors.error.color
                                : environment.theme.colors.success.color
                        )
                }
                .transition(.opacity)
            }

            // Restore button
            Button {
                restoreFromPasted()
            } label: {
                HStack(spacing: DSTokens.Spacing.xs) {
                    DSIconView(.rearrange, size: DSTokens.Icon.micro, colorRole: .onAccent)
                    Text("Restore State")
                }
            }
            .buttonStyle(.ds(role: .primary, size: .regular))
            .disabled(pasteInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Actions

    private func restoreFromPasted() {
        let trimmed = pasteInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try store.restoreFromSerializedState(trimmed)
            withAnimation(feedbackAnimation) {
                restoreMessage = "State restored successfully."
                restoreIsError = false
            }
        } catch {
            withAnimation(feedbackAnimation) {
                restoreMessage = error.localizedDescription
                restoreIsError = true
            }
        }
    }

    private func showCopyFeedback() {
        withAnimation(feedbackAnimation) {
            showingCopyFeedback = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(feedbackAnimation) {
                    showingCopyFeedback = false
                }
            }
        }
    }

    private var feedbackAnimation: Animation? {
        guard environment.motion == .standard else { return nil }
        return .easeOut(
            duration: environment.motion.duration(
                milliseconds: DSTokens.DurationMilliseconds.quick
            )
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(height: DSTokens.Stroke.hairline)
            .accessibilityHidden(true)
    }
}

#if DEBUG && !DIAGRAMKIT_SWIFTPM
#Preview {
    let store = LiveEditorStore()
    ShareView(store: store)
        .frame(width: 400, height: 500)
}
#endif

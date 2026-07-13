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
import DesignKitThemes

struct ShareView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context

    @SwiftUI.State private var serializedString: String = ""
    @SwiftUI.State private var pasteInput: String = ""
    @SwiftUI.State private var restoreMessage: String? = nil
    @SwiftUI.State private var restoreIsError: Bool = false
    @SwiftUI.State private var showingCopyFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
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
                        HStack(spacing: Tokens.Spacing.xs) {
                            DSIconView(.success, size: Tokens.Size.Icon.micro, colorRole: .success)
                            Text("Copied to clipboard")
                                .dsFont(.badge)
                                .foregroundStyle(theme.colors.textPrimary.color)
                        }
                        .padding(.horizontal, Tokens.Spacing.md)
                        .padding(.vertical, Tokens.Spacing.xs)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(Tokens.Spacing.lg)
        }
        .background(theme.colors.panelBackground.color)
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
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text("Copy the string below to share your editor state. Paste it into another instance to restore the diagram, theme, config, and view settings.")
                .dsFont(.caption)
                .foregroundStyle(theme.colors.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)

            // Serialized string display
            Text(serializedString.isEmpty ? "(empty state)" : serializedString)
                .dsFont(.code)
                .foregroundStyle(theme.colors.editorForeground.color)
                .padding(Tokens.Spacing.smMd)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { DSSurface(role: .sunken) { Color.clear } }
                .textSelection(.enabled)

            // Character count
            Text("\(serializedString.count) characters")
                .dsFont(.caption2)
                .foregroundStyle(theme.colors.textSecondary.color)

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
                HStack(spacing: Tokens.Spacing.xs) {
                    DSIconView(.copy, size: Tokens.Size.Icon.micro)
                    Text("Copy Share String")
                }
            }
            .buttonStyle(.ds(role: .secondary, size: .regular))
        }
    }

    // MARK: - Restore state

    private var restoreState: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text("Paste a previously copied share string here to restore the editor state.")
                .dsFont(.caption)
                .foregroundStyle(theme.colors.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)

            // Paste input field
            TextEditor(text: $pasteInput)
                .dsFont(.code)
                .foregroundStyle(theme.colors.editorForeground.color)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(Tokens.Spacing.xxs)
                .background { DSSurface(role: .sunken) { Color.clear } }

            // Restore message
            if let message = restoreMessage {
                HStack(spacing: Tokens.Spacing.xs) {
                    DSStatusIndicator(
                        restoreIsError ? .error : .success,
                        label: restoreIsError ? "Restore failed" : "Restore succeeded"
                    )
                    Text(message)
                        .dsFont(.caption)
                        .foregroundStyle(
                            restoreIsError
                                ? theme.colors.error.color
                                : theme.colors.success.color
                        )
                }
                .transition(.opacity)
            }

            // Restore button
            Button {
                restoreFromPasted()
            } label: {
                HStack(spacing: Tokens.Spacing.xs) {
                    DSIconView(.rearrange, size: Tokens.Size.Icon.micro, colorRole: .onAccent)
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
        guard context.motion == .standard else { return nil }
        return .easeOut(
            duration: context.motion.duration(Tokens.Animation.durQuick)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.colors.borderVariant.color)
            .frame(height: Tokens.Shape.strokeHairline)
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

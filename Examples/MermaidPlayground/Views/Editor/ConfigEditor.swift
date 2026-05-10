//
//  ConfigEditor.swift
//  MermaidPlayground
//
//  JSON config text editor bound to LiveEditorState.configJSON.
//  Performs basic JSON syntax validation and displays a validity
//  indicator. Deep config mapping and sanitization is Phase 3.
//

import SwiftUI
import DiagramKit

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct ConfigEditor: View {
    let store: LiveEditorStore

    @SwiftUI.State private var localConfig: String = ""
    @SwiftUI.State private var isJSONValid: Bool = true
    @SwiftUI.State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Validity indicator bar
            validationBar

            // Config text editor
            TextEditor(text: $localConfig)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(store.theme.background))
                .foregroundColor(Color(store.theme.foreground))
                #if os(iOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
                .padding(EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    localConfig = store.state.configJSON
                    validateJSON(localConfig)
                }
                .onChange(of: localConfig) { _, newValue in
                    validateJSON(newValue)
                    debounceConfigUpdate(newValue)
                }
                .onChange(of: store.state.configJSON) { _, newValue in
                    // External update (e.g., history restore, loader)
                    if localConfig != newValue {
                        localConfig = newValue
                        validateJSON(newValue)
                    }
                }
        }
    }

    // MARK: - Validation bar

    private var validationBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isJSONValid ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(isJSONValid ? "Valid JSON" : "Invalid JSON")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isJSONValid
                    ? Color.green
                    : Color.red)

            Spacer()

            Text("Config")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color(store.theme.effectiveMuted()))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(store.theme.foreground).opacity(0.04))
    }

    // MARK: - JSON validation

    private func validateJSON(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isJSONValid = true // empty is valid (treated as "no config")
            return
        }

        guard let data = text.data(using: .utf8) else {
            isJSONValid = false
            return
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            isJSONValid = true
        } catch {
            isJSONValid = false
        }
    }

    // MARK: - Debounced update

    private func debounceConfigUpdate(_ newValue: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled {
                await MainActor.run {
                    store.state.configJSON = newValue
                }
            }
        }
    }
}

#if DEBUG
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
#Preview {
    let store = LiveEditorStore(state: LiveEditorState(
        configJSON: "{\"theme\": \"dark\"}"
    ))
    return ConfigEditor(store: store)
        .frame(width: 400, height: 300)
}
#endif

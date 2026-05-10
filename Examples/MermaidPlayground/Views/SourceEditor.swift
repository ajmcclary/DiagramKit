//
//  SourceEditor.swift
//  MermaidPlayground
//
//  Mermaid source text editor with debounced updates.
//  Bound to LiveEditorStore instead of the legacy PlaygroundConfiguration.
//

import SwiftUI
import DiagramKit

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct SourceEditor: View {
    let store: LiveEditorStore

    @SwiftUI.State private var localSource: String = ""
    @SwiftUI.State private var debounceTask: Task<Void, Never>?

    var body: some View {
        TextEditor(text: $localSource)
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
                localSource = store.state.source
            }
            .onChange(of: localSource) { _, newValue in
                debounceSourceUpdate(newValue)
            }
            .onChange(of: store.state.source) { _, newValue in
                // External update (e.g., corpus picker, history restore)
                if localSource != newValue {
                    localSource = newValue
                }
            }
    }

    private func debounceSourceUpdate(_ newValue: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled {
                await MainActor.run {
                    store.setSource(newValue, origin: .user)
                }
            }
        }
    }
}

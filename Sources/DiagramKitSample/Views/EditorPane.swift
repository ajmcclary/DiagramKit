//
//  EditorPane.swift
//  DiagramPlayground
//
//  Editor pane with Code/Config tab bar and the native code editor.
//  Uses NativeCodeEditor (NSTextView/UITextView wrapper) with line numbers,
//  syntax highlighting, and inline diagnostics.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, *)
struct EditorPane: View {
    @Bindable var store: LiveEditorStore

    @State private var mermaidHighlighter = DiagramSyntaxHighlighter(mode: .mermaid)
    @State private var jsonHighlighter = DiagramSyntaxHighlighter(mode: .json)
    @State private var plainHighlighter = DiagramSyntaxHighlighter(mode: .plain)

    var body: some View {
        VStack(spacing: 0) {
            // Multi-tab bar (Phase 2 / Task 2.1)
            EditorTabBar(store: store)

            // Tab bar with format picker on the trailing edge
            HStack(spacing: 8) {
                EditorModePicker(
                    editorMode: $store.state.editorMode,
                    theme: store.theme
                )
                Spacer(minLength: 0)
                if store.state.editorMode == .code {
                    SourceFormatPicker(
                        sourceFormat: $store.state.sourceFormat,
                        theme: store.theme,
                        onChange: { store.setSourceFormat($0) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .background(Color(store.theme.background))

            // Config validation header (config mode only)
            if store.state.editorMode == .config {
                configValidationHeader
            }

            // Native code editor (+ optional minimap rail on the trailing edge)
            HStack(spacing: 0) {
                NativeCodeEditor(
                    store: store,
                    mode: store.state.editorMode,
                    theme: store.theme,
                    diagnostics: store.diagnostics,
                    highlighter: currentHighlighter
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if store.state.showMinimap && store.state.editorMode == .code {
                    EditorMinimap(store: store)
                }
            }
        }
        .background(Color(store.theme.background))
    }

    // MARK: - Highlighter selection

    private var currentHighlighter: DiagramSyntaxHighlighter? {
        switch store.state.editorMode {
        case .code:
            // The token tables are Mermaid-specific (Mermaid arrows, `%%`
            // comments, Mermaid diagram-type keywords). Non-Mermaid
            // formats fall through to the plain highlighter so they
            // don't get miscolored as Mermaid.
            return store.state.sourceFormat == .mermaid ? mermaidHighlighter : plainHighlighter
        case .config:
            return jsonHighlighter
        }
    }

    // MARK: - Config validation header

    /// Extracted from the former ConfigEditor — shows JSON syntax validity,
    /// mapping summary (recognized/unknown keys), and theme chip.
    private var configValidationHeader: some View {
        VStack(spacing: 0) {
            // Syntax validity indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(configIsValid ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(configIsValid ? "Valid JSON" : "Invalid JSON")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(configIsValid ? Color.green : Color.red)

                Spacer()

                Text("Config")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(store.theme.effectiveMuted()))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(store.theme.foreground).opacity(0.04))

            // Mapping summary
            if let config = store.parsedConfig {
                HStack(spacing: 6) {
                    if config.recognizedKeyCount > 0 {
                        Text("\(config.recognizedKeyCount) recognized")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.green)
                    }
                    if config.unknownKeyCount > 0 {
                        if config.recognizedKeyCount > 0 {
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundColor(Color(store.theme.effectiveMuted()))
                        }
                        Text("\(config.unknownKeyCount) unknown")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    // Theme indicator
                    if let themeName = config.themeName {
                        HStack(spacing: 3) {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 9))
                            Text(themeName)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(Color(store.theme.effectiveAccent()))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(store.theme.effectiveAccent()).opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(Color(store.theme.foreground).opacity(0.03))
            }
        }
    }

    /// Re-validate JSON each time the config text changes.
    private var configIsValid: Bool {
        let text = store.state.configJSON
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        guard let data = text.data(using: .utf8) else {
            return false
        }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }
}

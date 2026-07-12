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
import DiagramKitSampleDesignSystem

struct EditorPane: View {
    @Bindable var store: LiveEditorStore

    @State private var mermaidHighlighter = DiagramSyntaxHighlighter(mode: .mermaid)
    @State private var d2Highlighter = DiagramSyntaxHighlighter(mode: .d2)
    @State private var dotHighlighter = DiagramSyntaxHighlighter(mode: .dot)
    @State private var structurizrHighlighter = DiagramSyntaxHighlighter(mode: .structurizr)
    @State private var plantUMLHighlighter = DiagramSyntaxHighlighter(mode: .plantUML)
    @State private var jsonHighlighter = DiagramSyntaxHighlighter(mode: .json)
    @Environment(\.dsEnvironment) private var dsEnvironment

    var body: some View {
        VStack(spacing: 0) {
            // Multi-tab bar (Phase 2 / Task 2.1)
            EditorTabBar(store: store)

            // Tab bar with format picker on the trailing edge
            HStack(spacing: 8) {
                EditorModePicker(
                    editorMode: $store.state.editorMode
                )
                Spacer(minLength: 0)
                if store.state.editorMode == .code {
                    SourceFormatPicker(
                        sourceFormat: $store.state.sourceFormat,
                        onChange: { store.setSourceFormat($0) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .background(dsEnvironment.theme.colors.tabBarBackground.color)

            // Config validation header (config mode only)
            if store.state.editorMode == .config {
                configValidationHeader
            }

            // Native code editor (+ optional minimap rail on the trailing edge)
            HStack(spacing: 0) {
                NativeCodeEditor(
                    store: store,
                    mode: store.state.editorMode,
                    theme: dsEnvironment.theme,
                    diagnostics: store.diagnostics,
                    highlighter: currentHighlighter
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if store.state.showMinimap && store.state.editorMode == .code {
                    EditorMinimap(store: store)
                }
            }
        }
        .background(dsEnvironment.theme.colors.editorBackground.color)
    }

    // MARK: - Highlighter selection

    private var currentHighlighter: DiagramSyntaxHighlighter? {
        switch store.state.editorMode {
        case .code:
            return switch store.state.sourceFormat {
            case .mermaid: mermaidHighlighter
            case .d2: d2Highlighter
            case .graphviz: dotHighlighter
            case .structurizr: structurizrHighlighter
            case .plantuml: plantUMLHighlighter
            }
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

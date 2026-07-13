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
import DesignKitThemes

struct EditorPane: View {
    @Bindable var store: LiveEditorStore

    @State private var mermaidHighlighter = DiagramSyntaxHighlighter(mode: .mermaid)
    @State private var d2Highlighter = DiagramSyntaxHighlighter(mode: .d2)
    @State private var dotHighlighter = DiagramSyntaxHighlighter(mode: .dot)
    @State private var structurizrHighlighter = DiagramSyntaxHighlighter(mode: .structurizr)
    @State private var plantUMLHighlighter = DiagramSyntaxHighlighter(mode: .plantUML)
    @State private var jsonHighlighter = DiagramSyntaxHighlighter(mode: .json)
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Multi-tab bar (Phase 2 / Task 2.1)
            EditorTabBar(store: store)

            // Tab bar with format picker on the trailing edge
            HStack(spacing: Tokens.Spacing.sm) {
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
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.top, Tokens.Spacing.xxs)
            .background(theme.colors.tabBarBackground.color)

            // Config validation header (config mode only)
            if store.state.editorMode == .config {
                configValidationHeader
            }

            // Native code editor (+ optional minimap rail on the trailing edge)
            HStack(spacing: 0) {
                NativeCodeEditor(
                    store: store,
                    mode: store.state.editorMode,
                    theme: theme,
                    diagnostics: store.diagnostics,
                    highlighter: currentHighlighter
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if store.state.showMinimap && store.state.editorMode == .code {
                    EditorMinimap(store: store)
                }
            }
        }
        .background(theme.colors.editorBackground.color)
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
            HStack(spacing: Tokens.Spacing.xs) {
                Circle()
                    .fill(configIsValid
                        ? theme.colors.success.color
                        : theme.colors.error.color)
                    .frame(width: Tokens.Spacing.sm, height: Tokens.Spacing.sm)

                Text(configIsValid ? "Valid JSON" : "Invalid JSON")
                    .dsFont(.badge)
                    .foregroundStyle(configIsValid
                        ? theme.colors.success.color
                        : theme.colors.error.color)

                Spacer()

                Text("Config")
                    .dsFont(.caption2)
                    .foregroundStyle(theme.colors.textSecondary.color)
            }
            .padding(.horizontal, Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(theme.colors.editorGutterBackground.color)

            // Mapping summary
            if let config = store.parsedConfig {
                HStack(spacing: Tokens.Spacing.xs) {
                    if config.recognizedKeyCount > 0 {
                        Text("\(config.recognizedKeyCount) recognized")
                            .dsFont(.caption2)
                            .foregroundStyle(theme.colors.success.color)
                    }
                    if config.unknownKeyCount > 0 {
                        if config.recognizedKeyCount > 0 {
                            Text("·")
                                .dsFont(.caption2)
                                .foregroundStyle(theme.colors.textSecondary.color)
                        }
                        Text("\(config.unknownKeyCount) unknown")
                            .dsFont(.caption2)
                            .foregroundStyle(theme.colors.warning.color)
                    }

                    Spacer()

                    // Theme indicator
                    if let themeName = config.themeName {
                        HStack(spacing: Tokens.Spacing.xxxs) {
                            DSIconView(.theme, size: Tokens.Size.Icon.indicator, colorRole: .info)
                            Text(themeName)
                                .dsFont(.badge)
                        }
                        .foregroundStyle(theme.colors.accent.color)
                        .padding(.horizontal, Tokens.Spacing.xs)
                        .padding(.vertical, Tokens.Spacing.xxxs)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.Shape.radiusXS)
                                .fill(theme.colors.accent.color.opacity(Tokens.Opacity.tint))
                        )
                    }
                }
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.vertical, Tokens.Spacing.xxxs)
                .background(theme.colors.editorBackground.color)
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

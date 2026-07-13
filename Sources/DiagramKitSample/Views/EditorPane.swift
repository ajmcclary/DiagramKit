//
//  EditorPane.swift
//  DiagramPlayground
//
//  Editor pane with Code/Config tab bar hosting CodeEditorPlugin's
//  CodeEditor (syntax highlighting, line numbers, minimap) with
//  diagnostics surfaced as line annotations.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import DesignKitThemes
import CodeEditorPlugin
import CodeEditorAnnotations

struct EditorPane: View {
    @Bindable var store: LiveEditorStore

    @State private var editorController = EditorController()
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

            // CodeEditorPlugin editor. The 300 ms debounce matches the old
            // NativeCodeEditor's store-commit cadence; the binding write is
            // what re-parses the diagram, so keystrokes must not commit raw.
            CodeEditor(text: editorText, debounceInterval: .milliseconds(300))
                .codeLanguage(currentLanguage)
                .lineNumbers(true)
                .isSelectedLineHighlighted(true)
                .isMinimapVisible(store.state.showMinimap && store.state.editorMode == .code)
                .codeFontSize(Tokens.Typography.Size.bodySM)
                .editorController(editorController)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.colors.editorBackground.color)
        .onChange(of: store.diagnostics) { _, _ in syncDiagnosticAnnotations() }
        .onChange(of: store.state.editorMode) { _, _ in syncDiagnosticAnnotations() }
        .onAppear { syncDiagnosticAnnotations() }
    }

    // MARK: - Text binding

    /// Routes the editor buffer to the store's source (code mode) or
    /// config JSON (config mode). Writes arrive debounced from the editor
    /// and commit through the store's canonical setters.
    private var editorText: Binding<String> {
        Binding(
            get: {
                switch store.state.editorMode {
                case .code: store.state.source
                case .config: store.state.configJSON
                }
            },
            set: { newValue in
                switch store.state.editorMode {
                case .code: store.setSource(newValue, origin: .user)
                case .config: store.setConfigJSON(newValue)
                }
            }
        )
    }

    // MARK: - Language selection

    private var currentLanguage: Language {
        switch store.state.editorMode {
        case .config:
            return .json
        case .code:
            switch store.state.sourceFormat {
            case .mermaid: return .mermaid
            case .d2: return .d2
            case .graphviz: return .dot
            case .structurizr: return .structurizr
            case .plantuml: return .plantuml
            }
        }
    }

    // MARK: - Diagnostics → annotations

    /// Mirrors `store.diagnostics` into editor line annotations (the
    /// replacement for the old gutter dots). Config mode has its own
    /// validation header, so annotations only show in code mode.
    private func syncDiagnosticAnnotations() {
        editorController.removeAllAnnotations()
        guard store.state.editorMode == .code else { return }

        let source = store.state.source as NSString
        for diagnostic in store.diagnostics {
            guard let line = diagnostic.line,
                  let range = Self.characterRange(forLine: line, in: source)
            else { continue }
            editorController.addAnnotation(
                Annotation(
                    range: range,
                    content: diagnostic.message,
                    id: diagnostic.id.uuidString,
                    kind: annotationKind(for: diagnostic.severity)
                )
            )
        }
    }

    private func annotationKind(for severity: EditorDiagnostic.Severity) -> AnnotationKind {
        switch severity {
        case .error: .error
        case .warning: .warning
        case .info: .info
        }
    }

    /// UTF-16 character range of a 1-based line in `string`, or nil when the
    /// line is out of bounds (e.g. a stale diagnostic after an edit).
    private static func characterRange(forLine targetLine: Int, in string: NSString) -> NSRange? {
        guard targetLine >= 1 else { return nil }
        var line = 1
        var index = 0
        while index < string.length {
            if line == targetLine {
                var end = index
                while end < string.length && string.character(at: end) != 0x0A {
                    end += 1
                }
                return NSRange(location: index, length: end - index)
            }
            if string.character(at: index) == 0x0A {
                line += 1
            }
            index += 1
        }
        if line == targetLine {
            return NSRange(location: string.length, length: 0)
        }
        return nil
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

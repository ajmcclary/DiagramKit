//
//  LiveEditorStore+Workspace.swift
//  DiagramPlayground
//
//  v2 PlaygroundShell — workspace mode picker, citation toggle, editor
//  tabs, bidirectional editor/preview hover, and the ThemeBuilder
//  inspector card overrides. Extracted from LiveEditorStore.swift to
//  keep that file under the file-size discipline gate.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, *)
extension LiveEditorStore {

    // MARK: - v2 Workspace shell (Phase 1)

    /// Switch the active workspace mode (Code / Visual / Split).
    /// Visual/Split are wired by later phases; Phase 1 already accepts
    /// every value so the codec round-trip is exercisable.
    public func setWorkspaceMode(_ mode: WorkspaceMode) {
        state.workspaceMode = mode
    }

    /// Toggle the per-screen citation overlay.
    public func setShowCitations(_ flag: Bool) {
        state.showCitations = flag
    }

    // MARK: - Editor tabs (Phase 2 / Task 2.1)

    /// Append `id` to `openTabs` if absent and make it active. If the
    /// tab is already open this is a no-op besides activating it.
    public func openTab(_ id: String) {
        if !state.openTabs.contains(id) {
            state.openTabs.append(id)
        }
        state.activeTabId = id
        loadTabSource(id: id)
    }

    /// Make `id` the active tab. No-op when `id` is not currently open.
    public func activateTab(_ id: String) {
        guard state.openTabs.contains(id) else { return }
        state.activeTabId = id
        loadTabSource(id: id)
    }

    /// Remove `id` from `openTabs`. When the closed tab was active,
    /// activation falls back to the first remaining tab; if no tabs
    /// remain `activeTabId` becomes nil.
    public func closeTab(_ id: String) {
        guard state.openTabs.contains(id) else { return }
        state.openTabs.removeAll { $0 == id }
        if state.activeTabId == id {
            state.activeTabId = state.openTabs.first
            if let next = state.openTabs.first {
                loadTabSource(id: next)
            }
        }
    }

    /// Apply the source for a given tab id. Looks the entry up in
    /// `TestDiagrams.all` and falls back to leaving the source
    /// unchanged if no match exists (tabs may carry pinned ids that
    /// haven't been loaded yet, e.g. fresh corpus entries).
    fileprivate func loadTabSource(id: String) {
        guard let entry = TestDiagrams.all.first(where: { $0.id == id }) else { return }
        setSource(entry.source, origin: .system)
    }

    // MARK: - Bidirectional selection (Phase 2 / Task 2.3)

    /// Heuristic source-line ↔ node-id map rebuilt whenever the source
    /// or sourceFormat changes. Used by hoverEditorLine / hoverPreviewNode.
    public var sourceMap: SourceMap {
        SourceMap(source: state.source, format: state.sourceFormat)
    }

    /// Editor → preview hover. Sets the active source line and the
    /// node id at that line (when the source map resolves one). Pass
    /// `nil` to clear the hover.
    public func hoverEditorLine(_ line: Int?) {
        state.biSelLine = line
        if let line {
            state.biSelNode = sourceMap.lineToNode[line]
        } else {
            state.biSelNode = nil
        }
    }

    /// Preview → editor hover. Sets the active node and the source
    /// line of its declaration (when the source map resolves one).
    public func hoverPreviewNode(_ nodeId: String?) {
        state.biSelNode = nodeId
        if let nodeId {
            state.biSelLine = sourceMap.nodeToLine[nodeId]
        } else {
            state.biSelLine = nil
        }
    }

    // MARK: - Theme builder (Phase 10 / Task 10.1)

    public func setThemeOverride(_ token: ThemeBuilderState.Token, hex: String?) {
        state.themeBuilder.setOverride(token, hex: hex)
    }

    public func resetThemeOverrides() {
        state.themeBuilder.reset()
    }

    /// Apply the current `state.themeBuilder.overrides` onto `base` and
    /// return a new `DiagramTheme`. Bare passthrough when no overrides
    /// are set. Tokens that don't map to a `DiagramTheme` field (the
    /// three semantic colors — success / warning / error) are silently
    /// skipped; only the nine palette tokens carry through to the
    /// renderer for now.
    func applyingThemeOverrides(to base: DiagramTheme) -> DiagramTheme {
        let overrides = state.themeBuilder.overrides
        guard !overrides.isEmpty else { return base }

        func color(for token: ThemeBuilderState.Token) -> BMColor? {
            guard let hex = overrides[token.rawValue] else { return nil }
            // ThemeBuilderState stores hex without the `#` prefix.
            return DiagramColorParser.hexColor(hex)
        }

        return DiagramTheme(
            background: color(for: .bg) ?? base.background,
            foreground: color(for: .fg) ?? base.foreground,
            line: color(for: .line) ?? base.line,
            accent: color(for: .accent) ?? base.accent,
            muted: color(for: .muted) ?? base.muted,
            surface: color(for: .surface) ?? base.surface,
            border: color(for: .border) ?? base.border,
            noteBkg: color(for: .noteBkg) ?? base.noteBkg,
            noteBorder: color(for: .noteBorder) ?? base.noteBorder,
            font: base.font,
            lineWidth: base.lineWidth,
            cornerRadius: base.cornerRadius,
            transparent: base.transparent
        )
    }
}

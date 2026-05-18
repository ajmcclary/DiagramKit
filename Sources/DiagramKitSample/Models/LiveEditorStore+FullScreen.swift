//
//  LiveEditorStore+FullScreen.swift
//  DiagramPlayground
//
//  Phase 8/9 full-screen surface routing — Coverage matrix, Corpus
//  browser, Cross-format, Importer probe, Snippets library — plus
//  associated filter / search / sample-index state.
//

import SwiftUI
import DiagramKit

extension LiveEditorStore {

    // MARK: - Full-screen surfaces (Phase 8 / Task 8.1)

    public func setFullScreen(_ surface: FullScreenSurface) {
        state.fullScreen = surface
    }

    public func dismissFullScreen() {
        state.fullScreen = .none
    }

    // MARK: - Corpus browser (Phase 8 / Task 8.5)

    public func setCorpusSearch(_ value: String) {
        corpusSearch = value
    }

    public func setCorpusCategoryFilter(_ value: String?) {
        corpusCategoryFilter = value
    }

    public func setCorpusFormatFilter(_ value: String?) {
        corpusFormatFilter = value
    }

    public func setCorpusDiagnosticFilter(_ value: CorpusEntry.DiagnosticFacet?) {
        corpusDiagnosticFilter = value
    }

    public func setCorpusLinuxFilter(_ value: CorpusEntry.LinuxFacet?) {
        corpusLinuxFilter = value
    }

    /// Open `entry` in the workspace: dismiss the browser, set the
    /// active source / format, and bounce the workspace back to
    /// .split so the user sees the rendered preview alongside.
    public func openCorpusEntry(_ entry: CorpusEntry) {
        let format: SourceFormat
        if entry.formats.contains("mermaid") {
            format = .mermaid
        } else if let first = entry.formats.first.flatMap({ SourceFormat(rawValue: $0) }) {
            format = first
        } else {
            format = .mermaid
        }
        setSource(entry.source, format: format, origin: .system)
        setFullScreen(.none)
        setWorkspaceMode(.split)
    }

    // MARK: - Importer probe (Phase 9 / Task 9.2)

    public func setProbeSampleIndex(_ index: Int) {
        probeSampleIndex = max(0, min(ImporterProbeRunner.sampleSources.count - 1, index))
    }

    // MARK: - Snippets library (Phase 9 / Task 9.3)

    public func setSnippetSearch(_ value: String) {
        snippetSearch = value
    }

    /// Insert a snippet into the workspace. Phase 9 replaces the
    /// source wholesale — Code-mode cursor insertion would require
    /// NativeCodeEditor selection plumbing not in scope here. After
    /// insert: dismisses the snippets surface and bounces to .split.
    public func insertSnippet(_ snippet: Snippet) {
        setSource(snippet.body, format: snippet.format, origin: .system)
        setFullScreen(.none)
        setWorkspaceMode(.split)
    }
}

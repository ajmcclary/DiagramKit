//
//  LiveEditorStore+Loaders.swift
//  DiagramPlayground
//
//  Remote-source loader actions (Gist, raw HTTP) split out of
//  LiveEditorStore.swift. Methods stay on LiveEditorStore via this
//  extension — no public API change.
//

import Foundation
import DiagramKit

extension LiveEditorStore {

    // MARK: - Loader actions (Phase 5)

    /// Load diagram source and config from a GitHub Gist URL.
    ///
    /// Fetches the Gist via the public API, extracts a recognized
    /// diagram source file (Mermaid/D2/DOT/Structurizr/PlantUML by
    /// extension), and reads config from `config.json`. Config is
    /// sanitized before application. A loader history entry is saved
    /// automatically.
    ///
    /// - Parameter url: A GitHub Gist URL.
    /// - Throws: ``GistLoader.LoadError`` on failure.
    public func loadFromGist(url: URL) async throws {
        let result = try await GistLoader.load(from: url)

        state.source = result.source
        if let sniffed = result.sourceFormat {
            state.sourceFormat = sniffed
        }

        if let configJSON = result.configJSON {
            state.configJSON = configJSON
            parseConfig()
        }

        // Save loader history entry
        historyStore.saveLoaderEntry(
            state: state,
            label: result.label,
            sourceURL: result.sourceURL
        )

        isDirty = false
        requestRender(reason: .sourceChanged)
    }

    /// Load diagram source and/or config from raw HTTP(S) URLs.
    ///
    /// The source URL's path extension is sniffed for a `SourceFormat`;
    /// when no extension is present, the current `state.sourceFormat`
    /// is left untouched.
    ///
    /// - Parameters:
    ///   - codeURL: URL to load source from (optional).
    ///   - configURL: URL to load config JSON from (optional).
    /// - Throws: ``RawFileLoader.LoadError`` on failure.
    public func loadFromRawURL(codeURL: URL?, configURL: URL?) async throws {
        let result = try await RawFileLoader.load(codeURL: codeURL, configURL: configURL)

        if !result.source.isEmpty {
            state.source = result.source
            if let sniffed = result.sourceFormat {
                state.sourceFormat = sniffed
            }
        }

        if let configJSON = result.configJSON {
            state.configJSON = configJSON
            parseConfig()
        }

        // Save loader history entry
        historyStore.saveLoaderEntry(
            state: state,
            label: result.label,
            sourceURL: result.sourceURL
        )

        isDirty = false
        requestRender(reason: .sourceChanged)
    }
}

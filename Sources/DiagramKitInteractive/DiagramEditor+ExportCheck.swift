// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// The app saves a canvas edit's export as the document, so before a
// mutation commits, its export is checked for loss (owner ruling on the
// 2026-11-12 review): the text must read back as the mutated model, and
// every line of the original source the model does not hold — comments,
// frontmatter and init directives, click/link lines — must still be there
// unless the mutation removed what it belongs to.

import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

extension DiagramEditor {

    /// Throws `DiagramEditorError.exportWouldLoseContent` when saving
    /// `source` for `newDocument` would lose or change content.
    func _checkExport(
        _ source: String,
        of newDocument: DiagramDocument,
        replacing oldDocument: DiagramDocument,
        scope: _EditScope = .wholeExport
    ) async throws {
        // Mermaid is the format whose exporters are held to read-back
        // fidelity; other formats convert, and their check is not on.
        guard preferredExportFormat == .mermaid else { return }
        let format = preferredExportFormat
        let oldSource = self.source
        let readBack = exportRegistry.readBack
        let checksModel = Self._readBackCheckedTypes.contains(newDocument.type)
        let problem: String? = try await Self._runOnWorker {
            if let readBack, checksModel {
                let reparsed: DiagramDocument
                do {
                    reparsed = try readBack(source, format)
                } catch {
                    return "the saved text would not parse: \(error.localizedDescription)"
                }
                let expected = _modelFingerprint(newDocument)
                let actual = _modelFingerprint(reparsed)
                if expected != actual {
                    return "the saved text would not read back as the edited diagram (\(Self._firstDifference(expected, actual)))"
                }
            }
            if let problem = Self._untargetedLineChange(
                from: oldSource, to: source, scope: scope, newDocument: newDocument, oldDocument: oldDocument
            ) {
                return problem
            }
            return Self._missingSourceLines(source, newDocument: newDocument, oldDocument: oldDocument)
        }
        if let problem {
            throw DiagramEditorError.exportWouldLoseContent(details: problem)
        }
    }

    /// Diagram types whose Mermaid export is held to read-back fidelity
    /// (the export-fidelity suites prove it over the corpus). The other
    /// types' exporters do not yet read back exactly, so a model check
    /// would refuse every title or theme change on them; they get the
    /// source-line check only.
    nonisolated static let _readBackCheckedTypes: Set<DiagramType> = [
        .flowchart, .stateDiagram, .sequenceDiagram, .gantt,
    ]

    /// What part of the source an edit is about. A structural edit of a
    /// type whose export reads back exactly re-exports the body
    /// (`wholeExport`); an edit that does not concern the body (title,
    /// theme, layout) may change only the preamble lines of those keys
    /// (`preambleOnly`); a gantt resize may change only its task's line
    /// (`singleLine`). Any other changed line refuses the edit.
    enum _EditScope: Sendable, Equatable {
        case wholeExport
        case preambleOnly
        case singleLine(Int)
    }

    /// A line of the original source the edit is not about that the new
    /// text changes, or nil. Checked only when the document was read from
    /// that source (its `sourceFormat` is Mermaid).
    nonisolated static func _untargetedLineChange(
        from oldSource: String?,
        to source: String,
        scope: _EditScope,
        newDocument: DiagramDocument,
        oldDocument: DiagramDocument
    ) -> String? {
        guard scope != .wholeExport, let oldSource, oldDocument.sourceFormat == .mermaid else { return nil }
        let old = DiagramSourceNormalizer.normalizedLineEndings(oldSource)
        let new = DiagramSourceNormalizer.normalizedLineEndings(source)
        switch scope {
        case .wholeExport:
            return nil
        case .singleLine(let index):
            let a = old.split(separator: "\n", omittingEmptySubsequences: false)
            let b = new.split(separator: "\n", omittingEmptySubsequences: false)
            guard a.count == b.count else { return "the edit would add or remove lines" }
            if let i = a.indices.first(where: { $0 != index && a[$0] != b[$0] }) {
                return "the edit would change the line '\(a[i].trimmingCharacters(in: .whitespaces))'"
            }
            return nil
        case .preambleOnly:
            let preamble = _collectMermaidSourceAnnotations(
                old, title: oldDocument.title, theme: oldDocument.frontmatter?.theme, layout: oldDocument.frontmatter?.layout
            )?.preamble ?? ""
            guard old.hasPrefix(preamble) else { return nil }
            let body = old.dropFirst(preamble.count)
            guard new.hasSuffix(body) else {
                return "the edit would change the diagram's lines, not only its settings"
            }
            // In the preamble, only the lines of the settings that changed
            // may differ.
            let newPreamble = new.dropLast(body.count)
            var available: [Substring: Int] = [:]
            for line in newPreamble.split(separator: "\n", omittingEmptySubsequences: false) { available[line, default: 0] += 1 }
            var changedKeys: Set<String> = []
            if newDocument.title != oldDocument.title { changedKeys.insert("title") }
            if newDocument.frontmatter?.theme != oldDocument.frontmatter?.theme { changedKeys.insert("theme") }
            if newDocument.frontmatter?.layout != oldDocument.frontmatter?.layout { changedKeys.insert("layout") }
            for line in preamble.split(separator: "\n", omittingEmptySubsequences: false) {
                if let count = available[line], count > 0 { available[line] = count - 1; continue }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let key = trimmed.split(separator: ":", maxSplits: 1).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
                if changedKeys.contains(key) { continue }
                if trimmed.hasPrefix("%%{"), changedKeys.contains("theme") || changedKeys.contains("layout") { continue }
                return "the edit would change the line '\(trimmed)'"
            }
            return nil
        }
    }

    /// `source` with only the preamble settings that differ between the
    /// two documents (title, theme, layout) edited in place and every
    /// other line, the whole diagram body included, kept byte for byte,
    /// and the document that text reads as (a setting can also reach the
    /// payload, as a layout preset does a flowchart's config); nil when the
    /// edited text does not read back with `newDocument`'s settings.
    nonisolated static func _editPreambleInSource(
        _ source: String,
        oldDocument: DiagramDocument,
        newDocument: DiagramDocument,
        readBack: @Sendable (String, DiagramFormatID) throws -> DiagramDocument
    ) -> (source: String, document: DiagramDocument)? {
        let old = DiagramSourceNormalizer.normalizedLineEndings(source)
        let preamble = _collectMermaidSourceAnnotations(
            old, title: oldDocument.title, theme: oldDocument.frontmatter?.theme, layout: oldDocument.frontmatter?.layout
        )?.preamble ?? ""
        guard old.hasPrefix(preamble) else { return nil }
        var edited = preamble
        if newDocument.title != oldDocument.title {
            edited = _settingPreambleKey(edited, path: ["title"], jsonKey: nil, value: newDocument.title)
        }
        if newDocument.frontmatter?.theme != oldDocument.frontmatter?.theme {
            edited = _settingPreambleKey(edited, path: ["config", "theme"], jsonKey: "theme", value: newDocument.frontmatter?.theme)
        }
        if newDocument.frontmatter?.layout != oldDocument.frontmatter?.layout {
            edited = _settingPreambleKey(edited, path: ["config", "layout"], jsonKey: "layout", value: newDocument.frontmatter?.layout)
        }
        let text = edited + old.dropFirst(preamble.count)
        guard let back = try? readBack(text, .mermaid),
              back.type == newDocument.type,
              back.title == newDocument.title,
              back.frontmatter?.theme == newDocument.frontmatter?.theme,
              back.frontmatter?.layout == newDocument.frontmatter?.layout else { return nil }
        return (text, back)
    }

    /// The first line of the original source that the model does not hold
    /// and the new text no longer has, or nil.
    nonisolated static func _missingSourceLines(
        _ source: String,
        newDocument: DiagramDocument,
        oldDocument: DiagramDocument
    ) -> String? {
        guard let annotations = oldDocument.sourceAnnotations else { return nil }
        let configChanged = newDocument.title != oldDocument.title
            || newDocument.frontmatter?.theme != oldDocument.frontmatter?.theme
            || newDocument.frontmatter?.layout != oldDocument.frontmatter?.layout
        if !configChanged, !source.hasPrefix(annotations.preamble) {
            return "the frontmatter or init directives would change"
        }
        var available: [String: Int] = [:]
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            available[String(line), default: 0] += 1
        }
        func take(_ line: String) -> Bool {
            guard let count = available[line], count > 0 else { return false }
            available[line] = count - 1
            return true
        }
        for comment in annotations.comments where !take(comment.line) {
            return "the comment '\(comment.line.trimmingCharacters(in: .whitespaces))' would be lost"
        }
        let ids = _elementIDs(in: newDocument)
        for (key, lines) in annotations.verbatimStatements.sorted(by: { $0.key < $1.key }) {
            // A click or link line goes with its element.
            if let ids, let target = _verbatimTarget(key), !ids.contains(target) { continue }
            for line in lines where !take(line) {
                return "the line '\(line.trimmingCharacters(in: .whitespaces))' would be lost"
            }
        }
        return nil
    }

    /// The element a `click X` / `links X` / `link X: …` key belongs to.
    nonisolated static func _verbatimTarget(_ key: String) -> String? {
        let rest = key.split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init) ?? ""
        let target = rest.split(separator: ":", maxSplits: 1).first.map {
            $0.trimmingCharacters(in: .whitespaces)
        } ?? ""
        let id = target.split(separator: " ").first.map(String.init) ?? target
        return id.isEmpty ? nil : id
    }

    /// Ids a click/link line can belong to, or nil when the diagram type
    /// has no such lines the editor can remove.
    nonisolated static func _elementIDs(in document: DiagramDocument) -> Set<String>? {
        switch document.payload {
        case .flowchart(let graph), .stateDiagram(let graph):
            return Set(graph.nodesInOrder.map(\.id))
        case .sequenceDiagram(let model):
            return Set(model.actors.map(\.id))
        default:
            return nil
        }
    }

    nonisolated static func _firstDifference(_ expected: String, _ actual: String) -> String {
        _fingerprintDifference(expected, actual)
    }
}
#endif

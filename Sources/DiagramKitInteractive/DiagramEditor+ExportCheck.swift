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
        replacing oldDocument: DiagramDocument
    ) async throws {
        // Mermaid is the format whose exporters are held to read-back
        // fidelity; other formats convert, and their check is not on.
        guard preferredExportFormat == .mermaid else { return }
        let format = preferredExportFormat
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

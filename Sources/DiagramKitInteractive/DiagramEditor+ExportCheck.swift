// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// The app saves a canvas edit's export as the document, so before a
// mutation commits, its export is checked for loss (owner ruling on the
// 2026-11-12 review): the text must read back as the mutated model, and
// every line of the original source the model does not hold — comments,
// frontmatter and init directives, click/link lines — must still be there
// unless the mutation removed what it belongs to.

import Foundation
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
        // Every format the editor writes back is checked. For Mermaid the
        // model check covers the types whose export is proven to read back
        // and the line check covers what the model does not hold; for the
        // other formats every type is model-checked, and every line of the
        // original source the edit is not about must survive verbatim.
        let format = preferredExportFormat
        let oldSource = self.source
        let readBack = exportRegistry.readBack
        let checksModel = format != .mermaid || Self._readBackCheckedTypes.contains(newDocument.type)
        let problem: String? = try await Self._runOnWorker {
            if let readBack, checksModel {
                let reparsed: DiagramDocument
                do {
                    reparsed = try readBack(source, format)
                } catch {
                    return "the saved text would not be valid (\(error.localizedDescription.trimmingCharacters(in: CharacterSet(charactersIn: ". "))))"
                }
                let expected = _modelFingerprint(newDocument)
                let actual = _modelFingerprint(reparsed)
                if expected != actual {
                    return "saving it would lose or change \(Self._plainThing(expected, actual))"
                }
            }
            if format != .mermaid {
                return Self._lostSourceLine(from: oldSource, to: source, format: format, oldDocument: oldDocument, newDocument: newDocument)
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

    /// For a format other than Mermaid: the first line of the original
    /// source (comments included) that the new text no longer has and that
    /// does not name an element the edit changed, or nil. Those exporters
    /// re-write the whole file, so most edits on them are refused today;
    /// a refused edit says so, a silent loss would not.
    nonisolated static func _lostSourceLine(
        from oldSource: String?,
        to source: String,
        format: DiagramFormatID,
        oldDocument: DiagramDocument,
        newDocument: DiagramDocument
    ) -> String? {
        guard let oldSource else { return nil }
        var targets = _changedElementIDs(oldDocument, newDocument)
        // A settings edit is about the line that states the setting.
        if newDocument.title != oldDocument.title { targets.insert("title") }
        if newDocument.frontmatter?.theme != oldDocument.frontmatter?.theme { targets.insert("theme") }
        if newDocument.frontmatter?.layout != oldDocument.frontmatter?.layout { targets.insert("layout") }
        var available: [Substring: Int] = [:]
        let newText = DiagramSourceNormalizer.normalizedLineEndings(source)
        for line in newText.split(separator: "\n") { available[line, default: 0] += 1 }
        // A comment is never the edit's target: every comment line, and
        // every trailing comment, comes back unchanged (one that names a
        // renamed element keeps its old wording). Only a non-comment line
        // naming an element the edit changed may be rewritten.
        let syntax = _CommentSyntax(format)
        var inBlock = false
        for line in DiagramSourceNormalizer.normalizedLineEndings(oldSource).split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let isComment = syntax.isCommentLine(trimmed, inBlock: &inBlock)
            if let count = available[line], count > 0 { available[line] = count - 1; continue }
            if isComment {
                return "saving it would lose the comment \u{201C}\(trimmed)\u{201D}"
            }
            if targets.contains(where: { _mentions(line, $0) }) {
                if let trailing = syntax.trailingComment(trimmed), !newText.contains(trailing) {
                    return "saving it would lose the comment \u{201C}\(trailing)\u{201D}"
                }
                continue
            }
            return "saving it would lose or rewrite the line \u{201C}\(trimmed)\u{201D}"
        }
        return nil
    }

    /// Comment syntax of the formats other than Mermaid (whose comments
    /// the importer records).
    struct _CommentSyntax {
        let linePrefixes: [String]
        let blockOpen: String?
        let blockClose: String?
        let trailingMarkers: [String]

        init(_ format: DiagramFormatID) {
            switch format {
            case .d2: (linePrefixes, blockOpen, blockClose, trailingMarkers) = (["#"], nil, nil, [" #"])
            case .graphviz: (linePrefixes, blockOpen, blockClose, trailingMarkers) = (["//", "#"], "/*", "*/", [" //"])
            case .plantuml: (linePrefixes, blockOpen, blockClose, trailingMarkers) = (["'"], "/'", "'/", [])
            case .structurizr: (linePrefixes, blockOpen, blockClose, trailingMarkers) = (["//", "#"], "/*", "*/", [" //"])
            default: (linePrefixes, blockOpen, blockClose, trailingMarkers) = (["#", "//", "'", "%%"], "/*", "*/", [])
            }
        }

        func isCommentLine(_ trimmed: String, inBlock: inout Bool) -> Bool {
            if inBlock {
                if let close = blockClose, trimmed.contains(close) { inBlock = false }
                return true
            }
            if let open = blockOpen, let close = blockClose, trimmed.hasPrefix(open) {
                inBlock = !trimmed.dropFirst(open.count).contains(close)
                return true
            }
            return linePrefixes.contains { trimmed.hasPrefix($0) }
        }

        /// The comment at the end of a statement line (outside quotes).
        func trailingComment(_ trimmed: String) -> String? {
            var inQuote = false
            var index = trimmed.startIndex
            while index < trimmed.endIndex {
                if trimmed[index] == "\"" { inQuote.toggle() }
                if !inQuote {
                    for marker in trailingMarkers where trimmed[index...].hasPrefix(marker) {
                        return trimmed[trimmed.index(after: index)...].trimmingCharacters(in: .whitespaces)
                    }
                }
                index = trimmed.index(after: index)
            }
            return nil
        }
    }

    /// What a model mismatch would lose, in plain words.
    nonisolated static func _plainThing(_ expected: String, _ actual: String) -> String {
        let location = _fingerprintDifferenceLocation(expected, actual)
        let words = ((location.field ?? "") + " " + (location.type ?? "")).lowercased()
        let table: [(String, String)] = [
            ("acctitle", "the accessibility title"), ("accdescr", "the accessibility description"),
            ("note", "a note"), ("link", "a link"), ("interaction", "a link"), ("href", "a link"), ("tooltip", "a tooltip"),
            ("style", "a style"), ("css", "a style"), ("class", "a style class"), ("fill", "a style"),
            ("label", "a label"), ("descr", "a label"), ("text", "a label"), ("title", "the title"),
            ("edge", "a connection"), ("relationship", "a connection"), ("message", "a message"),
            ("subgraph", "a group"), ("nodeids", "a group"), ("children", "a group"), ("namespace", "a group"),
            ("shape", "a shape"), ("direction", "the direction"), ("config", "a diagram setting"),
            ("task", "a task"), ("section", "a section"),
            ("node", "an element"), ("entit", "an element"), ("actor", "a participant"), ("class", "a class"),
        ]
        return table.first { words.contains($0.0) }?.1 ?? "part of the diagram"
    }

    /// Whether `line` names `id` as a whole word.
    nonisolated static func _mentions(_ line: Substring, _ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        func isWord(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }
        var search = line.startIndex
        while let range = line[search...].range(of: id) {
            let before = range.lowerBound == line.startIndex ? nil : line[line.index(before: range.lowerBound)]
            let after = range.upperBound == line.endIndex ? nil : line[range.upperBound]
            if !(before.map(isWord) ?? false), !(after.map(isWord) ?? false) { return true }
            search = range.upperBound
        }
        return false
    }

    /// Ids of the elements an edit changed: nodes added, removed or
    /// altered, the ends of changed edges, changed subgraphs and their
    /// members (flowchart and state), and the participants of changed
    /// messages (sequence). Empty for other types.
    nonisolated static func _changedElementIDs(_ old: DiagramDocument, _ new: DiagramDocument) -> Set<String> {
        var ids: Set<String> = []
        switch (old.payload, new.payload) {
        case (.flowchart(let a), .flowchart(let b)), (.stateDiagram(let a), .stateDiagram(let b)):
            let nodesA = Dictionary(a.nodesInOrder.map { ($0.id, _canonicalDescription($0.node)) }, uniquingKeysWith: { f, _ in f })
            let nodesB = Dictionary(b.nodesInOrder.map { ($0.id, _canonicalDescription($0.node)) }, uniquingKeysWith: { f, _ in f })
            for id in Set(nodesA.keys).union(nodesB.keys) where nodesA[id] != nodesB[id] { ids.insert(id) }
            var edgesA: [String: Int] = [:]
            for e in a.edges { edgesA[_canonicalDescription(e), default: 0] += 1 }
            var changedEdges: [original_src_types.MermaidEdge] = []
            for e in b.edges {
                let key = _canonicalDescription(e)
                if let n = edgesA[key], n > 0 { edgesA[key] = n - 1 } else { changedEdges.append(e) }
            }
            for e in a.edges where (edgesA[_canonicalDescription(e)] ?? 0) > 0 { changedEdges.append(e) }
            for e in changedEdges { ids.insert(e.source); ids.insert(e.target) }
            func subgraphs(_ list: [original_src_types.MermaidSubgraph], into map: inout [String: (String, [String])]) {
                for s in list {
                    map[s.id] = (_canonicalDescription(s), s.nodeIds)
                    subgraphs(s.children, into: &map)
                }
            }
            var subA: [String: (String, [String])] = [:], subB: [String: (String, [String])] = [:]
            subgraphs(a.subgraphs, into: &subA)
            subgraphs(b.subgraphs, into: &subB)
            for id in Set(subA.keys).union(subB.keys) where subA[id]?.0 != subB[id]?.0 {
                ids.insert(id)
                ids.formUnion(subA[id]?.1 ?? [])
                ids.formUnion(subB[id]?.1 ?? [])
            }
        case (.sequenceDiagram(let a), .sequenceDiagram(let b)):
            let msgsA = a.messages, msgsB = b.messages
            for i in 0..<max(msgsA.count, msgsB.count) {
                let x = i < msgsA.count ? msgsA[i] : nil, y = i < msgsB.count ? msgsB[i] : nil
                if x.map(_canonicalDescription) != y.map(_canonicalDescription) {
                    for m in [x, y].compactMap({ $0 }) { ids.insert(m.from); ids.insert(m.to) }
                }
            }
        default:
            break
        }
        return ids
    }

    /// The line ending most lines of `text` use: CRLF or LF.
    nonisolated static func _dominantLineEnding(_ text: String) -> String {
        var crlf = 0, lf = 0
        var previous: Unicode.Scalar?
        for scalar in text.unicodeScalars {
            if scalar == "\n" {
                if previous == "\r" { crlf += 1 } else { lf += 1 }
            }
            previous = scalar
        }
        return crlf > lf ? "\r\n" : "\n"
    }

    /// `text` with every line ending written as `ending`.
    nonisolated static func _withLineEnding(_ text: String, _ ending: String) -> String {
        let normalized = DiagramSourceNormalizer.normalizedLineEndings(text)
        return ending == "\n" ? normalized : normalized.replacingOccurrences(of: "\n", with: ending)
    }

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
            guard a.count == b.count else { return "saving it would add or remove lines of the source" }
            if let i = a.indices.first(where: { $0 != index && a[$0] != b[$0] }) {
                return "saving it would also change the line \u{201C}\(a[i].trimmingCharacters(in: .whitespaces))\u{201D}"
            }
            return nil
        case .preambleOnly:
            let preamble = _collectMermaidSourceAnnotations(
                old, title: oldDocument.title, theme: oldDocument.frontmatter?.theme, layout: oldDocument.frontmatter?.layout
            )?.preamble ?? ""
            guard old.hasPrefix(preamble) else { return nil }
            let body = old.dropFirst(preamble.count)
            guard new.hasSuffix(body) else {
                return "saving it would rewrite the diagram's lines, not only the setting"
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
                return "saving it would also change the line \u{201C}\(trimmed)\u{201D}"
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
            return "saving it would change the frontmatter or init directive"
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
            return "saving it would lose the comment \u{201C}\(comment.line.trimmingCharacters(in: .whitespaces))\u{201D}"
        }
        let ids = _elementIDs(in: newDocument)
        for (key, lines) in annotations.verbatimStatements.sorted(by: { $0.key < $1.key }) {
            // A click or link line goes with its element.
            if let ids, let target = _verbatimTarget(key), !ids.contains(target) { continue }
            for line in lines where !take(line) {
                return "saving it would lose the line \u{201C}\(line.trimmingCharacters(in: .whitespaces))\u{201D}"
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

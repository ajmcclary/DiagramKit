// Apple-only (UndoManager, Observation editor model) gated by `#if canImport(UIKit) || canImport(AppKit)`. On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Phase 9: Interactive Model — Slice 9E
// Core mutation implementations (derivation only — no state change).

import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

// MARK: - Mutation application (derivation only)

extension DiagramEditor {

    // MARK: - Public mutation entry points

    /// Perform a core mutation on the document.
    ///
    /// Derives the new document, exports it on a fresh worker thread,
    /// and commits state + undo atomically. Concurrent calls serialize
    /// through the chained-Task queue (`_enqueueChainedMutation`): each
    /// caller's task installs synchronously and awaits the previously
    /// installed task inside the task body, so commits land in
    /// registration order and each gets its own undo entry.
    ///
    /// - Parameter mutation: The mutation to apply.
    /// - Throws: `DiagramEditorError` if the mutation cannot be applied
    ///   or source sync fails.
    public func perform(_ mutation: DiagramMutation) async throws {
        try await _enqueueChainedMutation { editor in
            try await editor._performInner(mutation)
        }
    }

    /// Change a flowchart's direction as an undoable structural edit.
    public func setFlowchartDirection(_ direction: original_src_types.Direction) async throws {
        try await _enqueueChainedMutation { editor in
            guard case .flowchart(var graph) = editor.document.payload else {
                throw DiagramEditorError.unsupportedMutation(mutation: "Set Direction", diagramType: String(describing: editor.document.type))
            }
            graph.direction = direction
            var document = editor.document
            document.payload = .flowchart(graph)
            try await editor._commitMutation(newDocument: document, actionName: "Set Direction")
        }
    }

    /// Inner commit body. Always runs on `MainActor`. Atomic: a throw
    /// from the worker leaves state untouched.
    func _performInner(_ mutation: DiagramMutation) async throws {
        let newDocument = try _apply(mutation, to: document)
        switch mutation {
        case .setTitle, .setTheme, .setLayoutPreset:
            // Not about the diagram's body: edit the settings in the source
            // and keep every other line as written (owner ruling,
            // 2026-11-12 review). If the text cannot be edited that way the
            // export below is checked to leave the body unchanged.
            let scope: _EditScope = document.sourceFormat == .mermaid ? .preambleOnly : .wholeExport
            if preferredExportFormat == .mermaid, document.sourceFormat == .mermaid,
               let readBack = exportRegistry.readBack, let source {
                let current = document
                let edited = try await Self._runOnWorker {
                    Self._editPreambleInSource(source, oldDocument: current, newDocument: newDocument, readBack: readBack)
                }
                if let edited {
                    try await _commitMutation(
                        newDocument: edited.document,
                        savedSource: edited.source,
                        scope: scope,
                        actionName: mutation.undoActionName,
                        updateSelection: { [self] previous, document in
                            _selectionAfterMutation(previousSelection: previous, in: document)
                        }
                    )
                    return
                }
            }
            try await _commitMutation(
                newDocument: newDocument,
                scope: scope,
                actionName: mutation.undoActionName,
                updateSelection: { [self] previous, document in
                    _selectionAfterMutation(previousSelection: previous, in: document)
                }
            )
            return
        case .deleteElement(let selection) where document.type == .stateDiagram:
            let (deleted, renames) = try _deleteElementReportingRenames(selection, from: document)
            try await _commitMutation(
                newDocument: deleted,
                adoptsReadBackOrder: true,
                actionName: mutation.undoActionName,
                updateSelection: { [self] previous, document in
                    // A renumbered note keeps its selection.
                    var previous = previous
                    if let p = previous, p.elementID.hasPrefix("node:"), let new = renames[String(p.elementID.dropFirst(5))] {
                        previous = DiagramSelection(diagramType: p.diagramType, elementID: "node:\(new)")
                    }
                    return _selectionAfterMutation(previousSelection: previous, in: document)
                }
            )
            return
        default:
            break
        }
        try await _commitMutation(
            newDocument: newDocument,
            actionName: mutation.undoActionName,
            updateSelection: { [self] previous, document in
                _selectionAfterMutation(previousSelection: previous, in: document)
            }
        )
    }

    /// A format's name as users know it.
    nonisolated static func _formatName(_ format: DiagramFormatID) -> String {
        switch format {
        case .d2: return "D2"
        case .graphviz: return "DOT (Graphviz)"
        case .plantuml: return "PlantUML"
        case .structurizr: return "Structurizr"
        case .mermaid: return "Mermaid"
        default: return format.rawValue
        }
    }

    /// Shared transaction: exports `newDocument`, snapshots the current
    /// state, commits the new document/source/diagnostics (optionally
    /// updating selection), and registers an undo entry. Atomic — a
    /// throw from `_exportAsync` or `_checkExport` propagates with no
    /// state change. The
    /// family-specific `_performXInner` methods all funnel here so the
    /// commit sequence, diagnostic layering, and undo registration stay
    /// in one place.
    func _commitMutation(
        newDocument: DiagramDocument,
        mutationDiagnostics: [DiagramDiagnostic] = [],
        savedSource: String? = nil,
        scope: _EditScope = .wholeExport,
        adoptsReadBackOrder: Bool = false,
        actionName: String,
        updateSelection: ((_ previous: DiagramSelection?, _ in: DiagramDocument) -> DiagramSelection?)? = nil
    ) async throws {
        var newDocument = newDocument
        guard supportsCanvasEditing else {
            let format = document.sourceFormat.flatMap { $0 == .mermaid ? nil : $0 } ?? preferredExportFormat
            throw DiagramEditorError.exportWouldLoseContent(
                details: "canvas editing is not available for \(Self._formatName(format)) files yet"
            )
        }
        // `savedSource`: a mutation that edited the text itself (a gantt
        // resize changes one task line) saves that text instead of a fresh
        // export; it is checked the same way.
        let exportResult: DiagramExportResult
        if let savedSource {
            exportResult = DiagramExportResult(source: savedSource)
        } else {
            do {
                exportResult = try await _exportAsync(newDocument)
            } catch {
                throw DiagramEditorError.sourceSyncFailed(underlying: error.localizedDescription)
            }
        }
        // A state diagram's node order is the order the source first names
        // each state, so after a delete the saved text names them in the
        // order the export writes them. When the read-back is the edited
        // model in every respect but that order, it is the edited model,
        // and is committed as such.
        if adoptsReadBackOrder, savedSource == nil, preferredExportFormat == .mermaid,
           let readBack = exportRegistry.readBack {
            let candidate = newDocument
            let text = exportResult.source
            let format = preferredExportFormat
            let adopted: DiagramDocument? = try await Self._runOnWorker {
                guard let back = try? readBack(text, format),
                      Self._stateFingerprintIgnoringOrder(back) == Self._stateFingerprintIgnoringOrder(candidate) else { return nil }
                return back
            }
            if let adopted { newDocument = adopted }
        }
        try await _checkExport(exportResult.source, of: newDocument, replacing: document, scope: scope)
        // The text is written with the line ending the source used (CRLF
        // when most of its lines end so), so an edit does not touch every
        // line of a Windows-authored file.
        let savedText = source.map { Self._withLineEnding(exportResult.source, Self._dominantLineEnding($0)) }
            ?? exportResult.source

        let oldDocument = document
        let oldSource = source
        let oldDiagnostics = lastExportDiagnostics
        let oldSelection = selection

        _commitDocument(newDocument)
        _commitSource(savedText)
        _commitDiagnostics(mutationDiagnostics + exportResult.diagnostics)
        if let updateSelection {
            selection = updateSelection(oldSelection, newDocument)
        }

        undoManager.registerUndo(withTarget: self) { editor in
            editor._restoreSnapshot(
                document: oldDocument,
                source: oldSource,
                diagnostics: oldDiagnostics,
                selection: oldSelection
            )
        }
        undoManager.setActionName(actionName)
    }

    private func _selectionAfterMutation(
        previousSelection: DiagramSelection?,
        in document: DiagramDocument
    ) -> DiagramSelection? {
        guard let previousSelection else { return nil }
        guard previousSelection.diagramType == document.type else { return nil }
        return _selectionExists(previousSelection, in: document) ? previousSelection : nil
    }

    private func _selectionExists(
        _ selection: DiagramSelection,
        in document: DiagramDocument
    ) -> Bool {
        switch document.payload {
        case .flowchart(let graph), .stateDiagram(let graph):
            let id = selection.elementID
            if id.hasPrefix("node:") {
                let nodeID = String(id.dropFirst(5))
                return graph.nodesInOrder.contains { $0.id == nodeID }
            }
            if id.hasPrefix("edge:") {
                return _findEdge(in: graph, selectionElementID: id) != nil
            }
            return false
        default:
            return true
        }
    }

    // MARK: - Internal derivation methods

    func _apply(
        _ mutation: DiagramMutation, to document: DiagramDocument
    ) throws -> DiagramDocument {
        switch mutation {
        case .deleteElement(let selection):
            return try _deleteElement(selection, from: document)
        case .setLabel(let selection, let label):
            return try _setLabel(of: selection, to: label, in: document)
        case .setTitle(let title):
            return _setTitle(title, in: document)
        case .noop:
            return document
        case .setTheme(let name):
            return try _setTheme(name, in: document)
        case .setLayoutPreset(let preset):
            return _setLayoutPreset(preset, in: document)
        }
    }

    // MARK: - Flow-graph payload helper

    /// Apply `body` to the `MermaidGraph` inside a `.flowchart` or
    /// `.stateDiagram` payload. Throws `.unsupportedMutation` for any
    /// other payload. The body's throws propagate unchanged.
    private func _withFlowGraphPayload(
        in document: inout DiagramDocument,
        mutation: String,
        body: (inout original_src_types.MermaidGraph) throws -> Void
    ) throws {
        switch document.payload {
        case .flowchart(var graph):
            try body(&graph)
            document.payload = .flowchart(graph)
        case .stateDiagram(var graph):
            try body(&graph)
            document.payload = .stateDiagram(graph)
        default:
            throw DiagramEditorError.unsupportedMutation(
                mutation: mutation,
                diagramType: String(describing: document.type)
            )
        }
    }

    // MARK: - Core mutation implementations

    func _deleteElement(
        _ selection: DiagramSelection, from document: DiagramDocument
    ) throws -> DiagramDocument {
        try _deleteElementReportingRenames(selection, from: document).document
    }

    /// `_deleteElement`, also returning the node ids the delete renamed
    /// (a state's notes are renumbered), so a selection can follow them.
    func _deleteElementReportingRenames(
        _ selection: DiagramSelection, from document: DiagramDocument
    ) throws -> (document: DiagramDocument, renames: [String: String]) {
        try _validateSelection(selection, matches: document)
        var doc = document
        let id = selection.elementID
        try _withFlowGraphPayload(in: &doc, mutation: "deleteElement") { graph in
            if id.hasPrefix("node:") {
                let nodeID = String(id.dropFirst(5))
                guard graph.nodesInOrder.contains(where: { $0.id == nodeID }) else {
                    throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
                }
                Self._removeEdges(from: &graph) { $0.source == nodeID || $0.target == nodeID }
                Self._purgeNodes([nodeID], from: &graph)
            } else if id.hasPrefix("edge:") {
                guard let index = _findEdge(in: graph, selectionElementID: id) else {
                    throw DiagramEditorError.elementNotFound(
                        id: String(id.dropFirst(5)), kind: "edge"
                    )
                }
                Self._removeEdges(from: &graph, at: [index])
            } else if id.hasPrefix("group:") {
                let groupID = String(id.dropFirst(6))
                let forest = Self._copySubgraphForest(graph.subgraphs)
                let (nextForest, removed) = Self._extractSubgraph(groupID, from: forest)
                guard let removed else {
                    throw DiagramEditorError.elementNotFound(id: groupID, kind: "subgraph")
                }
                // The group goes with its members (nested groups included)
                // and every transition or edge that names any of them or
                // the group itself, as a node delete takes its edges.
                var removedIDs = Self._allMemberNodeIDs(in: removed).union(Self._allSubgraphIDs(in: removed))
                // A state composite's [*] markers are shared by its
                // concurrency regions and filed under the first region that
                // names them: a marker still used by a transition whose
                // other end survives is not part of what is deleted.
                let markers = Set(graph.nodesInOrder.filter {
                    $0.node.shape == .stateStart || $0.node.shape == .stateEnd
                }.map(\.id)).intersection(removedIDs)
                let deletedStates = removedIDs.subtracting(markers)
                for marker in markers where graph.edges.contains(where: { edge in
                    (edge.source == marker && !deletedStates.contains(edge.target) && !markers.contains(edge.target))
                        || (edge.target == marker && !deletedStates.contains(edge.source) && !markers.contains(edge.source))
                }) {
                    removedIDs.remove(marker)
                }
                graph.subgraphs = nextForest
                Self._removeEdges(from: &graph) {
                    removedIDs.contains($0.source) || removedIDs.contains($0.target)
                }
                Self._purgeNodes(removedIDs, from: &graph)
            } else {
                throw DiagramEditorError.unknownElementKind(id: id)
            }
        }
        var renames: [String: String] = [:]
        if case .stateDiagram(var graph) = doc.payload, case .stateDiagram(let before) = document.payload {
            renames = Self._tidyStateGraphAfterDelete(&graph, before: before)
            doc.payload = .stateDiagram(graph)
        }
        return (doc, renames)
    }

    /// `_modelFingerprint` of a state diagram with its node list and each
    /// group's member list in id order, and a nested composite left out of
    /// its parent's member list: equal for two models that differ only in
    /// the order the source names states.
    nonisolated static func _stateFingerprintIgnoringOrder(_ document: DiagramDocument) -> String {
        guard case .stateDiagram(var graph) = document.payload else { return _modelFingerprint(document) }
        graph.nodesInOrder.sort { $0.id < $1.id }
        func sorted(_ list: [original_src_types.MermaidSubgraph]) -> [original_src_types.MermaidSubgraph] {
            list.map { sub in
                var sub = sub
                // A nested composite is listed among its parent's members
                // only when a transition names it before its block opens:
                // naming order again, and the nesting itself is compared.
                let childIDs = Set(sub.children.map(\.id))
                sub.nodeIds.removeAll { childIDs.contains($0) }
                sub.nodeIds.sort()
                sub.children = sorted(sub.children)
                return sub
            }
        }
        graph.subgraphs = sorted(graph.subgraphs)
        var copy = document
        copy.payload = .stateDiagram(graph)
        return _modelFingerprint(copy)
    }

    /// What state syntax cannot write after a delete, removed or renamed
    /// the way the parser would read the saved text:
    /// - a `[*]` start or end marker with no transition left (state syntax
    ///   writes `[*]` only as a transition end);
    /// - a note whose state is gone (a note whose link alone is gone stays,
    ///   as a floating note), and the remaining notes of a state
    ///   renumbered `X----note`, `X----note-2`, … as the parser names them;
    /// - an emptied concurrency region is dropped, a composite left with
    ///   one region is a plain composite, and the remaining regions are
    ///   renumbered `X_region_0`, `_1`, ….
    @discardableResult
    static func _tidyStateGraphAfterDelete(
        _ graph: inout original_src_types.MermaidGraph,
        before: original_src_types.MermaidGraph
    ) -> [String: String] {
        var renames: [String: String] = [:]
        // Notes. A note goes with its state. A note whose attaching link
        // was deleted (its state kept) stays as a floating note, which state
        // syntax writes as `note "…" as Id`, under a fresh id.
        let ids = Set(graph.nodesInOrder.map(\.id))
        let noteIDs = Set(before.nodesInOrder.filter { $0.node.shape == .stateNote }.map(\.id))
        var gone: Set<String> = []
        for note in noteIDs where ids.contains(note) {
            guard let link = before.edges.first(where: { $0.source == note || $0.target == note }),
                  !graph.edges.contains(where: { $0.source == note || $0.target == note }) else { continue }
            let state = link.source == note ? link.target : link.source
            if ids.contains(state) {
                var fresh = "\(state)_note"
                var n = 2
                while ids.contains(fresh) || renames.values.contains(fresh) { fresh = "\(state)_note_\(n)"; n += 1 }
                renames[note] = fresh
            } else {
                gone.insert(note)
            }
        }
        _purgeNodes(gone, from: &graph)
        if !renames.isEmpty { _renameNodes(renames, in: &graph) }
        // Markers no transition uses any more.
        let used = Set(graph.edges.flatMap { [$0.source, $0.target] })
        let orphans = Set(graph.nodesInOrder.filter {
            ($0.node.shape == .stateStart || $0.node.shape == .stateEnd) && !used.contains($0.id)
        }.map(\.id))
        _purgeNodes(orphans, from: &graph)
        // Note numbering per state.
        var numbering: [String: String] = [:]
        var perState: [String: Int] = [:]
        for (id, node) in graph.nodesInOrder where node.shape == .stateNote {
            guard let range = id.range(of: "----note") else { continue }
            let state = String(id[..<range.lowerBound])
            let n = perState[state, default: 0] + 1
            perState[state] = n
            let wanted = n == 1 ? "\(state)----note" : "\(state)----note-\(n)"
            if wanted != id { numbering[id] = wanted }
        }
        if !numbering.isEmpty {
            _renameNodes(numbering, in: &graph)
            for (old, new) in renames { if let next = numbering[new] { renames[old] = next } }
            for (old, new) in numbering where renames[old] == nil { renames[old] = new }
        }
        // A composite's [*] belongs to the region (or the composite) of its
        // first remaining transition, as the parser files it; regions share
        // one marker per composite. Done before regions are tidied, so a
        // region left holding only the markers counts as emptied.
        func owner(of id: String, in list: [original_src_types.MermaidSubgraph]) -> String? {
            for sub in list {
                if let inner = owner(of: id, in: sub.children) { return inner }
                if sub.nodeIds.contains(id) { return sub.id }
            }
            return nil
        }
        var moves: [String: String] = [:]
        for (id, node) in graph.nodesInOrder where node.shape == .stateStart || node.shape == .stateEnd {
            let scope = id.hasSuffix("_start") ? String(id.dropLast(6)) : (id.hasSuffix("_end") ? String(id.dropLast(4)) : "")
            guard !scope.isEmpty, scope != "root",
                  let edge = graph.edges.first(where: { $0.source == id || $0.target == id }) else { continue }
            let other = edge.source == id ? edge.target : edge.source
            guard let wanted = owner(of: other, in: graph.subgraphs),
                  wanted == scope || wanted.hasPrefix("\(scope)_region_") else { continue }
            if owner(of: id, in: graph.subgraphs) != wanted { moves[id] = wanted }
        }
        if !moves.isEmpty {
            func move(_ list: [original_src_types.MermaidSubgraph]) -> [original_src_types.MermaidSubgraph] {
                list.map { sub in
                    var sub = sub
                    sub.nodeIds.removeAll { moves[$0] != nil && moves[$0] != sub.id }
                    for (id, target) in moves where target == sub.id && !sub.nodeIds.contains(id) { sub.nodeIds.append(id) }
                    sub.children = move(sub.children)
                    return sub
                }
            }
            graph.subgraphs = move(graph.subgraphs)
        }
        // Regions.
        func fixRegions(_ list: [original_src_types.MermaidSubgraph]) -> [original_src_types.MermaidSubgraph] {
            list.map { sub in
                var sub = sub
                sub.children = fixRegions(sub.children)
                let isRegion = { (child: original_src_types.MermaidSubgraph) in child.id.hasPrefix("\(sub.id)_region_") }
                if !sub.children.isEmpty, sub.children.allSatisfy(isRegion) {
                    // An emptied region has nothing to write.
                    let kept = sub.children.filter { !$0.nodeIds.isEmpty || !$0.children.isEmpty }
                    if !kept.isEmpty { sub.children = kept }
                }
                let regions = sub.children.filter(isRegion)
                if !regions.isEmpty, regions.count == sub.children.count {
                    if regions.count == 1, let only = regions.first {
                        sub.nodeIds += only.nodeIds
                        sub.children = only.children
                    } else {
                        sub.children = regions.enumerated().map { index, region in
                            var region = region
                            region.id = "\(sub.id)_region_\(index)"
                            return region
                        }
                    }
                }
                return sub
            }
        }
        graph.subgraphs = fixRegions(graph.subgraphs)
        return renames
    }

    /// Rename node ids everywhere the graph names them.
    static func _renameNodes(_ renames: [String: String], in graph: inout original_src_types.MermaidGraph) {
        graph.nodesInOrder = graph.nodesInOrder.map { entry in
            guard let new = renames[entry.id] else { return entry }
            var node = entry.node
            node.id = new
            return (id: new, node: node)
        }
        for i in graph.edges.indices {
            if let new = renames[graph.edges[i].source] { graph.edges[i].source = new }
            if let new = renames[graph.edges[i].target] { graph.edges[i].target = new }
        }
        func rename(_ list: [original_src_types.MermaidSubgraph]) -> [original_src_types.MermaidSubgraph] {
            list.map { sub in
                var sub = sub
                sub.nodeIds = sub.nodeIds.map { renames[$0] ?? $0 }
                sub.children = rename(sub.children)
                return sub
            }
        }
        graph.subgraphs = rename(graph.subgraphs)
        for (old, new) in renames {
            if let v = graph.classAssignments.removeValue(forKey: old) { graph.classAssignments[new] = v }
            if let v = graph.nodeStyles.removeValue(forKey: old) { graph.nodeStyles[new] = v }
            if let v = graph.nodeInteractions.removeValue(forKey: old) { graph.nodeInteractions[new] = v }
        }
    }

    func _setLabel(
        of selection: DiagramSelection, to label: String, in document: DiagramDocument
    ) throws -> DiagramDocument {
        try _validateSelection(selection, matches: document)
        var doc = document
        let id = selection.elementID
        try _withFlowGraphPayload(in: &doc, mutation: "setLabel") { graph in
            if id.hasPrefix("node:") {
                let nodeID = String(id.dropFirst(5))
                guard graph.nodesInOrder.contains(where: { $0.id == nodeID }) else {
                    throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
                }
                graph.nodesInOrder = graph.nodesInOrder.map { entry in
                    if entry.id == nodeID {
                        var node = entry.node
                        node.label = label
                        // `@{ label: … }` overrides the bracket text in
                        // layout, so a rename must update it too.
                        if node.properties?.label != nil { node.properties?.label = label }
                        // A state's first description is its displayed
                        // label (the parser rebuilds the label from it).
                        if !node.descriptions.isEmpty { node.descriptions[0] = label }
                        return (id: entry.id, node: node)
                    }
                    return entry
                }
            } else if id.hasPrefix("edge:") {
                guard let index = _findEdge(in: graph, selectionElementID: id) else {
                    throw DiagramEditorError.elementNotFound(
                        id: String(id.dropFirst(5)), kind: "edge"
                    )
                }
                graph.edges[index].label = label
            } else {
                throw DiagramEditorError.unknownElementKind(id: id)
            }
        }
        return doc
    }

    func _setTitle(_ title: String?, in document: DiagramDocument) -> DiagramDocument {
        var doc = document
        doc.title = title
        return doc
    }

    func _setTheme(_ name: String?, in document: DiagramDocument) throws -> DiagramDocument {
        if let name, DiagramTheme.theme(named: name) == nil {
            throw DiagramEditorError.unknownThemeName(name: name)
        }
        var doc = document
        var fm = doc.frontmatter ?? DiagramDocumentFrontmatter()
        fm.theme = name
        doc.frontmatter = fm.isEmpty ? nil : fm
        return doc
    }

    func _setLayoutPreset(_ preset: LayoutPreset, in document: DiagramDocument) -> DiagramDocument {
        var doc = document
        var fm = doc.frontmatter ?? DiagramDocumentFrontmatter()
        fm.layout = preset == .adaptive ? LayoutPreset.adaptive.rawValue : nil
        doc.frontmatter = fm.isEmpty ? nil : fm
        // The flowchart parser copies the frontmatter layout onto the
        // graph's config, where the layout factory reads it; do the same so
        // the model is what the saved text reads as.
        if case .flowchart(var graph) = doc.payload {
            var config = graph.config ?? original_src_types.FlowchartConfig()
            config.layoutPreset = fm.layout
            let unset = config.curve == nil && config.htmlLabels == nil && config.markdownAutoWrap == nil
                && config.width == nil && config.inheritDir == nil && config.securityLevel == nil && config.layoutPreset == nil
            graph.config = unset ? nil : config
            doc.payload = .flowchart(graph)
        }
        return doc
    }

    // MARK: - Removal helpers

    /// Remove the edges `shouldRemove` selects, keeping every index-keyed
    /// `linkStyle` on the edge it styled (styles of removed edges are
    /// dropped, later indices shift down; `default` (-1) is untouched) and
    /// dropping id-keyed edge state no remaining edge uses.
    static func _removeEdges(
        from graph: inout original_src_types.MermaidGraph,
        where shouldRemove: (original_src_types.MermaidEdge) -> Bool
    ) {
        let indices = Set(graph.edges.indices.filter { shouldRemove(graph.edges[$0]) })
        _removeEdges(from: &graph, at: indices)
    }

    static func _removeEdges(from graph: inout original_src_types.MermaidGraph, at indices: Set<Int>) {
        guard !indices.isEmpty else { return }
        let removedIDs = Set(indices.compactMap { graph.edges.indices.contains($0) ? graph.edges[$0].id : nil })
        let sortedRemoved = indices.sorted()
        var linkStyles: [Int: [String: String]] = [:]
        for (index, style) in graph.linkStyles {
            if index < 0 {
                linkStyles[index] = style
            } else if !indices.contains(index) {
                // Number of removed edges below `index`.
                var lower = 0, upper = sortedRemoved.count
                while lower < upper {
                    let mid = (lower + upper) / 2
                    if sortedRemoved[mid] < index { lower = mid + 1 } else { upper = mid }
                }
                linkStyles[index - lower] = style
            }
        }
        graph.linkStyles = linkStyles
        graph.edges = graph.edges.enumerated().filter { !indices.contains($0.offset) }.map(\.element)
        let remainingIDs = Set(graph.edges.compactMap(\.id))
        for edgeID in removedIDs where !remainingIDs.contains(edgeID) {
            graph.edgeClassAssignments[edgeID] = nil
            graph.edgeProperties[edgeID] = nil
        }
    }

    /// Remove the nodes `ids` and everything keyed by them: per-node styles,
    /// class assignments, click handlers and subgraph membership. Class
    /// definitions are shared and stay.
    static func _purgeNodes(_ ids: Set<String>, from graph: inout original_src_types.MermaidGraph) {
        guard !ids.isEmpty else { return }
        graph.nodesInOrder.removeAll { ids.contains($0.id) }
        for id in ids {
            graph.classAssignments[id] = nil
            graph.nodeStyles[id] = nil
            graph.nodeInteractions[id] = nil
        }
        func prune(_ subgraphs: [original_src_types.MermaidSubgraph]) -> [original_src_types.MermaidSubgraph] {
            subgraphs.map { subgraph in
                var copy = subgraph
                copy.nodeIds.removeAll { ids.contains($0) }
                copy.children = prune(subgraph.children)
                return copy
            }
        }
        graph.subgraphs = prune(graph.subgraphs)
    }

    /// The ids of `sub` and every subgraph nested in it.
    static func _allSubgraphIDs(in sub: original_src_types.MermaidSubgraph) -> Set<String> {
        var ids: Set<String> = [sub.id]
        for child in sub.children { ids.formUnion(_allSubgraphIDs(in: child)) }
        return ids
    }

    // MARK: - Edge matching helpers

    /// Find the index of an edge matching the selection element ID.
    func _findEdge(
        in model: original_src_types.MermaidGraph,
        selectionElementID: String
    ) -> Int? {
        var counts: [String: Int] = [:]
        for (index, edge) in model.edges.enumerated() {
            let base = _guaranteedEdgeID(for: edge)
            let count = counts[base, default: 0]
            counts[base] = count + 1

            let stableID = count > 0 ? "\(base)/\(count)" : base
            if stableID == selectionElementID {
                return index
            }
        }
        return nil
    }

    /// Compute the guaranteed stable edge ID (matches PositionedEdge.stableElementID).
    /// Delegates to the single source-of-truth helper in DiagramKitModel so
    /// the bounds-lookup and editor paths cannot drift.
    func _guaranteedEdgeID(for edge: original_src_types.MermaidEdge) -> String {
        _guaranteedDiagramEdgeID(
            id: edge.id,
            source: edge.source,
            target: edge.target,
            label: edge.label
        )
    }

    func _validateSelection(
        _ selection: DiagramSelection,
        matches document: DiagramDocument
    ) throws {
        guard selection.diagramType == document.type else {
            throw DiagramEditorError.selectionTypeMismatch(
                selection: selection.diagramType,
                document: document.type
            )
        }
    }
}
#endif

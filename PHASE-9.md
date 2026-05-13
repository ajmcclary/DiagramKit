# Phase 9: Interactive Model (Editor Primitives)

Goal: provide editor primitives after import/export and stable geometry are
settled, without shipping a turnkey editor UI.

Date: 2026-05-12. This plan follows the completed Phase 8 (interactivity
primitives) and refines the Phase 9 sketch in `PHASES.md`. Phase 10
(release/deprecation cleanup) is split to a separate future document; this
file covers Phase 9 only.

## Table of Contents

1. [Motivation and Scope](#1-motivation-and-scope)
2. [Target Placement](#2-target-placement)
3. [DiagramEditor Design](#3-diagrameditor-design)
4. [Mutation API](#4-mutation-api)
5. [Undo Model](#5-undo-model)
6. [Source Sync via Exporters](#6-source-sync-via-exporters)
7. [What Is Not Shipped](#7-what-is-not-shipped)
8. [Test Strategy](#8-test-strategy)
9. [Verification Gates](#9-verification-gates)

---

## 1. Motivation and Scope

### 1.1 Why Editor Primitives

Phase 8 shipped the read-only interactivity surface: `DiagramSelection`,
`DiagramBoundsLookup`, hit-testing, marquee selection, and stable element IDs.
A consumer can answer "what did the user click on?" and "where is element X?"
but cannot answer "what should happen if the user deletes element X?"

Phase 9 fills that gap with a small, focused editor model that:

- Owns a `DiagramDocument` and exposes typed mutations.
- Provides an undo/redo stack so consumers can build Edit → Undo without
  designing their own snapshot machinery.
- Keeps source text in sync by re-emitting through the exporter protocol
  (Phase 7) using an explicit `DiagramFormatID`, never through hand-written
  string patches.
- Ships without a single SwiftUI view, gesture recognizer, or selection
  rect renderer. Consumers wire the model to their own UI.

MusicToolkit's philosophy applies: the library ships the model and the
spatial primitives; the consumer builds the editor UI. DiagramKit's
existing `LiveEditorStore` in the playground is a consumer-built editor —
Phase 9 makes that pattern available to all consumers.

### 1.2 What Phase 9 Delivers

- **`DiagramKitInteractive` target** — Apple-only (requires `@MainActor`,
  `@Observable`). Depends on `DiagramKitModel` and `DiagramKitExport`.
  No dependency on the umbrella `DiagramKit`, `DiagramKitImport`,
  `DiagramKitRenderingCG`, or `DiagramKitViews`.
- **`DiagramEditor` class** — `@MainActor @Observable`, owning a
  `DiagramDocument`, undo stack, selection state, typed mutations, and an
  explicit `preferredExportFormat`.
- **Undo/redo** — full-document snapshots with a configurable depth limit.
  Mutations commit atomically: compute → validate → swap state → register
  undo. Undo/redo closures are nonthrowing.
- **Source sync** — after every mutation, the editor re-exports the
  `DiagramDocument` through `DiagramExportLoader.export(_:to:registry:)`
  using the stored `preferredExportFormat`.
- **No UI, no layout.** No `DiagramEditorView`, no `positionedGraph` stored
  in the editor, no `selectionBounds`. Layout and hit-testing remain
  upstream consumer concerns.

### 1.3 What Phase 9 Does NOT Deliver

- Turnkey editor UI (`DiagramEditorView`, toolbar, inspector, property
  editor).
- Per-element styling or attribute mutations beyond label/title.
- Multi-user collaborative editing.
- Serialization of editor state (undo stack is not persisted).
- Export of selection state.
- Hit-testing or layout in the editor — consumers use `PositionedGraph.lookup`
  directly and manage layout themselves.
- `moveNode` — layout does not yet respect fixed positions; shipping the
  mutation would create a public promise the model cannot honor.
- Non-flowchart family mutations beyond the core `DiagramMutation` set
  (`deleteElement`, `setLabel`, `setTitle`). Sequence-diagram mutations
  and family-specific insertion are deferred.

---

## 2. Target Placement

```
DiagramKitCommon          ← portable geometry (existing)
  → DiagramKitModel       ← DiagramSelection, DiagramBoundsLookup (existing)
    → DiagramKitExport    ← DiagramExporter, ExporterRegistry,
                            DiagramExportLoader, DiagramFormatID (existing)
      → DiagramKitInteractive  ← NEW: DiagramEditor, DiagramMutation
```

`DiagramKitInteractive` is an **Apple-only** target because `@MainActor
@Observable` requires `Observation` (iOS 17+, macOS 14+, visionOS 1+ —
already the package floor). It depends on:

- `DiagramKitModel` — `DiagramDocument`, `DiagramSelection`,
  `DiagramBoundsLookup`, `DiagramType`, `DiagramDiagnostic`
- `DiagramKitExport` — `DiagramExporter`, `ExporterRegistry`,
  `DiagramExportLoader`, `DiagramExportResult`, `DiagramFormatID`

No dependency on `DiagramKitImport` (the editor does not parse source — it
receives an already-parsed `DiagramDocument`), `DiagramKitRenderingCG`,
`DiagramKitViews`, or the umbrella `DiagramKit` target. The editor model
is a pure consumer of the export boundary and the canonical document model.

### 2.1 Package.swift Changes

```swift
// New product
.library(name: "DiagramKitInteractive", targets: ["DiagramKitInteractive"]),

// New target
.target(
    name: "DiagramKitInteractive",
    dependencies: ["DiagramKitModel", "DiagramKitExport"],
    swiftSettings: strictConcurrencySettings
),
```

Optionally add it to the umbrella `DiagramKit` target (Apple-only) so
consumers who import `DiagramKit` get the editor without an extra import:

```swift
.target(name: "DiagramKitInteractive",
    condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])),
```

And to the test target:

```swift
.target(name: "DiagramKitInteractive",
    condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])),
```

### 2.2 File Layout

```
Sources/DiagramKitInteractive/
├── DiagramEditor.swift              (~220 lines)  class + core state
├── DiagramEditor+Undo.swift         (~80 lines)   undo/redo stack
├── DiagramEditor+SourceSync.swift   (~60 lines)   format-ID-driven source sync
├── DiagramEditor+Mutations.swift    (~180 lines)  typed mutation implementations
├── DiagramMutation.swift            (~50 lines)   core mutation value types
└── DiagramEditor+Flowchart.swift    (~120 lines)  flowchart-specific mutations
```

**Estimated source**: ~710 lines across 6 files. Well under the 500-line
warning threshold per file.

---

## 3. DiagramEditor Design

### 3.1 Core Class

```swift
// Sources/DiagramKitInteractive/DiagramEditor.swift

import DiagramKitModel
import DiagramKitExport
import Observation
import Foundation

/// A `@MainActor @Observable` editor model for a single DiagramKit diagram.
///
/// Owns a `DiagramDocument`, undo/redo stack, current selection, and a
/// preferred export format for source sync. Mutations are applied through
/// `perform(_:)` and commit atomically: the new document and source are
/// validated before any state changes.
///
/// ## Concurrency Contract
/// `DiagramEditor` is `@MainActor` because it owns mutable UI-thread
/// state (selection, undo stack). The underlying `DiagramDocument`
/// is `Sendable` and can be read from any context; mutations are
/// serialized through the main actor.
///
/// This type intentionally does not conform to `Sendable`. Consumers
/// that need to serialize editor operations should use the actor
/// isolation already provided by `@MainActor`.
@MainActor
@Observable
public final class DiagramEditor {
    // MARK: - Stored state

    /// The current diagram document. Read-only to external consumers;
    /// mutations go through `perform(_:)`.
    public private(set) var document: DiagramDocument

    /// The preferred export format for source sync.
    /// Mutations re-export through this format via `DiagramExportLoader`.
    public let preferredExportFormat: DiagramFormatID

    /// The exporter registry used for source sync.
    public let exportRegistry: ExporterRegistry

    /// The most recently synced source text, or nil if source sync
    /// has not run or the preferred format does not support the current
    /// diagram type.
    public private(set) var source: String?

    /// The current selection, or nil.
    /// Set directly by the consumer (e.g., from a tap gesture →
    /// `lookup.element(at:)` → `editor.selection = ...`).
    public var selection: DiagramSelection?

    /// The undo manager backing the undo/redo stack.
    public let undoManager: UndoManager

    /// Maximum number of undo states to retain.
    public var maximumUndoDepth: Int = 50 {
        didSet { undoManager.levelsOfUndo = maximumUndoDepth }
    }

    /// Diagnostics from the last export (source sync), if any.
    public private(set) var lastExportDiagnostics: [DiagramDiagnostic] = []

    // MARK: - Initialization

    /// Create an editor for the given document, preferred export format,
    /// and exporter registry.
    ///
    /// The editor does not run an initial source sync. Call
    /// `syncSource()` after initialization to populate `source`.
    public init(
        document: DiagramDocument,
        preferredExportFormat: DiagramFormatID,
        exportRegistry: ExporterRegistry
    ) {
        self.document = document
        self.preferredExportFormat = preferredExportFormat
        self.exportRegistry = exportRegistry
        self.undoManager = UndoManager()
        self.undoManager.levelsOfUndo = maximumUndoDepth
    }
}
```

**Estimated**: ~80 lines for the core class.

### 3.2 Design Decisions

1. **Explicit `preferredExportFormat`.** The editor stores a single
   `DiagramFormatID`, used for every `syncSource()` call via
   `DiagramExportLoader.export(_:to:registry:)`. This avoids the ambiguity
   of scanning a dictionary-backed registry where multiple exporters may
   support the same diagram type (e.g., both Mermaid and D2 support
   flowchart). The consumer decides the output format and passes it in.

2. **No parse/layout in the editor.** `DiagramEditor` takes an already-parsed
   `DiagramDocument`. Parsing and layout happen upstream, in
   `DiagramPipeline` or the consumer's own pipeline. The editor does not
   store a `PositionedGraph`, `selectionBounds`, or any layout state.
   Consumers manage layout and hit-testing independently.

3. **Selection is separate from mutation.** `selection` is a stored property
   the consumer sets directly (e.g., from a tap gesture →
   `lookup.element(at:)` → `editor.selection = ...`). The editor does not
   own hit-testing; that remains in `DiagramBoundsLookup` (Phase 8).

4. **No convenience `init(source:)` in the core target.** A source-based
   convenience initializer would require `DiagramKitImport` (for
   `DiagramLoader`) or the umbrella `DiagramKit` (for `DiagramPipeline`),
   creating unwanted dependencies. Consumers who want source→editor in one
   step parse the source themselves and call
   `DiagramEditor.init(document:preferredExportFormat:exportRegistry:)`.

5. **`UndoManager` over a custom stack.** `Foundation.UndoManager` provides
   grouping, redo, and `NSUndoManager` bridging for free on Apple platforms.
   It runs on the main thread, which matches `@MainActor` isolation. A
   custom stack would be portable but less capable.

6. **`@Observable` not `@MainActor class` with `@Published`.** The
   `Observation` framework is the forward path for SwiftUI and requires
   iOS 17+ / macOS 14+, matching the package's existing platform floor.

---

## 4. Mutation API

### 4.1 Design Principle

Mutations use `DiagramSelection` (Phase 8's opaque stable-element handle)
rather than raw `id: String` wherever the element already exists. This
aligns with the Phase 8 contract: consumers treat `elementID` as opaque and
use `DiagramBoundsLookup` to discover elements. Insertions use raw IDs
because no selection exists yet.

Core mutations (any editable diagram family):

```swift
public enum DiagramMutation: Sendable {
    case deleteElement(DiagramSelection)
    case setLabel(of: DiagramSelection, to: String)
    case setTitle(String?)
    case noop
}
```

Flowchart-specific mutations (added because flowchart is the primary
editor use case and needs insertions):

```swift
public enum FlowchartMutation: Sendable {
    case insertNode(id: String, label: String, type: String? = nil)
    case insertEdge(
        id: String,
        from: DiagramSelection,
        to: DiagramSelection,
        label: String? = nil
    )
}
```

`perform(_:)` dispatches core mutations. Flowchart mutations go through a
separate `performFlowchart(_:)` method that validates the document is a
flowchart and that edge endpoint selections reference existing nodes.

Sequence-diagram mutations, family-specific insertions for C4/class/ER,
and `moveNode` are all deferred. `moveNode` is deferred because the layout
engine does not yet respect fixed positions — shipping the mutation now
would create a public promise the model cannot honor.

### 4.2 Mutation Value Types

```swift
// Sources/DiagramKitInteractive/DiagramMutation.swift

/// A typed mutation on a DiagramDocument.
///
/// Mutations use `DiagramSelection` for existing elements (consistent
/// with Phase 8's opaque stable IDs) and raw `id: String` for insertions
/// where no selection yet exists.
///
/// All cases are `Sendable` — they carry only value-type payloads.
public enum DiagramMutation: Sendable {
    /// Delete the element identified by `selection` and any incident edges.
    case deleteElement(DiagramSelection)

    /// Change the label of the element identified by `selection`.
    case setLabel(of: DiagramSelection, to: String)

    /// Change the diagram's title.
    case setTitle(String?)

    /// A no-op mutation used as a sentinel for undo grouping boundaries.
    case noop
}
```

```swift
// Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift

/// Flowchart-specific mutations.
///
/// These require the document to be a flowchart. `performFlowchart(_:)`
/// validates this before applying.
public enum FlowchartMutation: Sendable {
    /// Insert a new node. `id` must not collide with an existing node.
    case insertNode(id: String, label: String, type: String? = nil)

    /// Insert a directed edge between two existing nodes.
    /// `from` and `to` must be `DiagramSelection` values whose
    /// `elementID` corresponds to existing flowchart nodes.
    case insertEdge(
        id: String,
        from: DiagramSelection,
        to: DiagramSelection,
        label: String? = nil
    )
}
```

**Estimated**: ~50 lines total.

### 4.3 Performing Mutations — Atomic Commit

Mutations follow a compute-then-commit pattern: derive the new document
and source first, validate both, then atomically swap state and register
undo. If derivation or source sync throws, no state is changed and no
undo pollution occurs.

```swift
// Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift

extension DiagramEditor {
    /// Perform a core mutation on the document.
    ///
    /// Derives the new document from the mutation, exports it through
    /// `preferredExportFormat`, and only then commits state and registers
    /// an undo action. If derivation or export throws, no state changes.
    ///
    /// - Parameter mutation: The mutation to apply.
    /// - Throws: `DiagramEditorError` if the mutation cannot be applied
    ///   or source sync fails.
    public func perform(_ mutation: DiagramMutation) throws {
        // 1. Derive new document
        let newDocument = try _apply(mutation, to: document)

        // 2. Export to validate source round-trip
        let exportResult = try DiagramExportLoader.export(
            newDocument,
            to: preferredExportFormat,
            registry: exportRegistry
        )

        // 3. Commit: capture old state → swap → register undo
        let oldDocument = document
        let oldSource = source
        let oldDiagnostics = lastExportDiagnostics

        document = newDocument
        source = exportResult.source
        lastExportDiagnostics = exportResult.diagnostics

        undoManager.registerUndo(withTarget: self) { editor in
            editor._restoreSnapshot(
                document: oldDocument,
                source: oldSource,
                diagnostics: oldDiagnostics
            )
        }
        undoManager.setActionName(mutation.undoActionName)
    }

    /// Perform a flowchart-specific mutation.
    ///
    /// - Parameter mutation: The flowchart mutation to apply.
    /// - Throws: `DiagramEditorError` if the document is not a flowchart,
    ///   the mutation cannot be applied, or source sync fails.
    public func performFlowchart(_ mutation: FlowchartMutation) throws {
        // Validate document type
        guard case .flowchart = document.payload else {
            throw DiagramEditorError.unsupportedMutation(
                mutation: String(describing: mutation),
                diagramType: String(describing: document.payload)
            )
        }

        let newDocument = try _applyFlowchart(mutation, to: document)
        let exportResult = try DiagramExportLoader.export(
            newDocument,
            to: preferredExportFormat,
            registry: exportRegistry
        )

        let oldDocument = document
        let oldSource = source
        let oldDiagnostics = lastExportDiagnostics

        document = newDocument
        source = exportResult.source
        lastExportDiagnostics = exportResult.diagnostics

        undoManager.registerUndo(withTarget: self) { editor in
            editor._restoreSnapshot(
                document: oldDocument,
                source: oldSource,
                diagnostics: oldDiagnostics
            )
        }
        undoManager.setActionName(mutation.undoActionName)
    }

    /// Begin an undo group. All mutations until `endUndoGrouping()`
    /// are undone/redone as a single unit.
    public func beginUndoGrouping() {
        undoManager.beginUndoGrouping()
    }

    /// End the current undo group.
    public func endUndoGrouping() {
        undoManager.endUndoGrouping()
    }

    // MARK: - Mutation application (derivation only — no state change)

    private func _apply(
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
        }
    }

    private func _applyFlowchart(
        _ mutation: FlowchartMutation, to document: DiagramDocument
    ) throws -> DiagramDocument {
        switch mutation {
        case .insertNode(let id, let label, let type):
            return try _insertFlowchartNode(
                id: id, label: label, type: type, into: document
            )
        case .insertEdge(let id, let from, let to, let label):
            return try _insertFlowchartEdge(
                id: id, from: from, to: to, label: label, into: document
            )
        }
    }

    // MARK: - Snapshot restore (nonthrowing — snapshots are known-good)

    private func _restoreSnapshot(
        document: DiagramDocument,
        source: String?,
        diagnostics: [DiagramDiagnostic]
    ) {
        // Register redo using current state (before restore)
        let currentDocument = self.document
        let currentSource = self.source
        let currentDiagnostics = self.lastExportDiagnostics

        undoManager.registerUndo(withTarget: self) { editor in
            editor._restoreSnapshot(
                document: currentDocument,
                source: currentSource,
                diagnostics: currentDiagnostics
            )
        }

        self.document = document
        self.source = source
        self.lastExportDiagnostics = diagnostics
    }
}
```

**Estimated**: ~180 lines.

### 4.4 Mutation Implementations

Each `_apply` method pattern-matches the document's payload case, applies
the mutation to the appropriate model type, and returns a new
`DiagramDocument`. The initial cut supports flowchart only — `deleteElement`
and `setLabel` dispatch on the `DiagramSelection.elementID` prefix to
determine whether the target is a node (`"node:..."`) or an edge
(`"edge:..."`).

```swift
private func _deleteElement(
    _ selection: DiagramSelection, from document: DiagramDocument
) throws -> DiagramDocument {
    var doc = document
    let id = selection.elementID
    switch doc.payload {
    case .flowchart(var model):
        if id.hasPrefix("node:") {
            let nodeID = String(id.dropFirst(5))
            guard model.nodes.contains(where: { $0.id == nodeID }) else {
                throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
            }
            model.nodes.removeAll { $0.id == nodeID }
            model.edges.removeAll { $0.source == nodeID || $0.target == nodeID }
        } else if id.hasPrefix("edge:") {
            // Edge IDs may have disambiguation suffixes; match by prefix
            let edgeID = String(id.dropFirst(5))
            guard model.edges.contains(where: { $0.id == edgeID || id.hasPrefix("edge:\($0.id)") }) else {
                throw DiagramEditorError.elementNotFound(id: edgeID, kind: "edge")
            }
            model.edges.removeAll { $0.id == edgeID || id == "edge:\($0.id)" }
        } else {
            throw DiagramEditorError.unknownElementKind(id: id)
        }
        doc.payload = .flowchart(model)
    default:
        throw DiagramEditorError.unsupportedMutation(
            mutation: "deleteElement",
            diagramType: String(describing: doc.payload)
        )
    }
    return doc
}
```

Flowchart-specific insertions operate on the `Flowchart` model directly
(validated by the caller):

```swift
private func _insertFlowchartNode(
    id: String, label: String, type: String?, into document: DiagramDocument
) throws -> DiagramDocument {
    var doc = document
    guard case .flowchart(var model) = doc.payload else {
        throw DiagramEditorError.unsupportedMutation(
            mutation: "insertNode",
            diagramType: String(describing: doc.payload)
        )
    }
    guard !model.nodes.contains(where: { $0.id == id }) else {
        throw DiagramEditorError.duplicateNodeID(id: id)
    }
    model.nodes.append(FlowchartNode(id: id, label: label, type: type))
    doc.payload = .flowchart(model)
    return doc
}
```

**Estimated**: ~120 lines for flowchart mutation implementations.
Non-flowchart families follow the same pattern and can land incrementally.

### 4.5 Mutation Support Matrix (Initial Cut)

| Operation | Flowchart | Sequence | Class | ER | C4 | Others |
|-----------|-----------|----------|-------|----|----|--------|
| `deleteElement` | ✅ | deferred | deferred | deferred | deferred | deferred |
| `setLabel` | ✅ | deferred | deferred | deferred | deferred | deferred |
| `setTitle` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `insertNode` | ✅ (FlowchartMutation) | deferred | deferred | deferred | deferred | deferred |
| `insertEdge` | ✅ (FlowchartMutation) | deferred | deferred | deferred | deferred | deferred |

`setTitle` works on any family because `DiagramDocument` carries a
diagram-level title independent of the typed payload. The implementation
sets `document.title` directly without payload dispatch.

---

## 5. Undo Model

### 5.1 Design

The undo model uses `Foundation.UndoManager` with full-document snapshots.
The critical design choice is **atomic commit**: the new document and source
are fully derived and validated before any state change occurs. This
prevents undo-stack pollution from failed mutations.

1. Derive `newDocument` from the mutation (may throw — unsupported family,
   duplicate ID, element not found).
2. Export `newDocument` through `DiagramExportLoader.export(_:to:registry:)`
   (may throw — no exporter for format, exporter internal error).
3. Capture old `(document, source, lastExportDiagnostics)`.
4. Swap state: `document = newDocument`, `source = exportResult.source`,
   `lastExportDiagnostics = exportResult.diagnostics`.
5. Register undo closure that calls `_restoreSnapshot(...)` with the
   captured old state.

If step 1 or 2 throws, steps 3–5 are never reached. The undo stack remains
clean.

### 5.2 Snapshot Restore Is Nonthrowing

`_restoreSnapshot` restores a previously-validated state. Because the
snapshot was captured after successful derivation and export, restoring it
is infallible. The closure does not use `try?` — any failure at this point
is a programming error and should trap.

### 5.3 Depth Limiting

`maximumUndoDepth` defaults to 50 and is forwarded to
`undoManager.levelsOfUndo`. When the stack exceeds the limit, `UndoManager`
drops the oldest states automatically.

### 5.4 What Is NOT Undone

- **Selection.** Selection is ephemeral UI state; undoing a mutation does
  not restore the selection that was active before the mutation.
- **Zoom/scroll.** View-level concerns, not editor model concerns.
- **Layout.** Undo restores the `DiagramDocument`, not a
  `PositionedGraph`. The consumer re-layouts after undo.

**Estimated**: ~80 lines in `DiagramEditor+Undo.swift`.

---

## 6. Source Sync via Exporters

### 6.1 Design

Source sync uses `DiagramExportLoader.export(_:to:registry:)` with the
editor's stored `preferredExportFormat`. No scanning, no "active exporter"
— the format ID is explicit and the registry does deterministic
`exporter(named:)` lookup.

```swift
// Sources/DiagramKitInteractive/DiagramEditor+SourceSync.swift

extension DiagramEditor {
    /// Re-export the current document via `preferredExportFormat`.
    ///
    /// Uses `DiagramExportLoader.export(_:to:registry:)` for deterministic
    /// format-ID-based dispatch. Sets `source` to the exported source text
    /// and `lastExportDiagnostics` to any non-fatal diagnostics.
    ///
    /// - Throws: `DiagramExportError` if no exporter is registered for
    ///   `preferredExportFormat`, or if the exporter throws a fatal error.
    public func syncSource() throws {
        let result = try DiagramExportLoader.export(
            document,
            to: preferredExportFormat,
            registry: exportRegistry
        )
        self.source = result.source
        self.lastExportDiagnostics = result.diagnostics
    }
}
```

**Estimated**: ~30 lines.

### 6.2 Source Sync in Mutation Flow

Source sync is integrated into `perform(_:)` — every mutation re-exports
automatically. Consumers never call `syncSource()` directly after a
mutation; they only call it after initializing the editor to populate
`source` from the initial document.

### 6.3 No Hand-Written String Patches

The editor never modifies `source` directly. Every source update flows
through `DiagramExportLoader.export(_:to:registry:)`. This keeps the
source-text pane in sync with the document model and avoids the class of
bugs where hand-edited source text drifts from the in-memory model.

---

## 7. What Is Not Shipped

The following are **explicitly deferred** or excluded from Phase 9:

- **`DiagramEditorView`.** No SwiftUI or AppKit view is included. Consumers
  build their own editor UI using `DiagramEditor` + `DiagramView` +
  `PositionedGraph.lookup`.
- **Turnkey gesture recognizers.** Consumers wire `NSClickGestureRecognizer`
  / `TapGesture` → `lookup.element(at:)` → `editor.selection = ...`.
- **Selection-highlight rendering.** Consumers draw their own highlight
  overlays using `lookup.bounds(of:)`. The editor does not store
  `selectionBounds` or a `positionedGraph`.
- **Property inspector UI.** No key-value editor for node/edge attributes.
- **Per-element styling mutations.** `DiagramMutation` covers structural
  changes (delete, label, title), not font/color/shape changes.
- **`moveNode`.** Removed from the public API entirely. The layout engine
  does not yet respect fixed positions; shipping `moveNode` would create
  a public promise the model cannot honor. It can be added in the future
  once layout supports anchored positions.
- **Multi-family mutation support beyond flowchart.** Sequence, class, ER,
  C4, and the remaining families can add `deleteElement`/`setLabel` support
  incrementally. `setTitle` works on all families.
- **Sequence-diagram and non-flowchart insertions.** Flowchart insertions
  (`FlowchartMutation.insertNode` / `insertEdge`) are the only insertions
  in the first cut.
- **Serialization of editor state.** The undo stack is not persisted.
- **Collaborative editing.** No CRDT or OT support.
- **Convenience `init(source:)` in the core target.** This would require
  `DiagramKitImport` or the umbrella `DiagramKit`, creating a dependency
  the core target should not have. Consumers parse source themselves and
  pass the resulting `DiagramDocument`.

---

## 8. Test Strategy

### 8.1 Test File Structure

```
Tests/DiagramKitTests/Interactive/
├── DiagramEditorTests.swift             (~20 tests: init, selection, syncSource)
├── DiagramEditorMutationTests.swift     (~25 tests: each core mutation type)
├── DiagramEditorFlowchartTests.swift    (~15 tests: flowchart-specific mutations)
├── DiagramEditorUndoTests.swift         (~15 tests: undo/redo/grouping/depth/atomicity)
├── DiagramEditorSourceSyncTests.swift   (~10 tests: format-ID-driven export)
└── DiagramMutationTests.swift           (~10 tests: value-type semantics)
```

**Estimated**: ~95 tests across 6 files.

### 8.2 Per-Test-Area Coverage

**DiagramEditorTests**:
- Init with `DiagramDocument` + `preferredExportFormat` + `exportRegistry`.
- `syncSource()` populates `source` after init.
- `syncSource()` with unsupported format → throws or empty result.
- Selection get/set.
- `undoManager` is accessible and configured.

**DiagramEditorMutationTests** (core mutations, flowchart):
- `deleteElement` with node selection: node removed, incident edges removed.
- `deleteElement` with edge selection: edge removed.
- `deleteElement` with nonexistent selection → throws `elementNotFound`.
- `setLabel` on node: label updated, source reflects change.
- `setLabel` on edge: label updated.
- `setTitle`: title updated.
- `setTitle(nil)`: title cleared.
- Mutation on non-flowchart family → throws `unsupportedMutation`.
- `noop` does not change document or source.
- Mutation atomicity: if export throws, document/source unchanged, undo
  stack clean.

**DiagramEditorFlowchartTests**:
- `insertNode`: new node in model, source reflects it.
- `insertNode` with duplicate ID → throws `duplicateNodeID`.
- `insertNode` on non-flowchart document → `performFlowchart` throws.
- `insertEdge`: new edge between existing nodes.
- `insertEdge` with nonexistent endpoint selection → throws `elementNotFound`.
- `performFlowchart` with `DiagramMutation.deleteElement` → works (same
  code path as `perform`).

**DiagramEditorUndoTests**:
- Single mutation undo restores previous document and source.
- Single mutation redo reapplies mutation.
- Multiple mutations undo in reverse order.
- Undo grouping: `beginUndoGrouping` / `endUndoGrouping` → one undo step.
- Redo after undo.
- Depth limiting: mutations beyond `maximumUndoDepth` drop oldest states.
- Undo action name matches mutation.
- Failed mutation does not pollute undo stack (atomicity).
- Undo/redo closures are nonthrowing — restoring a known-good snapshot
  always succeeds.

**DiagramEditorSourceSyncTests**:
- After mutation, `source` reflects the change through the preferred format.
- Mermaid format produces valid Mermaid source (round-trip: export → parse
  → same document structure).
- D2 format for flowchart produces valid D2 source.
- Changing `preferredExportFormat` is not supported (it's `let`) — the
  editor is created once per format. Test that format is preserved.

**DiagramMutationTests**:
- `Equatable` / `Hashable` / `Sendable` conformance.
- `undoActionName` is human-readable.
- `DiagramSelection` payloads round-trip correctly.

### 8.3 Test Fixtures

Tests use small, hand-crafted `DiagramDocument` values or parse minimal
Mermaid source strings through `DiagramLoader` in the test harness (not
in the core target). No dependency on the full 396-entry corpus.
Flowchart fixtures are hand-built `Flowchart` model values with 2–3 nodes
and 1–2 edges.

---

## 9. Verification Gates

### 9.1 Per-Slice Gates

```bash
swift build --build-tests
swift test --filter DiagramEditorTests
swift test --filter DiagramEditorMutationTests
swift test --filter DiagramEditorFlowchartTests
swift test --filter DiagramEditorUndoTests
swift test --filter DiagramEditorSourceSyncTests
swift test --filter DiagramMutationTests
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
```

### 9.2 Full Phase 9 Gate

```bash
swift test                                                  # full suite
swift test --filter Interactive                             # all editor tests
swift test --filter Interactivity                           # Phase 8 regression
swift test --filter CorpusSnapshotTests                     # no regressions
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
git diff --check
```

### 9.3 File-Size Constraint

No new `.swift` file exceeds the 500-line warning threshold. The planned
files are all under 250 lines. If `DiagramEditor+Mutations.swift`
approaches the threshold during implementation, split flowchart mutations
into `DiagramEditor+Mutations+Flowchart.swift`.

### 9.4 Sendable Annotation

- `DiagramEditor` is `@MainActor` and intentionally does not conform to
  `Sendable`. It is documented as main-actor-isolated.
- `DiagramMutation` is `Sendable` (all associated values are value types).
- `FlowchartMutation` is `Sendable` (all associated values are value types).
- `DiagramEditorError` is `Sendable` and conforms to `LocalizedError`.

### 9.5 Snapshot Baseline Policy

No snapshot baselines are created or modified. Phase 9 adds no rendering
changes.

---

## Completion Criteria

Phase 9 is complete when:

- [ ] `DiagramKitInteractive` target exists and builds without depending
      on `DiagramKit`, `DiagramKitImport`, `DiagramKitRenderingCG`, or
      `DiagramKitViews`.
- [ ] `DiagramEditor` class is implemented with `preferredExportFormat`,
      `exportRegistry`, undo, selection, and source sync.
- [ ] Core mutations (`deleteElement`, `setLabel`, `setTitle`) work on
      flowcharts.
- [ ] Flowchart mutations (`insertNode`, `insertEdge`) work on flowcharts.
- [ ] `setTitle` works on all families.
- [ ] Undo/redo is atomic: failed mutations do not pollute the undo stack.
- [ ] Undo/redo closures are nonthrowing.
- [ ] Source sync uses `DiagramExportLoader.export(_:to:registry:)` with
      the stored `preferredExportFormat`.
- [ ] All Phase 9 gates pass.
- [ ] No snapshot baselines modified.

---

## Delivery Estimate

| Artifact | Lines | Effort |
|----------|-------|--------|
| `DiagramEditor.swift` | ~80 | |
| `DiagramEditor+Mutations.swift` | ~180 | |
| `DiagramEditor+Flowchart.swift` | ~120 | |
| `DiagramEditor+Undo.swift` | ~80 | |
| `DiagramEditor+SourceSync.swift` | ~30 | |
| `DiagramMutation.swift` | ~50 | |
| Test files (6 files, ~95 tests) | ~900 | |
| **Total source + test** | **~1,440** | **~2-3 days** |

---

*This plan was written against the post-Phase-8 codebase described in
`PHASES.md` and `PHASE-8.md`. The interactivity primitives
(`DiagramSelection`, `DiagramBoundsLookup`, `DiagramStableElement`) are
in place. The exporter protocol (`DiagramExporter`, `ExporterRegistry`,
`DiagramExportLoader`, `DiagramFormatID`) is in place. `ExporterRegistry`
is keyed by `DiagramFormatID` with `exporter(named:)` lookup, and
`DiagramExportLoader.export(_:to:registry:)` is the canonical format-ID-driven
dispatch path. The Mermaid, D2, Structurizr, and PlantUML exporters exist
in `DiagramKitExport`.*

*Phase 10 (release/deprecation cleanup: alias removal, filename renames,
inline fixture migration, corpus snapshots, documentation updates) is split
to a separate document. Alias removal should wait for an actual release
semver decision, and `PHASES.md` still has PlantUML 6B-6E pending.*

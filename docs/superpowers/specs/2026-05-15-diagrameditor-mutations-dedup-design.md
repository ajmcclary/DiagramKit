# DiagramEditor Mutations Dedup — Design

**Date:** 2026-05-15
**Closes:** REVIEW.md §5 Minor / Polish — "`DiagramEditor+Mutations.swift` — near-identical `.flowchart` / `.stateDiagram` blocks in `_deleteElement` and `_setLabel` (~80 dup lines)."

## Problem

`Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift` contains two
mutation implementations, `_deleteElement` (lines 93–144) and `_setLabel`
(lines 146–213), whose `.flowchart` and `.stateDiagram` switch arms are
textually identical apart from the enum wrap on commit.

```swift
case .flowchart(var model):
    // 16 lines of node/edge mutation on `model`
    doc.payload = .flowchart(model)
case .stateDiagram(var model):
    // same 16 lines on `model`
    doc.payload = .stateDiagram(model)
```

Across the two mutations that is roughly 50 source lines of duplication
(REVIEW.md's "~80 dup lines" figure counts the full arm extents including
braces and blanks). The duplication exists because `DiagramPayload.flowchart`
and `.stateDiagram` both wrap the same inner type:

```swift
// Sources/DiagramKitModel/Types.swift:39, 42-44
public typealias ParsedGraphModel = original_src_types.MermaidGraph

public enum DiagramPayload: Sendable {
    case flowchart(ParsedGraphModel)
    case stateDiagram(ParsedGraphModel)
    // ... 26 other arms
}
```

State-diagram positive-path coverage is also absent today. Existing
`.stateDiagram` tests in `Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift`
only assert selection-type-mismatch throws (lines 270–281, 373–384); no
test exercises the happy path that the second copy of the body covers.

## Goal

Replace the duplicated payload-arm handling with one private helper that
forwards an `inout MermaidGraph` to a body closure, then add the two
missing `.stateDiagram` positive-path tests so the parity is structurally
enforced and observably tested.

## Non-goals

- Lifting the helper into `DiagramKitModel` as a public
  `DiagramPayload.withFlowGraphPayload` accessor. No other caller in the
  codebase needs the dual-arm shape (other `case .flowchart` callsites in
  parsers, renderers, exporters, and layouts have family-specific bodies
  that legitimately differ).
- Touching `_setTitle` (no dual-arm pattern), `_insertFlowchartNode`, or
  `_insertFlowchartEdge` (flowchart-only by design — see
  `DiagramEditor+Flowchart.swift`).
- Renaming `original_src_types.MermaidGraph` or `ParsedGraphModel`.
- Adding a generic visitor / per-element-kind helper layer. YAGNI: only
  two mutations share this shape today.

## Approach

**Add a private helper** in the same file that pattern-matches the two
flow-graph arms once and forwards an `inout MermaidGraph` to a body
closure. Both `_deleteElement` and `_setLabel` call it.

### Helper signature

```swift
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
```

**Why `private`** — single-file implementation detail. No external caller,
no test directly invokes it; tests cover behavior through the visible
mutation entry points.

**Why `mutation:` as a String parameter** — preserves the existing
`DiagramEditorError.unsupportedMutation(mutation: String, diagramType: String)`
case byte-for-byte. No new error case, no error-message drift.

**Why `throws -> Void`, not `rethrows`** — the helper itself throws
(`unsupportedMutation`), so `rethrows` is the wrong shape. Plain `throws`
is simpler; the body's throws propagate unchanged.

**Why `inout DiagramDocument` (not `(DiagramDocument) -> DiagramDocument`)**
— matches the caller's existing `var doc = document` pattern. The helper
mutates `doc` in place; the caller still returns `doc`.

### Refactored callers

`_deleteElement` after dedup:

```swift
func _deleteElement(
    _ selection: DiagramSelection, from document: DiagramDocument
) throws -> DiagramDocument {
    try _validateSelection(selection, matches: document)
    var doc = document
    let id = selection.elementID
    try _withFlowGraphPayload(in: &doc, mutation: "deleteElement") { graph in
        if id.hasPrefix("node:") {
            let nodeID = String(id.dropFirst(5))
            guard graph.nodesInOrder.contains(where: { $0.id == nodeID }) else {
                throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
            }
            graph.nodesInOrder.removeAll { $0.id == nodeID }
            graph.edges.removeAll { $0.source == nodeID || $0.target == nodeID }
        } else if id.hasPrefix("edge:") {
            guard let index = _findEdge(in: graph, selectionElementID: id) else {
                throw DiagramEditorError.elementNotFound(
                    id: String(id.dropFirst(5)), kind: "edge"
                )
            }
            graph.edges.remove(at: index)
        } else {
            throw DiagramEditorError.unknownElementKind(id: id)
        }
    }
    return doc
}
```

`_setLabel` collapses to a similar single-body shape (~25 lines).

**Closure-captures-`self`.** `_findEdge` is a method, not a free function,
so the closure captures `self`. Both `_deleteElement` and `_setLabel` are
`@MainActor`-isolated instance methods, so the implicit capture is fine —
no Sendable boundary is crossed. The closure does not escape (the helper
calls it synchronously and returns), so no `[weak self]` is required.

**Behavior parity.** The refactor is a pure restructuring:
- Validation order unchanged: `_validateSelection` still runs before any
  payload pattern-match.
- Error throw order unchanged: `elementNotFound` (node), `elementNotFound`
  (edge), `unknownElementKind`, `unsupportedMutation` all fire from the
  same code paths, just routed through the helper instead of inlined.
- Atomicity unchanged: the helper mutates `doc` in place; the caller's
  `var doc = document` rollback semantics are preserved (a throw inside
  the body never touches the original `document` argument).
- `_apply(_:to:)` dispatch unchanged; the public `perform(_:)` entry point
  unchanged; the worker-hop / `isExporting` / undo-registration logic in
  `_performInner` unchanged.

## Tests

Two new `@Test` cases in
`Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift`,
beside the existing flowchart happy-path tests.

### Test 1 — `stateDiagramDeleteElementRemovesNodeAndIncidentEdges`

Seed a `stateDiagram-v2` source containing two states `A` and `B` with an
edge `A --> B`. Delete `DiagramSelection(diagramType: .stateDiagram, elementID: "node:A")`.
Assert:
- `editor.document.payload` is still `.stateDiagram`.
- The inner `MermaidGraph.nodesInOrder` no longer contains `A`.
- The inner `MermaidGraph.edges` no longer contains the `A→B` edge.
- The export call landed (mock exporter returned non-empty source).

### Test 2 — `stateDiagramSetLabelRenamesNode`

Seed the same `stateDiagram-v2` source. Call
`.setLabel(of: DiagramSelection(diagramType: .stateDiagram, elementID: "node:A"), to: "Renamed A")`.
Assert:
- `editor.document.payload` is still `.stateDiagram`.
- The node with id `A` now has `label == "Renamed A"`.
- The other node and the edge are unchanged.

### Test scaffold

Both tests use the existing `MockExporter` in the file (lines 13–32),
which already declares `.stateDiagram` in `supportedDiagramTypes`. Source
seeding uses a literal `"stateDiagram-v2\n    A --> B"` string so the
Mermaid importer routes through the state parser, not the flowchart
fallback. The state-diagram path through `DiagramRegistry+State.swift` is
the one being exercised — `DiagramPayload.stateDiagram(ParsedGraphModel)`
is the resulting payload shape.

**No existing test changes shape.** Every flowchart happy-path test,
every selection-type-mismatch negative test, and every undo test
continues to assert exactly what it asserts today.

## Verification

- `swift build` clean (strict concurrency).
- `swift test --filter "DiagramEditorMutationTests|DiagramEditorUndoTests|DiagramEditorFlowchartTests|DiagramEditorTests|DiagramEditorSourceSyncTests|DiagramEditorAsyncExportTests|DiagramEditorUndoObservationTests"`
  all green.
- `Scripts/check-file-sizes.sh` — `DiagramEditor+Mutations.swift` drops
  from 265 → ~215 lines; still well under the 500-line warn threshold.
- `Scripts/check-sendable-annotations.sh` — no new `@unchecked Sendable`
  introduced.
- `Scripts/strict-concurrency-check.sh` — first-party clean.
- CLAUDE.md test-source file count unchanged. The new `@Test` cases land
  in the existing `DiagramEditorMutationTests.swift`; CLAUDE.md tracks
  test count by Swift file, not by `@Test` count.

## Rollout

Single PR / commit-by-commit on `main` per project standing default. No
deprecation period needed — the helper is private, callers are local,
and behavior is preserved.

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| `inout` body subtly changes value-type copy semantics for `MermaidGraph` arrays. | `MermaidGraph` is a struct with `Array`-typed fields; `inout` mutation has the same observable semantics as the existing `var model` + reassign pattern. The two new state-diagram tests pin the happy path; existing flowchart tests pin the original path. |
| Closure capture of `self` introduces a new Sendable warning under strict concurrency. | The closure runs synchronously inside an already-`@MainActor`-isolated method and does not cross an actor boundary. `Scripts/strict-concurrency-check.sh` is the gate. |
| Error throw ordering changes (`elementNotFound` vs `unsupportedMutation` fire in a different order for unusual payloads). | The helper throws `unsupportedMutation` only when the payload is neither `.flowchart` nor `.stateDiagram`. `_validateSelection` runs **before** the helper call (the dedup keeps this order). For supported payloads the body runs and its throw order is identical to the original inlined code. |
| Existing un-refactored callers of the dual-arm pattern accidentally adopt the new helper before parity tests land. | The two new `.stateDiagram` tests land in the same commit as the helper extraction, not a follow-up. |

## Open questions

None.

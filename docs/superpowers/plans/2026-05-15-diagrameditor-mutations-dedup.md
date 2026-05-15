# DiagramEditor Mutations Dedup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Collapse the duplicated `.flowchart` / `.stateDiagram` arms in `DiagramEditor._deleteElement` and `_setLabel` behind a single private helper, and add the missing `.stateDiagram` positive-path tests so parity is observably covered.

**Architecture:** Add a private `_withFlowGraphPayload(in:mutation:body:)` helper in `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift` that pattern-matches `.flowchart` / `.stateDiagram` once and forwards an `inout MermaidGraph` to a body closure. Two mutation callers route through it. Two new `@Test` cases in `Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift` build a `.stateDiagram` payload directly (mirroring the existing `flowDoc(...)` pattern — no parser round-trip) and pin delete + setLabel behavior on that payload.

**Tech Stack:** Swift 6, SwiftPM, swift-testing, Apple-only target (`DiagramKitInteractive`).

**Standing default:** commit-by-commit on `main`. No worktrees, no feature branch.

**Spec:** [docs/superpowers/specs/2026-05-15-diagrameditor-mutations-dedup-design.md](../specs/2026-05-15-diagrameditor-mutations-dedup-design.md)

---

## File Structure

- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift` — add the helper, rewire `_deleteElement` and `_setLabel`.
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift` — add `stateDoc(...)` fixture and two new `@Test` cases.

No new files. No model-tier changes. No public-API changes.

---

### Task 1: Add `stateDoc(...)` fixture helper

**Files:**
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift:53-66` (add new helper after the existing `flowDoc(_:mermaidEdges:)` helper)

The existing tests build `DiagramDocument` directly via `flowDoc(...)`; they don't round-trip through the parser. The new state-diagram tests follow the same pattern — direct payload construction, no parser involvement. This isolates the mutation logic from the parser and matches the file's existing style.

- [ ] **Step 1: Add the `stateDoc(...)` helper**

Open `Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift` and insert this helper immediately after the existing `flowDoc(_:mermaidEdges:)` declaration (after line 66, before the `// MARK: - DiagramEditorMutationTests` line at 68):

```swift
private func stateDoc(_ nodes: [String], edges: [(String, String)] = []) -> DiagramDocument {
    let mNodes = nodes.map { id in
        (id: id, node: original_src_types.MermaidNode(id: id, label: "Node \(id)", shape: .rectangle))
    }
    let mEdges = edges.map { (src, tgt) in
        original_src_types.MermaidEdge(source: src, target: tgt, style: .solid)
    }
    let model = original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: mNodes,
        edges: mEdges
    )
    return DiagramDocument(payload: .stateDiagram(model))
}
```

- [ ] **Step 2: Verify the test target still compiles**

Run: `swift build --build-tests`
Expected: `Build complete!` with no warnings or errors. (Strict concurrency is on; the helper is `Sendable`-clean because every captured type is a value type.)

- [ ] **Step 3: Commit**

```bash
git add Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift
git commit -m "$(cat <<'EOF'
test(interactive): add stateDoc(...) fixture for state-diagram mutation tests

Mirrors flowDoc(...) but wraps in .stateDiagram(MermaidGraph) so the
two upcoming state-diagram positive-path tests can build their payload
directly, matching the file's existing direct-construction pattern.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Pin `.stateDiagram` deleteElement happy-path

**Files:**
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift` (add a new `@Test` after the existing `deleteElementSelectionTypeMismatch` test, before the `// MARK: - setLabel` divider at line 283)

This test documents behavior the current `.stateDiagram` arm of `_deleteElement` already implements correctly. Because it's a regression-pin for a refactor (not a feature driver), the test passes green on first run; the upcoming refactor in Task 4 must preserve that green.

- [ ] **Step 1: Add the test**

Insert this `@Test` right after the `deleteElementSelectionTypeMismatch` function (after the `}` that closes it on or near line 281), before the `// MARK: - setLabel` divider at line 283:

```swift
    @Test("deleteElement removes state-diagram node and incident edges")
    func deleteElementStateDiagramNode() async throws {
        let doc = stateDoc(["A", "B", "C"], edges: [("A", "B"), ("B", "C")])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .stateDiagram, elementID: "node:B")
        try await editor.perform(.deleteElement(sel))

        guard case .stateDiagram(let model) = editor.document.payload else {
            #expect(Bool(false), "expected stateDiagram")
            return
        }
        #expect(model.nodesInOrder.count == 2)
        #expect(!model.nodesInOrder.contains(where: { $0.id == "B" }))
        #expect(model.edges.count == 0)
    }
```

- [ ] **Step 2: Run the new test (and the surrounding suite) — confirm it passes green**

Run: `swift test --filter DiagramEditorMutationTests`
Expected: All tests pass, including the new `deleteElementStateDiagramNode`. The line in the test log should read something like `Test "deleteElement removes state-diagram node and incident edges" passed`.

If the new test fails, stop and diagnose — the current `.stateDiagram` arm should already produce this result. Do **not** proceed to commit or to Task 3 until the test is green.

- [ ] **Step 3: Commit**

```bash
git add Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift
git commit -m "$(cat <<'EOF'
test(interactive): pin .stateDiagram deleteElement happy-path

Documents the behavior of DiagramEditor._deleteElement's .stateDiagram
arm so the upcoming dedup refactor can be verified safe. No production
code change.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Pin `.stateDiagram` setLabel happy-path

**Files:**
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift` (add a new `@Test` after the existing `setLabelSelectionTypeMismatch` test, before the `// MARK: - setTitle` divider at line 386)

- [ ] **Step 1: Add the test**

Insert this `@Test` right after the `setLabelSelectionTypeMismatch` function (after the `}` that closes it on or near line 384), before the `// MARK: - setTitle` divider at line 386:

```swift
    @Test("setLabel on state-diagram node updates label")
    func setLabelStateDiagramNode() async throws {
        let doc = stateDoc(["A", "B"])
        let editor = DiagramEditor(
            document: doc,
            preferredExportFormat: .mermaid,
            exportRegistry: mockRegistry()
        )
        let sel = DiagramSelection(diagramType: .stateDiagram, elementID: "node:A")
        try await editor.perform(.setLabel(of: sel, to: "Renamed A"))

        guard case .stateDiagram(let model) = editor.document.payload else {
            #expect(Bool(false), "expected stateDiagram")
            return
        }
        let nodeA = model.nodesInOrder.first { $0.id == "A" }
        #expect(nodeA?.node.label == "Renamed A")
        let nodeB = model.nodesInOrder.first { $0.id == "B" }
        #expect(nodeB?.node.label == "Node B")
    }
```

The trailing `nodeB` assertion pins that only the targeted node was touched.

- [ ] **Step 2: Run the new test (and the surrounding suite) — confirm it passes green**

Run: `swift test --filter DiagramEditorMutationTests`
Expected: All tests pass, including the new `setLabelStateDiagramNode`.

If it fails, stop and diagnose — the current `.stateDiagram` arm of `_setLabel` should already produce this result.

- [ ] **Step 3: Commit**

```bash
git add Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift
git commit -m "$(cat <<'EOF'
test(interactive): pin .stateDiagram setLabel happy-path

Documents the behavior of DiagramEditor._setLabel's .stateDiagram arm
so the upcoming dedup refactor can be verified safe. No production code
change.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Extract `_withFlowGraphPayload` helper + refactor `_deleteElement`

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift:91-144` (add helper, replace `_deleteElement` body)

The helper lands and the first caller migrates in a single commit so the helper is never committed as dead code.

- [ ] **Step 1: Add the helper after `_apply(_:to:)` and before `_deleteElement`**

In `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift`, after the closing `}` of `_apply(_:to:)` at line 89 and before the `// MARK: - Core mutation implementations` divider at line 91, insert:

```swift
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
```

- [ ] **Step 2: Replace the `_deleteElement` body to call the helper**

In the same file, replace the entire body of `_deleteElement` (currently lines 93–144 — from the `func _deleteElement(...)` signature through its closing `}`) with this version. Leave the function signature unchanged:

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

The closure captures `self` (for `_findEdge`). Both `_deleteElement` and the helper run on `@MainActor`, and the closure does not escape (the helper invokes it synchronously and returns), so no `[weak self]` is needed and no strict-concurrency warning is expected.

- [ ] **Step 3: Run the mutation suite — confirm all green (including state-diagram tests from Tasks 2–3)**

Run: `swift test --filter DiagramEditorMutationTests`
Expected: All tests pass — both the flowchart paths (already covered) and the two new `.stateDiagram` paths from Tasks 2–3.

If any test fails, the refactor introduced a regression. Stop and diagnose — do not amend forward; revert the body change, re-read against the spec, and try again.

- [ ] **Step 4: Run the broader Interactive test suite — confirm no collateral damage**

Run: `swift test --filter "DiagramEditorMutationTests|DiagramEditorUndoTests|DiagramEditorFlowchartTests|DiagramEditorAsyncExportTests|DiagramEditorTests|DiagramEditorSourceSyncTests|DiagramEditorUndoObservationTests"`
Expected: All tests pass across all seven suites. Each suite is an exact-suite filter (no substring trap into `CorpusSnapshotTests` parameterized entries).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift
git commit -m "$(cat <<'EOF'
refactor(interactive): extract _withFlowGraphPayload helper

DiagramEditor._deleteElement's .flowchart and .stateDiagram arms wrap
the same ParsedGraphModel (= MermaidGraph) and contain identical
bodies. Extract a private helper that pattern-matches both arms once
and forwards an inout MermaidGraph to a body closure; rewire
_deleteElement to use it. _setLabel migrates in the next commit.

REVIEW.md §5 polish.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Refactor `_setLabel` to use the helper

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift:146-213` (replace `_setLabel` body)

- [ ] **Step 1: Replace the `_setLabel` body to call the helper**

In `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift`, replace the entire body of `_setLabel` (currently the function spanning the lines that were 146–213 before Task 4 — find it by its `func _setLabel(...)` signature) with this version. Leave the function signature unchanged:

```swift
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
```

- [ ] **Step 2: Run the mutation suite — confirm all green**

Run: `swift test --filter DiagramEditorMutationTests`
Expected: All tests pass — both the existing flowchart setLabel tests and the new state-diagram setLabel test from Task 3.

- [ ] **Step 3: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift
git commit -m "$(cat <<'EOF'
refactor(interactive): _setLabel uses _withFlowGraphPayload helper

Second and last caller migration. _deleteElement was migrated in the
previous commit; this completes the dedup. _setTitle and the
flowchart-specific insert helpers don't share the dual-arm shape and
are intentionally left alone.

REVIEW.md §5 polish.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Final verification gates

Run each gate exactly once. Do not re-run unless something fails. (Per user memory: don't keep re-confirming once a result is in.)

**Files:**
- No edits. Read-only verification.

- [ ] **Step 1: File-size gate**

Run: `Scripts/check-file-sizes.sh`
Expected: Reports only the pre-existing yellow warnings. `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift` should now report somewhere around 215 lines (down from 265). No new yellow or red threshold crossings.

If `DiagramEditor+Mutations.swift` shows up as a new threshold crossing (it shouldn't), stop and re-check the file size manually with `wc -l`.

- [ ] **Step 2: Sendable annotations gate**

Run: `Scripts/check-sendable-annotations.sh`
Expected: ✓ green. No new `@unchecked Sendable` introduced (none touched at all).

- [ ] **Step 3: Strict concurrency gate**

Run: `Scripts/strict-concurrency-check.sh`
Expected: ✓ first-party clean. No new strict-concurrency warnings.

- [ ] **Step 4: Final broad-suite test sweep**

Run: `swift test --filter "DiagramEditorMutationTests|DiagramEditorUndoTests|DiagramEditorFlowchartTests|DiagramEditorAsyncExportTests|DiagramEditorTests|DiagramEditorSourceSyncTests|DiagramEditorUndoObservationTests"`
Expected: All tests green across all seven suites.

These seven suites cover every test file under `Tests/DiagramKitTests/Interactive/` that exercises `DiagramEditor`. The filter uses exact-suite names ORed with `|` — no substring trap.

- [ ] **Step 5: Done — no extra commit needed**

If all four gates passed, the implementation is complete. The `git log` for this work should show five commits since the spec landed at `cfccdc5`:

1. Task 1 — `test(interactive): add stateDoc(...) fixture …`
2. Task 2 — `test(interactive): pin .stateDiagram deleteElement happy-path`
3. Task 3 — `test(interactive): pin .stateDiagram setLabel happy-path`
4. Task 4 — `refactor(interactive): extract _withFlowGraphPayload helper`
5. Task 5 — `refactor(interactive): _setLabel uses _withFlowGraphPayload helper`

No CLAUDE.md sync is needed — test-source file count is by Swift file and no new test file landed.

---

## Risk register

| Risk | Mitigation |
|------|------------|
| The new `stateDoc(...)` fixture trips strict-concurrency by capturing a non-Sendable type. | The helper only captures value-type `MermaidNode` / `MermaidEdge` / `MermaidGraph` instances. `swift build --build-tests` in Task 1 Step 2 is the local gate. |
| The Task 2/3 tests fail green on first run (i.e., the `.stateDiagram` arm of `_deleteElement` / `_setLabel` was already broken). | Stop at Step 2 of the failing task and diagnose. The refactor cannot land safely until the existing behavior is understood. This would convert the task from "pin-then-refactor" into "fix-then-pin-then-refactor" — a different work item that should be brainstormed separately. |
| Task 4's helper-extraction creates a strict-concurrency warning about the body closure capturing `self`. | Both `_deleteElement` and the helper are `@MainActor`-isolated; the body closure does not escape (the helper invokes it synchronously). Task 4 Step 3/4 and Task 6 Step 3 are the gates. If a warning surfaces, mark the body parameter `@MainActor` and re-run. |
| `_findEdge` resolution inside the body closure resolves differently when called via the helper (e.g., overload resolution surprises). | `_findEdge` is a method on `DiagramEditor` and is captured via the closure's implicit `self`. Same resolution rules as the original inlined body. If a "missing member" error surfaces, the closure's `self` capture is the first thing to check. |
| A pre-existing test in one of the seven Interactive suites breaks for reasons unrelated to this refactor. | Task 4 Step 4 catches it before Task 5. If a pre-existing failure is observed, fix forward per project standing default (user memory: "Fix pre-existing failures, don't document"). |

---

## Self-review notes (inline, against spec)

- **Spec § Problem (lines counted, payload typealias quoted).** Plan headers Task 4 with file lines from the unedited file (91–144); Tasks 4–5 wire the helper exactly as the spec's "Helper signature" block specifies.
- **Spec § Approach (helper visibility, `mutation:` String param, `throws -> Void`).** Task 4 Step 1 reproduces the helper verbatim.
- **Spec § Refactored callers.** Task 4 Step 2 (`_deleteElement`) and Task 5 Step 1 (`_setLabel`) reproduce the spec's two example bodies; line counts and assertion strings match.
- **Spec § Tests (Test 1 + Test 2 names, assertions).** Task 2 and Task 3 reproduce the two tests. The `nodeB` parity assertion in Task 3 is a refinement of the spec's looser "the other node and the edge are unchanged" wording — kept explicit so the test is self-contained.
- **Spec § Verification (4 gates listed).** Task 6 runs all four — `Scripts/check-file-sizes.sh`, `Scripts/check-sendable-annotations.sh`, `Scripts/strict-concurrency-check.sh`, and the broad swift-testing filter — exactly once each.
- **Spec § Non-goals.** Plan does not touch `_setTitle`, `_insertFlowchartNode`, `_insertFlowchartEdge`, or any model-tier files. Plan does not rename `MermaidGraph` / `ParsedGraphModel`.
- **Spec § Risks.** Risk register mirrors the spec's, with the addition of "Task 2/3 tests fail green" (covering the case where pinning reveals a latent bug — a discovery path the spec didn't explicitly call out but the plan must handle).
- **Spec source seeding clarification.** The spec mentions a literal `"stateDiagram-v2\n    A --> B"` source string. The plan instead builds the `.stateDiagram` payload directly via `stateDoc(...)`, matching the existing `flowDoc(...)` pattern in the same file (no parser round-trip, faster, isolates the mutation logic from parser behavior). The resulting payload shape (`.stateDiagram(MermaidGraph)`) is identical either way; the refactor's correctness is unaffected.

No placeholders, no TBDs, no missing test code, no missing function bodies, no untyped references.

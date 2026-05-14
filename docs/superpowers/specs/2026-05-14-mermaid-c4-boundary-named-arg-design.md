# Mermaid C4 `$boundary` / `$parent` Named-Arg Round-Trip — Design

Author: Claude (Opus 4.7)
Date: 2026-05-14
Status: Draft for review

## Problem

`Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidC4Export.swift:100-103` emits `$boundary=<alias>` on every C4 shape whose `parentBoundary != "global"`, and `:127-130` emits `$parent=<alias>` on every C4 boundary whose `parentBoundary != "global"`. The Mermaid C4 parser in `Sources/DiagramKitModel/src_c4_parser.swift` never reads either:

- `_addPersonOrSystem` (`:426`) and `_addContainerOrComponent` (`:471`) ignore `named["boundary"]` and always assign `parentBoundary = currentBoundary` (the lexical-stack value, which is `"global"` for flat-emit shapes).
- `_addBoundary` (`:518`) and `_addDeploymentNode` (`:564`) ignore `named["parent"]`.

Result: Mermaid → Mermaid round-trip drops parent-boundary linkage for any shape or boundary not physically nested inside a `Boundary(...) { … }` block in the source. Discovered during Session 6's Structurizr round-trip work and recorded as REVIEW.md §7. Session 6's `StructurizrBoundaryRoundTripTests.structurizrToMermaidEmit` stops short of re-parsing the emitted Mermaid for this reason.

REVIEW.md's recommended fix mentions `named["$boundary"]`, but the parser at `:283-289` strips the leading `$` from each named arg before keying — the actual dictionary key is `"boundary"` (similarly `"parent"`).

## Goal

Close the Mermaid C4 `$boundary` / `$parent` round-trip end-to-end:

- Parser honors `$boundary=<alias>` on Person/System/Container/Component macros.
- Parser honors `$parent=<alias>` on Boundary/Enterprise_Boundary/System_Boundary/Container_Boundary/Deployment_Node/Node_L/Node_R macros.
- When both a named arg and a lexical scope are present and disagree, the named arg wins and the parser emits a `.warning`.
- When a named arg references an alias that is never defined in the diagram, the parser emits a `.warning` after the full parse pass (forward-refs are valid until validation).
- Session 6's `StructurizrBoundaryRoundTripTests.structurizrToMermaidEmit` extends to re-parse the Mermaid output now that the gap is closed.

## Non-goals

- **`Deployment_Node` → Mermaid round-trip fidelity.** Mermaid C4 export collapses every `C4Boundary` (including `nodeType`-tagged ones) to the `Boundary(...)` keyword. After this spec, `$parent=` on a deployment node parses correctly, but the round-trip still loses `nodeType` and `type`. Separate spec.
- **PlantUML C4 parser symmetry.** `Sources/DiagramKitPlantUML/C4/PlantUMLC4Parser.swift` has its own boundary handling; not in REVIEW §7 and not in scope.
- **Cross-format round-trip beyond Mermaid → Mermaid and Structurizr → Mermaid.** Mermaid → PlantUML → Mermaid is not exercised by Session 6's tests and stays out of scope.
- **Boundary `type` preservation through `$boundary=`.** Mermaid C4's `Boundary(b, label, type, tags)` already preserves `type` lexically; the named-arg path doesn't change that.
- **New corpus fixture for flat-emit C4.** The round-trip tests cover the case without growing the snapshot baseline set.
- **Migrating the `"global"` sentinel boundary to `Optional<String>`.** Model-shape change that would ripple through every C4 renderer.

## Architecture

Single file: `Sources/DiagramKitModel/src_c4_parser.swift`. No model-type changes, no exporter changes, no public-API changes outside the C4 parser's return shape.

Current data flow has two parallel paths for parent linkage; only one is wired:

```
Mermaid source
  ─ "System(s, 'S')"                                  ──► lexical stack ───► parentBoundary ✓
  ─ "Boundary(b, 'B') { System(s, 'S') }"             ──► lexical stack ───► parentBoundary ✓
  ─ "System(s, 'S') $boundary=b"                      ──► named["boundary"] ─► (dropped) ✗
  ─ "Boundary(b, 'B') $parent=outer"                  ──► named["parent"]   ─► (dropped) ✗
```

After the fix:

```
Mermaid source
  ─ flat-emit with $boundary= / $parent= ──► resolveParent(named, lexical) ─► parentBoundary ✓
  ─ nested with no named arg              ──► lexical stack                ─► parentBoundary ✓
  ─ nested + named arg disagreeing        ──► named wins + .warning        ─► parentBoundary ✓
  ─ after full parse pass                 ──► validateBoundaryRefs(...)    ─► .warning if dangling
```

## Resolution policy

Single function, two callers — shape side and boundary side:

```
effectiveParent = named[key] if present and non-empty, else lexical
```

`key` is `"boundary"` for shapes (Person/System/Container/Component) and `"parent"` for boundaries (Boundary/Enterprise_Boundary/System_Boundary/Container_Boundary/Deployment_Node/Node_L/Node_R).

**Mismatch detection.** If `named[key]` is present AND `lexical != "global"` AND `named[key] != lexical`, emit a `.warning`. Mismatch where `lexical == "global"` (the flat-emit case) is the expected path — no diagnostic.

**Unresolved-ref validation.** After the parse pass populates `shapes` and `boundaries`, walk both arrays. For each `parentBoundary` value that is not `"global"`, `""`, or present in `boundaries.map(\.alias)`, emit a `.warning`. The post-pass placement matters because Mermaid C4 declaration order is free — `$boundary=b` can reference a `Boundary(b, …)` that appears later in the source.

**Boundary alias coverage for the validator** explicitly includes the synthetic `"global"` boundary that `_parseC4Diagram` seeds at line 19 and the empty string. The check is `pb == "global" || pb == "" || boundaries.contains { $0.alias == pb }` — explicit so a future rename of the sentinel doesn't silently regress.

## Diagnostics catalog

Two new `.warning` diagnostics, both flowing through the existing `_parseC4Diagram` diagnostic accumulator:

| Severity | Message shape |
|---|---|
| `.warning` | `Mermaid C4 \(macroName)(\(alias)) named arg \(key)=\(namedValue) overrides enclosing \(lexical) — using named value` |
| `.warning` | `Mermaid C4 \(shape or boundary) '\(alias)' parentBoundary=\(value) references undefined boundary` |

Severity choice (`.warning`) aligns with REVIEW.md §4 (Format slices) and the Session-2 identifier-sanitization severity flip — same lossy/ambiguous operation, same severity.

## Code changes

### Two new private helpers

Placed near the existing `_findMatchingParen` block (~`:400`):

```swift
private func _resolveParentBoundary(
    named: [String: String],
    lexical: String,
    key: String,                      // "boundary" or "parent"
    macroName: String,
    alias: String,
    diagnostics: inout [DiagramDiagnostic]
) -> String {
    guard let namedValue = named[key], !namedValue.isEmpty else {
        return lexical
    }
    if lexical != "global" && lexical != namedValue {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Mermaid C4 \(macroName)(\(alias)) named arg \(key)=\(namedValue) overrides enclosing \(lexical) — using named value"
        ))
    }
    return namedValue
}

private func _validateBoundaryReferences(
    shapes: [C4Shape],
    boundaries: [C4Boundary],
    diagnostics: inout [DiagramDiagnostic]
) {
    let known: Set<String> = Set(boundaries.map(\.alias)).union(["global", ""])
    for s in shapes where !known.contains(s.parentBoundary) {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Mermaid C4 shape '\(s.alias)' parentBoundary=\(s.parentBoundary) references undefined boundary"
        ))
    }
    for b in boundaries where !known.contains(b.parentBoundary) {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Mermaid C4 boundary '\(b.alias)' parentBoundary=\(b.parentBoundary) references undefined boundary"
        ))
    }
}
```

### Diagnostic plumbing through `_parseC4Diagram`

Change the return type from `C4Diagram` to `(C4Diagram, [DiagramDiagnostic])`. The C4 parser is the only family-parser in the codebase that doesn't currently surface diagnostics from inside the parse pass; aligning it with the other slices matches the pattern Session 7 used for the sanitizeIdentifier rollout.

Affected callers:

- Production: `Sources/DiagramKit/DiagramRegistry+C4.swift` — one call site, destructure the tuple.
- Tests: `Tests/DiagramKitTests/C4ParserTests.swift`'s `parseC4Diagram(_:)` test helper (~line 64) — destructure once.

### Dispatch-site rewrites inside `_parseC4Diagram`

In the macro dispatch switch (`:144-230`), compute `effectiveBoundary` immediately before each `_add…` call and pass it as `currentBoundary:`. Twenty-eight call sites total:

- 8 `_addPersonOrSystem` sites (Person/Person_Ext/System/SystemDb/SystemQueue/System_Ext/SystemDb_Ext/SystemQueue_Ext) — `key: "boundary"`.
- 12 `_addContainerOrComponent` sites (Container family × 6, Component family × 6) — `key: "boundary"`.
- 4 `_addBoundary` sites (Boundary/Enterprise_Boundary/System_Boundary/Container_Boundary) — `key: "parent"`.
- 4 `_addDeploymentNode` sites (Deployment_Node/Node/Node_L/Node_R) — `key: "parent"`.

One `_validateBoundaryReferences(...)` call lands right before `return diagram` at `:265`.

Estimated diff size: ~80 lines added (two helpers + 28 dispatch-site one-liners + return-type plumbing through two call sites).

## Tests

Three test surfaces, one commit each:

### 1. Parser unit tests

New `Tests/DiagramKitTests/C4BoundaryNamedArgTests.swift`:

- Flat-emit `$boundary` on Person/System/Container/Component sets `parentBoundary` to the named value (one `@Test` per family — four cases).
- Flat-emit `$parent` on `Boundary` / `Enterprise_Boundary` / `System_Boundary` / `Container_Boundary` sets `parentBoundary` to the named value (four `@Test`s).
- Flat-emit `$parent` on `Deployment_Node` / `Node_L` / `Node_R` (one `@Test`).
- Lexical-only path still works (no named arg, nested in `Boundary(outer) { … }` → `parentBoundary == "outer"`) — one `@Test`.
- **Mismatch warning**: `Boundary(outer) { System(s) $boundary=other }` → `parentBoundary == "other"` AND one `.warning` mentioning both `outer` and `other` — one `@Test`.
- **Forward-ref OK**: `System(s) $boundary=later` followed by `Boundary(later, "Later")` → `parentBoundary == "later"` and no `.warning` — one `@Test`.
- **Unresolved-ref warning**: `System(s) $boundary=nowhere` (no `Boundary(nowhere, …)` anywhere) → `parentBoundary == "nowhere"` AND one `.warning` mentioning `nowhere` — one `@Test`.

### 2. Mermaid → Mermaid round-trip

New `Tests/DiagramKitTests/MermaidC4BoundaryRoundTripTests.swift`:

- Author a C4 source that emits both `$boundary` on a shape and `$parent` on a nested boundary. Parse → export → parse. Assert the second-pass `C4Diagram` matches the first on `shapes[i].parentBoundary` and `boundaries[i].parentBoundary`. One `@Test`.
- Author the same diagram in the nested `Boundary(...) { ... }` form. Parse → export → parse. Assert the parent linkage matches the flat-emit version's. (Pins that nested and flat representations are semantically interchangeable through the round-trip.) One `@Test`.

### 3. Session 6 extension

Edit `Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift`:

The existing `structurizrToMermaidEmit` test (called out in REVIEW §7 as "stops short of re-parsing the Mermaid output") now re-parses. Assert the re-parsed `C4Diagram` carries the boundary alias on the shapes that were inside the original `group "label" { … }` block. No new `@Test` — the existing test's assertion block grows by ~5 lines.

### Existing-test impact

- `C4ParserTests.swift:71`'s `#expect(shape.parentBoundary == "global")` and similar assertions still hold — no `$boundary` named arg in those fixtures.
- The return-type change for `_parseC4Diagram` touches the test helper; existing test sites destructure the tuple or use `.0`.
- Existing corpus snapshots stay green: sources that don't use `$boundary` / `$parent` keep their current zero-`.warning` count for boundary linkage.

## Risks

- **Return-type change** of `_parseC4Diagram` is source-incompatible for external callers. Mitigated: one production caller (`DiagramRegistry+C4.swift`), one test helper. Both touched in the same commit as the helper additions.
- **`.warning` severity for the mismatch case is opinionated.** A consumer that errors-on-warning treats mismatch as fatal. Mitigation: severity stays consistent with the REVIEW.md §4 + Session-2 identifier-sanitization alignment. A future "diagnostic severity policy doc" is the right place to revisit if needed.
- **Forward-ref validation runs once at end-of-parse.** `_addBoundary` updates an existing boundary by alias (`:537`), so order between flat-emit and definition is fine — the validator reads the final state.
- **`named["boundary"]` / `named["parent"]` key collision** with a hypothetical future Mermaid macro feature has the same risk profile as `$tags` / `$descr` / `$link` already in use.

## Commit map

Per the project's commit-by-commit-on-main standing default, the implementation lands across five commits:

1. **Spec** (this document).
2. **Plan** (written via the writing-plans skill).
3. **Helpers + dispatch + return-type plumbing.** Two new private helpers, 28 dispatch-site rewrites, `_parseC4Diagram` return type widened, both callers updated. Parser unit tests in `C4BoundaryNamedArgTests.swift` accompany this commit.
4. **Mermaid → Mermaid round-trip tests.** New `MermaidC4BoundaryRoundTripTests.swift`.
5. **Session 6 extension.** `StructurizrBoundaryRoundTripTests.structurizrToMermaidEmit` re-parse extension; updates to `REVIEW.md` Deferred Effort §7 closure note.

`CLAUDE.md` test source count sync lands in commit 5 alongside the REVIEW.md update.

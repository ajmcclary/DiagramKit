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

Two files: `Sources/DiagramKitModel/src_c4_parser.swift` (parser) and two callers — `Sources/DiagramKit/DiagramRegistry+C4.swift` and `Sources/DiagramKit/AsciiRenderRegistry.swift`. No model-type changes, no exporter changes, no public-API changes — the existing `public func parseC4Diagram(_:frontmatter:) -> C4Diagram` keeps its signature; diagnostics flow through a new SPI variant.

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

### Diagnostic plumbing via SPI variant

`parseC4Diagram` is `public` and called from ~25 test sites plus two production sites; widening its return type would break the public API and force a test sweep. Instead, add a new public underscore-prefixed (SPI) variant:

```swift
public func _parseC4DiagramWithDiagnostics(
    _ lines: [String],
    frontmatter: DiagramFrontmatter? = nil
) throws -> (C4Diagram, [DiagramDiagnostic])
```

The existing `parseC4Diagram(_:frontmatter:)` becomes a thin wrapper:

```swift
public func parseC4Diagram(
    _ lines: [String],
    frontmatter: DiagramFrontmatter? = nil
) throws -> C4Diagram {
    let (diagram, _) = try _parseC4DiagramWithDiagnostics(lines, frontmatter: frontmatter)
    return diagram
}
```

The underscore prefix follows CLAUDE.md's SPI convention; the body of the existing function shrinks to one line.

Affected production callers — both switch to the SPI variant so diagnostics reach the importer/loader boundary:

- `Sources/DiagramKit/DiagramRegistry+C4.swift:16` — currently calls `parseC4Diagram(...)`; switches to `_parseC4DiagramWithDiagnostics(...)` and appends the diagnostics to the registry's `DiagramImportResult`.
- `Sources/DiagramKit/AsciiRenderRegistry.swift:223` — same swap; this path renders ASCII and may surface diagnostics via the existing rendering result type.

Existing test callers (~25 sites in `C4ParserTests.swift`) are not touched — they keep calling the public `parseC4Diagram` and never see the diagnostics. New parser unit tests call `_parseC4DiagramWithDiagnostics` directly to assert on the warning surface.

### Dispatch-site rewrites inside `_parseC4Diagram`

In the macro dispatch switch (`:144-230`), compute `effectiveBoundary` immediately before each `_add…` call and pass it as `currentBoundary:`. Twenty-eight call sites total:

- 8 `_addPersonOrSystem` sites (Person/Person_Ext/System/SystemDb/SystemQueue/System_Ext/SystemDb_Ext/SystemQueue_Ext) — `key: "boundary"`.
- 12 `_addContainerOrComponent` sites (Container family × 6, Component family × 6) — `key: "boundary"`.
- 4 `_addBoundary` sites (Boundary/Enterprise_Boundary/System_Boundary/Container_Boundary) — `key: "parent"`.
- 4 `_addDeploymentNode` sites (Deployment_Node/Node/Node_L/Node_R) — `key: "parent"`.

One `_validateBoundaryReferences(...)` call lands right before `return diagram` at `:265`.

Estimated diff size: ~90 lines added (two helpers + 28 dispatch-site one-liners + new SPI wrapper function + two production registry callers updated to use the SPI variant).

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
- The existing ~25 `parseC4Diagram(...)` test sites in `C4ParserTests.swift` are not touched — the wrapper keeps the same signature.
- Existing corpus snapshots stay green: sources that don't use `$boundary` / `$parent` keep their current zero-`.warning` count for boundary linkage.

## Risks

- **Public-API shape:** `parseC4Diagram` stays unchanged; the SPI variant `_parseC4DiagramWithDiagnostics` is the new diagnostic-aware entry point. Two production registry call sites (`DiagramRegistry+C4.swift:16`, `AsciiRenderRegistry.swift:223`) switch to the SPI variant in the same commit as the helper additions. Tests calling `parseC4Diagram` are unaffected.
- **`.warning` severity for the mismatch case is opinionated.** A consumer that errors-on-warning treats mismatch as fatal. Mitigation: severity stays consistent with the REVIEW.md §4 + Session-2 identifier-sanitization alignment. A future "diagnostic severity policy doc" is the right place to revisit if needed.
- **Forward-ref validation runs once at end-of-parse.** `_addBoundary` updates an existing boundary by alias (`:537`), so order between flat-emit and definition is fine — the validator reads the final state.
- **`named["boundary"]` / `named["parent"]` key collision** with a hypothetical future Mermaid macro feature has the same risk profile as `$tags` / `$descr` / `$link` already in use.

## Commit map

Per the project's commit-by-commit-on-main standing default, the implementation lands across five commits:

1. **Spec** (this document).
2. **Plan** (written via the writing-plans skill).
3. **Helpers + dispatch + SPI variant.** Two new private helpers, 28 dispatch-site rewrites, new `_parseC4DiagramWithDiagnostics` SPI variant (existing `parseC4Diagram` shrinks to a one-line wrapper), two production registry callers (`DiagramRegistry+C4.swift`, `AsciiRenderRegistry.swift`) switched to the SPI variant. Parser unit tests in `C4BoundaryNamedArgTests.swift` accompany this commit.
4. **Mermaid → Mermaid round-trip tests.** New `MermaidC4BoundaryRoundTripTests.swift`.
5. **Session 6 extension.** `StructurizrBoundaryRoundTripTests.structurizrToMermaidEmit` re-parse extension; updates to `REVIEW.md` Deferred Effort §7 closure note.

`CLAUDE.md` test source count sync lands in commit 5 alongside the REVIEW.md update.

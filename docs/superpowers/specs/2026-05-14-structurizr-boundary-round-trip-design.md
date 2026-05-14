# Structurizr Boundary Round-Trip — Design

Author: Claude (Opus 4.7)
Date: 2026-05-14
Status: Draft for review

## Problem

`C4Diagram.boundaries` does not round-trip through Structurizr DSL. The Mermaid C4 family commonly authors `Boundary(b0, "BankBoundary0") { ... }`, `Enterprise_Boundary`, `System_Boundary`, and `Container_Boundary` (the IBS corpus entry nests them three deep). Today:

- `Sources/DiagramKitStructurizr/StructurizrExporter.swift:84-91` walks `model.boundaries` and emits one `.unsupported` diagnostic per entry, dropping all of them.
- `Sources/DiagramKitStructurizr/StructurizrMapper.swift:181-198` synthesizes one `C4Boundary` per view-scope element with a `.warning`, but only when a `container`/`component` view designates a parent softwareSystem/container as the scope. No authored boundary survives.
- The Structurizr DSL `group "label" { ... }` directive — the official Structurizr concept that maps cleanly to Mermaid C4 boundaries — is not recognized by `StructurizrParser`.

Result: Mermaid → Structurizr → Mermaid silently loses every authored boundary, and Structurizr DSL sources cannot express boundaries other than the implicit view-scope element.

## Goal

Close the round-trip end-to-end for the common case via Structurizr's `group "label" { ... }` directive inside `model { }`:

- Parser recognizes `group "label" { element-defs ... }` inside `model { }`.
- Mapper produces one `.authored` `C4Boundary` per group, alongside the existing `.viewScopeSynthesized` boundaries.
- Exporter emits every `.authored` boundary as a `group { ... }` block; `.viewScopeSynthesized` entries silently drop (they re-derive on next import).
- Mermaid's nested boundaries flatten to sibling Structurizr groups with one `.warning` per dropped parent link.

## Non-goals

- `group` inside `softwareSystem { }` / `container { }` element blocks. Structurizr DSL allows this; the parser will emit `.unsupported` and `skipBlock()`. A follow-up spec covers it.
- `tags` inside `group { }`. Element-scoped `tags` already drop with `.unsupported`; in-group `tags` follow the same policy.
- Preserving the original Mermaid boundary `alias` verbatim. Structurizr groups carry only a label; aliases regenerate from the label on re-import.
- Preserving the Mermaid `boundary.type` field (`ENTERPRISE`, `SYSTEM`, `CONTAINER`, `system`). Structurizr has no equivalent; all groups collapse to `type = "group"` on re-import.
- Re-enabling Structurizr corpus snapshots. `skipSnapshots: ["structurizr"]` stays for now.

## Data model changes

Both additions are non-breaking — new optional fields with defaults that preserve existing call sites.

### `Sources/DiagramKitModel/src_c4_types.swift`

```swift
public enum C4BoundaryOrigin: Sendable, Equatable {
    /// Boundary was authored explicitly in the source (Mermaid `Boundary(...)`,
    /// Structurizr `group "..." { ... }`). The exporter must re-emit it.
    case authored

    /// Boundary was synthesized by the importer from the view scope
    /// (e.g., StructurizrMapper marks the view-scope softwareSystem as a
    /// boundary in container views). The exporter MUST NOT re-emit it,
    /// because the next import will re-derive it from the same view scope.
    case viewScopeSynthesized
}
```

Add to `C4Boundary`:

```swift
public var origin: C4BoundaryOrigin = .authored
```

Positional `init` callers continue to work; named callers don't need to pass the new arg. `Equatable` synthesis still applies.

### `Sources/DiagramKitStructurizr/StructurizrAST.swift`

Add to `StructurizrModelElement`:

```swift
public var group: String? = nil
```

The parser sets this when an element appears inside a `group "label" { ... }` block; the label is stored verbatim (no alias derivation). No new `Group` entity — element tagging is enough for mapping.

## Parser changes (`StructurizrParser.swift`)

In `parseModel(_:)`, the `while let token = s.peek()` loop gains a new branch ahead of the existing element-def / relationship dispatch:

```swift
if case .identifier("group") = token {
    let groupElements = try parseGroup(&s, scopedRelationships: &relationships)
    elements.append(contentsOf: groupElements)
    continue
}
```

New private `parseGroup`:

1. Consume `"group"`.
2. Consume the string label. Throw `DiagramError.malformedSource(...)` if missing.
3. Expect `{`. Advance.
4. Loop. For each iteration:
   - `closeBrace` → break.
   - `.identifier("group")` → emit `.unsupported` ("Structurizr `group` cannot nest"), then `skipBlock()` (the inner group's body is discarded).
   - identifier followed by `=` → call `parseElementDef`, tag the returned element with `element.group = label` before appending to the local group buffer.
   - identifier followed by `->` → call `parseRelationshipDef` and append to the inout `scopedRelationships`.
   - `tags` → call `skipTags()`.
   - `!` directive → consume directive name and `skipDirective`.
   - Anything else → consume and emit `.diagnostic("unexpected statement in group block: ...")`.
5. Expect `}`. Advance. Return the tagged-element buffer.

In `parseElementDef`'s inner `{` body loop (the `softwareSystem { ... }` / `container { ... }` block), add a new branch on `.identifier("group")` that emits `.unsupported` ("`group` inside element blocks not yet supported") and `skipBlock()`. The element body otherwise parses as today.

No lexer changes — `group` is a regular identifier in `StructurizrLexer` already.

## Mapper changes (`StructurizrMapper.swift`)

After building `registry` (line 28) and before the visible-aliases / classification work, build a stable group-to-alias map:

```swift
var groupAliasMap: [String: String] = [:]   // label -> synthesized alias
var usedGroupAliases: Set<String> = []
for element in registry.elementsByAlias.values {
    guard let label = element.group, groupAliasMap[label] == nil else { continue }
    let alias = uniqueSanitizedGroupAlias(label, used: &usedGroupAliases)
    groupAliasMap[label] = alias
}
```

`uniqueSanitizedGroupAlias` reuses `StructurizrExporter.sanitizeStructurizrIdentifier(_:)` and appends `_2`, `_3`, … on collision — same shape as `StructurizrExporter.uniqueSanitizedAlias`. Factor the helper into `Sources/DiagramKitStructurizr/StructurizrIdentifiers.swift` so both call sites share it (small refactor; existing `StructurizrExporter` keeps `uniqueSanitizedAlias` as a thin wrapper that also appends the `.warning`).

In the shape-mapping loop (line 124), after computing `boundaryName` from the existing parent-element logic, **override** when a group tag is present:

```swift
if let groupLabel = element.group, let groupAlias = groupAliasMap[groupLabel] {
    boundaryName = groupAlias
}
```

After the shape loop, append one `C4Boundary` per group:

```swift
for (label, alias) in groupAliasMap {
    c4Boundaries.append(C4Boundary(
        alias: alias,
        label: label,
        type: "group",
        parentBoundary: "global",
        origin: .authored
    ))
}
```

The existing view-scope synthesis block (lines 181–198) keeps its `.warning`. Mark its `C4Boundary` `origin: .viewScopeSynthesized`. Order: emit authored groups first, view-scope-synthesized last — the existing `c4Boundaries` ordering invariant is "authored before synthesized."

## Exporter changes (`StructurizrExporter.swift`)

Replace the current "drop with `.unsupported`" block (lines 81–91) with the partition emit. After the existing alias-rename map is built (line 46-55):

```swift
let authoredBoundaries = model.boundaries.filter { $0.origin == .authored }
let authoredAliases = Set(authoredBoundaries.map(\.alias))
let shapesByBoundary: [String: [C4Shape]] = Dictionary(grouping: model.shapes) { $0.parentBoundary }
let rootShapes = model.shapes.filter { shape in
    shape.parentBoundary == "global" || !authoredAliases.contains(shape.parentBoundary)
}
```

`rootShapes` is the existing root-of-model shape set (shapes whose `parentBoundary == "global"` plus shapes whose parent boundary is `.viewScopeSynthesized` or unknown — those continue to emit at root, exactly as today).

Emit loop, inside `model {`:

1. For each `boundary in authoredBoundaries` (preserving the order from `model.boundaries`):
   - If `boundary.parentBoundary != "global"` and `!boundary.parentBoundary.isEmpty`: append one `DiagramDiagnostic(severity: .warning, message: "Structurizr `group` is non-nestable; flattening boundary '\(boundary.alias)' (parent: '\(boundary.parentBoundary)') to top-level")`. Continue with the emit (don't drop).
   - Look up `members = shapesByBoundary[boundary.alias] ?? []`.
   - If `members.isEmpty`: append one `DiagramDiagnostic(severity: .warning, message: "Empty group '\(boundary.label)' (alias '\(boundary.alias)') has no direct shapes after Structurizr flattening; dropping")` and `continue` (skip emit).
   - Emit `    group "\(escape(boundary.label))" {`.
   - For each shape in `members`, emit the existing shape line indented one more level (six spaces instead of four).
   - Emit `    }`.
2. For each `shape in rootShapes`, emit the existing shape line at four-space indent (the current behavior).
3. For each `shape` whose `parentBoundary` is authored (already emitted inside a group above), skip.
4. Relationships emit at the model root, unchanged.

The existing alias rename map (`aliasMap`, `uniqueSanitizedAlias`) applies inside `group { ... }` too, so aliases stay consistent across group-internal element defs and relationship endpoints.

## Round-trip semantics

| Preserved | Lossy (with diagnostic) |
|---|---|
| Boundary label | Boundary alias (regenerated from label; `b0` becomes e.g. `bankboundary0`) |
| Shape-to-boundary membership | Boundary `type` field (`ENTERPRISE` / `SYSTEM` / `CONTAINER` / `system` → all collapse to `"group"`) |
| Boundary count after flattening | Boundary nesting (`.warning` per dropped parent link) |
| Authored vs view-scope-synthesized origin | Empty boundaries (containing only nested boundaries) — `.warning` + dropped |
| `parentBoundary` linkage on shapes | `Enterprise_Boundary`/`System_Boundary`/`Container_Boundary` keyword identity (re-emit is always plain `Boundary`) |

The four Mermaid boundary keyword variants all map to the same `group { … }`. Re-export emits plain `Boundary` (the default in `MermaidC4Export`); this is acceptable — `boundary.type` is rendering-only metadata, and the visual structure is preserved.

## Test plan

Five new layers.

### `Tests/DiagramKitTests/StructurizrParserGroupTests.swift`

Five `@Test`s:

1. `group "Group 0" { p = person "User" }` parses; resulting element has `group == "Group 0"`.
2. Two adjacent `group "A" { … }` `group "B" { … }` produce two separately-tagged sets in source order.
3. `group "X" { ... }` inside a `softwareSystem { … }` element block emits one `.unsupported` and `skipBlock`'s.
4. `group "Outer" { group "Inner" { ... } }` emits one `.unsupported` ("Structurizr `group` cannot nest") and `skipBlock`'s the inner block; the outer body still parses.
5. `group { person ... }` (missing label string) throws `DiagramError.malformedSource`.

### `Tests/DiagramKitTests/StructurizrMapperGroupTests.swift`

Four `@Test`s:

1. Single group → exactly one `C4Boundary` with `origin == .authored`, `type == "group"`, `parentBoundary == "global"`.
2. Group label `"Bank Boundary"` → boundary alias `bank_boundary` (matches `sanitizeStructurizrIdentifier`).
3. Two groups with the same label → distinct aliases via `uniqueSanitizedGroupAlias` (`bank_boundary` and `bank_boundary_2`).
4. Container-view source (`container app { include * }`) with no `group` still emits the existing view-scope-synthesized boundary, now tagged `origin == .viewScopeSynthesized`, and still emits the existing `.warning`.

### `Tests/DiagramKitTests/StructurizrExporterGroupTests.swift`

Six `@Test`s:

1. `C4Boundary(origin: .authored)` + one member shape → `group "<label>" {\n      <alias> = person "..."\n    }` block emitted at four-space indent.
2. `C4Boundary(origin: .viewScopeSynthesized)` → no `group { }` line in the output; no diagnostic emitted.
3. Authored boundary with `parentBoundary != "global"` → still emitted as a sibling group; exactly one `.warning` appended ("Structurizr `group` is non-nestable; flattening ...").
4. Authored boundary with zero direct member shapes → no `group { }` line; exactly one `.warning` ("Empty group ...").
5. Two authored boundaries in `model.boundaries` order produce two `group { }` blocks in the same order.
6. Shapes with `parentBoundary == "global"` keep emitting at the model root (no behavior change).

### `Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift`

Three `@Test`s:

1. Single-boundary Mermaid → Structurizr → Mermaid: source `C4Context\n  Boundary(b0, "G0") { Person(p1, "P1") }`. After round-trip via `MermaidImporter` → `StructurizrExporter` → `StructurizrImporter`, assert exactly one boundary with `label == "G0"`, exactly one shape with alias `p1` and `parentBoundary == <synthesized alias>` matching the boundary.
2. Two-level nesting collapses cleanly. Source: `C4Context\n  Enterprise_Boundary(b0, "Outer") {\n    System(s0, "S0")\n    Enterprise_Boundary(b1, "Inner") {\n      System(s1, "S1")\n    }\n  }`. After round-trip, assert exactly two boundaries with labels `"Outer"` and `"Inner"` (both non-empty: `s0` stays in `Outer`; `s1` stays in `Inner`). Exactly one `.warning` about non-nestable flattening fires — for `b1` (whose `parentBoundary == b0`); `b0` is global-parented and emits cleanly. The empty-group case (a boundary that contained only nested boundaries) is covered separately by exporter test §3.4.
3. Structurizr-authored `group "X" { p1 = person ... }` → Mermaid via the C4Diagram path produces `Boundary(<alias>, "X")` with `p1.parentBoundary == <alias>`. Round-trip back to Structurizr emits `group "X" { p1 = person ... }` (label and membership preserved).

### Corpus fixture

Add one entry to `Examples/DiagramPlayground/Resources/test-diagrams.json`:

```json
{
  "id": "structurizr-5-group",
  "category": "c4",
  "name": "Structurizr: Group Block",
  "sources": {
    "mermaid": "C4Context\n  Boundary(b0, \"Group 0\") {\n    Person(u, \"User\")\n    System(app, \"My App\")\n  }\n  Rel(u, app, \"Uses\")",
    "structurizr": "workspace {\n  model {\n    group \"Group 0\" {\n      u = person \"User\"\n      app = softwareSystem \"My App\"\n    }\n    u -> app \"Uses\"\n  }\n  views {\n    systemContext app {\n      include *\n    }\n  }\n}"
  },
  "expectedImporters": {
    "mermaid": "Mermaid",
    "structurizr": "Structurizr"
  },
  "skipSnapshots": ["structurizr"]
}
```

The existing `StructurizrCorpusFixtureTests.swift` (4 fixtures) keeps its assertions — none of those four use `group { }`, so the view-scope `.warning` still fires and the new `.viewScopeSynthesized` origin tag is invisible to those tests.

### Verification gate

- `swift test --filter StructurizrParserGroupTests` green.
- `swift test --filter StructurizrMapperGroupTests` green.
- `swift test --filter StructurizrExporterGroupTests` green.
- `swift test --filter StructurizrBoundaryRoundTripTests` green.
- `swift test --filter StructurizrCorpusFixtureTests` still green (unchanged).
- `swift test --filter C4SlotSemanticsTests` still green (the C4 slot fix is unaffected).
- `Scripts/check-sendable-annotations.sh` green (new enum is `Sendable`).
- `Scripts/check-file-sizes.sh` no new threshold crossings.

No snapshot baseline regeneration. Structurizr stays on `skipSnapshots: ["structurizr"]`.

## Commit map (preview)

The writing-plans skill will turn this into a sequenced plan. Anticipated shape: one prep commit (data-model additions + tests of the additions), three feature commits (parser, mapper, exporter), one integration commit (round-trip tests + corpus fixture). Mapper depends on the data-model fields; exporter depends on the mapper's origin tagging; round-trip tests depend on all three.

## Open questions

None remaining — the four design calls (full round-trip via `group { … }`, optional `origin` enum on `C4Boundary`, flatten + per-level `.warning` for nested boundaries, parser-tagging-overrides-parent-element scoping) are settled by the brainstorming dialogue. Out-of-scope items listed under Non-goals.

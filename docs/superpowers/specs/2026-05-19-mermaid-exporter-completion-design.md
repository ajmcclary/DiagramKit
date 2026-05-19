# Mermaid Exporter Completion — Design

**Date:** 2026-05-19
**Status:** Approved (brainstorm)
**Source backlog:** [COVERAGE.md](../../../COVERAGE.md) §"Gaps and the work to close them" → #1.

## Goal

Extend `MermaidExporter` to cover all 28 Mermaid families, eliminating the
21 `.unsupportedDiagram` fall-throughs at
`Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift:33-51`. After this
work, every `DiagramDocument` whose payload is a Mermaid-native family
round-trips back through `MermaidExporter` losslessly. The Mermaid Export
column in [COVERAGE.md](../../../COVERAGE.md) moves from 7/28 to 28/28.

## In Scope

The 21 missing families:

`xyChart`, `pie`, `journey`, `quadrantChart`, `requirement`, `gitGraph`,
`mindmap`, `timeline`, `sankey`, `block`, `packet`, `kanban`, `architecture`,
`radar`, `treemap`, `venn`, `ishikawa`, `treeView`, `eventModeling`,
`wardleyBeta`, `zenuml`.

## Out of Scope

- Changes to parsers, layouts, SVG/CG/ASCII renderers, or `DiagramDocument`
  payload shapes. Exporters consume the existing typed model.
- New corpus entries. The spec uses the 397 existing Mermaid corpus entries
  in `Sources/DiagramKitSample/Resources/test-diagrams.json` both to seed
  fixtures and as the round-trip target set.
- PlantUML / D2 / DOT / Structurizr coverage — those backlog items remain
  separate specs ([COVERAGE.md](../../../COVERAGE.md) §"Backlog summary"
  items 2–4).
- Mermaid-prefixed public aliases (sunset in Session 12).

## Invariants Preserved

- **No thread pool.** Exporters run synchronously on the same dispatch
  as today; the 8 MB-stack `Thread` worker model is untouched.
- **File-size policy** (500-line warn / 1000-line error per
  `Scripts/check-file-sizes.sh`). One file per family keeps each well
  under the warn line; existing per-family exporters average ~200 lines.
- **Diagnostic discipline.** Only typed factories
  (`.lossyTransform` / `.featureDropped` / `.informational`); raw
  `DiagramDiagnostic(severity:message:)` remains deprecated and
  `Scripts/check-diagnostic-discipline.sh` enforces it.
- **Round-trip discipline.** Every new exporter wires into
  `DiagramKitTestSupport.RoundTripHarness`; any `RoundTripLoss` pairs to
  a typed diagnostic by `DiagnosticCategory` equality.
- **Public surface unchanged.** No new public types, no new module
  boundaries. The work fits the existing `DiagramKitMermaid` slice.

## Architecture & File Layout

### Files to add (21)

```
Sources/DiagramKitMermaid/Exporter/MermaidExport/
  MermaidArchitectureExport.swift
  MermaidBlockExport.swift
  MermaidEventModelingExport.swift
  MermaidGitGraphExport.swift
  MermaidIshikawaExport.swift
  MermaidJourneyExport.swift
  MermaidKanbanExport.swift
  MermaidMindmapExport.swift
  MermaidPacketExport.swift
  MermaidPieExport.swift
  MermaidQuadrantExport.swift
  MermaidRadarExport.swift
  MermaidRequirementExport.swift
  MermaidSankeyExport.swift
  MermaidTimelineExport.swift
  MermaidTreemapExport.swift
  MermaidTreeViewExport.swift
  MermaidVennExport.swift
  MermaidWardleyExport.swift
  MermaidXYChartExport.swift
  MermaidZenUMLExport.swift
```

### Files to extend (3)

- `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift` — 21 new
  `case` arms in `export(_:)`, 21 entries appended to
  `supportedDiagramTypes`. The `default:` arm is removed when the
  switch becomes exhaustive at the end of wave 3.
- `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidExportHelpers.swift`
  — additions on-demand as second callers appear. Planned additions:
  - Indent-based tree emitter (used by `mindmap`, `treemap`, `treeView`,
    `block`).
  - Section-block emitter (used by `journey`, `timeline`, `kanban`,
    `eventModeling`).
  - RFC 4180 CSV field quoter (used by `sankey`).
  No upfront refactor — helpers move in when a second caller appears.
- `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidExportDiagnostics.swift`
  — new diagnostic constructors only if a family requires them; most
  will not.

### Shared scaffolding contract

All per-family files mirror today's pattern:

```swift
enum Mermaid<Family>Export {
    static func emit(_ model: <Family>Diagram) throws -> DiagramExportResult {
        var lines: [String] = ["<header>"]
        var diagnostics: [DiagramDiagnostic] = []
        // ... emit semantic fields ...
        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }
}
```

Title / `accTitle` / `accDescr` are handled inside each family file in the
canonical position for that DSL. The umbrella `prependingDocumentTitle` in
`MermaidExporter` keeps acting on the document-level title only.

### Dispatch site

`MermaidExporter.export(_:)` grows from 7 to 28 explicit `case` arms; the
`default:` fall-through is removed in the wave 3 closing commit. The
exhaustive switch is the compile-time guarantee that no payload variant
escapes silently.

## Per-Family Contract

Field names below are working contract. Where the actual `*Diagram`
payload uses a different identifier, the per-family file binds to the
real name; the spec's intent stands.

| Family | Mermaid header | Key fields to emit | Canonicalizations | Lossy points |
|---|---|---|---|---|
| `pie` | `pie` (+ optional `showData`) | title, slice label/value pairs | quote labels containing whitespace/`:` | none expected |
| `journey` | `journey` | title, sections, tasks `(name: score: actor,actor)` | always emit `section` keyword even for default section | none expected |
| `timeline` | `timeline` | title, sections, periods with events | period label canonicalized to single line | none expected |
| `sankey` | `sankey-beta` | CSV rows `source,target,value` | RFC 4180 quoting (fields containing `,` or `"`) | none expected |
| `kanban` | `kanban` | columns, cards with metadata `@{ assigned: ..., ticket: ..., priority: ... }` | metadata keys in fixed alphabetical order | none expected |
| `mindmap` | `mindmap` | root + indent-based children, node shapes, icons, classes | indent normalized to 4 spaces per level | none expected |
| `treemap` | `treemap-beta` | indent-based hierarchy, leaf values | indent normalized to 2 spaces per level | none expected |
| `packet` | `packet-beta` | range definitions `bit-bit: "label"` | sorted by start bit | none expected |
| `gitGraph` | `gitGraph` (+ direction) | branches, commits (id/tag/type), `checkout`, `merge`, `cherry-pick` | re-emit in canonical execution order | parser-discarded inline options surfaced as `.informational` only if present |
| `xyChart` | `xychart-beta` (+ direction) | title, x-axis def, y-axis range, bar/line series | numeric formatting fixed (no trailing zeros beyond model) | none expected |
| `quadrantChart` | `quadrantChart` | title, axis labels, quadrant labels, points `(x, y)` | coordinates emitted as decimals with model precision | none expected |
| `requirement` | `requirement` | typed requirement blocks, element blocks, `<-` relationship lines | block field order fixed (id → text → risk → verifymethod) | none expected |
| `radar` | `radar-beta` | title, axes, datasets with curves | none | none expected |
| `venn` | `venn-beta` | sets, intersection labels | set member lists sorted | none expected |
| `ishikawa` | `ishikawa` | spine, categories, causes (sub-causes) | indent normalized | none expected |
| `treeView` | `treeView` | root + indent-based file/folder lines | indent normalized to 2 spaces per level | none expected |
| `eventModeling` | `eventModeling` | swimlanes, events with type markers (`command`/`event`/`view`), edges | edge list emitted after all nodes | none expected |
| `zenuml` | `zenuml` | participants, sequence statements, alt/par/loop blocks | re-emit in source order | parser-discarded styling surfaced as `.informational` only if present |
| `block` | `block-beta` (+ columns) | nested block defs, edges, classes | nesting indent normalized to 2 spaces per level | none expected |
| `architecture` | `architecture-beta` | groups, services (with icons), edges (with port specs) | none | none expected — icons emit as `(iconName)` exactly as model holds them |
| `wardleyBeta` | `wardleyBeta` | title, evolution axis, value chain, components, anchors | none | none expected |

### The "none expected" rule

Mermaid is canonical. The parser → model → exporter loop should be
lossless for every field the parser captures. If implementation surfaces
a real lossy edge (a field the parser stores that the DSL grammar cannot
round-trip without a diagnostic), the per-family file documents it and
emits a typed diagnostic — but the spec does not pre-invent lossy edges
to "be safe."

### Global canonicalization

All exporters emit LF-terminated output and 4-space indentation for
header-level keywords, matching the existing Gantt/Class/Sequence files.
The round-trip harness compares structurally, not textually, so the
canonicalization is invisible to round-trip but stable for snapshots.

## Diagnostic Policy

Default: **silent and lossless.** Per
[docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md),
an exporter emits a diagnostic only when it drops or transforms
semantic data. For these 21 families the expectation is zero
diagnostics: the parser captured the data, the DSL grammar can
re-emit it, structural equality holds.

A diagnostic is mandatory only when:

- A parsed field genuinely has no DSL syntax to emit (rare — Mermaid
  is canonical) → `.featureDropped(.<category>, ...)`.
- A field re-emits in a form the parser re-reads with non-identity
  semantics (e.g., relative → absolute, as the existing Gantt date
  normalization does) → `.lossyTransform(.<category>, ...)`.
- A field re-emits identically but in a different surface form
  (whitespace, comments, key order) → **no diagnostic.**
  Canonicalization is not loss.

### Round-trip harness pairing

`RoundTripLoss` cases must pair to typed diagnostics by
`DiagnosticCategory`. If a family emits a
`.lossyTransform(.structure, ...)`, the harness expects a
`RoundTripLoss` whose category equals `.structure`. This spec adds
zero new `RoundTripLoss` cases — if the closed enum needs a new case,
that is a separate decision; default stance is the existing cases
suffice.

### Throw boundary

Exporters throw only for programmer errors (impossible payload
combinations, structurally invalid input). Lossy emission is never a
throw — it is a diagnostic on the result.

### Gate

`Scripts/check-diagnostic-discipline.sh` must pass on every commit
that adds or modifies an exporter file. Each wave's closing PR runs
the full `Scripts/bootstrap-smoke-check.sh` sweep.

## Test Strategy

### 1. Round-trip fixtures (primary acceptance)

Each family gets a directory at
`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-<family>/`
with 2–3 hand-authored minimal `.md` fixtures:

- `01-basic.md` — minimum well-formed example (one node / one slice /
  one entry).
- `02-<feature>.md` — exercises the family's distinguishing features
  (sections, nesting, edge labels, metadata blocks, etc.).
- `03-<edge>.md` — only when warranted, for a corner case the contract
  table called out (e.g., RFC 4180 quoting for `sankey`, deep nesting
  for `mindmap`/`block`, alt/par/loop for `zenuml`).

Fixtures drive `DiagramKitTestSupport.RoundTripHarness` via the existing
test harness — no new test files needed. Same-format mermaid fixtures
run `parse → export → parse → assertStructurallyEqual` and pair any
`RoundTripLoss` to typed diagnostics.

### 2. Corpus round-trip coverage (regression guardrail)

The existing `CorpusSnapshotTests` already exercises all 397 Mermaid
corpus entries through parse + layout + render. The exporter is not on
that path. The spec adds **one parameterized test** alongside the
existing round-trip suites: for every Mermaid corpus entry whose family
is now exporter-supported, run
`parse → export → parse → assertStructurallyEqual`. This catches
contract drift on the full corpus without requiring 397 hand-authored
fixtures and without spawning new snapshot baselines.

Test runs follow the project convention: `swift test --filter
<ExactSuiteName>`. Substring filters that pull in `CorpusSnapshotTests`
parameterized cases are forbidden (per the `feedback_swift_test_filter`
memory).

### 3. Per-family unit tests (precision, only when needed)

Most families need no dedicated unit test — the round-trip fixture is
sufficient. A family file gets a `<Family>ExportTests.swift` *only*
when the contract table flags a canonicalization or quoting rule that
round-trip fidelity alone cannot pin (e.g., `sankey` RFC 4180 quoting
needs explicit string assertions; `gantt` already follows this pattern).

### Snapshot baselines

No new snapshot baselines required — round-trip is structural-equality,
not byte-equality. `Scripts/rebaseline-snapshots.sh` is untouched.

### Fixture authorship method

For each family, derive `01-basic.md` from the smallest corpus entry of
that family in `Sources/DiagramKitSample/Resources/test-diagrams.json`;
derive `02-<feature>.md` from a richer corpus entry. This keeps
fixtures grounded in real-world DSL idiom rather than synthetic
minimum cases.

## Implementation Waves

Three waves, each independently shippable (passes all discipline gates
and grows `supportedDiagramTypes` incrementally). The umbrella
`MermaidExporter.export(_:)` carries the `default:` fall-through until
wave 3 lands; only then does the switch become exhaustive and
`default:` is removed.

### Wave 1 — Flat text DSLs (9 families)

`pie`, `journey`, `timeline`, `sankey`, `kanban`, `mindmap`, `treemap`,
`packet`, `gitGraph`.

Rationale: minimal cross-family coupling, lots of variety on simple
shapes (section/group emission, indent-based emission, CSV quoting,
command sequences). Shared helpers settle here:

- Indent-based tree emitter (used by `mindmap`, `treemap`, later
  `treeView`, `block`).
- Section-block emitter (used by `journey`, `timeline`, `kanban`,
  later `eventModeling`).
- RFC 4180 CSV field quoter (used by `sankey`).

After wave 1: 16/28 families supported. 9 round-trip fixture
directories, ~20 fixture files. Corpus round-trip test gains 9 family
arms.

### Wave 2 — Structured but bounded (9 families)

`xyChart`, `quadrantChart`, `requirement`, `radar`, `venn`, `ishikawa`,
`zenuml`, `treeView`, `eventModeling`.

Rationale: each has a more elaborate per-row schema (typed blocks,
coordinate pairs, axis specs, statement grammars) but reuses
scaffolding from wave 1. `treeView` and `eventModeling` reuse the
wave-1 indent and section helpers respectively, validating the
abstractions before wave 3 stresses them.

After wave 2: 25/28 families supported. ~20 more fixture files.

### Wave 3 — Nested / icon-heavy (3 families)

`block`, `architecture`, `wardleyBeta`.

Rationale: highest risk concentration.

- `block` — arbitrary nesting depth, edge attachment to nested ids,
  column layout directives.
- `architecture` — icon vocabulary, group containment, port-spec edges.
- `wardleyBeta` — `Beta` family, value-chain + evolution axis geometry
  encoded as DSL.

After wave 3: 28/28 families supported. `default:` removed from
`MermaidExporter.export(_:)`. COVERAGE.md updates: Mermaid export row
goes from 7/28 to 28/28; the "21 missing families" bullet is removed
from the backlog summary; the "Last audited" date moves to the closing
commit date.

## Commit Cadence

Per the project's `feedback_branching` standing default, work happens
commit-by-commit on `main`. Suggested cadence: one commit per family
(file + fixtures + dispatch arm + `supportedDiagramTypes` entry),
batched into per-wave PRs only if review pressure demands it. Each
commit independently green on `swift test --filter "RoundTrip"`.

At the end of each wave:

- `Scripts/bootstrap-smoke-check.sh` — full gate sweep.
- `Scripts/check-diagnostic-discipline.sh` — typed-factory enforcement.
- Corpus round-trip pass scoped to the newly-supported families.

## Definition of Done (per family)

- Round-trip fixtures pass under
  `swift test --filter "RoundTrip"`.
- Corpus round-trip test passes for that family.
- `Scripts/check-diagnostic-discipline.sh` passes.
- `Scripts/check-file-sizes.sh` passes (new file < 500 lines warn; no
  file approaches the 1000-line error line).
- New `case` arm wired into `MermaidExporter.export(_:)` and the family
  appended to `supportedDiagramTypes`.

## Definition of Done (spec-level)

- All 21 families shipped through wave 3.
- `MermaidExporter.export(_:)` switch is exhaustive; `default:` removed.
- COVERAGE.md updated: Mermaid Export column all `✓`; Totals row
  `28/28`; backlog summary item #1 removed; "Last audited" date moved
  to the closing commit date.
- `Scripts/bootstrap-smoke-check.sh` green on the closing commit.

## References

- [COVERAGE.md](../../../COVERAGE.md) — backlog source and audit table.
- [CLAUDE.md](../../../CLAUDE.md) — package invariants and conventions.
- [docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md) —
  typed diagnostic factories and decision tree.
- `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidGanttExport.swift`
  — exemplar for canonicalization commentary on a family with real
  re-emission tradeoffs.
- `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidFlowchartExport.swift`
  — exemplar for the largest existing per-family exporter (338 lines).
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-flowchart/`
  — exemplar fixture directory layout.

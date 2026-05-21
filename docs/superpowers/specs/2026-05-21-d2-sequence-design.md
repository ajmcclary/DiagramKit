# 2026-05-21 — D2 sequence diagram coverage (Wave F)

## Summary

Add `sequenceDiagram` import + export to the `DiagramKitD2` slice,
taking D2 coverage from 7/28 to 8/28 in each direction. D2 has native
`shape: sequence_diagram` syntax, which makes this the strongest
remaining native-fit gap in [COVERAGE.md](../../../COVERAGE.md) —
the §2 D2/DOT gap analysis ranked classDiagram/stateDiagram/erDiagram/
architecture/mindmap/treeView (all closed by Waves 2 and E) but did
not enumerate sequence even though D2 supports it natively.

The work is bidirectional, lossless on same-format round-trip via
comment-encoded recovery markers, and lossy-with-typed-diagnostics on
the cross-format paths. No new `DiagnosticCategory` cases, no new
`RoundTripLoss` cases, no new public umbrella surface.

This builds on:

- [`2026-05-19-coverage-expansion-design.md`](2026-05-19-coverage-expansion-design.md)
  (Wave 2 — D2/DOT class/state/er): the per-family mapper + exporter
  layering this spec extends.
- [`2026-05-20-coverage-marker-recovery-design.md`](2026-05-20-coverage-marker-recovery-design.md):
  the comment-encoded recovery-marker pattern and the existing
  `D2RecoveryMarker.scanner` infrastructure.
- [`2026-05-20-d2-dot-coverage-wave-e-design.md`](2026-05-20-d2-dot-coverage-wave-e-design.md)
  (Wave E): the structural-probe-plus-marker-recovery dispatch
  pattern in `D2Importer.parse`.

## Matrix delta

One new cell in each direction, mirrored across import and export:

| Family          | D2 (was → now) | DOT | PlantUML | Structurizr |
|-----------------|:--------------:|:---:|:--------:|:-----------:|
| sequenceDiagram | — → ✓          |  —  |    ✓     |      —      |

Totals after Wave F: D2 8/28 import, D2 8/28 export (was 7/28 each).
DOT stays at 7/28 (DOT has no native sequence-diagram dialect — out
of scope per the doc's "no defensible projection" policy).

## Scope

### In scope

- A new D2 sequence mapper (`D2SequenceMapper`), exporter
  (`D2SequenceExporter`), and structural probe (`D2SequenceProbe`)
  in `Sources/DiagramKitD2/`.
- Routing-chain extension in `D2Importer`: insert sequence after the
  existing class/ER/state probes, before the marker-forced
  architecture/mindmap/treeView branches.
- Exporter dispatch extension in `D2Exporter` for `.sequenceDiagram`.
- Eleven new `D2RecoveryMarker.Kind` cases for sequence-specific
  encoding (`seqActorKind`, `seqArrowType`, `seqMessageAttr`,
  `seqBlockType`, `seqBlockDivider`, `seqNote`, `seqBox`,
  `seqAutonumber`, `seqTitle`, `seqAccTitle`, `seqAccDescr`) with
  matching `emit*` / `parseKind` branches.
- Five new round-trip fixtures:
  - `roundtrip/d2-sequence/` — same-format D2.
  - `roundtrip/sequence-cross-mermaid-d2/{mermaid-to-d2, d2-to-mermaid}/`
    — directed cross-format pair (× 2 directions).
  - `roundtrip/sequence-cross-plantuml-d2/{plantuml-to-d2, d2-to-plantuml}/`
    — directed cross-format pair (× 2 directions).
- Three new test suites under `Tests/DiagramKitTests/D2/`:
  `D2SequenceImportTests`, `D2SequenceExportTests`,
  `D2SequenceProbeTests`. Plus one same-format
  `D2SequenceRoundTripTests` under `Tests/DiagramKitTests/RoundTrip/`.
- Four new cross-format directed cases added to the existing
  `CrossFormatRoundTripTests` parameterized suite (two unordered
  pairs: mermaid↔d2 and plantuml↔d2, each with two directions).
- [`COVERAGE.md`](../../../COVERAGE.md) updates: import + export
  totals, round-trip discipline counts, partial-support detail
  wave-closer reference.

### Out of scope

- DOT sequence diagrams. DOT has no native sequence-diagram dialect,
  so a defensible projection does not exist; this stays a deliberate
  `—` per the policy in
  [COVERAGE.md §2](../../../COVERAGE.md#2-d2-and-dot-expansion-mostly-mismatch-narrow-opportunities).
- New `DiagnosticCategory` cases. Reuses `.shapeDowngrade`,
  `.semanticDowngrade`, `.metadataDropped`, `.idSanitization`.
- New `RoundTripLoss` cases.
- `lifelines`, `bottomActors`, `rectHighlights` from the Mermaid
  `SequenceDiagram` payload. D2 has no analogue. These drop with
  `.lossyTransform(.semanticDowngrade, …)` on export and never appear
  on import. They round-trip natively only through the Mermaid →
  Mermaid same-format path (already covered).
- Autonumber rendering nuance beyond `(start, step, visible)`. Mermaid's
  `autonumber` accepts richer forms (display formats) that this spec
  preserves only at the model level.
- `.link`/`.links`/`.properties`/`.details` `SequenceItem` cases
  (HTML-extension metadata). Drop with
  `.featureDropped(.metadataDropped, …)`.
- New corpus entries in
  `Sources/DiagramKitSample/Resources/test-diagrams.json`; no new
  SVG / image / ASCII snapshot baselines.
- New public umbrella surface. All new types are `internal` to
  `DiagramKitD2`; the additive public bits (`D2RecoveryMarker.Kind`
  cases, `D2Importer.supportedDiagramTypes`) are SPI-equivalent
  surface that doesn't escape the slice.

## Coverage tier — Standard

The spec adopts the **Standard** tier from brainstorming. Concretely,
sequence features covered (round-trip clean via markers on same-format
D2, and via the natural shared subset on cross-format paths):

| Sequence feature                              | Same-format D2 | Cross-format mermaid↔d2 | Cross-format plantuml↔d2 |
|-----------------------------------------------|:--------------:|:-----------------------:|:------------------------:|
| Participants (all 8 `ParticipantType` cases)  | ✓ via markers  | ✓ for natural subset    | ✓ for natural subset     |
| Messages — solid / dotted / bidirectional     | ✓              | ✓                       | ✓                        |
| Messages — all 26 `SequenceArrowType` values  | ✓ via markers  | downgrade with diag.    | downgrade with diag.     |
| Self-messages                                 | ✓              | ✓                       | ✓                        |
| Blocks — `alt`/`opt`/`loop`/`par`/`critical`  | ✓ via markers  | ✓                       | ✓                        |
| Block dividers (`else`/`and`)                 | ✓ via markers  | ✓                       | ✓                        |
| Notes (`over`/`right of`/`left of`)           | ✓ via markers  | ✓                       | ✓                        |
| Boxes (fill, name, wrap, actor membership)    | ✓ via markers  | ✓                       | drop with diag.          |
| Activations / deactivations                   | ✓ via markers  | ✓                       | ✓                        |
| Autonumber `(start, step, visible)`           | ✓ via markers  | ✓                       | ✓                        |
| Title / accTitle / accDescr                   | ✓ via markers  | ✓                       | ✓                        |
| `create` / `destroy` participant              | ✓ via markers  | ✓                       | drop with diag.          |
| Lifelines / bottomActors / rectHighlights     | drop with diag.| drop with diag.         | drop with diag.          |
| `.link` / `.links` / `.properties` / `.details` | drop with diag. | drop with diag.       | drop with diag.          |

## File layout

**New files in `Sources/DiagramKitD2/`:**

- `D2SequenceProbe.swift` — structural detection
  (`shape: sequence_diagram` at top level) plus a marker-forced
  family override hook.
- `D2SequenceMapper.swift` — `D2Document → SequenceDiagram` timeline
  reconstruction from the D2 AST + recovery markers.
- `D2SequenceExporter.swift` — `SequenceDiagram → D2 source` with
  paired markers.

**Edited files:**

- `Sources/DiagramKitD2/D2RecoveryMarker.swift` — eleven new
  `Kind` cases + emit/parse helpers (§"Recovery markers" below).
- `Sources/DiagramKitD2/D2Importer.swift` — add `.sequenceDiagram`
  to `supportedDiagramTypes`; insert sequence dispatch branch in
  `parse(_:)`.
- `Sources/DiagramKitD2/D2Exporter.swift` — extend the family
  switch to dispatch `.sequenceDiagram` to `D2SequenceExporter`.
- `COVERAGE.md` — matrix totals, round-trip discipline counts, and
  Wave F partial-support detail entry.

`D2Probe.swift` (the `isD2Source` source-format probe) needs no
change — it already accepts any source containing `shape:` lines.

## Family detection on import

`D2Importer.parse(_:)` dispatches by trying per-family probes and
falling back to flowchart. Wave F extends the chain:

```
1. D2ClassProbe          (existing; checks shape: class)
2. D2ERProbe             (existing; checks shape: sql_table)
3. D2StateProbe          (existing)
4. D2SequenceProbe       ← new; checks top-level `shape: sequence_diagram`
5. marker-forced family  (existing; architecture/mindmap/treeView/sequence)
6. structural architecture
7. flowchart fallback
```

`D2SequenceProbe.detectsSequence(_:)` walks the parsed `D2Document`
(not raw source) and returns `true` iff a top-level
`D2NodeDefinition` carries `shape == "sequence_diagram"`. Nested
`sequence_diagram` containers do **not** trigger the probe — they
represent `SequenceBox` instances inside an outer sequence diagram.

The marker-forced override at step 5 honors
`# diagramkit:family=sequence`. This mirrors Wave E's pattern for
mindmap/treeView (a single sentinel marker can override the
structural probe when the user has edited the `shape:` line away).

## Mapper — D2 → SequenceDiagram

The mapper walks the parsed D2 AST and emits a
`SequenceDiagram(items: [SequenceItem])` timeline directly, in
declaration order, so the derived computed arrays (`actors`,
`messages`, `blocks`, `boxes`, `notes`) reconstruct correctly.

### Per-node translation

| D2 construct                                        | `SequenceItem` emission                                                                                                          |
|-----------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|
| Top-level node `alice` (with optional `: Label`)    | `.actor(SequenceActor(id, label, type: .participant, isExplicit: true))`                                                          |
| Top-level node + `alice.shape: person`              | `type = .actor`; D2 shape map: `person → .actor`, `cylinder → .database`, `queue → .queue`, `oval → .boundary`, `hexagon → .control`, `cloud → .entity`, `page → .collections`. Unknown shapes default to `.participant` and emit `.lossyTransform(.shapeDowngrade)`. |
| Edge `alice -> bob: msg`                            | `.message(SequenceMessage(from, to, label, arrowType: .solid))`                                                                   |
| Edge `alice -> alice: msg`                          | `.message(...)` with `from == to`                                                                                                  |
| Edge `alice <-> bob: msg`                           | `arrowType: .bidirectionalSolid`                                                                                                   |
| Edge `alice --> bob: msg`                           | `arrowType: .dotted`                                                                                                               |
| Container `alt_1: { … }`                            | `.blockStart(type, label)` + child items + `.blockEnd(type)`. Block `type` recovered from `seq-block-type` marker if present, else inferred from container-label prefix (`alt_*`/`opt_*`/`loop_*`/`par_*`/`critical_*`/`break_*`), else defaults to `"opt"` with `.lossyTransform(.semanticDowngrade)`. |
| Nested container with `shape: sequence_diagram`     | `.boxStart` + member `.actor` items + `.boxEnd`. Box fill / name / wrap recovered from `seq-box` marker; absent marker → `fill = "#ECECFF"`, `wrap = false`, `name = container.label`. |
| Comment `# Note (over alice,bob): text`             | Recognized only if paired with a `seq-note` marker; otherwise it is treated as an arbitrary comment and ignored.                  |

### Marker application (second pass)

After the AST walk, the mapper applies markers in declaration order:

- `seq-actor-kind=<id>,<participantType>` — overrides shape-derived
  `ParticipantType`. Useful when D2 source has no `shape:` line (e.g.
  participant declared implicitly via an edge).
- `seq-arrow-type=<msgIndex>,<rawArrowValue>` — overrides the
  structurally-decoded `SequenceArrowType` with the exact raw value.
  `msgIndex` is the importer's reconstructed message-array index
  (declaration order, 0-based).
- `seq-message-attr=<msgIndex>,<attr>` — per-message attribute.
  `<attr>` ∈ `{activate, deactivate, wrap, seqNum=<n>, create, destroy}`.
- `seq-block-type=<containerLabel>,<blockType>` — pins block type
  when label-prefix inference is ambiguous.
- `seq-block-divider=<containerLabel>,<dividerIndex>,<label>` —
  restores `alt … else …` and `par … and …` dividers.
- `seq-note=<afterMsgIndex>,<position>,<actorIdsCsv>,<text>` —
  restores notes. `<position>` ∈ `{over, "right of", "left of"}`.
- `seq-box=<containerLabel>,<fill>,<wrap>,<name>` — restores box
  metadata; the matching container becomes a `boxStart`/`boxEnd`
  instead of a `blockStart`/`blockEnd`.
- `seq-autonumber=<start>,<step>,<visible>` — restores autonumber.
- `seq-title=<text>` — top-level title.
- `seq-acc-title=<text>` — accessibility title.
- `seq-acc-descr=<text>` — accessibility description.

### Import-side diagnostics

| Situation                                                 | Diagnostic                                                                                  |
|-----------------------------------------------------------|---------------------------------------------------------------------------------------------|
| D2 `shape:` value doesn't map to `ParticipantType`        | `.lossyTransform(.shapeDowngrade, "D2 shape '\(name)' downgraded to .participant")`         |
| Block-type inference falls back to `"opt"`                | `.lossyTransform(.semanticDowngrade, "Block 'alt_1' assumed type 'opt'")`                   |
| `# diagramkit:` marker fails to parse                     | Silent drop (matches existing `RecoveryMarkerScanner` policy)                               |
| Container with `shape: sequence_diagram` but no members   | `.lossyTransform(.semanticDowngrade, "Empty sequence box dropped")`                         |

## Exporter — SequenceDiagram → D2

The exporter writes D2 source by iterating the canonical
`items: [SequenceItem]` timeline. It does **not** use the derived
`actors`/`messages`/`blocks` arrays directly — that would lose the
timeline ordering of notes relative to messages.

### Emission outline

```d2
# diagramkit:family=sequence
shape: sequence_diagram

# diagramkit:seq-title=Login flow
# title: Login flow

alice: Alice
# diagramkit:seq-actor-kind=alice,actor
alice.shape: person

bob: Bob

# diagramkit:seq-box=customerBox,#ECECFF,true,Customer side
customerBox: Customer side {
  shape: sequence_diagram
  alice
}

alice -> bob: Hello
# diagramkit:seq-arrow-type=0,0
# diagramkit:seq-message-attr=0,activate

bob --> alice: Hi
# diagramkit:seq-arrow-type=1,1

# diagramkit:seq-note=1,right of,bob,Thinking...
# Note (right of bob): Thinking...

# diagramkit:seq-block-type=alt_1,alt
alt_1: {
  bob -> alice: yes
  # diagramkit:seq-block-divider=alt_1,1,no
  bob -> alice: no
}
```

### Per-item emission rules

| `SequenceItem`                                | D2 emission                                                                                                                                                                       |
|-----------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `.title(t)`                                   | `seq-title` marker + human-readable `# title: <t>` comment                                                                                                                          |
| `.accTitle(t)` / `.accDescr(d)`               | Marker only (no human-readable D2 form)                                                                                                                                            |
| `.actor(a)`                                   | `<id>: <label>` line + optional `<id>.shape: <d2Shape>` when `type` round-trips structurally; always emit `seq-actor-kind` marker so non-structural kinds (`.boundary`/`.control`/`.collections`) round-trip exactly |
| `.createParticipant(a)`                       | Same as `.actor` + `seq-message-attr=<msgIdx>,create` on the next message                                                                                                          |
| `.destroyParticipant(id)`                     | `seq-message-attr=<msgIdx>,destroy` on the preceding message                                                                                                                       |
| `.message(m)`                                 | `<from> <arrow> <to>: <label>` with arrow `->` / `-->` / `<->` chosen by closest-fit. Always emit `seq-arrow-type` marker. `activate`/`deactivate`/`wrap`/`sequenceNumber` each emit a `seq-message-attr` marker. |
| `.blockStart(type, label)` / `.blockEnd`      | `<containerLabel>: { … }` with `seq-block-type` marker. Container label is `<type>_<n>` (e.g. `alt_1`) so inference still works if the marker is lost.                              |
| `.blockDivider(type, label)`                  | `seq-block-divider` marker only (D2 has no native divider form)                                                                                                                    |
| `.boxStart(fill, title, wrap)` / `.boxEnd`    | `<boxLabel>: <title?> { shape: sequence_diagram; … }` + `seq-box` marker                                                                                                            |
| `.note(n)`                                    | `# Note (<position> <actorIds>): <text>` comment + `seq-note` marker                                                                                                                |
| `.activationStart` / `.activationEnd`         | `seq-message-attr=<adjacentMsgIdx>,activate` or `,deactivate` on the adjacent message (D2 has no standalone activation primitive)                                                  |
| `.autonumberEvent(start, step, visible)`      | `seq-autonumber` marker                                                                                                                                                            |
| `.link` / `.links` / `.properties` / `.details` | Dropped with `.featureDropped(.metadataDropped, "Sequence \(case) item dropped: D2 has no equivalent")`                                                                          |

### ID sanitization

D2 identifiers permit hyphens and dots but treat dots as path
separators. The exporter routes actor / box / block labels through
the existing `D2Exporter` sanitizer (`actor.name` → `actor_name`,
spaces → underscores). Each sanitization emits one
`.lossyTransform(.idSanitization, …)` diagnostic per identifier.

### Export-side diagnostics

| Situation                                                       | Diagnostic                                                                                  |
|-----------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `lifelines` / `bottomActors` / `rectHighlights` non-empty       | `.lossyTransform(.semanticDowngrade, "Mermaid \(slot) has no D2 analogue")` per non-empty slot |
| ID required sanitization                                        | `.lossyTransform(.idSanitization, "Renamed '\(orig)' → '\(safe)'")`                          |
| `.link` / `.links` / `.properties` / `.details` item present    | `.featureDropped(.metadataDropped, "Sequence \(case) item dropped: D2 has no equivalent")`   |
| Arrow type encoded as nearest D2 arrow                          | Silent (marker carries the exact type — round-trip is lossless via markers)                  |
| Participant type non-structural (`.boundary`/`.control`/`.collections`) | Silent (marker carries exact type)                                                  |

## Recovery markers

The new `Kind` cases extend `D2RecoveryMarker.swift`:

```swift
public enum Kind: Sendable, Equatable {
    // existing 8 cases (classStereotype, stateAction, erCardinality,
    // archIcon, archGroup, family, treeRoot, mindmapIcon)
    case seqActorKind(actorID: String, participantType: String)
    case seqArrowType(messageIndex: Int, rawValue: Int)
    case seqMessageAttr(messageIndex: Int, attr: String)
    case seqBlockType(containerLabel: String, blockType: String)
    case seqBlockDivider(containerLabel: String, dividerIndex: Int, label: String)
    case seqNote(afterMessageIndex: Int, position: String, actorIDsCsv: String, text: String)
    case seqBox(containerLabel: String, fill: String, wrap: Bool, name: String)
    case seqAutonumber(start: Double, step: Double, visible: Bool)
    case seqTitle(text: String)
    case seqAccTitle(text: String)
    case seqAccDescr(text: String)
}
```

Each gets a matching `emit*` helper following the existing pattern
(`# diagramkit:<kind>=<comma-separated-args>`) and a `parseKind`
branch using `stripPrefix(…)`. The shared
`RecoveryMarkerScanner<Kind>` infrastructure in `DiagramKitCommon`
handles scanning, namespace enforcement (`# diagramkit:` prefix),
and stable positional correlation — no new scaffolding.

**Marker-name namespace audit.** The `seq-*` prefix doesn't collide
with the existing 8 marker kinds. The shared scanner enforces the
`# diagramkit:` namespace so foreign D2 comments cannot be parsed as
markers.

**`messageIndex` stability.** Mirrors Wave 3's
positional-correlation pattern (Structurizr boundaries) and Wave E's
`archGroup` ordering. Index is the position in the importer's
reconstructed `messages` array, declaration order, 0-based. Stable
across edits that don't reorder messages; an edit that reorders
messages loses positional markers, falls back to structural
defaults, and emits `.lossyTransform(.semanticDowngrade)` exactly
where the lossy fallback applies.

## Diagnostics

No new `DiagnosticCategory` cases. All emissions reuse:

| Category                                | Used for                                                                          |
|-----------------------------------------|-----------------------------------------------------------------------------------|
| `.lossyTransform(.shapeDowngrade)`      | D2 shape value with no `ParticipantType` mapping; default `.participant` used     |
| `.lossyTransform(.semanticDowngrade)`   | Block-type inference fallback, lifeline/bottomActor/rectHighlight drop, empty box |
| `.lossyTransform(.idSanitization)`      | Identifier rename (dots/spaces → underscores)                                     |
| `.featureDropped(.metadataDropped)`     | `.link` / `.links` / `.properties` / `.details` item drop                          |

No new `RoundTripLoss` cases — same-format round-trip is lossless
via markers (so the harness sees zero loss), and cross-format losses
all fall into the four categories above, which already have
`RoundTripLoss` mappings.

## Round-trip fixtures

### Same-format

```
Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-sequence/
  source.d2
```

`source.d2` exercises the Standard tier: 4 participants (two with
`shape:`-derived kinds, two with marker-overridden kinds), 6
messages (mix of `.solid`, `.dotted`, `.bidirectionalSolid`, plus
one `.solidCross` and one `.solidOpen` that only round-trip via
marker), one `alt`/`else` block with a divider, one `loop` block,
one box wrapping two actors, two notes (one `over`, one `right of`),
one autonumber directive, one title.

### Cross-format (4 directed, 2 unordered)

```
roundtrip/sequence-cross-mermaid-d2/
  mermaid-to-d2/source.mmd
  d2-to-mermaid/source.d2

roundtrip/sequence-cross-plantuml-d2/
  plantuml-to-d2/source.puml
  d2-to-plantuml/source.d2
```

Each direction is one `RoundTripHarness` test method (mirrors the
Wave E layout — 6 directed cross-format pairs there became 6 test
methods).

**Cross-format Mermaid sequence features included** are the subset
that all three formats support natively: participants, messages with
solid / dotted / bidirectional arrows, self-messages, `alt`/`opt`/
`loop` blocks, `Note over` / `right of` / `left of`, autonumber,
title. Exotic Mermaid-only features (`.solidCross`/`.solidPoint`/
half-arrows, `lifelines`, `bottomActors`, `rectHighlights`) appear
only in the same-format `d2-sequence` fixture where markers carry
them; including them in cross-format fixtures would force broader
`RoundTripLoss` allowances and obscure regression detection.

## Test plan

**New unit-level test suites under `Tests/DiagramKitTests/D2/`:**

- `D2SequenceImportTests` — mapper tests: each `SequenceItem`
  variant, each marker kind, each diagnostic category. Negative
  cases: malformed markers, missing `shape: sequence_diagram`,
  participants implied via edges.
- `D2SequenceExportTests` — exporter tests, including idempotence
  (`export(import(source)) == export(import(export(import(source))))`).
- `D2SequenceProbeTests` — detection edge cases: top-level vs nested
  `shape: sequence_diagram`, marker-forced override, negative cases
  for class/state/architecture sources.

**New round-trip suites:**

- `Tests/DiagramKitTests/RoundTrip/D2SequenceRoundTripTests.swift` —
  same-format.
- Four new directed cases added to `CrossFormatRoundTripTests`:
  `mermaidToD2Sequence`, `d2ToMermaidSequence`,
  `plantUMLToD2Sequence`, `d2ToPlantUMLSequence`.

**Corpus / snapshots.** No additions to
`Sources/DiagramKitSample/Resources/test-diagrams.json` and no new
SVG / image / ASCII snapshot baselines. Mirrors Wave E.

## Public surface impact

Nothing new at the umbrella level. All new types are `internal` to
`DiagramKitD2`:

- `D2SequenceMapper`, `D2SequenceExporter`, `D2SequenceProbe`:
  `internal`.
- `D2RecoveryMarker.Kind`: gains 11 new public cases (the enum was
  already public; consistent with the existing 8 cases). No
  documented client uses `D2RecoveryMarker` outside this slice.
- `D2Importer.supportedDiagramTypes`: gains `.sequenceDiagram`
  (additive set change, no breakage).

No changes required in `DiagramKitMermaid`, `DiagramKitPlantUML`,
`DiagramKitGraphviz`, or `DiagramKitStructurizr`. Cross-format
round-trips work because each format independently imports/exports
`.sequenceDiagram` on its own side and the harness composes them.

No `DiagramError`, `DiagnosticCategory`, or `RoundTripLoss`
additions.

## Linux portability

The `DiagramKitD2` slice is Linux-portable today (pure-string format,
no `CoreGraphics` / `UIKit` / `AppKit` dependencies). All new files
follow the same constraint:

- No `#if canImport(…)` gates required.
- All new types are value types over `Sendable` primitives — no
  `@unchecked Sendable` introductions.
- Must compile under `swift:6.3.1-noble` via `Dockerfile.linux-check`.

## Discipline gates

Existing gates that must pass on the closing commit:

- `Scripts/check-diagnostic-discipline.sh` — typed factories only;
  no raw `DiagramDiagnostic(severity:message:)`.
- `Scripts/check-file-sizes.sh` — each new file < 500 lines warning,
  < 1000 lines hard cap. Mapper is most at risk; if it approaches
  the warning, split per-`SequenceItem`-kind into a
  `D2SequenceMapper+<Topic>.swift` extension file.
- `Scripts/check-sendable-annotations.sh` — no `@unchecked Sendable`
  introductions.
- `Scripts/strict-concurrency-check.sh` — first-party Swift 6
  strict-concurrency build.
- `Scripts/linux-check.sh` — `Dockerfile.linux-check` builds the
  Linux-portable target matrix.
- `Scripts/bootstrap-smoke-check.sh` — local merge gate; chains all
  of the above plus `swift test` and the multiplatform
  `xcodebuild` sweep.

## Sequencing

Sequencing is intentionally left for `writing-plans` to expand. The
expected seams (each lands a green test):

1. `D2RecoveryMarker.Kind` extension + emit/parse round-trip unit
   tests.
2. `D2SequenceProbe` + dispatch wiring in `D2Importer`.
3. `D2SequenceMapper` — actors + simple messages first.
4. Mapper — blocks + boxes (nesting).
5. Mapper — notes + activations + autonumber + titles
   (marker-driven).
6. `D2SequenceExporter` — actors + simple messages.
7. Exporter — blocks + boxes.
8. Exporter — notes + markers + titles.
9. Same-format round-trip fixture + harness test.
10. Cross-format `mermaid↔d2` pair (2 directed tests).
11. Cross-format `plantuml↔d2` pair (2 directed tests).
12. `COVERAGE.md` update + Wave F closer commit.

Approximately 12 implementation tasks, sized similarly to Wave E
(which landed 16 tasks for 3 families × 2 formats).

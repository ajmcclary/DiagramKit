# Foreign-Format Coverage — Recovery Marker Generalization — Design

**Date:** 2026-05-20
**Status:** Approved (brainstorm)
**Builds on:** [2026-05-19-coverage-expansion-design.md](2026-05-19-coverage-expansion-design.md)
(closed 2026-05-19, three waves) and the Structurizr Wave 3 recovery-marker
pattern (`a399f4d6` … `baf5ae53`).
**Source matrix:** [COVERAGE.md](../../../COVERAGE.md).

## Goal

Close every `⚠` cell in COVERAGE.md whose loss is induced by Mermaid's
expressiveness gap relative to the foreign format. Achieve this by generalizing
the Structurizr Wave 3 comment-encoded recovery-marker pattern to D2, DOT, and
PlantUML, plus reconcile two stale `⚠` matrix entries that emit no diagnostics
on supported input.

After this work, the **export table** reaches **zero `⚠`** for every covered
(family × format) cell; the **import table** retains one residual category per
slice — `⚠` for foreign-native features that have no Mermaid landing slot
(D2/DOT `slotUnsupported`; PlantUML `styleDrop`, `diagramFamilyUnsupported`).

| Direction | Today | After |
|---|---|---|
| Export table `⚠` count | 10 | **0** |
| Import table `⚠` count | 9 | 8 (residual foreign-only losses) |

Closing the import-side residuals requires extending Mermaid's payload model
(payload-side slots for D2-native `direction`, `icon`, `tooltip`, `link`; for
PlantUML's `component`-vs-`interface` distinction; for PlantUML class
stereotypes/packages). That's deferred to a separate spec under "Future work."

### Success bar

A cell counts as closed (`⚠ → ✓`) if:

- the importer/exporter for that cell emits no `.lossyTransform`,
  `.featureDropped`, or `.informational` diagnostics on the corpus
  (`Sources/DiagramKitSample/Resources/test-diagrams.json`), AND
- the round-trip harness round-trips the cell's fixture
  (`parse → export → parse → assert structurally equal`) with no allowed
  `RoundTripLoss`.

For the recovery-marker cases, this means: the previously-emitted lossy
diagnostic is **deleted** at the same emission site that now also emits a
recovery marker.

## Scope

Two kinds of work, addressed across three waves:

1. **Matrix reconciliation** (Wave A). Two cells are diagnostic-free on
   supported input but show `⚠` in the matrix; verify and flip:
   - `classDiagram × PlantUML` (export)
   - `architecture × PlantUML` (export)

2. **Recovery-marker generalization** (Waves A, B, C). Apply the Wave 3
   Structurizr pattern (pre-lexer scan + positional correlation + implicit
   diagnostic suppression) to nine distinct loss-cases spread across 15
   foreign-format cells:

| Loss case | Cells affected | Marker kind |
|---|---|---|
| D2 class visibility + stereotype | D2 × class (im + ex) | `class-visibility`, `class-stereotype` |
| DOT class visibility + stereotype | DOT × class (im + ex) | `class-visibility`, `class-stereotype` |
| D2 composite-state nesting | D2 × state (im + ex) | `state-parent` |
| DOT composite-state nesting | DOT × state (im + ex) | `state-parent` |
| D2 ER relationship cardinality | D2 × er (im + ex) | `er-cardinality` |
| DOT ER relationship cardinality | DOT × er (im + ex) | `er-cardinality` |
| PlantUML activity partition + ID sanitization | PlantUML × flowchart (im + ex) | `activity-partition`, `activity-original-id` |
| PlantUML sequence participant link/properties/details | PlantUML × sequence (ex; im already ✓) | `sequence-participant-link`, `sequence-participant-property`, `sequence-participant-details` |
| PlantUML class unsupported source lines | PlantUML × class (im, round-trip only) | `class-unsupported-line` |

Plus the PlantUML × architecture (component) `styleDrop` loss-case will gain a
`component-style` marker that preserves round-trip identity, even though the
import-side cell remains `⚠` because the diagnostic still fires on vanilla
PlantUML sources.

## Out of Scope

- **Mermaid-side recovery markers for foreign-induced losses.** Would close the
  remaining 8 import-table `⚠` cells. Requires a Mermaid `%% diagramkit:`
  scanner + payload-model slots for foreign-native features. Deferred to a
  separate spec.
- **New family×format intersections.** Wardley, Sankey, treeView in non-native
  formats etc. remain `—`. Adding any requires a concrete user need per the
  existing COVERAGE.md policy.
- **Sixth source format.** Not in scope.
- **Performance optimization of pre-lexer scans.** Each scan is one extra O(n)
  pass over source; acceptable.
- **Native PlantUML parsing of stereotypes/packages.** The `class-unsupported-line`
  marker round-trips literal source lines but does not teach the parser to
  understand them.
- **Corpus growth.** `test-diagrams.json` stays at 424 entries; image/SVG/ASCII
  snapshot baselines stay at 437/437/424. New fixtures live exclusively under
  `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.

## Invariants Preserved

- **No thread pool.** Pre-lexer scan + native parse + mapper all run on the
  existing `DiagramEngine._runOnWorker` 8 MB-stack `Thread`. No new dispatch.
- **No new public surface.** All new types and helpers are `internal` or SPI.
  Pre-lexer scan is invoked from inside each slice's `parse(source:)`.
- **No new Mermaid family rows.** Mermaid stays at 28/28 native.
- **Linux portability.** All new code lives in Linux-portable targets
  (`DiagramKitCommon`, `DiagramKitD2`, `DiagramKitGraphviz`, `DiagramKitPlantUML`,
  `DiagramKitStructurizr`). Pure `String` line-walking; no platform gating.
- **Strict concurrency.** New shared scaffold is generic over `Sendable & Equatable`
  Kind. Scan results are immutable value types. No new `@unchecked Sendable`
  annotations; no allow-list additions in `Scripts/check-sendable-annotations.sh`.
- **File-size policy.** All new files target ~150–300 lines. Below the 500-line
  warning threshold; no allow-list additions.
- **Diagnostic discipline.** All emission sites use typed
  `DiagramDiagnostic.lossyTransform(.<category>, …)` /
  `.featureDropped(.<category>, …)` / `.informational(.<category>, …)` /
  `.warning(.<category>, …)` factories. Raw
  `DiagramDiagnostic(severity:message:)` not used.

## Architecture

### Module placement

```
Sources/DiagramKitCommon/RecoveryMarker/
  RecoveryMarkerSyntax.swift        // sentinel + grammar constants
  RecoveryMarkerScanner.swift       // generic line-walker + correlator
  DeclarationIndex.swift            // per-line declaration registry + latestDeclaration(before:)
```

Each format slice grows three files:

```
Sources/DiagramKitD2/
  D2RecoveryMarker.swift            // Kind enum + scanner registration + emission helpers
  D2PreLexerScan.swift              // declaration indexer for class/state/er constructs
  // existing D2Mapper.swift gains switch arms applying each Kind

Sources/DiagramKitGraphviz/
  DOTRecoveryMarker.swift           // Kind enum + scanner + helpers
  DOTPreLexerScan.swift             // declaration indexer
  // existing DOTMapper.swift gains switch arms

Sources/DiagramKitPlantUML/
  PlantUMLRecoveryMarker.swift      // Kind enum + scanner + helpers (' prefix, not #)
  PlantUMLPreLexerScan.swift        // declaration indexer per family
  // per-family mapper switch arms

Sources/DiagramKitStructurizr/
  StructurizrRecoveryMarker.swift   // refit to share common scaffold (no Kind changes)
```

Structurizr's existing `StructurizrRecoveryMarker.swift` is refit onto the
shared scaffold in Wave A. Existing Structurizr tests must stay green without
modification — refit is behavior-preserving.

### Shared scaffold API (`DiagramKitCommon.RecoveryMarker`)

```swift
public struct RecoveryMarkerScanner<Kind: Sendable & Equatable> {
    public init(
        commentPrefix: String,           // "#" for D2/DOT/Structurizr, "'" for PlantUML
        sentinel: String = "diagramkit:",
        parseKind: @Sendable (_ rest: String) -> Kind?
    )

    public func scan(source: String) -> ScanResult<Kind>
}

public struct ScanResult<Kind: Sendable & Equatable>: Sendable, Equatable {
    public let markers: [(lineNumber: Int, kind: Kind)]
    public let lines: [String]
}

public protocol HasLineNumber {
    var lineNumber: Int { get }
}

public func latestDeclaration<D: HasLineNumber>(
    before line: Int,
    in index: [D]
) -> D?
```

Each slice supplies (a) its comment prefix, (b) its `Kind` enum, (c) its
declaration-line indexer, (d) the `parseKind` closure.

### Marker line grammar

```
<comment-prefix> diagramkit:<kind-kebab>=<args>
```

`<args>` is one of:

- `value` — single-string payload
- `field1,field2,…` — comma-separated positional fields
- `b64:<base64-of-utf8>` — for free-form text (one kind only:
  `sequence-participant-details`)

Whitespace around comma-separated fields is stripped by the scanner. Internal
newlines/quotes/CR are sanitized on emission for non-base64 kinds (matching the
Structurizr Wave 3 sanitizer at `StructurizrExporter.swift:164–180`).

### Correlation rule (all slices, all kinds)

A marker at line N applies to the **latest qualifying declaration on a line
strictly less than N**. "Qualifying declaration" is kind-specific:

- `class-visibility`, `class-stereotype` → latest class declaration
- `state-parent` → latest state declaration
- `er-cardinality` → latest relationship/edge declaration
- `activity-partition`, `activity-original-id` → latest activity step (`:label;`)
- `sequence-participant-*` → latest participant declaration
- `component-style` → latest component/interface node
- `class-unsupported-line` → latest class declaration (the literal source line
  is preserved as the marker payload; on re-import, the parser re-emits it as
  `unsupportedLines` for that class)
- `tag`, `boundary-parent` → existing Structurizr semantics (unchanged)

### Conflict handling

Matches Wave 3 precedent:

- Non-`diagramkit:` comments → silently ignored.
- Multiple markers of the same kind on the same declaration → kind-defined:
  list-accumulate (e.g., `class-visibility` markers stack per member) or
  last-wins (e.g., `component-style` is singular).
- Marker whose correlation target doesn't exist post-parse → silently dropped
  (no diagnostic). Same as Structurizr.
- Marker line starts with `diagramkit:` sentinel but args fail to parse →
  scanner returns `nil` Kind; emits `.recoveryMarkerMalformed(.warning)` with
  the line text + line number.

## Marker Syntax Reference

### D2 (`#` prefix)

```d2
# diagramkit:class-visibility=Order,placeOrder(),+
# diagramkit:class-stereotype=Order,<<entity>>
# diagramkit:state-parent=heating,Active
# diagramkit:er-cardinality=r0,one,zero-or-many
```

`D2RecoveryMarker.Kind`:

```swift
public enum Kind: Sendable, Equatable {
    case classVisibility(className: String, member: String, visibility: Visibility)
    case classStereotype(className: String, stereotype: String)
    case stateParent(stateId: String, parentId: String)
    case erCardinality(relationshipId: String, source: ERCardinality, target: ERCardinality)
}

public enum Visibility: String, Sendable, Equatable {
    case `public` = "+"
    case `private` = "-"
    case `internal` = "~"
    case `protected` = "#"
}

public enum ERCardinality: String, Sendable, Equatable {
    case one, zeroOrOne = "zero-or-one"
    case zeroOrMany = "zero-or-many"
    case oneOrMany = "one-or-many"
}
```

### DOT (`#` prefix)

Same Kind shape as D2. Each kind name kebab-cased identically. Marker lines use
DOT's `#` line-comment form (DOT also accepts `//` and `/* */`; markers use `#`
for symmetry with D2/Structurizr).

### PlantUML (`'` prefix)

```plantuml
' diagramkit:activity-partition=order_create,OrderProcessing
' diagramkit:activity-original-id=s0,placeOrder
' diagramkit:sequence-participant-link=alice,https://example.com/alice
' diagramkit:sequence-participant-property=alice,role,manager
' diagramkit:sequence-participant-details=alice,b64:VGhpcyBpcyBhIGRldGFpbCBibG9jay4=
' diagramkit:component-style=auth,interface
' diagramkit:class-unsupported-line=Order,<<entity>>
```

`PlantUMLRecoveryMarker.Kind`:

```swift
public enum Kind: Sendable, Equatable {
    case activityPartition(originalId: String, partition: String)
    case activityOriginalId(syntheticId: String, originalId: String)
    case sequenceParticipantLink(participantId: String, url: String)
    case sequenceParticipantProperty(participantId: String, key: String, value: String)
    case sequenceParticipantDetails(participantId: String, base64: String)
    case componentStyle(id: String, style: ComponentStyle)
    case classUnsupportedLine(anchorAlias: String, line: String)
}

public enum ComponentStyle: String, Sendable, Equatable {
    case component, interface
}
```

PlantUML's block comment form `/' '/` is **not** recognized for markers. Only
line-form `'` at the start of a trimmed line counts. Markers wrapped in a
block comment are silently ignored.

### Structurizr (`#` prefix, refit-only)

No syntax changes:

```structurizr
# diagramkit:tag=external
# diagramkit:boundary-parent=Outer
```

Refit moves these onto `RecoveryMarkerScanner<StructurizrRecoveryMarker.Kind>`
without changing semantics.

## Pipeline integration

### Importer path

Each importer's `parse(source:)` gains a pre-lexer scan immediately before
lexing/parsing. The scan operates on the raw source string; tokenization and
parsing remain unchanged (the lexer continues to strip comments — markers are
already harvested into `scan.markers` and applied post-parse).

```swift
func parse(source: String) -> DiagramImportResult {
    let scan = D2RecoveryMarker.scanner.scan(source: source)
    let tokens = D2Lexer.tokenize(source)             // strips comments as today
    let ast = D2Parser.parse(tokens)
    let document = D2Mapper.map(ast, applying: scan)  // applies markers post-AST
    return DiagramImportResult(document: document, diagnostics: …)
}
```

The mapper's per-kind switch arms consult `scan.markers`, find each marker's
correlation target via `latestDeclaration(before:)`, and apply the kind's
payload onto the built document. Marker application happens after native AST
mapping, so element handles are stable.

### Exporter path

Each lossy emission site gets `if loss { emit native form; emit marker(...) }`
treatment. The diagnostic emission at that site is **deleted** in the same
patch — by construction, the marker carries the lost information forward.

For example, `D2ClassExporter.write(payload)` before:

```swift
for member in cls.members {
    if member.visibility != .default {
        diagnostics.append(.lossyTransform(.classVisibilityDrop, …))
    }
    write("  \(member.signature)")
}
```

After:

```swift
for member in cls.members {
    write("  \(member.signature)")
    if member.visibility != .default {
        write("# \(D2RecoveryMarker.classVisibility(class: cls.name, member: member.signature, visibility: member.visibility))")
    }
}
```

## Per-Wave Plan

### Wave A — Shared scaffold + Structurizr refit + matrix reconciliation (~10 tasks)

| Task | Description |
|---|---|
| A.1 | Add `RecoveryMarkerSyntax.swift` — sentinel and grammar constants in `DiagramKitCommon`. |
| A.2 | Add `RecoveryMarkerScanner.swift` — generic line-walker. |
| A.3 | Add `DeclarationIndex.swift` + `HasLineNumber` protocol + `latestDeclaration(before:)` helper. |
| A.4 | Add `.recoveryMarkerMalformed(.warning)` to `DiagnosticCategory`. Allow-list in `Scripts/check-diagnostic-discipline.sh`. |
| A.5 | Refit `StructurizrRecoveryMarker.swift` and `StructurizrImporter.swift` onto the shared scaffold. Existing Structurizr tests must stay green unchanged. |
| A.6 | Wire malformed-marker emission. Add unit tests for the malformed path. |
| A.7 | Add corpus-driven test (`CorpusDiagnosticFreeTests` or similar) that asserts the previously-flipped cells emit `[]` on the corpus. |
| A.8 | Flip COVERAGE.md `classDiagram × PlantUML export` ⚠ → ✓. |
| A.9 | Flip COVERAGE.md `architecture × PlantUML export` ⚠ → ✓. Remove the "Partial-support detail" section from COVERAGE.md (it becomes vacuous). |
| A.10 | Closer commit: BASELINES.md refresh; COVERAGE.md legend gains a footnote noting `⚠` in the import table means foreign-source features without a Mermaid landing slot. Update `ARCHITECTURE.md` "What Lives Where" with the new `DiagramKitCommon/RecoveryMarker/` directory. |

### Wave B — D2 + DOT marker recovery (~9 tasks)

| Task | Description |
|---|---|
| B.1 | `D2RecoveryMarker.swift` — Kind enum + scanner registration + emission helpers (class-visibility, class-stereotype, state-parent, er-cardinality). |
| B.2 | `D2PreLexerScan.swift` — declaration indexer for class/state/er. |
| B.3 | `D2Mapper.swift` — switch arms applying each marker kind. |
| B.4 | `D2ClassExporter.swift` + `D2StateExporter.swift` + `D2ERExporter.swift` — emit markers; delete `.lossyTransform(.classVisibilityDrop)`, `.classStereotypeDrop`, `.stateNestingFlatten`, `.cardinalityDrop` emission sites. |
| B.5 | DOT counterpart: `DOTRecoveryMarker.swift`, `DOTPreLexerScan.swift`, `DOTMapper.swift` switch arms. |
| B.6 | `DOTClassExport.swift` + `DOTStateExporter.swift` + `DOTERExport.swift` — emit markers; delete the same lossyTransform diagnostics. |
| B.7 | Round-trip fixtures under `roundtrip/`: D2 × {class, state, er}, DOT × {class, state, er} same-format (6 fixtures). Cross-format mermaid↔d2, mermaid↔dot, d2↔dot for class/state/er (9 directed pairs). |
| B.8 | Delete the `RoundTripLoss` cases for `.classVisibilityDrop`, `.classStereotypeDrop`, `.stateNestingFlatten`, `.cardinalityDrop`. Tighten harness allow-lists. Delete the corresponding `DiagnosticCategory` cases now that no emission site references them. |
| B.9 | Closer commit: COVERAGE.md export cells flip ⚠ → ✓ for D2/DOT × {class, state, er} (6 cells). Rebaseline `.txt` snapshots for affected cross-format fixtures via `Scripts/rebaseline-snapshots.sh --target svg`. BASELINES.md update. |

### Wave C — PlantUML marker recovery (~8 tasks)

| Task | Description |
|---|---|
| C.1 | `PlantUMLRecoveryMarker.swift` — Kind enum + scanner registration. Comment prefix `'`, not `#`. Includes `activity-partition`, `activity-original-id`, `sequence-participant-link/property/details`, `component-style`, `class-unsupported-line`. |
| C.2 | `PlantUMLPreLexerScan.swift` — declaration indexer per family (activity steps, sequence participants, component nodes, class declarations). |
| C.3 | PlantUML activity: mapper switch arms; `PlantUMLActivityExporter.swift` marker emission; delete `.lossyTransform(.partitionFlatten)` (import-side) and `.lossyTransform(.idSanitization)` (export-side). |
| C.4 | PlantUML sequence: mapper switch arms (sequence import is already ✓); `PlantUMLSequenceExporter.swift` marker emission; delete the informational diagnostic at line 126. |
| C.5 | PlantUML class: mapper switch arm for `class-unsupported-line`; `PlantUMLClassExporter.swift` marker emission for preserved unsupported lines. **Note:** import on vanilla PlantUML class source still emits `.featureDropped(.diagramFamilyUnsupported)` — the cell stays `⚠` in the import table; the marker only closes round-trip identity. |
| C.6 | PlantUML component: mapper switch arm for `component-style`; `PlantUMLComponentExporter.swift` marker emission. **Note:** mapper still emits `.lossyTransform(.styleDrop)` on vanilla foreign-source import; marker only closes round-trip. Import cell stays `⚠`. |
| C.7 | Round-trip fixtures under `roundtrip/`: PlantUML × {flowchart, sequence, component, class} same-format (4 fixtures). Cross-format mermaid↔plantuml for flowchart-activity and sequence-with-extras (2 directed pairs). |
| C.8 | Closer commit: COVERAGE.md export cells flip ⚠ → ✓ for PlantUML × {flowchart, sequence, class, architecture}. PlantUML import flips for flowchart only. Delete `.partitionFlatten`, `.idSanitization`, `.identifierEscape` diagnostic categories. Rebaseline `.txt` snapshots. BASELINES.md update. |

**Total: ~27 tasks across 3 waves.**

Each wave's closer commit must pass `Scripts/bootstrap-smoke-check.sh`, update
COVERAGE.md and BASELINES.md, and leave the discipline-gate scripts green.

## Diagnostic policy

**New category:**

| Category | Severity | Trigger |
|---|---|---|
| `.recoveryMarkerMalformed` | `.warning` | Comment matches sentinel prefix but args fail to parse |

**Deleted categories** (no longer emitted anywhere after this work):

| Category | Slice | Replaced by |
|---|---|---|
| `.classVisibilityDrop` | D2, DOT | `class-visibility` marker |
| `.classStereotypeDrop` | D2, DOT | `class-stereotype` marker |
| `.stateNestingFlatten` | D2, DOT | `state-parent` marker |
| `.cardinalityDrop` | D2, DOT | `er-cardinality` marker |
| `.partitionFlatten` | PlantUML activity | `activity-partition` marker |
| `.idSanitization` | PlantUML activity | `activity-original-id` marker |
| `.identifierEscape` | PlantUML sequence | `sequence-participant-*` markers |

**Retained categories** (still emitted by importers on foreign-native input):

| Category | Slice | Why retained |
|---|---|---|
| `.slotUnsupported` | D2, DOT | D2-native `direction`, `icon`, `tooltip`, `link` features have no Mermaid landing slot. |
| `.styleDrop` | PlantUML component | PlantUML `component` vs `interface` styling has no Mermaid `architecture` landing slot. |
| `.diagramFamilyUnsupported` | PlantUML class | PlantUML stereotypes, packages, and other syntax beyond simple class declarations have no Mermaid landing slot. |

The retained categories represent **foreign → Mermaid** losses. Closing them
requires payload-model surgery and is deferred to a future spec.

**Deletion gating:** each deletion is gated by a corpus-wide assertion that
zero emission sites remain for that category. Performed in the wave that
removes the last emission site. Concretely: Wave B deletes
`.classVisibilityDrop`, `.classStereotypeDrop`, `.stateNestingFlatten`, and
`.cardinalityDrop` (last emission sites are in D2/DOT exporters). Wave C
deletes `.partitionFlatten`, `.idSanitization`, and `.identifierEscape` (last
emission sites are in PlantUML exporters). Wave A adds
`.recoveryMarkerMalformed`.

## Round-trip harness changes

`DiagramKitTestSupport.RoundTripHarness` and `RoundTripLoss` are tightened:

- **Deleted `RoundTripLoss` cases** (matching deleted diagnostics): visibility,
  stereotype, state-nesting, cardinality, partition, id-sanitization, sequence
  participant extras. Per Wave 3 precedent, removal is in-place (no
  deprecation cycle) — anything still referencing them fails to compile and is
  fixed in the same patch.
- **Retained cases**: `.slotUnsupported`, `.styleDrop`,
  `.diagramFamilyUnsupported` — these continue to admit foreign-side losses
  the spec doesn't close.
- The harness's "every observed loss must have a paired warning diagnostic on
  the export step" invariant is preserved. Marker-bearing round-trips produce
  no losses, so they don't need paired diagnostics.

## Test coverage

| Wave | Required green |
|---|---|
| A | All existing tests, including the full Structurizr suite (refit must be behavior-preserving). New: marker-malformed warning test; corpus diagnostic-free assertion for the two flipped cells. |
| B | All existing tests + new D2/DOT class/state/er round-trip fixtures (15 new entries under `roundtrip/`). Cross-format pairs (mermaid↔d2, mermaid↔dot, d2↔dot) assert structural equality with no allowed `RoundTripLoss` for the closed categories. |
| C | All existing tests + new PlantUML fixtures (6 new entries under `roundtrip/`). PlantUML sequence cross-format pair (mermaid ↔ plantuml) with link/properties/details participants asserts loss-free round-trip. |

**Snapshot impact.**

- No new snapshots — recovery markers appear only in raw source output;
  SVG/image/ASCII renderers are unaffected.
- `.txt` snapshots that compare exported source regenerate where marker
  comments are now appended. Rebaseline pass per wave's closer commit using
  `Scripts/rebaseline-snapshots.sh --target svg` (covers `.txt` because the
  script treats SVG and ASCII output uniformly).
- Snapshot baseline counts stay at 437 SVG / 437 image / 424 ASCII.

## Risks and mitigations

1. **Structurizr refit regression.** The shared scanner abstraction must
   exactly preserve `StructurizrRecoveryMarker`'s positional-correlation
   semantics. *Mitigation:* refit in Wave A is purely behavior-preserving;
   existing Structurizr tests stay green without modification. Any required
   test change is a red flag and blocks Wave A's closer commit.

2. **Marker syntax collisions with user comments.** A user comment starting
   with the slice's sentinel is harvested by the scanner. *Mitigation:*
   matches Wave 3 precedent — malformed `diagramkit:` lines emit
   `.recoveryMarkerMalformed(.warning)` but don't break parsing. Corpus has no
   user comments matching this sentinel today (verifiable by grep).

3. **Sanitization corrupts marker payload content.** The shared sanitizer
   replaces newlines/quotes/CR with spaces on emission. *Mitigation:* base64
   bypasses sanitization and is mandatory for the one genuinely free-form
   case (`sequence-participant-details`). Other kinds carry only short,
   structured tokens (identifiers, visibility chars, cardinality names) and
   are safe under sanitization.

4. **Snapshot churn from added marker lines.** Cross-format exports
   appending marker comments change snapshot output. *Mitigation:* explicit
   rebaseline pass at each wave's closer commit. Image/SVG renderers
   unaffected; only `.txt` source snapshots change.

5. **Round-trip harness invariant drift.** Deleting `RoundTripLoss` cases is
   tightly coupled to deleting the matching diagnostic categories.
   *Mitigation:* each wave's closer commit explicitly lists both deletions;
   the diff is small and reviewable. Compilation failure of any orphan
   reference catches missed cleanups.

6. **PlantUML `'` corner cases.** PlantUML accepts inline block-comment forms
   `/' '/`. *Mitigation:* the scanner only inspects leading whitespace + first
   non-whitespace token per line. Block-comment-wrapped markers are
   intentionally ignored. This restriction is documented in the syntax
   reference.

## Future work

Out-of-scope items that are deferrable, in priority order:

1. **Mermaid-side recovery markers for `slotUnsupported` losses.** Would
   close the remaining 8 import-table `⚠` cells (D2/DOT × {flowchart, class,
   state, er}, PlantUML × {architecture, class}). Requires a Mermaid
   `%% diagramkit:` scanner (Mermaid's line-comment form is `%%`), payload-
   side slots for foreign-native features (`direction`, `icon`, `tooltip`,
   `link`, `componentStyle`, `unsupportedLine`), and per-family parser
   tolerance for those slots. Conservative estimate: one full coverage-
   expansion-sized spec.

2. **`.recoveryMarkerMalformed` severity tuning.** Defaulted to `.warning`
   on the theory that malformed markers indicate user-source error. If
   corpus runs show false positives (legitimate user comments matching the
   sentinel), consider downgrading to `.informational`.

3. **Reducing PlantUML's `diagramFamilyUnsupported` surface.** Native parser
   support for stereotypes (`<<…>>`), packages, and generics would reduce
   the import-side `⚠` even without Mermaid-side markers. Requires payload
   slots for stereotypes and packages.

## File-level rollout checklist

Per the previous coverage-expansion spec's precedent:

- [ ] Wave A closer commit: `Wave A closes recovery-marker scaffold + matrix reconciliation`
- [ ] Wave B closer commit: `Wave B closes D2 + DOT recovery markers — lift ⚠ to ✓`
- [ ] Wave C closer commit: `Wave C closes PlantUML recovery markers — lift ⚠ to ✓`

Each closer commit updates:

- COVERAGE.md (matrix + totals + legend footnote + closing-commit map)
- BASELINES.md (test counts, snapshot counts, gate status)
- The relevant slice's `What Lives Where` entry in CLAUDE.md if the file
  layout changes
- Diagnostic-discipline allow-list (`Scripts/check-diagnostic-discipline.sh`)
- File-size allow-list if any new file exceeds 500 lines (not anticipated)

## Open questions

- **`.recoveryMarkerMalformed` severity.** Defaulted to `.warning`. Revisit
  if corpus shows false positives.
- **Wave C task C.5 / C.6 import-side leftovers.** PlantUML × class and
  PlantUML × architecture (component) cells stay `⚠` in the import table
  after this work. Documenting this in COVERAGE.md's legend footnote is
  sufficient; closure is explicitly Future Work item 1.

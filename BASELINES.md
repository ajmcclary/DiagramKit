# BASELINES.md

Last updated: 2026-05-20

## Import coverage residuals — Wave D (Mermaid payload wiring)

- **2026-05-20 — Wave D:** Closes the nine residual import-side `⚠`
  cells in COVERAGE.md, driving the **import table** to zero `⚠`. Lands
  via three sub-waves, each closing its cells through surgical wiring
  rather than payload-model surgery. Only new public surface is the
  `ArchitectureServiceKind` enum (+ defaulted `kind` field on
  `ArchitectureService`/`PositionedArchitectureService`) and a public
  memberwise `init` on `ClassNamespace`.
  - **Sub-wave D.1 (class family):** D2 `link`/`tooltip`/`style` blocks
    route into `ClassNode.link`/`.tooltip`/`.styles` via a new
    attribute-vs-member distinction in `D2ClassMapper.PartialClass`
    (`classAttributeKeys` set, `inStyleBlock` flag, `appendAttribute` /
    `appendStyleAttribute`). DOT class records read `URL`/`href`/
    `tooltip`/`style`/`color`/`fillcolor`/`fontcolor` via
    `DOTClassMapper.routeClassAttributes(_:)`. PlantUML class parser
    pre-extracts `<<stereotype>>` markers (multiple join with comma-
    space) and recognizes `package "name" { … }` blocks, lifting them
    into `ClassNode.annotations` + `ClassNode.parent` + `ClassNamespace`.
    Three commits, three cells flipped.
  - **Sub-wave D.2 (state + er families):** `D2StateMapper` lifts
    container nesting into `MermaidSubgraph` with populated `nodeIds`
    (also restores inner states to `nodeOrder` — previously they were
    silently dropped). `DOTStateMapper` mirrors with
    `subgraph cluster_X { … }` → `MermaidSubgraph` (cluster_ prefix
    stripped, label from inline `label="…"` or bare id). `D2ERMapper`
    parses `{lo..hi}` cardinality grammar (`{0..1}`/`{0..N}`/`{1..1}`/
    `{1..N}` with `N`/`n`/`*` as upper-bound aliases) → `ErRelSpec.cardA`/
    `.cardB`. `DOTERMapper` maps crow's-foot arrow tokens (`tee`/`crow`/
    `odot`/`crowodot`) on `arrowtail`/`arrowhead` to the same slots.
    Four commits, four cells flipped.
  - **Sub-wave D.3 (PlantUML flowchart + architecture):** Introduces
    `ArchitectureServiceKind` enum and threads it through the layout +
    SVG renderer (component → boxed rectangle + small header rect,
    interface → lollipop circle). `PlantUMLComponentMapper` maps the
    AST's component/interface kind directly into the new field, dropping
    its previous `styleDrop` diagnostic. `PlantUMLActivityMapper` lifts
    `partition "Name" { … }` blocks into `MermaidSubgraph`, dropping the
    `subgraphFlatten` diagnostic. `PlantUMLActivityExport` groups nodes
    by their first containing subgraph and emits matching `partition`
    blocks on round-trip. Three commits, two cells flipped + payload
    addition.
  - Wave A/B/C recovery markers stay live as round-trip-identity
    fallback for syntax outside the natively-parsed surface.
  - 11 new tests in `ImportDiagnosticAbsenceTests` cover the nine cells +
    two architecture-kind defaults. Existing PlantUML component +
    activity round-trip tests updated to assert the new kind/subgraph
    behavior instead of the deleted diagnostics. Two existing tests
    (`partitionEmitsSubgraphFlattenDiagnostic`,
    `basicComponentParsesToArchitecture`'s `interfaceDiagnostics` arm)
    were updated in the same line of work (per the project's "fix
    pre-existing failures, don't document" practice).
  - Spec:
    [docs/superpowers/specs/2026-05-20-import-coverage-residuals-design.md](docs/superpowers/specs/2026-05-20-import-coverage-residuals-design.md).
    Plan:
    [docs/superpowers/plans/2026-05-20-import-coverage-residuals-plan.md](docs/superpowers/plans/2026-05-20-import-coverage-residuals-plan.md).

## Coverage marker recovery — Wave C (PlantUML recovery markers)

- **2026-05-20 — Wave C:** Generalize the recovery-marker pattern to
  PlantUML (comment prefix `'`, not `#`). Two export cells flip
  `⚠ → ✓` in COVERAGE.md: `flowchart × PlantUML` (activity idiom) and
  `sequenceDiagram × PlantUML`. The export table now has **zero `⚠`
  cells** for any covered (family × format) intersection.
  - **PlantUMLRecoveryMarker** with five Kind cases: `activityPartition`,
    `activityOriginalId`, `sequenceParticipantLink`, `sequenceParticipantLinks`,
    `sequenceParticipantProperties`, `sequenceParticipantDetails`. Sequence
    payloads with free-form JSON content (`.links`, `.properties`) use base64
    to round-trip past the marker sanitizer.
  - `PlantUMLActivityExport` emits `' diagramkit:activity-original-id=<n_i>,<orig>`
    markers for non-synthetic node ids and drops the `.lossyTransform(.idSanitization)`
    emission. `PlantUMLImporter` scans markers and applies a rename map to
    `nodesInOrder[i].id` and edge endpoints.
  - `PlantUMLSequenceExporter` emits one of four typed markers per
    `.link`/`.links`/`.properties`/`.details` `SequenceItem` case and drops
    the `.informational(.identifierEscape)` emission.
  - **Out of scope per Future Work:** import-side `⚠` for
    `flowchart × PlantUML` (`.subgraphFlatten` for partition flattening),
    `classDiagram × PlantUML` (`.diagramFamilyUnsupported` for stereotypes/
    packages), and `architecture × PlantUML` (`.styleDrop` for
    component-vs-interface). All three are foreign-native features without
    a Mermaid landing slot — closing requires Mermaid payload-model
    surgery and is tracked as deferred follow-on work alongside the D2/DOT
    `slotUnsupported` and `.stateActionDrop` cases.
  - 117 PlantUML tests + 166 round-trip tests pass.
    `Scripts/check-diagnostic-discipline.sh` and
    `Scripts/check-file-sizes.sh` remain green.

## Coverage marker recovery — Wave B (D2 + DOT recovery markers)

- **2026-05-20 — Wave B:** Generalize Wave A's shared `RecoveryMarkerScanner`
  to D2 and DOT. Six export cells flip `⚠ → ✓` in COVERAGE.md:
  `classDiagram × {D2, DOT}`, `stateDiagram × {D2, DOT}`, `erDiagram × {D2, DOT}`.
  - **D2RecoveryMarker** + **DOTRecoveryMarker** with `classStereotype` and
    `erCardinality` Kind cases. `D2ClassExport` / `DOTClassExport` emit
    per-class `# diagramkit:class-stereotype=...` markers and drop the
    `.classStereotypeDrop` diagnostic. `D2ERExport` / `DOTERExport` emit
    per-relationship `# diagramkit:er-cardinality=...` markers and drop both
    `.cardinalityDrop` diagnostics.
  - `D2Importer` / `GraphvizImporter` apply markers post-mapper to recover
    `ClassNode.annotations` and `ErRelationship.relSpec.cardA/cardB`.
  - `stateDiagram × {D2, DOT}` export cells were stale `⚠` — both exporters
    already emit zero diagnostics (`.stateActionDrop` only fires in the
    import-side mapper for foreign-native entry/exit pseudo-states). Plan
    amendment `fe42f44` captured this; state-action recovery is deferred to
    a Future Work item (needs Mermaid payload-model surgery for an action
    slot, which is out of scope per the spec's "Mermaid landing slot"
    exclusion).
  - Round-trip discipline: `D2ClassRoundTripTests`, `DOTClassRoundTripTests`,
    `DOTERRoundTripTests`, and the `RoundTripCrossRegistry` class-pair entries
    drop `.classStereotypeDrop` / `.cardinalityDrop` from their allowed-loss
    sets (markers now close the round-trip lossage). `RoundTripLoss` enum
    cases stay (used by other test infrastructure); category deletion deferred.
  - Pre-existing-failure cleanup: stale "multiple views" Structurizr test
    (Wave 3 closer deleted the diagnostic), `allCases.count == 11`
    RoundTripLossExpectedCategoryTests sweep (now 14), PlantUML probe-order
    bug (sequence input misclassified as use-case when `actor` was present;
    use-case probe tightened, activity probe no longer matches standalone
    `end`), `PlantUMLExporterTests.unsupportedType` (test used `.flowchart`
    which is now exported via activity; switched to `.xyChart`).
  - 166 round-trip tests + 107 PlantUML tests + 100 D2 tests + 90 DOT tests
    pass. `Scripts/check-diagnostic-discipline.sh` and
    `Scripts/check-file-sizes.sh` remain green.

## Coverage marker recovery — Wave A (shared scaffold + matrix reconciliation)

- **2026-05-20 — Wave A:** Generic `RecoveryMarkerScanner<Kind>` +
  `DeclarationIndex` + `HasLineNumber` protocol land in
  `Sources/DiagramKitCommon/RecoveryMarker/`. `StructurizrRecoveryMarker.swift`
  is refit onto the shared scaffold without behavior change (existing
  Structurizr suite stays green). New diagnostic category
  `.recoveryMarkerMalformed` (severity `.warning`) registers in
  `DiagnosticCategory` + `DiagnosticCategoryTests`. Two stale `⚠` matrix
  entries flip to `✓` after corpus verification:
  `classDiagram × PlantUML export` and `architecture × PlantUML export`.
  COVERAGE.md legend gains a footnote distinguishing import-side foreign-
  native losses (deferred) from export-side losses closed by recovery
  markers. Wave A also removes one stale test
  (`StructurizrImporterTests: parse: emits diagnostic for multiple views`)
  that asserted a diagnostic removed by Wave 3 closer (`1dc03750`).
  `Scripts/check-diagnostic-discipline.sh` and
  `Scripts/check-file-sizes.sh` remain green.

## Coverage expansion — Wave 3 (Structurizr)

- **2026-05-19 — Coverage Wave 3 (Structurizr):** Structurizr × c4
  export column moves from `⚠` to `✓`. Comment-encoded recovery via
  `# diagramkit:tag=<tag>` and `# diagramkit:boundary-parent=<label>`
  markers round-trips element-scoped tags and flattened nested-boundary
  parentage losslessly. Two `.lossyTransform(.boundaryFlatten, ...)`
  emissions at the nested-parent flattening and empty-group elision
  sites, plus one `.featureDropped(.diagramFamilyUnsupported, ...)` for
  element-scoped tags, are removed (recovery comments eliminate the
  loss). `StructurizrMapper.map(_:scan:)` now loops over every view in
  the workspace via a private `mapSingleView` helper; first view stays
  the rendered output for back-compat with every existing Structurizr
  snapshot and round-trip. The `"only the first view is imported in
  this release"` placeholder diagnostic is removed. Boundary-parent
  markers encode the parent's *label* (not alias) so cross-format
  imports that derive aliases from labels resolve to the correct
  parent. Two parser-side fixes support the cross-format Mermaid leg:
  (1) `MermaidC4Parser._addBoundary` / `_addDeploymentNode` only push
  lexical scope when the boundary line ends in `{`; flat
  `Boundary(...) $parent=...` lines no longer corrupt downstream
  scope; (2) the `StructurizrMapper` topologically sorts
  c4Boundaries (parents first) and sorts `shapeAliases` /
  `boundaryAliases` so the Mermaid C4 exporter emits boundaries
  parent-first and the view-scope choice is deterministic.
  `diffC4Diagram` now compares `C4Shape.tags` and authored
  `C4Boundary.parentBoundary` (the `global` sentinel is excluded).
  3 new same-format fixtures (`04-tags.dsl`, `05-nested-boundary.dsl`,
  `06-multi-view.dsl`) + 2 new cross-format directed fixtures
  (`cross-{mermaid-structurizr,structurizr-mermaid}-c4/02-boundary.*`).
  Same-format round-trip fixture count grows from 27 to **30**;
  cross-format directed fixture count grows from 38 to **40**
  (19 unordered → 20 unordered). `structurizrC4` cell allow-list
  shrinks from `{.idSanitization, .boundaryFlatten, .c4SlotDrop}` to
  `{.idSanitization, .c4SlotDrop}`. The four cross-cells
  `mermaidStructurizrC4`, `structurizrMermaidC4`, `plantumlStructurizrC4`,
  `structurizrPlantumlC4` each remove `.boundaryFlatten`. Spec
  [docs/superpowers/specs/2026-05-19-coverage-expansion-design.md](docs/superpowers/specs/2026-05-19-coverage-expansion-design.md)
  Wave 3 row is closed.

## Coverage expansion — Wave 2 (D2 + DOT)

- **2026-05-19 — Coverage Wave 2 (D2 + DOT, 3 families each):** D2 and
  DOT import + export columns in [COVERAGE.md](COVERAGE.md) each move
  from 1/28 to **4/28**, picking up `classDiagram`, `stateDiagram`, and
  `erDiagram` in both directions. Each new cell lands at **⚠** with
  typed `.lossyTransform(.<category>, …)` diagnostics. Three new
  `DiagnosticCategory` warning cases — `classStereotypeDrop`,
  `stateActionDrop`, `cardinalityDrop` — and three paired
  `RoundTripLoss` cases with `expectedCategory` entries wire the
  harness pairing. New files: `D2ClassExporter.swift`,
  `D2StateExporter.swift`, `D2ERExporter.swift` plus
  `DOTClassExport.swift`, `DOTStateExport.swift`, `DOTERExport.swift`
  (each carries probe + mapper + exporter). `D2Importer` and
  `GraphvizImporter` dispatch in probe order class → state → ER →
  flowchart. `DOTLexer`'s `\l` escape behavior pushed class/ER
  record-row separators to `\n` (real newline) — see commit log on
  Task 8. `diffErDiagram` now emits `.loss(.cardinalityDrop)` (one per
  side) instead of `.unexpected` for cardinality mismatches, so the
  harness can pair the loss to the exporter's diagnostic by category.
  Same-format round-trip suite grows from 21 to **27** family arms
  (+ d2-class, d2-state, d2-er, dot-class, dot-state, dot-er).
  Cross-format directed-pair count grows from 20 to **38**
  (19 unordered): three families × three unordered pairs ×
  bidirectional = 18 new directed pairs. No corpus growth, no snapshot
  baseline changes. Spec
  [docs/superpowers/specs/2026-05-19-coverage-expansion-design.md](docs/superpowers/specs/2026-05-19-coverage-expansion-design.md).

## Coverage expansion — Wave 1 (PlantUML)

- **2026-05-19 — Coverage Wave 1 (PlantUML, 5 new idioms):** PlantUML
  import + export columns in [COVERAGE.md](COVERAGE.md) move from
  6/28 to **9/28** (the 5 new idioms collapse onto 3 new payload rows
  — flowchart, erDiagram, architecture — because activity+useCase
  share `.flowchart` and object is an alt-idiom on the existing
  `.classDiagram` cell). New PlantUML slices under
  `Sources/DiagramKitPlantUML/{Activity,ER,UseCase,Object,Component}/`
  plus their exporters under `Exporter/`. `PlantUMLFamilyProbe` adds
  5 new probes; `isPlantUMLStateBody` split to remove the activity
  marker overlap. Same-format round-trip suite gains 5 new arms
  (plantuml-activity, plantuml-er, plantuml-usecase, plantuml-object,
  plantuml-component) and grows from 16 to 21 same-format fixtures.
  Cross-format Mermaid ↔ PlantUML for ER + flowchart adds 4 directed
  pairs, growing the cross-format directed-pair count from 16 to 20
  (10 unordered). Architecture and alt-idiom cross-format pairs
  remain deferred — they require new RoundTripLoss kinds outside
  Wave 1's "no new categories" constraint. Spec
  [docs/superpowers/specs/2026-05-19-coverage-expansion-design.md](docs/superpowers/specs/2026-05-19-coverage-expansion-design.md).

For the closed Critical-finding/commit map, the 2026-05-14 rebaseline
event log, and the post-remediation feature-work table, see
[docs/archive/BASELINES-history.md](docs/archive/BASELINES-history.md).

## Build

- `swift build --build-tests`: ~22–27s on a MacBook Pro M4 (24 GB)
  after the Phase 4 target split. Steady-state incremental builds are
  still sub-2s. `Scripts/strict-concurrency-check.sh`: clean.

## Tests

- Test source files: 298 Swift files under `Tests/DiagramKitTests`
  (300 total: 298 + 2 in `Tests/DiagramKitLinuxTests`). The 15-file XCUI
  bundle that previously lived alongside the sample was removed on
  2026-05-18 when the sample relocated to `Sources/DiagramKitSample/`.
- `swift test` excluding corpus snapshots: ~30s.
- `swift test --filter CorpusSnapshotTests`: ~5 min; use chunked
  execution for recording. The known signal-10 hang on a full corpus
  run is unchanged from `main`.
- `swift test --filter CorpusMultiFormatSnapshotTests`: ~0.15s
  (426 test cases per test).

## Corpus

- `Sources/DiagramKitSample/Resources/test-diagrams.json`:
  **426 entries** (397 Mermaid-only + 29 multi-format: D2, DOT,
  Structurizr, PlantUML).
- Multi-format entries carry `sources`, `expectedImporters`, and
  (where needed) `skipSnapshots`.
- Non-Mermaid Structurizr and PlantUML snapshots are skipped due to
  non-deterministic rendering.
- Chunked execution via `SNAPSHOT_DIAGRAM_IDS` avoids the signal-10
  hang in the parameterized suite.

## Snapshot baselines

`swift-snapshot-testing` stores SVG and ASCII snapshots with a `.txt`
extension; image snapshots are `.png`. The split below is by snapshot
*kind*, not file extension.

- SVG: **439** (426 Mermaid corpus + 13 multi-format).
- Image: **439** (426 Mermaid corpus + 13 multi-format).
- ASCII: **426** (one per corpus entry — Phases 7–11 added renderers
  for the remaining 23 families).
- Total tracked corpus baselines: **1,304** files
  (439 PNG + 865 `.txt`).

## Gate status

- `swift build --build-tests`: pass (2026-05-15).
- `Scripts/check-file-sizes.sh`: pass — warning-only surface, no
  1000-line errors. 55 files over the 500-line warning threshold;
  9 files over the 1000-line hard limit are allowlisted in
  `Scripts/check-file-sizes-allowlist.txt`.
- `Scripts/check-sendable-annotations.sh`: pass — 12 yellow allowlist
  entries remaining (sunset `2027-06-30`).
- `Scripts/strict-concurrency-check.sh`: pass.
- `Scripts/linux-check.sh`: skips as an environment condition when
  Docker/Podman is missing or installed but not usable. CI honors
  `SKIP_LINUX_CHECK=1`.
- `Scripts/bootstrap-smoke-check.sh`: aggregating gates pass; Xcode
  platform builds are skipped in the headless workspace and recorded
  as environment skips by `run_build`.

## Mermaid exporter coverage

- **2026-05-19 — Wave 3 (3 families, closing wave):** Mermaid Export
  column moves from 25/28 to 28/28. New exporters: `block`,
  `architecture`, `wardleyBeta`. `block` reuses Wave 1's
  `emitIndentedTree` (5th caller after mindmap, treemap, treeView,
  ishikawa); `architecture` and `wardleyBeta` emit linearly with no
  helper reuse. 6 new round-trip fixture files under
  `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`. Same-format
  round-trip suite grows from 34 to 37 family arms. The
  `MermaidExporter.export(_:)` switch is now **exhaustive at 28/28**;
  the `default: .unsupportedDiagram` fall-through is removed. The
  Swift compiler's exhaustiveness check is the compile-time
  invariant. `CorpusRoundTripTests` passes for every Mermaid corpus
  entry in the now-fully-supported set with no additions to
  `knownFailures`. Spec
  [docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md](docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md)
  is closed.
- **2026-05-19 — Wave 2 (9 families):** Mermaid Export column moves
  from 16/28 to 25/28. New exporters: `xyChart`, `quadrantChart`,
  `requirement`, `radar`, `venn`, `ishikawa`, `treeView`, `zenuml`,
  `eventModeling`. `ishikawa` and `treeView` reuse Wave 1's
  `emitIndentedTree`; no new helpers were extracted. 18 new
  round-trip fixture files under
  `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`. Same-format
  round-trip suite grows from 25 to 34 family arms. The
  `CorpusRoundTripTests` suite passes for every Mermaid corpus entry
  in the post-Wave-2 supported set with no additions to
  `knownFailures`. The `default: .unsupportedDiagram` arm in
  `MermaidExporter.export(_:)` stays for Wave 3.
- **2026-05-19 — Wave 1 (9 families):** Mermaid Export column in
  [COVERAGE.md](COVERAGE.md) moves from 7/28 to 16/28. New
  exporters: `pie`, `sankey`, `packet`, `journey`, `timeline`,
  `kanban`, `mindmap`, `treemap`, `gitGraph`. Shared scaffolding
  additions: `MermaidExportHelpers.emitSectionedItems` (used by
  journey + timeline) and `MermaidExportHelpers.emitIndentedTree`
  (used by mindmap + treemap). 18 new round-trip fixture files
  under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.
  Same-format round-trip suite grows from 16 to 25 family arms.
  New `CorpusRoundTripTests` walks every Mermaid corpus entry in
  the supported set through `parse → export → parse →
  assertStructurallyEqual`; pre-existing exporter divergences in
  non-Wave-1 families (flowchart, state, sequence, class, ER) are
  tracked in `CorpusRoundTripTests.knownFailures` for drain via
  later waves. Wave 2 (`xyChart`, `quadrantChart`, `requirement`,
  `radar`, `venn`, `ishikawa`, `zenuml`, `treeView`,
  `eventModeling`) and Wave 3 (`block`, `architecture`,
  `wardleyBeta`) plans land in
  `docs/superpowers/plans/`.

## Open deferrals

- **EventModeling tests** — `EventModelingTests.swift` remains a
  single monolithic XCTest file. Splitting per-concern (parser /
  layout / renderer / corpus fixture) is a separate scoped phase.
  Documented at the suite level so it stays discoverable.
- **`DiagramLayer.commonInit()` → `@MainActor`** — blocked on
  dropping `@preconcurrency QuartzCore`; documented in source.

## Merge-gate caveats

- `Scripts/bootstrap-smoke-check.sh` no longer fails fast: every
  governance script and platform build runs, failures aggregate, and
  the script exits non-zero only if at least one gate reported
  failure. The complete failure surface is visible in a single local
  invocation.
- `Scripts/linux-check.sh` is environment-aware: if neither `docker`
  nor `podman` is on `PATH`, if the selected runtime is installed but
  not usable, or if `SKIP_LINUX_CHECK=1` is set, it exits 0 with a
  notice. Real container build/run failures still exit non-zero.
- `swift test` still hits the documented signal-10 hang on a full
  corpus run; chunked execution via `SNAPSHOT_DIAGRAM_IDS` remains
  the recommended workflow for recording or verifying snapshots.

## Continuous integration

`.github/workflows/ci.yml` runs every PR on a macOS runner: package
dump, build, test, the three governance scripts, and
`linux-check.sh` with `SKIP_LINUX_CHECK=1` (the macOS runner image
does not ship a container runtime). The local merge gate adds the
Xcode platform sweep and a real `linux-check.sh` against the
maintainer's installed runtime.

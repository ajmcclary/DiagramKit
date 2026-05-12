# DiagramKit Multi-Format Roadmap

This is the active execution roadmap. `ANALYSIS.md` is the long-form rationale.
Detailed phase records live in `PHASE-0.md`, `PHASE-1.md`, `PHASE-2.md`,
`PHASE-3.md`, and `PHASE-4.md`.

## Current State

Phases 0, 1, 2, 3, and 4 are implemented locally. Phase 4 has post-review
remediation in this worktree: compact DOT headers probe correctly, quoted
comment markers survive lexing, chained DOT edges stay in their local subgraph
scope, DOT port syntax and edges to subgraphs emit diagnostics, later explicit
node statements update edge-synthesized nodes, and the DOT parser/mapper are
split below the file-size warning threshold.

Commit the Phase 4 remediation before starting Phase 5.

What is true now:

- Public, format-neutral names are primary: `DiagramEngine`,
  `DiagramPipeline`, `DiagramImageRenderer`, `DiagramDocument`,
  `DiagramError`, `DiagramStructuralError`, `DiagramView`,
  `DiagramNativeView`, `DiagramLayer`, and `DiagramViewModel`.
- Mermaid-prefixed compatibility aliases and wrappers remain deprecated for
  downstream users.
- `String` has primary format-neutral helpers:
  `parseDiagram()`, `renderDiagramImage(...)`, `renderDiagramSVG(...)`, and
  `renderDiagramASCII(...)`.
- `DiagramKitImport` is the source-format import boundary target. It owns
  `DiagramSourceImporter`, `DiagramImportResult`, `DiagramDiagnostic`,
  `ImporterRegistry`, and `DiagramLoader`.
- `DiagramKitD2` is the first non-Mermaid importer target. It parses a narrow
  D2 vertical slice and maps it to `DiagramPayload.flowchart`.
- `DiagramKitGraphviz` is the second non-Mermaid importer target. It parses a
  narrow Graphviz DOT vertical slice and maps it to
  `DiagramPayload.flowchart`.
- `MermaidImporter` remains the broad fallback importer and must stay last in
  the default registry.
- `DiagramPipeline.defaultRegistry` is currently ordered as
  `[GraphvizImporter(), D2Importer(), MermaidImporter()]`: narrow DOT and D2
  probes first, broad Mermaid fallback last.
- Source-taking `DiagramPipeline` paths for parse, layout, prepare, and primary
  SVG rendering load through `DiagramLoader` by default. Graph/positioned paths
  remain format-agnostic and consume `DiagramDocument`/`PositionedGraph`.
- Source-taking ASCII rendering is still Mermaid-specific. Do not treat
  `DiagramPipeline.renderASCII(source:)` as part of the generic importer
  boundary until it is deliberately migrated.
- `DiagramRegistry`, `DiagramDescriptor`, and `DiagramHeader` remain public
  Mermaid-family routing types for compatibility. They are documented as
  Mermaid-specific, not the multi-format import registry.
- `DiagramKitTestSupport.CorpusEntry` is the canonical test-side corpus decoder.
  It decodes legacy Mermaid-only entries and future multi-format entries while
  preserving `entry.source` as the Mermaid source.
- Corpus format metadata uses canonical lowercase format IDs such as `mermaid`,
  `d2`, `graphviz`, `plantuml`, and `structurizr`; importer names remain
  display values such as `Mermaid` and `D2`.
- The real corpus file is still Mermaid-only. Multi-format examples live as
  inline fixtures with `skipSnapshots` until the final baseline pass, unless a
  future phase explicitly calls for a controlled corpus update.
- DOT inline corpus fixtures exist for the supported vertical slice. They do
  not add real corpus entries or snapshot baselines.
- Snapshot baselines currently include 396 SVG, 396 image, and 174 ASCII files.
  Snapshot recording is deferred until the final baseline pass unless a phase is
  explicitly about intentional renderer baseline changes.
- `BASELINES.md` exists and should be kept current when gate status, corpus
  counts, or baseline counts change.
- `Scripts/linux-check.sh` is Docker/Podman-dependent. If the daemon is not
  running locally, record it as skipped due to environment rather than treating
  it as a source failure.

## Operating Principles

- Do not start Phase 5 until Phase 4 remediation is committed.
- Keep source import separate from diagram-family layout. Importers produce
  `DiagramDocument`; they do not layout or render.
- Preserve the worker-thread invariant: every public async facade path still
  uses a fresh 8 MB-stack worker thread.
- Preserve font determinism: `DiagramFontRegistry.registerBundledFontsIfNeeded()`
  must run before rendering-related pipeline work.
- Keep `DiagramDocument -> PositionedGraph -> render` independent of source
  format. Layout must not care whether the document came from Mermaid, D2, DOT,
  Structurizr, or PlantUML.
- Probe order is contractual. Narrow/specific importers are prepended before
  broader fallbacks. Mermaid stays last.
- Unsupported format features must produce diagnostics. No silent partial
  imports and no empty successful conversions.
- Land each new format as a vertical slice with parser tests, probe collision
  tests, inline corpus fixtures, diagnostics tests, and at least one
  parse-to-layout/render smoke path through existing infrastructure.
- Keep real `test-diagrams.json` entries Mermaid-only until the final snapshot
  pass unless a phase explicitly opts into controlled baseline churn.
- Expect snapshot drift during the phased import and renderer-improvement work.
  Review diffs for mechanical regressions now, but defer baseline recording to
  the final snapshot pass unless a phase explicitly says otherwise.
- Keep new and touched files below the 500-line warning threshold. Split tests
  by concern before they become new file-size warnings.

## Verification Policy

Use the smallest relevant test while iterating. Before closing a phase, run:

```bash
swift package dump-package
swift build --build-tests
swift test --filter <phase-specific suites>
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
git diff --check
```

`Scripts/check-file-sizes.sh` may report pre-existing warnings while still
exiting successfully. A phase should not add new warnings in touched files.

Run `Scripts/linux-check.sh` and the full `Scripts/bootstrap-smoke-check.sh`
before merge readiness when Docker/Podman and Xcode runtimes are available. If
Docker/Podman is unavailable locally, record Linux as skipped due to
environment; do not block local phase remediation on it.

Snapshot policy:

- Run targeted `CorpusSnapshotTests` subsets when a change could affect parsing,
  layout, or rendering.
- Do not record snapshots during Phase 1-6 unless the phase explicitly includes
  an intentional rendering-baseline update.
- Treat crashes, 0x0 layout regressions, missing outputs, importer
  misrouting, and unexpected snapshot deletions as blockers.
- Treat known visual improvements as reviewed drift and save baseline recording
  for the final snapshot pass.

## Phase 0: Naming Stabilization

Goal: make the public surface format-neutral without changing behavior.

Status: complete and committed.

Completed:

- Introduced format-neutral public names.
- Kept Mermaid-prefixed compatibility aliases/wrappers deprecated.
- Updated string helpers to format-neutral names.
- Created `BASELINES.md`.
- Deferred Mermaid-family registry ownership to Phase 1.

Closure evidence lives in `PHASE-0.md`.

## Phase 1: Importer Boundary And Mermaid Extraction

Goal: split source-format import from diagram-family layout while preserving
Mermaid behavior.

Status: complete and committed locally.

Completed:

- New `DiagramKitImport` target.
- `DiagramSourceImporter`, `DiagramImportResult`, `DiagramDiagnostic`,
  `ImporterRegistry`, and `DiagramLoader`.
- `ImporterRegistry.prepending(_:)` puts future narrow importers before broader
  fallbacks.
- `MermaidImporter` wraps the current Mermaid-family registry dispatch and is
  the explicit fallback importer.
- Source-taking parse/layout/prepare/primary SVG paths use the loader-backed
  import boundary.
- Graph/positioned paths remain format-agnostic.
- `DiagramRegistry` remains public and Mermaid-family-specific for
  compatibility.
- `DiagramError` remains in `DiagramKitModel`; `DiagramStructuralError` remains
  where existing render/layout code can use it without forcing a larger move.

Closure evidence lives in `PHASE-1.md`.

## Phase 2: Multi-Format Corpus Foundation

Goal: make the corpus capable of hosting multiple source formats before the
second importer lands.

Status: complete and committed locally.

Completed:

- `CorpusEntry` type in `DiagramKitTestSupport` with multi-format decoding,
  format helpers, and validation.
- `CorpusFile` container decodes `test-diagrams.json` including optional
  `version`/`description`; ignores `metadata`.
- `ExpectedDiagnostic` and `CorpusEntryError` for fixture metadata.
- Mismatch detection: decoder throws `CorpusEntryError.sourceMermaidMismatch`
  when `source` and `sources["mermaid"]` differ.
- `sources` maps must include a `mermaid` key when present. Omitting it is a
  schema error, not a fallback path.
- Format IDs in `sources`, `expectedImporters`, and `skipSnapshots` normalize to
  lowercase during decoding.
- `CorpusSnapshotTests` uses `CorpusEntry`/`CorpusFile` from
  `DiagramKitTestSupport`; calls `validate()` on all entries.
- Playground corpus decoding mirrors the test-support schema invariants.
- Real `test-diagrams.json` is untouched. All 396 entries remain Mermaid-only,
  decode correctly, and pass `validate()`.
- Snapshot names unchanged. No baselines re-recorded.

Closure evidence lives in `PHASE-2.md`.

## Phase 3: D2 Importer Vertical Slice

Goal: prove the importer architecture with the highest-ROI non-Mermaid format.

Status: complete and committed locally.

Completed:

- Added `DiagramKitD2` as a separate importer target and product.
- Added `D2Importer`, `D2Parser`, `D2AST`, `D2Mapper`, `D2Probe`, and
  `D2Shapes`.
- Prepended `D2Importer()` before `MermaidImporter()` in
  `DiagramPipeline.defaultRegistry`.
- Parsed the first D2 slice: nodes, edges, labels, containers, top-level
  direction, simple shape hints, comments, and `:`/`=` separators.
- Mapped D2 to `DiagramPayload.flowchart`, reusing existing flowchart layout and
  SVG/CG render paths.
- Kept top-level `direction` as an AST directive, not a synthetic node.
- Merged D2 property statements into existing nodes and synthesized edge-only
  endpoint nodes.
- Emitted diagnostics for unsupported D2 constructs.
- Added D2 parser/importer/probe/fixture/registry coverage.
- Kept real `test-diagrams.json`, `CorpusSnapshotTests.swift`, and snapshot
  baselines unchanged.

Deferred from Phase 3:

- Full D2 styling parity.
- D2 layout engine parity (`near`, grid, constraints, fixed positions).
- Non-flowchart mappings.
- Exporting D2.
- Real multi-format corpus entries and D2 snapshot baselines.

Closure evidence lives in `PHASE-3.md`.

## Phase 4: DOT Importer Vertical Slice

Goal: add Graphviz DOT as the next focused graph-language importer.

Status: complete locally; post-review remediation is in this worktree and
should be committed before Phase 5.

Completed:

- Added `DiagramKitGraphviz` as a separate importer target and product.
- Added `GraphvizImporter`, `DOTLexer`, `DOTParser`, `DOTAST`, `DOTMapper`,
  `DOTProbe`, and focused parser/mapper helper files.
- Prepended `GraphvizImporter()` before `D2Importer()` and `MermaidImporter()`
  in `DiagramPipeline.defaultRegistry`.
- Added a narrow DOT probe that requires `graph`, `digraph`, or `strict graph`
  / `strict digraph` structure, including compact headers such as
  `digraph{A->B}`.
- Parsed the first DOT slice: graph/digraph headers, optional strict mode,
  node statements, node labels, directed and undirected edges, chained edges,
  simple attribute lists, graph attributes, and `subgraph cluster_*`
  containers.
- Mapped DOT to `DiagramPayload.flowchart`, reusing the existing flowchart
  layout and SVG/CG render paths.
- Applied scoped node defaults and merged later explicit node statements into
  existing or edge-synthesized nodes.
- Kept chained edge segments inside the statement list where they are parsed,
  so cluster membership remains correct.
- Preserved `//`, `#`, and `/* ... */` markers inside quoted strings while
  still stripping real comments.
- Emitted diagnostics for unsupported DOT attributes, strict mode, port syntax,
  and edges to subgraphs.
- Added DOT parser/importer/probe/fixture/registry coverage and parse-to-layout
  smoke tests.
- Kept real `test-diagrams.json` and snapshot baselines unchanged.
- Kept new/touched DOT source files below the 500-line warning threshold by
  splitting parser and mapper helpers.

Deferred from Phase 4:

- Full DOT grammar coverage, including HTML-like labels, record layouts, edge
  labels on every chained segment, compound edges, and subgraph edge semantics.
- Graphviz layout parity.
- DOT-specific styling beyond current flowchart shape/label mapping.
- Exporting DOT.
- Real multi-format corpus entries and DOT snapshot baselines.

Closure evidence lives in `PHASE-4.md`. Post-review remediation evidence is in
the current worktree until committed.

## Phase 5: Structurizr Importer Vertical Slice

Goal: support the C4-shaped subset where Structurizr maps cleanly to current
DiagramKit models.

Approach:

- Write `PHASE-5.md` before implementation and review it before code changes.
- Add `DiagramKitStructurizr` as a separate importer target and product.
- Keep the probe narrow around `workspace` and Structurizr DSL structure.
- Prepend `StructurizrImporter()` before existing importers once the probe is
  proven collision-safe.
- Focus on workspace/model/view slices that map to existing C4 payloads.
- Keep DSL sections that do not map cleanly as explicit diagnostics.
- Do not build a complete Structurizr runtime.
- Keep fixtures inline with `skipSnapshots`; defer real corpus entries and
  baselines.

Tests:

- Structurizr parser and importer tests for the supported workspace/view slice.
- C4 mapping tests that prove the importer produces the expected payload.
- Probe collision tests against Mermaid, D2, DOT, and PlantUML.
- Diagnostics tests for unsupported workspace sections.

## Phase 6: PlantUML In Vertical Slices

Goal: support useful PlantUML subsets without attempting a full PlantUML clone.

Approach:

- Write a separate plan for each PlantUML family slice.
- Add `DiagramKitPlantUML` only when the first family plan is accepted.
- Keep the outer probe narrow around `@startuml`/`@enduml`; route inside the
  target by supported family.
- Treat each family as independently shippable. Do not block earlier families
  on later grammar coverage.
- Every unsupported syntax branch emits a diagnostic.
- Keep fixtures inline with `skipSnapshots`; defer real corpus entries and
  baselines.

Order:

1. Sequence diagrams.
2. Class diagrams.
3. State/activity diagrams.
4. Mindmap and Gantt.
5. C4-flavored PlantUML.

Tests:

- One parser/importer suite per PlantUML family slice.
- Probe collision tests for `@startuml` plus family-specific headers.
- Corpus fixtures only for the families implemented in that slice.
- Existing Mermaid, D2, DOT, and Structurizr routing regressions.

## Phase 7: Exporter Protocol

Goal: add source generation after multiple importers prove the canonical model.

Approach:

- Add `DiagramExporter`, `DiagramExportResult`, and exporter diagnostics.
- Add sparse conversion-matrix tests.
- Add exporters in this order:
  1. Mermaid
  2. D2
  3. Structurizr/C4
  4. PlantUML subsets
- Add round-trip tests:
  `parse(formatA) -> export(formatB) -> parse(formatB) -> export(formatB)`.

Rules:

- Supported conversion emits source.
- Unsupported conversion emits diagnostics.
- No conversion silently produces empty output.
- Exporters do not patch source strings by hand for editor sync; they operate
  from `DiagramDocument`.

## Phase 8: Interactivity Primitives

Goal: expose stable identity and geometry without building a full editor.

Approach:

- Add stable semantic IDs for nodes, edges, groups, and diagram-specific items.
- Add `DiagramSelection`.
- Add `DiagramBoundsLookup`.
- Attach lookup data to `PreparedDiagram`.
- Consider portable geometry types in `DiagramKitCommon` if `CGRect` would leak
  Apple-only types into format-neutral surfaces.

Start with flowchart, state, class, sequence, and ER, then fill in the long
tail.

## Phase 9: Optional Interactive Model

Goal: provide editor primitives only after import/export and stable geometry are
settled.

Approach:

- Add a `DiagramKitInteractive` target if real consumers need it.
- Introduce a `@MainActor` editor model with selection state, undo, and typed
  mutations.
- Keep turnkey editor UI out of the first cut. Ship primitives first.
- Source sync should go through exporters, not hand-written string patches.

## Phase 10: Release And Deprecation Cleanup

Goal: reduce compatibility surface after the new architecture has lived through
at least one release cycle.

Approach:

- Decide which Mermaid-prefixed aliases stay indefinitely and which get removed.
- Rename remaining files whose filenames materially confuse ownership.
- Move approved inline multi-format fixtures into the real corpus.
- Run full corpus snapshots, review accumulated drift, and record only
  intentional baselines.
- Update README, ARCHITECTURE, CLAUDE, AGENTS, CONTRIBUTING, and BASELINES.
- Run the full gate in an environment with Docker/Podman and Xcode runtimes:
  `Scripts/bootstrap-smoke-check.sh`.

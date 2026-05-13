# DiagramKit Multi-Format Roadmap

This is the active execution roadmap. `ANALYSIS.md` is the long-form rationale.
Detailed phase records live in `PHASE-0.md`, `PHASE-1.md`, `PHASE-2.md`,
`PHASE-3.md`, `PHASE-4.md`, `PHASE-5.md`, `PHASE-6.md`, `PHASE-7.md`, and
`PHASE-8.md`.

## Current State

Phases 0, 1, 2, 3, 4, 5, 6A, 7, and 8 are implemented. The remaining Phase 6
work is the planned PlantUML family slices: class, state/activity,
mindmap+gantt, and C4-flavored PlantUML.

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
- `DiagramKitStructurizr` is the third non-Mermaid importer target. It parses a
  narrow Structurizr DSL vertical slice and maps it to
  `DiagramPayload.c4(C4Diagram)`.
- `DiagramKitPlantUML` is the fourth non-Mermaid importer target. Slice 6A
  parses PlantUML sequence diagrams and maps them to
  `DiagramPayload.sequenceDiagram`.
- `DiagramKitExport` is the source-format export boundary target. It owns
  `DiagramFormatID`, `DiagramExporter`, `DiagramExportResult`,
  `DiagramExportError`, `ExporterRegistry`, and `DiagramExportLoader`.
- `DiagramPipeline.defaultExportRegistry` is keyed by canonical format ID and
  currently registers Mermaid, D2, Structurizr, and PlantUML exporters.
- Exporter support is intentionally sparse and importer-gated: Mermaid exports
  flowchart, sequence, class, ER, and C4; D2 exports flowchart; Structurizr
  exports C4; PlantUML exports sequence only until later PlantUML importer
  slices land.
- Phase 8 interactivity primitives are in place. `DiagramKitCommon` owns
  portable `DiagramPoint`, `DiagramSize`, and `DiagramRect`; `DiagramKitModel`
  owns `DiagramStableElement`, `DiagramSelection`, and `DiagramBoundsLookup`.
- `PositionedGraph.lookup` is an eager computed lookup derived from positioned
  content. It does not cache and does not change `PreparedDiagram`.
- Lookup coverage includes the priority families plus broad long-tail coverage:
  flowchart, state, sequence, class, ER, C4, xyChart, journey, gantt,
  quadrantChart, requirement, gitGraph, mindmap, timeline, sankey, block,
  packet, kanban, architecture, treemap, ishikawa, treeView, eventModeling,
  wardleyBeta, and ZenUML. Pie, radar, and venn currently return empty lookups
  because their positioned geometry needs a deliberate hit-area design.
- Hit-testing precedence is explicit: highest element kind priority wins, then
  draw order, then smallest area. This keeps nodes above containing groups even
  when builders append groups later.
- Flowchart and state diagrams share positioned payloads, but lookup selections
  preserve the correct `DiagramType` (`.flowchart` vs `.stateDiagram`).
- Stable IDs must remain source/model-derived, not layout-coordinate-derived.
  Current regression coverage locks this down for the reviewed XY chart and
  ZenUML cases.
- `MermaidImporter` remains the broad fallback importer and must stay last in
  the default registry.
- `DiagramPipeline.defaultRegistry` is currently ordered as
  `[StructurizrImporter(), PlantUMLImporter(), GraphvizImporter(), D2Importer(), MermaidImporter()]`:
  narrow Structurizr and PlantUML probes first, then DOT and D2, with broad
  Mermaid fallback last.
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
- Structurizr inline corpus fixtures exist for the supported C4 slice. They
  parse fixture sources through `StructurizrImporter`, inspect the resulting
  `C4Diagram`, and remain marked `skipSnapshots`.
- PlantUML sequence fixtures exist as inline tests. They parse through
  `PlantUMLImporter`, inspect the resulting `SequenceDiagram`, and do not add
  real corpus entries or snapshot baselines.
- Snapshot baselines currently include 396 SVG, 396 image, and 174 ASCII files.
  Snapshot recording is deferred until the final baseline pass unless a phase is
  explicitly about intentional renderer baseline changes.
- `BASELINES.md` exists and should be kept current when gate status, corpus
  counts, or baseline counts change.
- `Scripts/linux-check.sh` is Docker/Podman-dependent. If the daemon is not
  running locally, record it as skipped due to environment rather than treating
  it as a source failure.

## Operating Principles

- Continue Phase 6 family-by-family. Slice 6A is the infrastructure and
  sequence-diagram baseline; do not let later PlantUML slices destabilize it.
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
- Exporter `supportedDiagramTypes` must stay a subset of the same-format
  importer coverage. Experimental source generation can exist internally, but
  the public exporter must not claim output that cannot be re-ingested.
- Exported source should have parser-facing tests, not only header/substr
  smoke tests. Each exporter slice needs at least one validity or round-trip
  test through the matching importer.
- Land each new format as a vertical slice with parser tests, probe collision
  tests, inline corpus fixtures, diagnostics tests, and at least one
  parse-to-layout/render smoke path through existing infrastructure.
- Keep real `test-diagrams.json` entries Mermaid-only until the final snapshot
  pass unless a phase explicitly opts into controlled baseline churn.
- Expect snapshot drift during the phased import and renderer-improvement work.
  Review diffs for mechanical regressions now, but defer baseline recording to
  the final snapshot pass unless a phase explicitly says otherwise.
- Keep new and touched files below the 500-line warning threshold when
  practical. Known warning files must stay below the 1000-line error threshold,
  and future additions should split them before they grow further.

## Approach Going Forward

1. Treat Phase 8 as the stable identity/geometry baseline. Future interaction
   work should build on `DiagramSelection` and `DiagramBoundsLookup`, not new
   ad hoc hit-testing surfaces.
2. Backfill interactivity tests toward the full planned suite before adding an
   editor model. The immediate guardrail is focused regression coverage for
   diagram type preservation, hit-test priority, and layout-independent IDs.
3. Continue PlantUML 6B-6E as independent importer/exporter expansion tracks.
   A PlantUML family becomes publicly exportable only after the same-format
   importer can parse it.
4. Treat Phase 9 as optional consumer-driven work: selection state, undo, and
   typed mutations should land only after there is a concrete editor need.
5. Keep Graphviz/DOT export and long-tail Mermaid export as later exporter
   extensions that reuse the Phase 7 export boundary.
6. Save real multi-format corpus entries, snapshot recording, and accumulated
   visual drift cleanup for the final release/baseline pass.

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
- Do not record snapshots during the phased import/export/interactivity work
  unless the phase explicitly includes an intentional rendering-baseline update.
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

Status: complete and committed locally.

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

Closure evidence lives in `PHASE-4.md`.

## Phase 5: Structurizr Importer Vertical Slice

Goal: support the C4-shaped subset where Structurizr maps cleanly to current
DiagramKit models.

Status: complete and committed locally.

Completed:

- Added `DiagramKitStructurizr` as a separate importer target and product.
- Added `StructurizrImporter`, `StructurizrLexer`, `StructurizrParser`,
  `StructurizrParserState`, `StructurizrAST`, `StructurizrModelRegistry`,
  `StructurizrMapper`, and `StructurizrProbe`.
- Prepended `StructurizrImporter()` before Graphviz, D2, and Mermaid in
  `DiagramPipeline.defaultRegistry`.
- Parsed the first Structurizr slice: `workspace`, `model`, `views`, `person`,
  `softwareSystem`, `container`, `component`, `deploymentNode` diagnostics,
  explicit relationships, scoped relationships, `include *`, explicit
  includes, comments, optional workspace/view strings, and narrow unsupported
  statement diagnostics.
- Mapped Structurizr to `DiagramPayload.c4(C4Diagram)`, reusing existing C4
  layout and SVG/CG render paths.
- Created real `C4Boundary` entries for container/component view scopes instead
  of relying on `parentBoundary` alone.
- Preserved C4 element description/technology order and relationship label,
  technology, and description fields.
- Emitted diagnostics for dynamic/deployment views, deployment nodes,
  directives, tags, view excludes, unknown view statements, and missing
  scope/include aliases.
- Kept deployment nodes diagnostic-only with no fallback rendered shape.
- Added lexer/parser/registry/importer/probe/fixture/regression/layout smoke
  coverage. The focused Structurizr suite is 96 tests in 10 suites.
- Kept real `test-diagrams.json`, `CorpusSnapshotTests.swift`, and snapshot
  baselines unchanged.
- Kept new/touched Phase 5 source and test files below the 500-line warning
  threshold.

Deferred from Phase 5:

- Full Structurizr DSL coverage, including deployment instances, dynamic and
  deployment views, multiple diagrams per workspace, tags/styles/themes,
  properties, `!include` resolution, implied relationships, groups, URLs, and
  plugin/script/ref/extend directives.
- Structurizr-specific layout parity beyond the current C4 layout.
- Exporting Structurizr.
- Real multi-format corpus entries and Structurizr snapshot baselines.

Closure evidence lives in `PHASE-5.md`.

## Phase 6: PlantUML In Vertical Slices

Goal: support useful PlantUML subsets without attempting a full PlantUML clone.

Status: in progress. Slice 6A is complete locally with post-review remediation
in this worktree. Slice 6B, PlantUML class diagrams, is next.

Approach:

- Use `PHASE-6.md` as the canonical PlantUML plan and status table.
- Keep `DiagramKitPlantUML` as a separate importer target.
- Keep the outer probe narrow around valid `@start...`/`@end...` blocks; route
  inside the target by supported family.
- Treat each family as independently shippable. Do not block earlier families
  on later grammar coverage.
- Every unsupported syntax branch emits a diagnostic.
- Keep fixtures inline with `skipSnapshots`; defer real corpus entries and
  baselines.

Completed in 6A:

- Added `DiagramKitPlantUML` as a separate importer target and product.
- Added PlantUML outer probing, family probing, diagnostics, and sequence
  parser/mapper/probe files.
- Inserted `PlantUMLImporter()` between `StructurizrImporter()` and
  `GraphvizImporter()` in `DiagramPipeline.defaultRegistry`.
- Parsed the first PlantUML sequence slice: participants, actors, aliases,
  display names, six arrow variants plus reverse direction, message labels,
  self-messages, explicit and bare activations, notes, groups, boxes,
  autonumber start/stop, and `return`.
- Mapped PlantUML sequence diagrams to `DiagramPayload.sequenceDiagram`, using
  real `SequenceItem` cases including `boxStart`/`boxEnd`,
  `activationStart`/`activationEnd`, `blockStart`/`blockDivider`/`blockEnd`,
  and `autonumberEvent`.
- Fixed post-review gaps: boxes now produce `SequenceBox` output, `return`
  emits a dotted reverse message with deactivation, bare activation commands use
  previous-message context, PlantUML probes no longer reject valid labels that
  contain other-format keywords, registry order tests include PlantUML, and the
  sequence tests are split below the 500-line warning threshold.
- Added 55 PlantUML sequence tests across parser, mapper, and integration
  suites, plus registry and probe collision coverage.
- Kept real `test-diagrams.json`, `CorpusSnapshotTests.swift`, and snapshot
  baselines unchanged.

Order:

1. Sequence diagrams. Complete in 6A.
2. Class diagrams. Next.
3. State/activity diagrams.
4. Mindmap and Gantt.
5. C4-flavored PlantUML.

Tests:

- Split tests by concern before any new file crosses the 500-line warning
  threshold.
- One parser/importer suite group per PlantUML family slice.
- Probe collision tests for `@startuml` plus family-specific headers.
- Corpus fixtures only for the families implemented in that slice.
- Existing Mermaid, D2, DOT, Structurizr, and registry routing regressions.

## Phase 7: Exporter Protocol

Goal: add source generation after multiple importers prove the canonical model.

Status: complete and committed locally.

Completed:

- Added `DiagramKitExport` as the export boundary target and product.
- Added `DiagramFormatID`, `DiagramExporter`, `DiagramExportResult`,
  `DiagramExportError`, `ExporterRegistry`, and `DiagramExportLoader`.
- Wired `DiagramPipeline.defaultExportRegistry` and re-exported
  `DiagramKitExport` through the umbrella target.
- Added Mermaid export for the first high-value families: flowchart, sequence,
  class, ER, and C4.
- Added D2 export for flowchart.
- Added Structurizr export for C4.
- Added PlantUML export for sequence diagrams only, matching current
  `PlantUMLImporter` coverage.
- Added sparse conversion-matrix tests and no-silent-empty-output tests.
- Added source-validity and round-trip coverage for the remediated exporter
  syntax paths: Mermaid flowchart labels, Mermaid sequence labels/notes,
  PlantUML sequence aliases/notes, D2 quoted labels, and Structurizr quoted
  strings.

Rules:

- Supported conversion emits source.
- Unsupported conversion emits diagnostics.
- No conversion silently produces empty output.
- Exporters do not patch source strings by hand for editor sync; they operate
  from `DiagramDocument`.
- `supportedDiagramTypes` must not get ahead of importer coverage. PlantUML C4
  remains deferred until the PlantUML C4 importer slice can parse the emitted
  source or a separate cross-format exporter contract is introduced.

Deferred:

- Graphviz/DOT export.
- Exporting the long tail of Mermaid families beyond the current P0 set.
- PlantUML class, state/activity, mindmap, gantt, and C4 export until the
  matching importer slices land.
- Real multi-format corpus entries and export snapshot baselines.

## Phase 8: Interactivity Primitives

Goal: expose stable identity and geometry without building a full editor.

Status: implemented, with focused post-review remediation for state-diagram
selection typing, hit-test precedence, and layout-independent long-tail IDs.

Completed:

- Added portable geometry types in `DiagramKitCommon`.
- Added `DiagramStableElement`, `DiagramSelection`, and `DiagramBoundsLookup`
  in `DiagramKitModel`.
- Added eager `PositionedGraph.lookup` dispatch over positioned content.
- Covered flowchart/state, sequence, class, ER, C4, and most long-tail
  positioned families.
- Kept `PreparedDiagram` unchanged; consumers access
  `prepared.positioned.lookup`.
- Left pie, radar, and venn as empty lookups pending a more precise hit-area
  design.
- Added focused regression coverage for the post-review fixes.

Deferred:

- Full interactivity test matrix from `PHASE-8.md`.
- Better hit areas for pie/radar/venn.
- Splitting `DiagramBoundsLookup+LongTail.swift` if future additions push it
  toward the 1000-line file-size error threshold.
- Editor model, undo, typed mutations, and selection-highlight rendering.

Closure evidence lives in `PHASE-8.md`.

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

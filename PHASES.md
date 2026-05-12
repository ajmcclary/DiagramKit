# DiagramKit Multi-Format Roadmap

This is the active execution roadmap. `ANALYSIS.md` is the long-form rationale.
`PHASE-0.md`, `PHASE-1.md`, and `PHASE-2.md` are the detailed phase plans and
history.

## Current State

Phases 0, 1, and 2 are implemented locally. Phase 2 has post-review schema
hardening in this worktree: format IDs are canonical lowercase values,
`sources` requires a `mermaid` source, and the playground decoder enforces the
same source/Mermaid consistency rules as the test-support decoder.

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
- `DiagramKitImport` exists as the format-import boundary target. It owns
  `DiagramSourceImporter`, `DiagramImportResult`, `DiagramDiagnostic`,
  `ImporterRegistry`, and `DiagramLoader`.
- `MermaidImporter` is the first concrete importer and is intentionally broad:
  it acts as the fallback importer and must be ordered last once narrower
  importers are added.
- `DiagramPipeline.defaultRegistry` is the Phase 1 default registry. It is
  Mermaid-only today. Custom registries are passed to registry-aware pipeline
  methods rather than through an `ImporterRegistry.default` global.
- Source-taking `DiagramPipeline` paths for parse, layout, prepare, and primary
  SVG rendering load through `DiagramLoader` by default. Graph/positioned paths
  remain format-agnostic and consume `DiagramDocument`/`PositionedGraph`.
- ASCII rendering is still Mermaid-specific in Phase 1. Do not claim it as part
  of the generic importer boundary until it is deliberately migrated.
- `DiagramRegistry`, `DiagramDescriptor`, and `DiagramHeader` remain public
  Mermaid-family routing types for compatibility. They are documented as
  Mermaid-specific, not the multi-format import registry.
- `DiagramKitTestSupport.CorpusEntry` is the canonical test-side corpus decoder.
  It decodes legacy Mermaid-only entries and future multi-format entries while
  preserving `entry.source` as the Mermaid source.
- Corpus format metadata uses canonical lowercase format IDs such as `mermaid`,
  `d2`, `graphviz`, `plantuml`, and `structurizr`; importer names remain display
  values such as `Mermaid`.
- The real corpus file is still Mermaid-only. Multi-format examples live as
  inline fixtures in the corpus multi-format test files until the first d2
  slice lands.
- Snapshot baselines currently include 396 SVG, 396 image, and 174 ASCII files.
  Snapshot recording is deferred until the final baseline pass unless a phase is
  explicitly about intentional renderer baseline changes.
- `BASELINES.md` exists and should be kept current when gate status, corpus
  counts, or baseline counts change.
- `Scripts/linux-check.sh` is Docker/Podman-dependent. If the daemon is not
  running locally, record it as skipped due to environment rather than treating
  it as a source failure.

## Operating Principles

- Do not start new parser ports until Phase 2 is closed and committed.
- Keep source import separate from diagram-family layout. Importers produce
  `DiagramDocument`; they do not layout or render.
- Preserve the worker-thread invariant: every public async facade path still
  uses a fresh 8 MB-stack worker thread.
- Preserve font determinism: `DiagramFontRegistry.registerBundledFontsIfNeeded()`
  must run before rendering-related pipeline work.
- Keep `DiagramDocument -> PositionedGraph -> render` independent of source
  format. Layout must not care whether the document came from Mermaid, d2, DOT,
  Structurizr, or PlantUML.
- Probe order is contractual. Narrow/specific importers are prepended before
  the Mermaid fallback.
- Unsupported format features must produce diagnostics. No silent partial
  imports and no empty successful conversions.
- Land each new format as a vertical slice with parser tests, probe collision
  tests, corpus fixtures, diagnostics tests, and enough snapshot coverage to
  prove it uses the existing render paths.
- Expect snapshot drift during the phased import and renderer-improvement work.
  Review diffs for mechanical regressions now, but defer baseline recording to
  the final snapshot pass unless a phase explicitly says otherwise.

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

Implemented shape:

- New `DiagramKitImport` target.
- `DiagramSourceImporter`, `DiagramImportResult`, `DiagramDiagnostic`,
  `ImporterRegistry`, and `DiagramLoader`.
- `ImporterRegistry.prepending(_:)` puts future narrow importers before broader
  fallbacks.
- `MermaidImporter` wraps the current Mermaid-family registry dispatch and is
  the explicit fallback importer.
- `DiagramPipeline.defaultRegistry` is Mermaid-only.
- Source-taking parse/layout/prepare/primary SVG paths use the loader-backed
  import boundary.
- Graph/positioned paths remain format-agnostic.
- `DiagramRegistry` remains public and Mermaid-family-specific for
  compatibility.
- `DiagramError` remains in `DiagramKitModel`; `DiagramStructuralError` remains
  where existing render/layout code can use it without forcing a larger move.

Closure evidence:

- `swift build --build-tests`
- `swift test --filter ImporterRegistryTests`
- `swift test --filter ProbeCollisionMatrixTests`
- `swift test --filter MermaidImporterTests`
- `swift test --filter MermaidLegacyAPITests`
- `swift test --filter DiagramRegistryTests`
- governance scripts from the verification policy
- snapshot review only; do not record baselines

See `PHASE-1.md` for the full implementation plan and verification history.

## Phase 2: Multi-Format Corpus Foundation

Goal: make the corpus capable of hosting multiple source formats before the
second importer lands.

Status: implemented locally; post-review schema hardening is in the current
worktree and should be committed before Phase 3 starts. Full plan and design
decisions are in [PHASE-2.md](PHASE-2.md).

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
- `Package.swift`: `DiagramKitTests` depends on `DiagramKitTestSupport`.
- `SampleDiagrams.swift`: `TestDiagram` carries multi-format fields + custom
  decoder matching `CorpusEntry`; `TestExpectedDiagnostic` added.
- `CorpusMultiFormatTests.swift` and `CorpusMultiFormatIntegrationTests.swift`:
  6 test suites (decoding, metadata, backward compat, validation, playground
  parity, sparse matrix) across 22 tests. Fixture-only tests stay separate from
  real-corpus/render spot checks to satisfy the file-size gate.
- Real `test-diagrams.json` untouched. All 396 entries remain Mermaid-only,
  decode correctly, and pass `validate()`.
- Snapshot names unchanged. No baselines re-recorded.

Close this phase with:

- `swift build --build-tests`
- `swift test --filter CorpusMultiFormatTests`
- `swift test --filter CorpusMultiFormatIntegrationTests`
- `swift test --filter ImporterRegistryTests`
- governance scripts from the verification policy

Do not add d2/DOT/PlantUML/Structurizr code until this phase is committed.

## Phase 3: D2 Importer Vertical Slice

Goal: prove the importer architecture with the highest-ROI non-Mermaid format.

Scope:

- Add `DiagramKitD2` as a separate importer target.
- Implement a narrow D2 probe and prepend it before Mermaid in configured
  registries.
- Parse basic nodes, edges, labels, containers, direction, and simple shape
  hints.
- Map the first slice to `DiagramPayload.flowchart`.
- Emit diagnostics for unsupported D2 constructs.
- Add corpus entries with equivalent Mermaid and d2 sources.

Defer:

- Full D2 styling parity.
- D2 layout engine parity.
- Non-flowchart mappings unless they fall out naturally.
- Exporting d2.

Tests:

- D2 parser unit tests.
- Probe collision tests proving D2 beats Mermaid for D2-shaped input.
- Corpus entries render through existing SVG/image paths.
- Unsupported syntax produces diagnostics without crashing.

## Phase 4: DOT Importer Vertical Slice

Goal: add Graphviz DOT as a focused graph-language importer after d2 proves the
pattern.

Scope:

- Add `DiagramKitGraphviz` as a separate importer target.
- Support `graph`, `digraph`, strict graphs, node labels, directed edges,
  undirected edges, and simple subgraph clusters.
- Map to `DiagramPayload.flowchart`.
- Emit diagnostics for unsupported attributes and layout-only DOT concepts.

Tests:

- DOT parser unit tests.
- DOT/Mermaid/D2 probe collision tests.
- Corpus fixtures with DOT and equivalent Mermaid sources.
- Diagnostics tests for unsupported DOT attributes.

## Phase 5: Structurizr Importer Vertical Slice

Goal: support the C4-shaped subset where Structurizr maps cleanly to the current
model.

Scope:

- Add `DiagramKitStructurizr` as a separate importer target.
- Focus on workspace/model/view slices that map to existing C4 payloads.
- Keep DSL sections that do not map cleanly as explicit diagnostics.
- Do not build a complete Structurizr runtime.

Tests:

- Structurizr parser/probe tests.
- C4 corpus fixtures with Mermaid and Structurizr sources.
- Diagnostics tests for unsupported workspace sections.

## Phase 6: PlantUML In Vertical Slices

Goal: support useful PlantUML subsets without attempting a full PlantUML clone.

Order:

1. Sequence diagrams.
2. Class diagrams.
3. State/activity diagrams.
4. Mindmap and Gantt.
5. C4-flavored PlantUML.

Rules:

- Treat each family as its own vertical slice.
- Every unsupported syntax branch emits a diagnostic.
- Do not block earlier slices on later grammar coverage.
- Keep parser state isolated enough that slices can ship independently.

Tests:

- One suite per PlantUML family slice.
- Probe collision tests for `@startuml` and family-specific headers.
- Corpus fixtures only for the families implemented in that slice.

## Phase 7: Exporter Protocol

Goal: add source generation after multiple importers prove the canonical model.

Tasks:

- Add `DiagramExporter`, `DiagramExportResult`, and exporter diagnostics.
- Add sparse conversion-matrix tests.
- Add exporters in this order:
  1. Mermaid
  2. d2
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

Tasks:

- Add stable semantic IDs for nodes, edges, groups, and diagram-specific items.
- Add `DiagramSelection`.
- Add `DiagramBoundsLookup`.
- Attach lookup data to `PreparedDiagram`.
- Consider portable geometry types in `DiagramKitCommon` if `CGRect` would leak
  Apple-only types into format-neutral surfaces.

Start with flowchart, state, class, sequence, and ER, then fill in the long tail.

## Phase 9: Optional Interactive Model

Goal: provide editor primitives only after import/export and stable geometry are
settled.

Tasks:

- Add a `DiagramKitInteractive` target if real consumers need it.
- Introduce a `@MainActor` editor model with selection state, undo, and typed
  mutations.
- Keep turnkey editor UI out of the first cut. Ship primitives first.
- Source sync should go through exporters, not hand-written string patches.

## Phase 10: Release And Deprecation Cleanup

Goal: reduce compatibility surface after the new architecture has lived through
at least one release cycle.

Tasks:

- Decide which Mermaid-prefixed aliases stay indefinitely and which get removed.
- Rename remaining files whose filenames materially confuse ownership.
- Update README, ARCHITECTURE, CLAUDE, AGENTS, CONTRIBUTING, and BASELINES.
- Run full corpus snapshots and record only reviewed, intentional baselines.
- Run the full gate in an environment with Docker/Podman and Xcode runtimes:
  `Scripts/bootstrap-smoke-check.sh`.

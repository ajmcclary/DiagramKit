# DiagramKit Multi-Format Roadmap

This is the active execution roadmap. `ANALYSIS.md` is the long-form rationale,
and `PHASE-0.md` is the completed rename plan/history.

## Current State

Phase 0 is effectively complete:

- Public, format-neutral names are primary: `DiagramEngine`,
  `DiagramPipeline`, `DiagramImageRenderer`, `DiagramDocument`,
  `DiagramError`, `DiagramStructuralError`, `DiagramView`,
  `DiagramNativeView`, `DiagramLayer`, and `DiagramViewModel`.
- Mermaid-prefixed compatibility aliases and wrappers remain deprecated for
  downstream users.
- `String` has primary format-neutral helpers:
  `parseDiagram()`, `renderDiagramImage(...)`, `renderDiagramSVG(...)`, and
  `renderDiagramASCII(...)`.
- `DiagramRegistry`, `DiagramDescriptor`, and `DiagramHeader` remain the
  Mermaid-family routing surface for now. They are intentionally deferred to the
  importer phase.
- Snapshot baselines are now 396 SVG, 396 image, and 174 ASCII files. The image
  additions are intentional rendering-improvement baselines, not rename fallout.
- `BASELINES.md` exists and should be kept current when gate status or corpus
  counts change.
- `Scripts/linux-check.sh` is Docker/Podman-dependent. If the daemon is not
  running locally, record it as skipped due to environment rather than treating
  it as a source failure.

## Operating Principles

- Do not start new parser ports before the importer boundary exists.
- Preserve the worker-thread invariant: every public pipeline path still uses a
  fresh 8 MB-stack worker thread.
- Preserve font determinism: `DiagramFontRegistry.registerBundledFontsIfNeeded()`
  must run first in every pipeline method.
- Keep `DiagramDocument -> PositionedGraph -> render` independent of source
  format. Layout must not care whether the document came from Mermaid, d2, DOT,
  Structurizr, or PlantUML.
- Keep unsupported format features explicit through diagnostics. No silent
  partial imports.
- Land each new format as a vertical slice with corpus fixtures and snapshot
  coverage before broadening syntax support.

## Phase 0: Close The Rename Branch

Goal: finish the naming transition and documentation cleanup without changing
behavior.

Status: complete except final review/commit.

Required closure checks:

- `swift build --build-tests`
- `swift test --filter BeautifulMermaidSwiftTests/testStringDiagramExtensionsUseFormatNeutralNames`
- `swift test --filter BeautifulMermaidSwiftTests/testStringRenderDiagramImageForSimpleFlowIsNonNil`
- `Scripts/check-file-sizes.sh`
- `Scripts/check-sendable-annotations.sh`
- `Scripts/strict-concurrency-check.sh`

Skip `Scripts/linux-check.sh` when Docker/Podman is unavailable locally; run it
before merge in an environment with the daemon available.

## Phase 1: Importer Boundary And Mermaid Extraction

Goal: split source-format import from diagram-family layout while preserving all
Mermaid behavior.

Build this before any new source format.

Tasks:

- Add a format-neutral importer protocol surface:
  - `DiagramSourceImporter`
  - `DiagramImportResult`
  - `DiagramDiagnostic`
  - `ImporterRegistry`
  - `DiagramLoader`
- Move source-format probing behind the importer registry. The loader should
  produce `DiagramDocument`; it should not layout or render.
- Make Mermaid the first concrete importer:
  - `MermaidImporter`
  - `MermaidDiagramRegistry` or an internal equivalent for the current
    diagram-family descriptors
  - Compatibility aliases for public `DiagramRegistry`/`DiagramDescriptor` names
    if they remain public during the transition
- Keep layout dispatch in terms of `DiagramDocument` and `PositionedGraph`.
- Move `DiagramError`/`DiagramStructuralError` into the model/import diagnostics
  layer only when the new dependency boundary is clear.

Tests:

- Default registry picks Mermaid for all existing corpus entries.
- Mermaid legacy APIs still parse/render through the new loader.
- Probe collision tests cover at least:
  - Mermaid `graph TD`
  - DOT `graph { a -- b }`
  - d2-style `a -> b`
  - PlantUML `@startuml`
  - Structurizr `workspace { ... }`
- Corpus snapshots stay unchanged for Mermaid.

## Phase 2: Multi-Format Corpus Foundation

Goal: make the test corpus capable of hosting multiple source formats before the
second importer lands.

Tasks:

- Extend `test-diagrams.json` support to accept both the current schema and a
  multi-format schema:

```json
{
  "id": "flow-1-simple",
  "source": "graph TD\nA-->B",
  "sources": {
    "mermaid": "graph TD\nA-->B",
    "d2": "A -> B"
  }
}
```

- Keep `source` as the Mermaid fallback for backward compatibility.
- Update `SampleDiagrams.swift`, `CorpusSnapshotTests`, and any playground
  loaders to preserve current behavior when only `source` exists.
- Add fixture metadata for expected diagnostics, unsupported features, and
  importer identity.
- Keep snapshot names stable for existing Mermaid entries.

Tests:

- Old fixture schema decodes.
- New fixture schema decodes.
- Existing 396 Mermaid entries still run as Mermaid.
- A fixture can carry a second format source without changing current Mermaid
  snapshots.

## Phase 3: D2 Importer Vertical Slice

Goal: prove the architecture with the highest-ROI non-Mermaid format.

Scope:

- New `DiagramKitD2` importer target.
- Parse basic nodes, edges, labels, containers, and direction.
- Map to `DiagramPayload.flowchart`.
- Add diagnostics for unsupported D2 constructs.
- Add corpus entries with equivalent Mermaid and d2 sources.

Defer:

- Full D2 styling parity.
- Non-flowchart mappings unless they fall out naturally.
- Exporting d2.

Tests:

- Unit tests for parser/probe collisions.
- Corpus entries render through existing SVG/image/ASCII paths.
- Unsupported syntax produces diagnostics without crashing.

## Phase 4: DOT And Structurizr Importers

Goal: add two narrower formats after D2 validates the importer architecture.

DOT:

- New `DiagramKitGraphviz` importer target.
- Support strict graph/digraph basics, node labels, directed and undirected
  edges, and subgraph clusters where they map cleanly to flowchart groups.
- Map only to flowchart unless a future need proves otherwise.

Structurizr:

- New `DiagramKitStructurizr` importer target.
- Focus on C4 workspace/model/view slices that map to existing C4 payloads.
- Prefer diagnostics for unsupported DSL sections.

Tests:

- Collision matrix expands for DOT and Structurizr.
- Each importer has corpus fixtures and diagnostics tests.
- No renderer changes required.

## Phase 5: PlantUML In Vertical Slices

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

## Phase 6: Exporters

Goal: add source generation after multiple importers prove the canonical model.

Tasks:

- Add `DiagramExporter`, `DiagramExportResult`, and exporter diagnostics.
- Add exporters in this order:
  1. Mermaid
  2. d2
  3. Structurizr/C4
  4. PlantUML subsets
- Add sparse-matrix tests:
  - supported conversion emits source
  - unsupported conversion emits diagnostics
  - no conversion silently produces empty output
- Add round-trip tests:
  `parse(formatA) -> export(formatB) -> parse(formatB) -> export(formatB)`.

## Phase 7: Interactivity Primitives

Goal: expose stable identity and geometry without building a full editor.

Tasks:

- Add stable semantic IDs for nodes, edges, groups, and diagram-specific items.
- Add `DiagramSelection`.
- Add `DiagramBoundsLookup`.
- Attach lookup data to `PreparedDiagram`.
- Consider portable geometry types in `DiagramKitCommon` if `CGRect` would leak
  Apple-only types into format-neutral surfaces.

Start with flowchart, state, class, sequence, and ER, then fill in the long tail.

## Phase 8: Optional Interactive Model

Goal: provide editor primitives only after import/export and stable geometry are
settled.

Tasks:

- Add a `DiagramKitInteractive` target if real consumers need it.
- Introduce a `@MainActor` editor model with selection state, undo, and typed
  mutations.
- Keep turnkey editor UI out of the first cut. Ship primitives first.
- Source sync should go through exporters, not hand-written string patches.

## Phase 9: Release And Deprecation Cleanup

Goal: reduce compatibility surface after the new architecture has lived through
at least one release cycle.

Tasks:

- Decide which Mermaid-prefixed aliases stay indefinitely and which get removed.
- Rename remaining files whose filenames materially confuse ownership.
- Update README, ARCHITECTURE, CLAUDE, AGENTS, CONTRIBUTING, and BASELINES.
- Refresh snapshots only for intentional rendering changes, never for pure
  symbol renames.
- Run the full gate in an environment with Docker/Podman and Xcode runtimes:
  `Scripts/bootstrap-smoke-check.sh`.


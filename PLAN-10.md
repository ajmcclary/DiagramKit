# Phase 10: Release And Deprecation Cleanup — Plan

**Date**: 2026-05-12
**Status**: Planning
**Depends on**: Phases 0–9 complete; Phases 6B–6E (remaining PlantUML slices) continue independently

This is the execution plan for the final Phase 10 surface reduction pass. It
does not block remaining PlantUML importer slices (6B–6E); those are additive
and do not touch the aliases, filenames, or corpus handled here.

---

## 1. Pre-Flight Survey

### 1.1 Deprecated Alias Inventory

36 `@available(*, deprecated, renamed:)` entries across 10 files:

| Target | File | Alias | → New Name | Public Surface |
|--------|------|-------|------------|----------------|
| DiagramKitModel | Types.swift | `MermaidGraph` | `DiagramDocument` | Core model |
| DiagramKitModel | Types.swift | `BeautifulMermaidError` | `DiagramError` | Core error |
| DiagramKitModel | DiagramSourceNormalizer.swift | `MermaidSourceNormalizer` | `DiagramSourceNormalizer` | Internal |
| DiagramKitModel | DiagramColorParser.swift | `MermaidColorParser` | `DiagramColorParser` | Internal |
| DiagramKitModel | src_ascii_converter.swift | `MermaidGraphInput` | `DiagramDocumentInput` | Internal |
| DiagramKitCommon | IssueReportingSupport.swift | `_MermaidRecoverableError` | `_RecoverableDiagramError` | SPI (underscore) |
| DiagramKitCommon | IssueReportingSupport.swift | `_withMermaidIssueReporting` | `_withDiagramIssueReporting` | SPI |
| DiagramKitCommon | IssueReportingSupport.swift | `_reportMermaidIssueIfNeeded` | `_reportDiagramIssueIfNeeded` | SPI |
| DiagramKitCommon | IssueReportingSupport.swift | `_reportMermaidIssue` | `_reportDiagramIssue` | SPI |
| DiagramKitCommon | IssueReportingSupport.swift | `_isRecoverableMermaidError` | `_isRecoverableDiagramError` | SPI |
| DiagramKit | MermaidRenderer.swift | `MermaidRenderer` | `DiagramEngine` | Primary facade |
| DiagramKit | MermaidPipeline.swift | `MermaidPipeline` | `DiagramPipeline` | Pipeline |
| DiagramKit | DiagramImageRenderer.swift | `MermaidImageRenderer` | `DiagramImageRenderer` | Image render |
| DiagramKit | DiagramDescriptor.swift | `MermaidStructuralError` | `DiagramStructuralError` | Error type |
| DiagramKit | MermaidRenderer.swift | `renderImageAsync(source:…)` | `renderImage(source:…)` | Deprecated method |
| DiagramKit | MermaidRenderer.swift | `renderSVGAsync(source:…)` | `renderSVG(source:…)` | Deprecated method |
| DiagramKit | MermaidRenderer.swift | `renderASCIIAsync(source:…)` | `renderASCII(source:…)` | Deprecated method |
| DiagramKit | MermaidRenderer.swift | `prepareAsync(source:…)` | `prepare(source:…)` | Deprecated method |
| DiagramKit | MermaidRenderer.swift | `parseMermaid()` | `parseDiagram()` | String ext |
| DiagramKit | MermaidRenderer.swift | `renderMermaidImage(…)` | `renderDiagramImage(…)` | String ext |
| DiagramKit | MermaidRenderer.swift | `renderMermaidSVG(…)` | `renderDiagramSVG(…)` | String ext |
| DiagramKit | MermaidRenderer.swift | `renderMermaidASCII(…)` | `renderDiagramASCII(…)` | String ext |
| DiagramKit | src_index.swift | `renderMermaidSVG(…)` | `renderDiagramSVG(…)` | Free function |
| DiagramKit | src_index.swift | `renderMermaidSVGAsync(…)` | `renderDiagramSVGAsync(…)` | Free function |
| DiagramKitRenderingCG | MermaidPreparation.swift | `MermaidPreparation` | `DiagramPreparation` | Internal |
| DiagramKitRenderingCG | MermaidPreparation.swift | `MermaidPreparationError` | `DiagramPreparationError` | Internal |
| DiagramKitRenderingCG | MermaidWorkerThread.swift | `MermaidWorkerThread` | `DiagramWorkerThread` | Internal |
| DiagramKitRenderingCG | MermaidBitmapRenderer.swift | `MermaidBitmapRenderer` | `DiagramBitmapRenderer` | Internal |
| DiagramKitRenderingCG | MermaidViewPreparer.swift | `MermaidViewPreparer` | `DiagramViewPreparer` | Internal |
| DiagramKitRenderingCG | MermaidViewPreparer.swift | `MermaidViewPreparerEnvironment` | `DiagramViewPreparerEnvironment` | Internal |
| DiagramKitRenderingCG | FontRegistry.swift | `BeautifulMermaidFontRegistry` | `DiagramFontRegistry` | Internal |
| DiagramKitViews | MermaidView.swift | `MermaidView` | `DiagramNativeView` | Platform view |
| DiagramKitViews | MermaidLayer.swift | `MermaidLayer` | `DiagramLayer` | View layer |
| DiagramKitViews | MermaidDiagram.swift | `MermaidDiagram` | `DiagramViewModel` | View model |
| DiagramKitViews | MermaidDiagramView.swift | `MermaidDiagramView` | `DiagramView` | SwiftUI view |

### 1.2 Mermaid-Prefixed Filenames That House Renamed Types

Ten files whose filename no longer matches their primary type:

| Current Filename | Primary Type | Target |
|---|---|---|
| `Sources/DiagramKit/MermaidRenderer.swift` | `DiagramEngine` | DiagramKit |
| `Sources/DiagramKit/MermaidPipeline.swift` | `DiagramPipeline` | DiagramKit |
| `Sources/DiagramKitRenderingCG/MermaidViewPreparer.swift` | `DiagramViewPreparer` | DiagramKitRenderingCG |
| `Sources/DiagramKitRenderingCG/MermaidWorkerThread.swift` | `DiagramWorkerThread` | DiagramKitRenderingCG |
| `Sources/DiagramKitRenderingCG/MermaidPreparation.swift` | `DiagramPreparation` | DiagramKitRenderingCG |
| `Sources/DiagramKitRenderingCG/MermaidBitmapRenderer.swift` | `DiagramBitmapRenderer` | DiagramKitRenderingCG |
| `Sources/DiagramKitViews/MermaidView.swift` | `DiagramNativeView` | DiagramKitViews |
| `Sources/DiagramKitViews/MermaidLayer.swift` | `DiagramLayer` | DiagramKitViews |
| `Sources/DiagramKitViews/MermaidDiagram.swift` | `DiagramViewModel` | DiagramKitViews |
| `Sources/DiagramKitViews/MermaidDiagramView.swift` | `DiagramView` | DiagramKitViews |

These are files that *house* a renamed primary type — e.g.
`MermaidViewPreparer.swift` contains `DiagramViewPreparer` as the primary
class. The filename material confuses ownership and should be corrected before
the release.

### 1.3 Correctly-Named Mermaid-Prefixed Files (No Rename Needed)

These files are Mermaid-specific importers, exporters, or helpers. Their
Mermaid prefix is correct and should be preserved:

- `Sources/DiagramKit/MermaidImporter.swift` — Mermaid source importer
- `Sources/DiagramKit/Exporter/MermaidExporter.swift` — Mermaid exporter
- `Sources/DiagramKit/Exporter/MermaidExport/MermaidC4Export.swift`
- `Sources/DiagramKit/Exporter/MermaidExport/MermaidClassExport.swift`
- `Sources/DiagramKit/Exporter/MermaidExport/MermaidERExport.swift`
- `Sources/DiagramKit/Exporter/MermaidExport/MermaidExportDiagnostics.swift`
- `Sources/DiagramKit/Exporter/MermaidExport/MermaidExportHelpers.swift`
- `Sources/DiagramKit/Exporter/MermaidExport/MermaidFlowchartExport.swift`
- `Sources/DiagramKit/Exporter/MermaidExport/MermaidSequenceExport.swift`

### 1.4 Inline Multi-Format Fixtures

Three corpus fixture test files currently hold inline fixtures with
`skipSnapshots` — they parse real multi-format sources but generate no
snapshot baselines:

| File | Lines | Approx Fixtures | Formats |
|---|---|---|---|
| `Tests/DiagramKitTests/D2CorpusFixtureTests.swift` | 167 | 4 | D2 |
| `Tests/DiagramKitTests/DOTCorpusFixtureTests.swift` | 165 | 4 | Graphviz DOT |
| `Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift` | 249 | 5 | Structurizr |

PlantUML sequence fixtures live in `PlantUMLSequenceParserTests.swift`,
`PlantUMLSequenceMapperTests.swift`, and `PlantUMLSequenceIntegrationTests.swift`
(835 total lines). These are not corpus-formatted — they use plain `@Test`
assertions, not `CorpusEntry` decoding. They will need adapter wrappers if
promoted to real corpus entries.

### 1.5 Current Corpus State

- `test-diagrams.json`: 396 Mermaid-only entries, version 2.0.0
- Snapshot baselines: 396 SVG, 396 image, 174 ASCII (966 total tracked files)
- Test source files: 188 (up from 169 at Phase 0 — the BASELINES.md count
  needs updating)

### 1.6 Registry Ordering (for reference)

```swift
public static let defaultRegistry: ImporterRegistry = ImporterRegistry(
    importers: [
        StructurizrImporter(),   // narrow probe: workspace {
        PlantUMLImporter(),      // narrow probe: @startuml
        GraphvizImporter(),      // narrow probe: digraph/graph
        D2Importer(),            // narrow probe: : / -> syntax
        MermaidImporter(),       // broad fallback
    ]
)
```

No change to ordering needed. Probes are correct. Mermaid stays last.

---

## 2. Step 1 — Alias Removal Decisions

### Decision Matrix

**Tier 1 — Keep for one more release cycle** (widely used public API):

| Alias | Rationale |
|-------|-----------|
| `MermaidRenderer` / `DiagramEngine` | Primary public facade; most downstream code references this |
| `MermaidPipeline` / `DiagramPipeline` | Pipeline entry point; widely used |
| `MermaidImageRenderer` / `DiagramImageRenderer` | Image rendering |
| `MermaidGraph` / `DiagramDocument` | Core model; referenced in every consumer |
| `BeautifulMermaidError` / `DiagramError` | Public error type |
| `MermaidStructuralError` / `DiagramStructuralError` | Public error type |
| `MermaidView` / `DiagramNativeView` | Platform view type |
| `MermaidDiagramView` / `DiagramView` | SwiftUI view type |
| `MermaidLayer` / `DiagramLayer` | View layer type |
| `MermaidDiagram` / `DiagramViewModel` | View model type |

These stay as `@available(*, deprecated, message: "Will be removed in the next
major version. Use <NewName> instead.")` — upgrading the annotation from
`renamed:` to an explicit removal warning.

**Tier 2 — Remove now** (internal-facing, SPI, or deprecated methods):

| Alias | Rationale |
|-------|-----------|
| `MermaidPreparation` | Internal pipeline detail; never public-facing |
| `MermaidPreparationError` | Internal error type |
| `MermaidWorkerThread` | Internal threading; explicitly documented as internal |
| `MermaidBitmapRenderer` | Internal bitmap renderer |
| `MermaidViewPreparer` | Internal view prep |
| `MermaidViewPreparerEnvironment` | Internal view prep env |
| `BeautifulMermaidFontRegistry` | Internal font registry; amusingly named |
| `MermaidSourceNormalizer` | Internal source processing |
| `MermaidColorParser` | Internal color parsing |
| `MermaidGraphInput` | Internal ASCII converter typealias |
| `_MermaidRecoverableError` | SPI (underscore-prefixed); zero public usage |
| `_withMermaidIssueReporting` | SPI; zero public usage |
| `_reportMermaidIssueIfNeeded` | SPI; zero public usage |
| `_reportMermaidIssue` | SPI; zero public usage |
| `_isRecoverableMermaidError` | SPI; zero public usage |
| `renderImageAsync(source:…)` | Deprecated convenience method on `DiagramEngine` |
| `renderSVGAsync(source:…)` | Deprecated convenience method |
| `renderASCIIAsync(source:…)` | Deprecated convenience method |
| `prepareAsync(source:…)` | Deprecated convenience method |
| `parseMermaid()` on String | Deprecated String extension |
| `renderMermaidImage(…)` on String | Deprecated String extension |
| `renderMermaidSVG(…)` on String | Deprecated String extension |
| `renderMermaidASCII(…)` on String | Deprecated String extension |
| `renderMermaidSVG(…)` free function | Deprecated free function |
| `renderMermaidSVGAsync(…)` free function | Deprecated free function |

### 2.1 Removal Audit: Internal Callers

Before removing Tier 2 aliases, verify zero internal references to the
deprecated names. If any internal call site still uses a deprecated name,
migrate it to the canonical name first.

### 2.2 Removal Audit: External Consumers

Check the playground (`Examples/MermaidPlayground/`) for references to
Tier 2 names. Migrate any stale references.

---

## 3. Step 2 — Rename Mermaid-Prefixed Filenames

Ten files renamed via `git mv`. Each rename is paired with a
build-verification step since file renames should not change compilation.

### 3.1 Rename Map

```
Sources/DiagramKit/MermaidRenderer.swift          → DiagramEngine.swift
Sources/DiagramKit/MermaidPipeline.swift          → DiagramPipeline.swift
Sources/DiagramKitRenderingCG/MermaidViewPreparer.swift   → DiagramViewPreparer.swift
Sources/DiagramKitRenderingCG/MermaidWorkerThread.swift   → DiagramWorkerThread.swift
Sources/DiagramKitRenderingCG/MermaidPreparation.swift    → DiagramPreparation.swift
Sources/DiagramKitRenderingCG/MermaidBitmapRenderer.swift → DiagramBitmapRenderer.swift
Sources/DiagramKitViews/MermaidView.swift          → DiagramNativeView.swift
Sources/DiagramKitViews/MermaidLayer.swift          → DiagramLayer.swift
Sources/DiagramKitViews/MermaidDiagram.swift        → DiagramViewModel.swift
Sources/DiagramKitViews/MermaidDiagramView.swift    → DiagramView.swift
```

### 3.2 Audit: Import Statements

After rename, verify no import statements in other files reference the old
filename. Swift uses module-scoped imports, not file-scoped, so renames
should be transparent. Verify with a clean build.

### 3.3 Playground References

`Examples/MermaidPlayground/` may contain relative file references. Audit
and update as needed.

---

## 4. Step 3 — Move Inline Multi-Format Fixtures Into the Real Corpus

### 4.1 Extraction Strategy

For each inline fixture test file, extract the JSON `CorpusEntry`-shaped
payloads, validate them against `CorpusEntry.decode`, remove the
`skipSnapshots` key, and append them to `test-diagrams.json`.

### 4.2 Candidate Fixtures

**D2 fixtures** (from `D2CorpusFixtureTests.swift`, ~4 entries):
```
d2-1-simple-edge:     direction: right\nA: Start\nB: End\nA -> B
d2-2-container:       direction: right\nA: Start\nB: End\nA -> B\n  subgraph Cluster { C -> D }
d2-3-shape-hint:      direction: right\nA: Start {shape: hexagon}\nB: End\nA -> B
d2-4-comments:        # A comment\nA: Start\nA -> B: label
```

**DOT fixtures** (from `DOTCorpusFixtureTests.swift`, ~4 entries):
```
dot-1-simple-digraph:  digraph G { a -> b }
dot-2-directed-edge:   digraph G { a -> b [label="edge"] }
dot-3-subgraph:        digraph G { subgraph cluster_0 { a -> b } }
dot-4-node-attrs:      digraph G { node [shape=box] a -> b }
```

**Structurizr fixtures** (from `StructurizrCorpusFixtureTests.swift`, ~5 entries):
```
structurizr-1-simple:      workspace { model { user = person "User" } }
structurizr-2-system:      workspace { model { sys = softwareSystem "System" } }
structurizr-3-relationship: workspace { model { u = person "User"  s = softwareSystem "Sys"  u -> s "Uses" } }
structurizr-4-container:    workspace { model { sys = softwareSystem "Sys" { c = container "App" } } }
structurizr-5-view:         workspace { model { u = person "User" } views { systemContext sys { include * } } }
```

### 4.3 PlantUML Sequence Fixtures

PlantUML sequence fixtures are embedded in parser/mapper/integration tests,
not in the corpus JSON format. Extracting them requires:

1. Convert representative PlantUML sequence sources into `CorpusEntry` JSON
   with `sources: { "mermaid": "<equiv>", "plantuml": "<plantuml>" }` where
   possible (sequence is a shared diagram type).
2. Where no Mermaid equivalent exists, use `sources: { "plantuml": "..." }`
   and mark `expectedImporters: ["PlantUML"]`.
3. Add 4–6 PlantUML sequence entries covering: basic messages, participant
   aliases, activations, notes, boxes, and groups.

### 4.4 Corpus Entry Format

Each new entry follows the multi-format schema established in Phase 2:

```json
{
    "id": "d2-1-simple-edge",
    "category": "flowchart",
    "name": "D2: Simple Edge (A → B)",
    "source": "<Mermaid equivalent>",
    "sources": {
        "mermaid": "<Mermaid source>",
        "d2": "<D2 source>"
    },
    "expectedImporters": ["Mermaid", "D2"]
}
```

Where a Mermaid equivalent exists, provide both sources. Where only the
non-Mermaid format applies (e.g., Structurizr C4), the Mermaid source is
still required for `entry.source` backward compatibility but the entry is
tagged with `expectedImporters` for the appropriate format.

### 4.5 Validation Gate

After appending entries to `test-diagrams.json`:
```bash
swift test --filter CorpusMultiFormatIntegrationTests
swift test --filter CorpusMultiFormatTests
```

These validate that all entries decode, `validate()` passes, and no
`sourceMermaidMismatch` errors exist.

### 4.6 Post-Migration Cleanup

After entries are in the real corpus:
1. Remove the inline JSON fixtures from the three `*CorpusFixtureTests.swift` files.
2. Replace them with tests that load from the real corpus file and verify
   the entries parse correctly through their respective importers.
3. Alternatively, keep the fixture test files as focused unit tests that
   verify specific behaviors not covered by corpus-wide snapshot rendering.
   (Prefer this — the fixture files exercise importer-specific diagnostics,
   edge cases, and format-specific assertions that corpus-wide rendering
   wouldn't catch.)

---

## 5. Step 4 — Full Corpus Snapshots

### 5.1 Pre-Snapshot Audit

Before recording, run full corpus snapshot tests to review accumulated drift:

```bash
SNAPSHOT_DIAGRAM_IDS=d2-1-simple-edge,d2-2-container,... swift test --filter CorpusSnapshotTests/imageSnapshot
```

Review the diff:
- **Expected differences**: new D2/DOT/Structurizr entries have no prior
  baselines → they will show as "new" or "missing."
- **Unexpected differences**: existing Mermaid entries should not change.
  If they do, investigate before proceeding — it indicates a regression
  introduced during Phases 1–9 that was hidden by deferred snapshot
  recording.

### 5.2 Baseline Recording

Record SVGs first (fastest, easiest to diff), then images, then ASCII.
ASCII baselines are Mermaid-only — the D2/DOT/Structurizr entries won't
produce ASCII output unless explicitly wired.

```bash
# Record SVG baselines for all formats
SNAPSHOT_TESTING_RECORD=all swift test --filter CorpusSnapshotTests/svgSnapshot

# Record image baselines
SNAPSHOT_TESTING_RECORD=all swift test --filter CorpusSnapshotTests/imageSnapshot

# Record ASCII baselines (Mermaid entries only)
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests/asciiSnapshot
```

### 5.3 Post-Record Validation

```bash
# Verify all snapshots match (no drift after record)
swift test --filter CorpusSnapshotTests

# Count new baselines
find Tests/DiagramKitTests/__Snapshots__ -name "*.svg" | wc -l
find Tests/DiagramKitTests/__Snapshots__ -name "*.png" | wc -l
find Tests/DiagramKitTests/__Snapshots__ -name "*.txt" | wc -l
```

### 5.4 Baseline Count Projection

| Format | Before | New Entries | After (approx) |
|--------|--------|-------------|----------------|
| SVG | 396 | ~17 (D2:4, DOT:4, Structurizr:5, PlantUML:4) | ~413 |
| Image | 396 | ~17 | ~413 |
| ASCII | 174 | 0 (Mermaid-only) | 174 |
| **Total tracked** | **966** | **~34** | **~1000** |

---

## 6. Step 5 — Update Documentation

### 6.1 README.md

- Update public API examples to use canonically-named types.
- Add a "Migration from Mermaid-prefixed names" section with a
  tiered deprecation table.
- Update installation/quick-start to use `DiagramEngine`, `DiagramPipeline`,
  etc.
- Add multi-format support mention with links to format-specific importer
  targets.

### 6.2 ARCHITECTURE.md

- Verify all type names, file paths, and target names are current.
- Update the pipeline diagram to show the multi-format import boundary.
- Add the `DiagramKitInteractive` target to the target layering diagram.
- Remove any stale references to pre-rename file paths.

### 6.3 CLAUDE.md

- Update the "Critical Constraints" section with current invariants.
- Update the "Conventions" section to reflect deprecated alias policy.
- Verify the test commands work with renamed files.

### 6.4 AGENTS.md

- Update the target layering to include `DiagramKitInteractive`.
- Update the test counts.
- Verify the verification gate commands reference current file paths.

### 6.5 CONTRIBUTING.md

- Add a deprecation policy section: how long aliases live, how to add
  new ones, when they get removed.
- Document the `@available(*, deprecated, message:)` convention for
  Tier 1 aliases.

### 6.6 BASELINES.md

Full refresh with live metrics:
- Build time (re-measure)
- Test count: 188 source files → exact test count from `swift test`
- Snapshot baselines: updated counts after Step 4
- Gate status: all gates re-run
- File-size warnings: current state

---

## 7. Step 6 — Full Gate Run

### 7.1 Incremental Gates

```bash
# Build
swift package dump-package
swift build --build-tests

# Alias removal verification
swift test

# Corpus validation
swift test --filter CorpusMultiFormatIntegrationTests
swift test --filter CorpusMultiFormatTests
swift test --filter CorpusSnapshotTests

# Governance
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
git diff --check
```

### 7.2 Full Smoke Check

```bash
Scripts/bootstrap-smoke-check.sh
```

This chains: `swift package dump-package`, `swift test`, governance gates,
Linux check (Docker/Podman), and a multiplatform `xcodebuild` sweep.

### 7.3 Linux Check Caveat

If Docker/Podman is not running locally, record Linux as skipped due to
environment. Do not treat it as a source failure. The `bootstrap-smoke-check.sh`
script already follows this convention.

---

## 8. Execution Order

Phase 10 is ordered strictly — each step depends on the previous:

| Step | Name | Est. Time | Depends On |
|------|------|-----------|------------|
| 1 | Alias removal decisions + Tier 2 removal | ~2h | — |
| 2 | Filename renames | ~1h | Step 1 |
| 3 | Move inline fixtures to real corpus | ~3h | Step 2 |
| 4 | Full corpus snapshots | ~1h (machine) | Step 3 |
| 5 | Documentation updates | ~2h | Step 4 |
| 6 | Full gate run | ~15m (machine) | Step 5 |
| **Total** | | **~9.25h** | |

### 8.1 Commit Strategy

Work in three commits:

**Commit A** — Alias Removal + Filename Renames:
- Remove Tier 2 aliases and deprecated methods.
- Upgrade Tier 1 alias annotations to "will be removed" messages.
- `git mv` the ten Mermaid-prefixed filenames.
- Verify build and full test suite.

**Commit B** — Corpus Expansion + Snapshots:
- Append multi-format entries to `test-diagrams.json`.
- Update inline fixture tests to reference real corpus.
- Record snapshot baselines.
- Verify no Mermaid snapshot regressions.

**Commit C** — Documentation + Final Gate:
- Update all six documentation files.
- Run `Scripts/bootstrap-smoke-check.sh`.
- Tag the commit as the Phase 10 completion marker.

---

## 9. Risk Registry

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Tier 2 alias removal breaks downstream | Low | Medium | Audit playground and any known consumers first; Tier 2 aliases are internal-facing |
| Filename renames break Xcode project | Low | Low | SPM uses directory scanning, not project references; verify with `swift build` |
| New corpus entries fail `validate()` | Medium | Low | The `CorpusMultiFormatIntegrationTests` suite catches schema errors |
| Existing Mermaid snapshots drift unexpectedly | Medium | High | Run full corpus snapshots BEFORE recording; review every diff before proceeding |
| Docker/Podman unavailable for Linux check | High | Low | Protocol: record as skipped, do not block |
| PlantUML fixture extraction is ambiguous | Medium | Low | Use only well-covered parser test cases; validate round-trip through `PlantUMLImporter` |
| File-size warnings cross the 1000-line error threshold | Low | High | `check-file-sizes.sh` gate catches this; split files if needed |

---

## 10. Completion Criteria

Phase 10 is complete when:

- [ ] Tier 2 aliases and deprecated methods are removed; zero internal
      references to the removed names remain.
- [ ] Tier 1 aliases carry `message: "Will be removed in the next major
      version."` instead of bare `renamed:`.
- [ ] Ten Mermaid-prefixed filenames are renamed to match their primary types.
- [ ] At least 13 new multi-format entries (D2: 4, DOT: 4, Structurizr: 5)
      exist in `test-diagrams.json`, plus 4–6 PlantUML sequence entries.
- [ ] All inline fixture tests still pass and reference the real corpus
      entries where appropriate.
- [ ] Full corpus snapshot baselines are recorded and passing.
- [ ] Zero unexpected snapshot regressions in the 396 Mermaid entries.
- [ ] `BASELINES.md` reflects current counts, build time, and gate status.
- [ ] README, ARCHITECTURE, CLAUDE, AGENTS, and CONTRIBUTING are updated.
- [ ] `Scripts/bootstrap-smoke-check.sh` passes or Linux is recorded as
      skipped due to environment.
- [ ] `swift build --build-tests` and `swift test` pass cleanly.

---

## 11. Open Questions (Resolved or Deferred)

1. **Should we remove `MermaidParser`?** — `MermaidParser` (the old
   `Parser.swift` entry point, 22 lines) is not deprecated. It remains in
   use as the Mermaid-family dispatch. Phase 1 made `MermaidImporter` the
   primary public entry point. `MermaidParser` can be deprecated but not
   removed — internal Mermaid-family code still references it. **Decision**:
   Add a deprecation annotation to `MermaidParser` in this phase, remove
   it after the PlantUML slices land and Mermaid internals are fully
   migrated to `MermaidImporter`.

2. **Should deprecated `DiagramEngine` convenience methods stay?**
   `renderImageAsync`, `renderSVGAsync`, `renderASCIIAsync`, and
   `prepareAsync` are already deprecated and delegate to the canonical
   names. They exist only for the pre-`DiagramEngine` API surface.
   **Decision**: Remove them in Step 1 (Tier 2).

3. **What about `DiagramRegistry` / `DiagramDescriptor` / `DiagramHeader`?**
   These remain Mermaid-internal routing types with a Phase 1 comment banner
   marking them as such. They are not deprecated and are not on the Phase 10
   removal list. **Decision**: Leave as-is. They are correct for their
   Mermaid-specific role.

4. **Should we add snapshot baselines for PlantUML entries?**
   PlantUML sequence entries map to `DiagramPayload.sequenceDiagram`, which
   already has Mermaid sequence baselines. The SVG/image output for a
   structurally identical sequence diagram from PlantUML source should be
   identical to the Mermaid source version. **Decision**: Only add PlantUML
   entries that produce structurally different sequence diagrams (e.g.,
   PlantUML-specific arrow variants that differ from Mermaid equivalents).
   If the output is identical, one snapshot covers both.

5. **Should `renderASCII` be genericized?**
   Currently ASCII rendering is Mermaid-only. `PHASES.md` explicitly says:
   "Source-taking ASCII rendering is still Mermaid-specific. Do not treat
   `DiagramPipeline.renderASCII(source:)` as part of the generic importer
   boundary until it is deliberately migrated." **Decision**: Deferred.
   Not a Phase 10 concern.

---

*This plan was written against the post-Phase-9 codebase described in
`PHASES.md`, `PHASE-9.md`, and `ANALYSIS.md`. All 28 diagram families are
parseable through Mermaid. Importers for D2, Graphviz DOT, Structurizr,
and PlantUML (sequence) are in place. The exporter protocol supports
Mermaid, D2, Structurizr, and PlantUML. Interactivity primitives (Phase 8)
and editor primitives (Phase 9) are shipping. Phase 6B–6E (remaining
PlantUML slices) continue independently and are not blocked by this plan.*

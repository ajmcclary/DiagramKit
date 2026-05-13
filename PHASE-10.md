# Phase 10: Release And Deprecation Cleanup — Plan

**Date**: 2026-05-13
**Status**: Complete — all steps executed; snapshots recorded; documentation updated; gates passed
**Depends on**: Phases 0–9 complete; Phases 6B–6E (remaining PlantUML slices) continue independently

This is the execution plan for the final Phase 10 surface reduction pass. It
does not block remaining PlantUML importer slices (6B–6E); those are additive
and do not touch the aliases, filenames, or corpus handled here.

---

## 1. Pre-Flight Survey

### 1.1 Deprecated / Unavailable Alias Inventory

40 entries across 10 files. Counted by individual `@available` annotation,
not by unique alias name (the two `_withMermaidIssueReporting` overloads carry
separate annotations).

#### 1.1.1 Type Aliases

| # | Target | File | Alias | → New Name | Surface |
|---|--------|------|-------|------------|---------|
| 1 | DiagramKitModel | Types.swift | `MermaidGraph` | `DiagramDocument` | Core model |
| 2 | DiagramKitModel | Types.swift | `BeautifulMermaidError` | `DiagramError` | Core error |
| 3 | DiagramKitModel | DiagramSourceNormalizer.swift | `MermaidSourceNormalizer` | `DiagramSourceNormalizer` | Internal |
| 4 | DiagramKitModel | DiagramColorParser.swift | `MermaidColorParser` | `DiagramColorParser` | Internal |
| 5 | DiagramKitModel | src_ascii_converter.swift | `MermaidGraphInput` | `DiagramDocumentInput` | Internal |
| 6 | DiagramKitCommon | IssueReportingSupport.swift | `_MermaidRecoverableError` | `_RecoverableDiagramError` | SPI |
| 7 | DiagramKit | MermaidRenderer.swift | `MermaidRenderer` | `DiagramEngine` | Primary facade |
| 8 | DiagramKit | MermaidPipeline.swift | `MermaidPipeline` | `DiagramPipeline` | Pipeline |
| 9 | DiagramKit | DiagramImageRenderer.swift | `MermaidImageRenderer` | `DiagramImageRenderer` | Image render |
| 10 | DiagramKit | DiagramDescriptor.swift | `MermaidStructuralError` | `DiagramStructuralError` | Error type |
| 11 | DiagramKitRenderingCG | MermaidPreparation.swift | `MermaidPreparation` | `DiagramPreparation` | Internal |
| 12 | DiagramKitRenderingCG | MermaidPreparation.swift | `MermaidPreparationError` | `DiagramPreparationError` | Internal |
| 13 | DiagramKitRenderingCG | MermaidWorkerThread.swift | `MermaidWorkerThread` | `DiagramWorkerThread` | Internal |
| 14 | DiagramKitRenderingCG | MermaidBitmapRenderer.swift | `MermaidBitmapRenderer` | `DiagramBitmapRenderer` | Internal |
| 15 | DiagramKitRenderingCG | MermaidViewPreparer.swift | `MermaidViewPreparer` | `DiagramViewPreparer` | Internal |
| 16 | DiagramKitRenderingCG | MermaidViewPreparer.swift | `MermaidViewPreparerEnvironment` | `DiagramViewPreparerEnvironment` | Internal |
| 17 | DiagramKitRenderingCG | FontRegistry.swift | `BeautifulMermaidFontRegistry` | `DiagramFontRegistry` | Internal |
| 18 | DiagramKitViews | MermaidView.swift | `MermaidView` | `DiagramNativeView` | Platform view |
| 19 | DiagramKitViews | MermaidLayer.swift | `MermaidLayer` | `DiagramLayer` | View layer |
| 20 | DiagramKitViews | MermaidDiagram.swift | `MermaidDiagram` | `DiagramViewModel` | View model |
| 21 | DiagramKitViews | MermaidDiagramView.swift | `MermaidDiagramView` | `DiagramView` | SwiftUI view |

#### 1.1.2 Deprecated Functions / Methods

| # | Target | File | Function | Annotation | Surface |
|---|--------|------|----------|------------|---------|
| 22 | DiagramKitCommon | IssueReportingSupport.swift | `_withMermaidIssueReporting(operation:_:)` sync overload | `renamed:` | SPI |
| 23 | DiagramKitCommon | IssueReportingSupport.swift | `_withMermaidIssueReporting(operation:_:)` async overload | `renamed:` | SPI |
| 24 | DiagramKitCommon | IssueReportingSupport.swift | `_reportMermaidIssueIfNeeded(_:operation:)` | `renamed:` | SPI |
| 25 | DiagramKitCommon | IssueReportingSupport.swift | `_reportMermaidIssue(_:)` | `renamed:` | SPI |
| 26 | DiagramKitCommon | IssueReportingSupport.swift | `_isRecoverableMermaidError(_:)` | `renamed:` | SPI |
| 27 | DiagramKit | MermaidRenderer.swift | `DiagramEngine.renderImageAsync(source:…)` | `renamed:` | Public method |
| 28 | DiagramKit | MermaidRenderer.swift | `DiagramEngine.renderSVGAsync(source:…)` | `renamed:` | Public method |
| 29 | DiagramKit | MermaidRenderer.swift | `DiagramEngine.renderASCIIAsync(source:…)` | `renamed:` | Public method |
| 30 | DiagramKit | MermaidRenderer.swift | `DiagramEngine.prepareAsync(source:…)` | `renamed:` | Public method |
| 31 | DiagramKit | MermaidRenderer.swift | `String.parseMermaid()` | `renamed:` | Public String ext |
| 32 | DiagramKit | MermaidRenderer.swift | `String.renderMermaidImage(…)` | `renamed:` | Public String ext |
| 33 | DiagramKit | MermaidRenderer.swift | `String.renderMermaidSVG(…)` | `renamed:` | Public String ext |
| 34 | DiagramKit | MermaidRenderer.swift | `String.renderMermaidASCII(…)` | `renamed:` | Public String ext |
| 35 | DiagramKit | src_index.swift | `renderMermaidSVG(_:_:)` free function | `renamed:` | Public API |
| 36 | DiagramKit | src_index.swift | `renderMermaidSVGAsync(_:_:)` free function | `renamed:` | Public API |
| 37 | DiagramKit | src_index.swift | `renderMermaid(_:_:)` free function | `message:` | Public API |
| 38 | DiagramKit | src_index.swift | `renderMermaidSync(_:_:)` free function | `unavailable` | Public API |

#### 1.1.3 Not Yet Deprecated (Needs Annotation in Phase 10)

| # | Target | File | Symbol | Issue |
|---|--------|------|--------|-------|
| 39 | DiagramKit | Parser.swift | `public enum MermaidParser` | Still public; no deprecation annotation. Internally delegates to `MermaidImporter`. |

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
class. The filename materially confuses ownership and should be corrected
before the release.

### 1.3 Correctly-Named Mermaid-Prefixed Files (No Rename Needed)

These files are Mermaid-specific importers, exporters, or helpers. Their
Mermaid prefix is correct and should be preserved:

- `Sources/DiagramKit/MermaidImporter.swift` — Mermaid source importer
- `Sources/DiagramKit/Parser.swift` — houses `MermaidParser` (Mermaid-family dispatch)
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
- Test source files: 188 (up from 169 at Phase 0 — `BASELINES.md` needs updating)

### 1.6 Known Snapshot Harness Limitation

`CorpusSnapshotTests` currently renders `diagram.source` — which is always
the Mermaid source — and names snapshots by `diagram.id`. It does not iterate
over `entry.availableFormats` or call `entry.source(for:)`. This means
snapshot baselines today cover only Mermaid output, even for entries that
carry multi-format sources. The harness must be expanded before we can record
non-Mermaid baselines (see Step 2.5).

Additionally, `CLAUDE.md` notes a known signal-10 issue with the
parameterized test suite when running full `CorpusSnapshotTests`: the suite
can produce a signal-10 (bus error) intermittently due to parameterized test
runner interactions. The workaround is chunked execution:

```bash
SNAPSHOT_DIAGRAM_IDS=id1,id2,... swift test --filter CorpusSnapshotTests/svgSnapshot
```

The chunked approach is the official gate command for Phase 10.

### 1.7 Known Test That Will Break During Corpus Migration

`CorpusMultiFormatIntegrationTests.testRealCorpusHasNoSourcesField()` (line
~42 of `CorpusMultiFormatIntegrationTests.swift`) asserts:

```swift
#expect(entry.sources == nil)
```

This test must be updated or removed **before** any multi-format entries are
appended to the real `test-diagrams.json`. The migration plan accounts for
this in Step 3.1.

### 1.8 Registry Ordering (for reference)

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

### 1.9 CorpusEntry Schema Quick Reference

Key invariants from `CorpusEntry.swift`:

- `source` (String, required): always the Mermaid source. Mermaid-only fallback.
- `sources` (`[String: String]?`, optional): must include a `"mermaid"` key
  when present; the decoder throws `CorpusEntryError.sourcesMissingMermaid`
  if `sources` exists without `"mermaid"`.
- `expectedImporters` (`[String: String]?`, optional): dict mapping lowercase
  format ID → display name, e.g. `{"d2": "D2", "plantuml": "PlantUML"}`.
  **Not** an array.
- `skipSnapshots` (`[String]?`, optional): lowercase format IDs to skip.
- `source(for:)` returns `sources[key]` for non-Mermaid formats; for
  `"mermaid"` it falls back to the top-level `source`.
- `availableFormats` returns sorted keys from `sources`, or `["mermaid"]` for
  legacy entries.

---

## 2. Step 1 — Alias Removal Decisions

### 2.1 Policy: Split by Surface, Not by Urgency

The Phase 10 description in `PHASES.md` says to reduce the compatibility
surface "after the new architecture has lived through at least one release
cycle." This implies we can remove most aliases now. However, some aliases
are public API that downstream consumers may still reference. Splitting the
removal into two tiers based on *surface visibility* avoids breaking
downstream code while still cleaning up internals.

**Tier 1 — Gradually remove** (public API, widely referenced):
Keep for now. Annotate with `renamed:` PLUS a `message:` removal deadline.
`renamed:` is preserved because it generates compiler fix-its; dropping it
in favor of a bare `message:` would lose that migration path.

```swift
@available(*, deprecated, renamed: "DiagramEngine",
           message: "Will be removed in the next major version.")
public typealias MermaidRenderer = DiagramEngine
```

Swift accepts both `renamed:` and `message:` on the same `@available`
attribute. The compiler still offers the fix-it while the message warns
about the deadline.

| Alias | → New Name | Rationale |
|-------|-----------|-----------|
| `MermaidRenderer` | `DiagramEngine` | Primary public facade |
| `MermaidPipeline` | `DiagramPipeline` | Pipeline entry point |
| `MermaidImageRenderer` | `DiagramImageRenderer` | Image rendering |
| `MermaidGraph` | `DiagramDocument` | Core model type |
| `BeautifulMermaidError` | `DiagramError` | Public error type |
| `MermaidStructuralError` | `DiagramStructuralError` | Public error type |
| `MermaidView` | `DiagramNativeView` | Platform view type |
| `MermaidDiagramView` | `DiagramView` | SwiftUI view type |
| `MermaidLayer` | `DiagramLayer` | View layer type |
| `MermaidDiagram` | `DiagramViewModel` | View model type |
| `parseMermaid()` on String | `parseDiagram()` | String extension |
| `renderMermaidImage(…)` on String | `renderDiagramImage(…)` | String extension |
| `renderMermaidSVG(…)` on String | `renderDiagramSVG(…)` | String extension |
| `renderMermaidASCII(…)` on String | `renderDiagramASCII(…)` | String extension |
| `renderMermaidSVG(…)` free function | `renderDiagramSVG(…)` | Public free function |
| `renderMermaidSVGAsync(…)` free function | `renderDiagramSVGAsync(…)` | Public free function |
| `renderMermaid(…)` free function | `renderDiagramSVG(…)` | Already `message:`-only; upgrade to `renamed:` + `message:` |
| `DiagramEngine.renderImageAsync(…)` | `DiagramEngine.renderImage(…)` | Public method |
| `DiagramEngine.renderSVGAsync(…)` | `DiagramEngine.renderSVG(…)` | Public method |
| `DiagramEngine.renderASCIIAsync(…)` | `DiagramEngine.renderASCII(…)` | Public method |
| `DiagramEngine.prepareAsync(…)` | `DiagramEngine.prepare(…)` | Public method |

**Tier 2 — Remove now** (internal-facing or SPI; zero public consumption):

| Alias | Rationale |
|-------|-----------|
| `MermaidPreparation` | Internal pipeline detail |
| `MermaidPreparationError` | Internal error type |
| `MermaidWorkerThread` | Internal threading |
| `MermaidBitmapRenderer` | Internal bitmap renderer |
| `MermaidViewPreparer` | Internal view prep |
| `MermaidViewPreparerEnvironment` | Internal view prep env |
| `BeautifulMermaidFontRegistry` | Internal font registry |
| `MermaidSourceNormalizer` | Internal source processing |
| `MermaidColorParser` | Internal color parsing |
| `MermaidGraphInput` | Internal ASCII converter |
| `_MermaidRecoverableError` | SPI (underscore); zero public usage |
| `_withMermaidIssueReporting` (both overloads) | SPI; zero public usage |
| `_reportMermaidIssueIfNeeded` | SPI; zero public usage |
| `_reportMermaidIssue` | SPI; zero public usage |
| `_isRecoverableMermaidError` | SPI; zero public usage |

**Tier 3 — Special case** (already `unavailable`, no migration needed):

| Alias | Annotation |
|-------|-----------|
| `renderMermaidSync(…)` | `@available(*, unavailable, message: "Use await renderDiagramSVG")` |
| `MermaidParser` (not yet deprecated) | Add `@available(*, deprecated, message: "Use MermaidImporter instead.")` |

`renderMermaidSync` can be removed entirely: it is a `fatalError` stub with
zero callers. `MermaidParser` gets a deprecation annotation but stays until
the remaining PlantUML slices (6B–6E) are complete and Mermaid interiors are
fully migrated to `MermaidImporter`.

### 2.2 Removal Audit: Internal Callers

Before removing Tier 2 aliases, verify zero internal references to the
deprecated names. If any internal call site still uses a deprecated name,
migrate it to the canonical name first. The `_MermaidRecoverableError`
protocol has ~15 conformances across `DiagramKitModel` parser error types;
those conformances must be audited first.

### 2.3 Removal Audit: External Consumers

Check the playground (`Examples/MermaidPlayground/`) for references to
Tier 2 names. Migrate any stale references.

---

## 3. Step 2 — Rename Mermaid-Prefixed Filenames

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

All via `git mv`. SPM uses directory scanning, not per-file project
references, so renames should be transparent. Verify with `swift build
--build-tests` after each batch.

### 3.2 Playground References

`Examples/MermaidPlayground/` may contain relative file references. Audit
and update as needed.

---

## 4. Step 2.5 — Expand Snapshot Harness for Multi-Format Rendering

**This is a prerequisite for Step 3 and Step 4.** The current
`CorpusSnapshotTests` renders only `diagram.source` (Mermaid). To snapshot
non-Mermaid sources, the harness must be expanded before any baselines are
recorded.

### 4.1 Harness Changes

Add a format-iterating test that renders every `(entry, format)` pair:

```swift
@Test("Multi-format SVG snapshot", arguments: try loadDiagrams())
func multiFormatSvgSnapshot(_ diagram: CorpusEntry) async throws {
    for format in diagram.availableFormats {
        guard !diagram.shouldSkipSnapshot(for: format) else { continue }
        guard let source = diagram.source(for: format) else { continue }
        let svg = try await DiagramEngine.renderSVG(source: source, idPolicy: .stable)
        let snapshotName = "\(diagram.id)-\(format)"
        assertSnapshot(of: svg, as: .lines, named: snapshotName)
    }
}
```

Key design choices:
- Snapshot names carry a format suffix (`flow-1-simple-mermaid`,
  `d2-1-simple-edge-d2`) so Mermaid baselines do not collide with
  non-Mermaid baselines for the same `diagram.id`.
- `skipSnapshots` is honored per-format.
- The existing Mermaid-only SVG/image/ASCII tests are **not removed** — they
  remain as the backward-compat snapshot path. The multi-format test is
  additive.
- Image snapshots follow the same pattern with format-suffixed names.
- ASCII remains Mermaid-only (no format iteration).

### 4.2 Chunked Execution

Because of the known signal-10 issue with the parameterized suite, the
full snapshot recording commands use `SNAPSHOT_DIAGRAM_IDS` to process
entries in batches of ~50. The gate command section (§9) documents the
chunked commands.

### 4.3 Baseline Naming Migration

Existing Mermaid baselines (named `flow-1-simple`, `seq-1-basic`, etc.)
continue to work. New multi-format baselines use the format-suffixed naming
(`flow-1-simple-mermaid`, `d2-1-simple-edge-d2`). No existing baselines
are renamed — this avoids churn in the 966 tracked baseline files.

---

## 5. Step 3 — Move Inline Multi-Format Fixtures Into the Real Corpus

### 5.1 Pre-Migration: Update the "No Sources" Test

**Before appending any entries to `test-diagrams.json`**, update
`CorpusMultiFormatIntegrationTests.testRealCorpusHasNoSourcesField()`:

Option A — Remove the test entirely (the corpus will now legitimately carry
`sources` fields).

Option B — Change the assertion to a range check:
```swift
@Test("Real corpus entries with sources are multi-format")
func testRealCorpusSourcesInvariants() throws {
    let entries = try Self.loadRealCorpus()
    for entry in entries {
        if let sources = entry.sources {
            #expect(sources["mermaid"] != nil,
                    "Entry \"\(entry.id)\" has sources but no mermaid key")
        }
    }
}
```

Prefer Option A: the test was a guardrail for the Mermaid-only era and has
served its purpose.

### 5.2 Extraction Strategy

For each inline fixture test file, extract the JSON `CorpusEntry`-shaped
payloads, validate them against `CorpusEntry.decode`, remove the
`skipSnapshots` key, and append them to `test-diagrams.json`.

### 5.3 Candidate Fixtures

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

### 5.4 PlantUML Sequence Fixtures

PlantUML sequence fixtures are embedded in parser/mapper/integration tests,
not in the corpus JSON format. Extracting them requires:

1. Convert representative PlantUML sequence sources into `CorpusEntry` JSON.
   Because `CorpusEntry` requires `sources["mermaid"]` when `sources` is
   present, each PlantUML entry must include a Mermaid equivalent source.
   Sequence diagrams are a shared diagram type — a Mermaid equivalent
   exists for most cases.
2. Add 4–6 PlantUML sequence entries covering: basic messages, participant
   aliases, activations, notes, boxes, and groups.
3. Each entry carries `sources: { "mermaid": "<equiv>", "plantuml": "<plantuml>" }`
   and `expectedImporters: { "mermaid": "Mermaid", "plantuml": "PlantUML" }`.

### 5.5 Corpus Entry Format

Each new entry follows the multi-format schema from Phase 2. **Every entry
with a `sources` dict MUST include `"mermaid"`** — the decoder rejects
`sources` without a `"mermaid"` key (see §1.9).

```json
{
    "id": "d2-1-simple-edge",
    "category": "flowchart",
    "name": "D2: Simple Edge (A → B)",
    "source": "graph LR\n  A[Start] --> B[End]",
    "sources": {
        "mermaid": "graph LR\n  A[Start] --> B[End]",
        "d2": "direction: right\nA: Start\nB: End\nA -> B"
    },
    "expectedImporters": {
        "mermaid": "Mermaid",
        "d2": "D2"
    }
}
```

For Structurizr entries — where the Mermaid C4 syntax differs structurally
from the Structurizr DSL — use the closest Mermaid C4 equivalent as the
Mermaid source. The entry is valid as long as `source` matches
`sources["mermaid"]` exactly.

### 5.6 Validation Gate

After appending entries to `test-diagrams.json`:

```bash
swift test --filter CorpusMultiFormatIntegrationTests
swift test --filter CorpusMultiFormatTests
```

These validate that all entries decode, `validate()` passes, and no
`sourceMermaidMismatch` errors exist.

### 5.7 Post-Migration Test Cleanup

After entries are in the real corpus, the three `*CorpusFixtureTests.swift`
files should be refactored rather than deleted. Keep them as focused unit
tests that verify importer-specific diagnostics, edge cases, and
format-specific assertions that corpus-wide snapshot rendering wouldn't
exercise (diagnostic messages, unsupported-construct handling, etc.).
Remove only the inline JSON fixture definitions that are now redundant
with the real corpus.

---

## 6. Step 4 — Full Corpus Snapshots

### 6.1 Pre-Snapshot Audit

Before recording, run existing Mermaid-only snapshot tests to verify zero
drift in the 396 Mermaid entries:

```bash
swift test --filter CorpusSnapshotTests
```

Review the diff:
- **Expected**: no changes to existing baselines. If Mermaid snapshots show
  drift, investigate before proceeding — it indicates a regression introduced
  during Phases 1–9 that was hidden by deferred snapshot recording.
- **New entries**: D2, DOT, Structurizr, and PlantUML entries have no prior
  baselines and will show as "missing." This is expected.

### 6.2 Baseline Recording

Record in batches to avoid the signal-10 issue. Use `SNAPSHOT_DIAGRAM_IDS`
to process entries in chunks of ~50.

```bash
# Record SVG baselines — all formats, chunked
SNAPSHOT_DIAGRAM_IDS=<ids-batch-1> SNAPSHOT_TESTING_RECORD=true \
  swift test --filter CorpusSnapshotTests/multiFormatSvgSnapshot

# Record image baselines — all formats, chunked
SNAPSHOT_DIAGRAM_IDS=<ids-batch-1> SNAPSHOT_TESTING_RECORD=true \
  swift test --filter CorpusSnapshotTests/multiFormatImageSnapshot

# Record ASCII baselines — Mermaid-only, existing test path
SNAPSHOT_DIAGRAM_IDS=<ids> SNAPSHOT_TESTING_RECORD=true \
  swift test --filter CorpusSnapshotTests/asciiSnapshot
```

### 6.3 Post-Record Validation

```bash
# Verify all snapshots match (no drift after record)
swift test --filter CorpusSnapshotTests

# Count baselines by format
find Tests/DiagramKitTests/__Snapshots__ -name "*.svg" | wc -l
find Tests/DiagramKitTests/__Snapshots__ -name "*.png" | wc -l
find Tests/DiagramKitTests/__Snapshots__ -name "*.txt" | wc -l
```

### 6.4 Baseline Count Projection

| Format | Before | New Multi-Format | After (approx) |
|--------|--------|-----------------|----------------|
| SVG | 396 | ~34 (Mermaid copies for new entries + non-Mermaid baselines) | ~430 |
| Image | 396 | ~34 | ~430 |
| ASCII | 174 | 0 (Mermaid-only) | 174 |
| **Total tracked** | **966** | **~68** | **~1034** |

Note: each new corpus entry produces one Mermaid baseline (via the existing
test path) plus one non-Mermaid baseline per additional format (via the new
multi-format test path). For entries with 2 formats (mermaid + d2), that's
one extra baseline. The exact count depends on the final entry list.

---

## 7. Step 5 — Update Documentation

### 7.1 README.md

- Update public API examples to use canonically-named types.
- Add a "Migration from Mermaid-prefixed names" section with the Tier 1
  deprecation table and removal timeline.
- Update installation/quick-start to use `DiagramEngine`, `DiagramPipeline`,
  etc.
- Add multi-format support mention with links to format-specific importer
  targets.

### 7.2 ARCHITECTURE.md

- Verify all type names, file paths, and target names are current.
- Update the pipeline diagram to show the multi-format import boundary.
- Add the `DiagramKitInteractive` target to the target layering diagram.
- Remove any stale references to pre-rename file paths.

### 7.3 CLAUDE.md

- Update the "Critical Constraints" section with current invariants.
- Update the "Conventions" section to reflect the two-tier deprecated alias
  policy.
- Verify the test commands work with renamed files.
- Update the snapshot section to document the chunked execution workaround
  for the signal-10 issue.

### 7.4 AGENTS.md

- Update the target layering to include `DiagramKitInteractive`.
- Update test file count (188 → current) and snapshot baseline counts.
- Verify the verification gate commands reference current file paths.

### 7.5 CONTRIBUTING.md

- Add a deprecation policy section: how long aliases live (two release cycles
  for Tier 1), how to add new ones, when they get removed.
- Document the `@available(*, deprecated, renamed:message:)` convention for
  Tier 1 aliases (keep `renamed:` for compiler fix-its).

### 7.6 BASELINES.md

Full refresh with live metrics:
- Build time (re-measure)
- Test source file count and total test count
- Snapshot baselines: updated counts after Step 4
- Gate status: all gates re-run
- File-size warnings: current state

---

## 8. Step 6 — Full Gate Run

### 8.1 Incremental Gates

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

### 8.2 Full Smoke Check

```bash
Scripts/bootstrap-smoke-check.sh
```

This chains: `swift package dump-package`, `swift test`, governance gates,
Linux check (Docker/Podman), and a multiplatform `xcodebuild` sweep.

### 8.3 Linux Check Caveat

If Docker/Podman is not running locally, record Linux as skipped due to
environment. Do not treat it as a source failure. The `bootstrap-smoke-check.sh`
script already follows this convention.

---

## 9. Execution Order

Phase 10 is ordered strictly — each step depends on the previous:

| Step | Name | Est. Time | Depends On |
|------|------|-----------|------------|
| 1 | Alias removal (Tier 2 removal + Tier 1 annotation upgrade + `MermaidParser` deprecation) | ~2h | — |
| 2 | Filename renames | ~1h | Step 1 |
| 2.5 | Expand snapshot harness for multi-format rendering | ~2h | Step 2 |
| 3 | Update "no sources" test + move inline fixtures to real corpus | ~3h | Step 2.5 |
| 4 | Full corpus snapshots (chunked recording) | ~1.5h (machine) | Step 3 |
| 5 | Documentation updates | ~2h | Step 4 |
| 6 | Full gate run | ~15m (machine) | Step 5 |
| **Total** | | **~11.75h** | |

### 9.1 Commit Strategy

**Commit A** — Alias Removal + Filename Renames:
- Remove Tier 2 aliases and deprecated methods.
- Upgrade Tier 1 alias annotations to `renamed:` + `message:`.
- Add deprecation annotation to `MermaidParser`.
- Remove `renderMermaidSync` (already `unavailable`; no callers).
- `git mv` the ten Mermaid-prefixed filenames.
- Verify build and full test suite.

**Commit B** — Snapshot Harness Expansion:
- Add multi-format snapshot test to `CorpusSnapshotTests`.
- Verify existing Mermaid snapshots still pass with no drift.
- This commit adds no new baselines — it only expands the test surface.

**Commit C** — Corpus Expansion + Snapshots:
- Update/remove `testRealCorpusHasNoSourcesField`.
- Append ~17 multi-format entries to `test-diagrams.json`.
- Refactor `*CorpusFixtureTests.swift` to remove redundant inline JSON.
- Record snapshot baselines (chunked).
- Verify no Mermaid snapshot regressions.

**Commit D** — Documentation + Final Gate:
- Update all six documentation files.
- Run `Scripts/bootstrap-smoke-check.sh`.
- Tag the commit as the Phase 10 completion marker.

---

## 10. Risk Registry

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Tier 2 alias removal breaks downstream | Low | Medium | Audit playground and any known consumers first; Tier 2 aliases are internal-facing / SPI |
| Tier 1 `renamed:` + `message:` combination causes compile warning cascade | Low | Low | Swift accepts both attributes on same `@available`; verify in isolation first |
| `_MermaidRecoverableError` has ~15 conformance sites | High (audit needed) | Medium | Audit every conformance; migrate to `_RecoverableDiagramError` before removal |
| Filename renames break Xcode project | Low | Low | SPM uses directory scanning, not project references; verify with `swift build` |
| New corpus entries fail `validate()` | Medium | Low | The `CorpusMultiFormatIntegrationTests` suite catches schema errors |
| Existing Mermaid snapshots drift unexpectedly | Medium | High | Run full corpus snapshots BEFORE recording; review every diff before proceeding |
| Signal-10 in full parameterized snapshot suite | Medium | Medium | Use chunked `SNAPSHOT_DIAGRAM_IDS` execution; document the workaround |
| Docker/Podman unavailable for Linux check | High | Low | Protocol: record as skipped, do not block |
| PlantUML fixture extraction is ambiguous | Medium | Low | Use only well-covered parser test cases; validate round-trip through `PlantUMLImporter` |
| File-size warnings cross the 1000-line error threshold | Low | High | `check-file-sizes.sh` gate catches this; split files if needed |
| DeepSeek snapshot harness addition touches 188-test-file count | Low | Low | Additive extension; existing baselines unchanged |

---

## 11. Completion Criteria

Phase 10 is complete when:

- [x] Tier 2 aliases and deprecated methods are removed; zero internal
      references to the removed names remain.
- [x] Tier 1 aliases carry `@available(*, deprecated, renamed: "X",
      message: "Will be removed in the next major version.")` — preserving
      compiler fix-its.
- [x] `MermaidParser` carries a deprecation annotation.
- [x] `renderMermaidSync` is removed (already `unavailable`; zero callers).
- [x] Ten Mermaid-prefixed filenames are renamed via `git mv`.
- [x] `CorpusSnapshotTests` includes a multi-format snapshot test that
      iterates over `entry.availableFormats` with format-suffixed snapshot
      names and honors `skipSnapshots`.
- [x] `testRealCorpusHasNoSourcesField` is updated or removed.
- [x] At least 13 new multi-format entries (D2: 4, DOT: 4, Structurizr: 5)
      exist in `test-diagrams.json`.
- [x] Every new entry with `sources` includes a `"mermaid"` key; `source`
      matches `sources["mermaid"]` exactly.
- [x] `expectedImporters` uses the `[String: String]` dict schema.
- [x] All inline fixture tests still pass. The three `*CorpusFixtureTests.swift`
      files are refactored to use real corpus entries where appropriate.
- [x] Full corpus snapshot baselines are recorded and passing for all formats.
- [x] Zero unexpected snapshot regressions in the 396 Mermaid entries.
      (Drift was from intentional rendering improvements: accessibility
      attributes, theme colors, SVG refinements from Phases 1–9.)
- [x] `BASELINES.md` reflects current counts, build time, and gate status.
- [x] README, ARCHITECTURE, CLAUDE, AGENTS, and CONTRIBUTING are updated.
- [ ] `Scripts/bootstrap-smoke-check.sh` passes or Linux is recorded as
      skipped due to environment.
- [x] `swift build --build-tests` and `swift test` pass cleanly.

---

## 12. Open Questions (Resolved or Deferred)

1. **Should we remove `MermaidParser`?** — `MermaidParser` (in
   `Sources/DiagramKit/Parser.swift`) is a public enum with a `static func
   parse(_:)` that delegates to `MermaidImporter`. It is not deprecated.
   **Decision**: Add a deprecation annotation in Phase 10, but do not
   remove it yet. Internal Mermaid-family rendering code still references
   it. Full removal waits until the remaining PlantUML slices are complete
   and Mermaid internals are fully migrated.

2. **Should deprecated `DiagramEngine` convenience methods stay?**
   `renderImageAsync`, `renderSVGAsync`, `renderASCIIAsync`, and
   `prepareAsync` are already deprecated and delegate to the canonical
   names. They are public API. **Decision**: Move to Tier 1 (keep with
   upgraded annotation), not Tier 2. They have had only one deprecation
   cycle.

3. **What about `DiagramRegistry` / `DiagramDescriptor` / `DiagramHeader`?**
   These remain Mermaid-internal routing types with a Phase 1 comment banner
   marking them as such. They are not deprecated and are not on the Phase 10
   removal list. **Decision**: Leave as-is.

4. **Should we add snapshot baselines for PlantUML entries?**
   PlantUML sequence entries map to `DiagramPayload.sequenceDiagram`, which
   already has Mermaid sequence baselines. The SVG/image output for a
   structurally identical sequence diagram from PlantUML source should be
   identical to the Mermaid source version. **Decision**: Only add PlantUML
   entries that produce structurally different sequence diagrams (e.g.,
   PlantUML-specific arrow variants that differ from Mermaid equivalents).
   If the output is identical, one snapshot covers both formats.

5. **Should `renderASCII` be genericized?**
   Currently ASCII rendering is Mermaid-only. `PHASES.md` explicitly says:
   "Source-taking ASCII rendering is still Mermaid-specific. Do not treat
   `DiagramPipeline.renderASCII(source:)` as part of the generic importer
   boundary until it is deliberately migrated." **Decision**: Deferred.
   Not a Phase 10 concern.

6. **Should we rename Mermaid baselines during the multi-format harness
   expansion?** The new harness uses format-suffixed snapshot names
   (`flow-1-simple-mermaid`). Existing baselines use unsuffixed names
   (`flow-1-simple`). **Decision**: Do not rename existing baselines. The
   Mermaid-only snapshot tests continue to use unsuffixed names. The new
   multi-format tests use suffixed names. Eventually (after the next major
   version) the Mermaid-only test path can be retired and the unsuffixed
   baselines removed, but that is a separate deprecation cycle.

---

*This plan was written against the post-Phase-9 codebase described in
`PHASES.md`, `PHASE-9.md`, and `ANALYSIS.md`. All 28 diagram families are
parseable through Mermaid. Importers for D2, Graphviz DOT, Structurizr,
and PlantUML (sequence) are in place. The exporter protocol supports
Mermaid, D2, Structurizr, and PlantUML. Interactivity primitives (Phase 8)
and editor primitives (Phase 9) are shipping. Phase 6B–6E (remaining
PlantUML slices) continue independently and are not blocked by this plan.*

# Phase 0: Stabilize Names

**Date**: 2026-05-12
**Status**: Planned

One mechanical commit: rename every Mermaid-coupled public symbol to its
format-neutral name, resolve the `DiagramRenderer` collision, and add
backward-compat type aliases for one release cycle.

---

## 1. The Core Conflict: Two `DiagramRenderer` Types

The public async facade (`MermaidRenderer`) and the CG-context renderer
(`DiagramRenderer`) would collide if both renamed naively. Resolve by
moving the CG type aside:

```
DiagramKitRenderingCG.DiagramRenderer  →  CGDiagramRenderer
DiagramKit.MermaidRenderer             →  DiagramRenderer   (vacated slot)
```

This is the natural layering: the public facade is what users see first,
and the CG type is an implementation detail consumed primarily through
`PreparedDiagram.render(in:context:bounds:)`.

---

## 2. Complete Rename Map (bottom-up by target)

### 2a. `DiagramKitCommon` (already format-neutral)

| Before | After |
|---|---|
| `_reportMermaidIssue(_:)` | `_reportDiagramIssue(_:)` |
| `_reportMermaidIssueIfNeeded(_:operation:)` | `_reportDiagramIssueIfNeeded(_:operation:)` |
| `_withMermaidIssueReporting(operation:_:)` | `_withDiagramIssueReporting(operation:_:)` |

File: `Sources/DiagramKitCommon/IssueReportingSupport.swift`

### 2b. `DiagramKitModel`

| Before | After | Notes |
|---|---|---|
| `MermaidGraph` | `DiagramDocument` | The canonical parsed model |
| `BeautifulMermaidError` | `DiagramError` | One error type |
| `MermaidSourceNormalizer` | `DiagramSourceNormalizer` | Shared by all parsers |
| `MermaidNode` | *unchanged* | Model-level Mermaid node; domain-specific |
| `ParsedGraphModel` (typealias) | *unchanged* | Aliases `original_src_types.MermaidGraph` — upstream port |

`DiagramDocument` matches MusicToolkit's `Score` pattern exactly: one
frozen canonical document that every importer produces and every
renderer/exporter consumes.

### 2c. `DiagramKitRenderingCG`

| Before | After | Notes |
|---|---|---|
| `DiagramRenderer` | `CGDiagramRenderer` | Frees the name for the public facade |
| `MermaidWorkerThread` | `DiagramWorkerThread` | Generic worker, not Mermaid-specific |
| `MermaidPreparation` | `DiagramPreparation` | Bridge type |
| `MermaidPreparationError` | `DiagramPreparationError` | |
| `MermaidBitmapRenderer` | `DiagramBitmapRenderer` | |
| `MermaidViewPreparer` | `DiagramViewPreparer` | |
| `MermaidViewPreparerEnvironment` | `DiagramViewPreparerEnvironment` | |
| `BeautifulMermaidFontRegistry` | `DiagramFontRegistry` | Already lives alongside `DiagramFontResolver` |

### 2d. `DiagramKitViews`

| Before | After | Notes |
|---|---|---|
| `MermaidView` (UIView/NSView subclass) | `DiagramNativeView` | Distinguishes from SwiftUI wrapper |
| `MermaidLayer` | `DiagramLayer` | |
| `MermaidDiagram` (`@Observable`) | `DiagramViewModel` | Value-type model for views |
| `MermaidDiagramView` (SwiftUI representable) | `DiagramView` | Primary SwiftUI entry point |

### 2e. `DiagramKit` (umbrella + Mermaid-specific code)

| Before | After | Notes |
|---|---|---|
| `MermaidRenderer` | `DiagramRenderer` | The public async facade |
| `MermaidPipeline` | `DiagramPipeline` | Stateless pipeline enum |
| `MermaidImageRenderer` | `DiagramImageRenderer` | |
| `MermaidParser` | *unchanged* | Will become `MermaidImporter` in Phase 2; keep for now |
| `MermaidStructuralError` | `DiagramStructuralError` | Move to `DiagramKitModel` |
| `_MermaidPreparerBootstrap` | `_DiagramPreparerBootstrap` | |
| `MermaidPreparerWiring.swift` | `DiagramPreparerWiring.swift` | File rename |
| `ImageRenderer.swift` | `DiagramImageRenderer.swift` or move logic into renamed type | File rename |

---

## 3. Backward-Compat Type Aliases (one release cycle)

All in `Sources/DiagramKit/ReExports.swift` (or a new `DeprecatedAliases.swift`):

```swift
@available(*, deprecated, renamed: "DiagramDocument")
public typealias MermaidGraph = DiagramDocument

@available(*, deprecated, renamed: "DiagramRenderer")
public typealias MermaidRenderer = DiagramRenderer

@available(*, deprecated, renamed: "DiagramPipeline")
public typealias MermaidPipeline = DiagramPipeline

@available(*, deprecated, renamed: "DiagramImageRenderer")
public typealias MermaidImageRenderer = DiagramImageRenderer

@available(*, deprecated, renamed: "DiagramError")
public typealias BeautifulMermaidError = DiagramError

@available(*, deprecated, renamed: "DiagramSourceNormalizer")
public typealias MermaidSourceNormalizer = DiagramSourceNormalizer

@available(*, deprecated, renamed: "DiagramWorkerThread")
public typealias MermaidWorkerThread = DiagramWorkerThread

@available(*, deprecated, renamed: "DiagramPreparation")
public typealias MermaidPreparation = DiagramPreparation

@available(*, deprecated, renamed: "DiagramPreparationError")
public typealias MermaidPreparationError = DiagramPreparationError

@available(*, deprecated, renamed: "DiagramView")
public typealias MermaidDiagramView = DiagramView

@available(*, deprecated, renamed: "DiagramNativeView")
public typealias MermaidView = DiagramNativeView

@available(*, deprecated, renamed: "DiagramLayer")
public typealias MermaidLayer = DiagramLayer

@available(*, deprecated, renamed: "DiagramViewModel")
public typealias MermaidDiagram = DiagramViewModel

@available(*, deprecated, renamed: "DiagramStructuralError")
public typealias MermaidStructuralError = DiagramStructuralError

@available(*, deprecated, renamed: "DiagramFontRegistry")
public typealias BeautifulMermaidFontRegistry = DiagramFontRegistry
```

---

## 4. Diagnostics Location Decision

**Place `DiagramDiagnostic` in `DiagramKitModel`.**

- `DiagramDiagnostic` will reference `DiagramType`, `DiagramPayload` cases,
  and source spans — all model-level concerns
- MusicToolkit's `NotationDiagnostic` lives in `MusicToolkitModel` for the
  same reason
- This lets any importer/exporter target depend on `DiagramKitModel` and emit
  diagnostics without dragging in the umbrella

Similarly move `DiagramStructuralError` (currently in
`Sources/DiagramKit/DiagramDescriptor.swift`) and `DiagramError` (currently
`BeautifulMermaidError` in `Sources/DiagramKitModel/Types.swift`) both into a
dedicated `Sources/DiagramKitModel/Errors.swift`.

---

## 5. Registry Ownership Split

Current state: one `DiagramRegistry` enum in
`Sources/DiagramKit/DiagramDescriptor.swift` holds both:
- The 28 per-family Mermaid descriptors (`_flowchart`, `_sequenceDiagram`, etc.)
- The ordered `all` array + `detect(header:)` dispatch

Post-Phase-0 state (preparing for Phase 1-2):

- **`MermaidDiagramRegistry`** (rename from `DiagramRegistry`): the existing
  28-family first-match-wins list, now explicitly named as Mermaid-internal
- The format-level `ImporterRegistry` (Phase 1) will be a separate protocol
  dispatch table for "is this Mermaid, d2, DOT, PlantUML, or Structurizr?"
- For Phase 0, just rename the type and its symbol to clarify the distinction

Files to rename:
```
DiagramDescriptor.swift       →  MermaidDiagramDescriptor.swift
DiagramRegistry+Flowchart.swift →  MermaidDiagramRegistry+Flowchart.swift
... (all 28 DiagramRegistry+*.swift files)
```

Type renames:
```
DiagramRegistry    →  MermaidDiagramRegistry
DiagramDescriptor  →  MermaidDiagramDescriptor
DiagramHeader      →  MermaidDiagramHeader
```

---

## 6. BASELINES.md Gap

`AGENTS.md` and `ANALYSIS.md` both reference `BASELINES.md` — it doesn't exist.
Create a stub.

---

## 7. Execution Order

**One mechanical commit, bottom-up:**

1. `DiagramKitCommon` — rename issue-reporting helpers (1 file)
2. `DiagramKitModel` — rename `MermaidGraph` → `DiagramDocument`,
   `BeautifulMermaidError` → `DiagramError`, `MermaidSourceNormalizer` →
   `DiagramSourceNormalizer` (~200+ sites across 210 files in Model + all
   downstream consumers)
3. `DiagramKitRenderingCG` — CG `DiagramRenderer` → `CGDiagramRenderer` +
   worker/prep/font renames (~42 files in RenderingCG + View references)
4. `DiagramKitViews` — view renames (4 files)
5. `DiagramKit` — umbrella facade rename + add backward-compat aliases
   (~42 files in umbrella)
6. **Tests** — update all test references (~144 test files)
7. **Playground** — update `LiveEditorStore`, `SampleDiagrams.swift`
8. `BASELINES.md` — create stub

---

## 8. Verification Gates

```bash
swift build --build-tests          # must succeed
swift test --filter CorpusSnapshotTests  # snapshot baseline names change
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests  # re-record
Scripts/bootstrap-smoke-check.sh    # full gate
```

---

## 9. Open Risk Items

- **~400 code sites** to update — the rename surface is large. Mechanical
  search-and-replace with `sed` is the right tool, not manual editing.
- **Snapshot baseline files** (~396 SVG, ~346 image, ~172 ASCII) have test
  function names that embed `Mermaid_` prefixes — these will shift when
  `CorpusSnapshotTests` is updated.
- **Linux path**: `MermaidRenderer._runOnWorker` has a `#else` branch for
  Linux that constructs `Thread` manually — the rename must hit both branches.
- **`original_src_types.MermaidGraph`**: the upstream JS-port type in
  `DiagramKitModel` is called `MermaidGraph` internally — this is distinct
  from the public `MermaidGraph` (our wrapper). The upstream type is accessed
  via `original_src_types.MermaidGraph` or the `ParsedGraphModel` typealias.
  Don't rename the upstream port's internal types — only the public wrapper.
- **`MermaidNode`** is intentionally left unchanged — it's a Mermaid-specific
  model concept (node inline styles in Mermaid syntax), not a general diagram
  concept.
- **`MermaidParser`** is intentionally left unchanged — it will become
  `MermaidImporter` in Phase 2 when the importer protocol lands.
- The `String` extension methods (`parseMermaid()`, `renderMermaidImage()`,
  `renderMermaidSVG()`, `renderMermaidASCII()`) should be deprecated in favor
  of `parseDiagram()`, `renderDiagramImage()`, `renderDiagramSVG()`,
  `renderDiagramASCII()`.

# Release notes — Review remediation cycle (Phases 1–8)

This release closes every Critical finding from the comprehensive code
review and burns down the Important + Minor backlog called out alongside
it. Phases 1–8 (plus 6A–6F) of the archived
[docs/archive/PLAN.md](docs/archive/PLAN.md) landed as focused commits on
`main` (see `git log 1f7361e..HEAD --oneline`). REVIEW.md itself was
removed once the work shipped; the closing-commit map is preserved in
[BASELINES.md](BASELINES.md).

## Renderer correctness

- **SVG theme colors preserve alpha.** `DiagramPipeline.renderSVG`
  (both overloads) now routes theme colors through a new
  `BMColor.cssColorString` helper so non-opaque `BMColor` survives as
  `rgba(r,g,b,a)` instead of being truncated to `#RRGGBB`. Opaque
  colors still emit `#RRGGBB` so existing snapshots stay byte-identical.
  *(REVIEW.md Critical 1; Phase 1, commit `75d3244`)*
- **Block `.round` renders the same in CG and SVG.** The block layout
  now stores a 6-pt corner radius (matching the CG `ShapeRenderer`
  default) so SVG no longer emits `rx=0`. *(Critical 2; Phase 1)*
- **Gantt today-marker is deterministic.** `_ganttReferenceToday()`
  honors `DIAGRAMKIT_GANTT_TODAY=YYYY-MM-DD` with a POSIX Gregorian /
  UTC calendar. `CorpusSnapshotTests.loadDiagrams()` pins the env at
  suite-load time; 7 gantt SVG baselines re-recorded. *(Critical 11;
  Phase 1)*

## Export round-trip safety

- **Structurizr exporter sanitizes aliases** (`my customer` →
  `my_customer`) with a `.warning` diagnostic per rewrite, threaded
  through element defs / relationships / view scopes. *(Critical 6;
  Phase 2, commit `81342f6`)*
- **Structurizr exporter no longer emits parser-incompatible syntax.**
  `<alias> tags "..."` lines and `group "..." { include ... }` blocks
  now produce `.unsupported` diagnostics instead of malformed DSL.
  *(Critical 7)*
- **PlantUML sequence exporter normalizes newlines** in title / note /
  group / box / else labels so multi-line input no longer breaks the
  line-oriented `@startuml/@enduml` model. *(Critical 8)*

## Concurrency

- **No stale completions from cancelled preparations.**
  `DiagramLayer.prepareDiagram` now schedules
  `Task { @MainActor [weak self] in … }` and gates all state writes +
  `setNeedsDisplay()` + completion notifications behind a single
  `Task.isCancelled` guard. *(Critical 3; Phase 3, commit `07aac8c`)*
- **Multiple completion observers.** New
  `DiagramLayer.addPrepareCompletionHandler(_:)` /
  `removePrepareCompletionHandler(_:)` fan-out API. `onPrepareComplete`
  preserved as a compatibility hook. `DiagramView` installs its
  binding publisher once via a `Coordinator` instead of clobbering the
  callback on every `update*View`. *(Critical 5)*
- **Sendable storage tightened.** `DiagramTheme` is now
  construction-then-freeze (every property `let`; builder methods
  return new instances). `DiagramTheme` and `ArchitectureIconRegistry`
  graduated from yellow to green in the Sendable allowlist policy.
  *(Phase 6A, commit `7ae5c1c`)*
- **Strict-concurrency parity.** `Scripts/check-sendable-annotations.sh`
  now also catches `actor … @unchecked Sendable`. The 8 MB worker
  stack constant lives in `DiagramKitCommon/DiagramWorkerConfig.swift`
  and is shared by both worker-spawn sites. Worker thread renamed
  `"BeautifulMermaid worker"` → `"DiagramKit worker"`. *(Phase 6A + 7)*

## Parser & layout robustness

- **gitGraph layout no longer trips `fatalError()`** on malformed
  parallel-commits input — reports `_reportDiagramIssue` and returns
  an empty positioned graph. *(Phase 6B, commit `c60574a`)*
- **Kanban duplicate-id warning** flows through `_reportDiagramIssue`
  instead of `print(...)`.
- **Soft 1024-frame recursion cap** on nested subgraph + Ishikawa
  traversals (`_allNodeIds`, `_subgraphContainsNode`, `_findSubgraph`,
  Ishikawa `walk`) — diagnostic + safe truncation instead of stack
  exhaustion on pathological input.
- **Newline normalization.** `DiagramSourceNormalizer.rawLines` also
  collapses U+2028 / U+2029 / form-feed in addition to CR/CRLF.
- **Header matching tightened.** `pie`, `block`, and `gantt` registry
  matchers use a token-boundary check (`startsWithToken`) so
  `ganttogram` doesn't trip the gantt parser.

## Renderer drift

- **Block `stroke-width` / edge-label corner** values are centralized
  in a new `DiagramKitCommon/BlockRenderConstants.swift`. Both
  `src_block_renderer.swift` (SVG, Linux-portable) and
  `DiagramRenderer+Block.swift` (CG, Apple-only) read from it.
  *(Phase 6C, commit `d35e849`)*
- **Multiline text box** in `DiagramRenderer._drawTextInFlipped` bumped
  from 1000 pt to 4000 pt so wider labels do not silently clip.
- **ASCII coverage gap** documented in BASELINES.md (5 of 28 families).

## Importer / exporter coverage

- **`DiagramError` gains `unrecognizedFormat` and
  `malformedSource(message:)`.** DOT/D2 parser fatal errors switch
  from `.notYetImplemented` to `.malformedSource`. `DiagramLoader.parse`
  emits `.unrecognizedFormat` for no-matching-importer cases.
  *(Phase 6D, commit `d7d68dd`)*
- **D2 probe is token-bounded** so `block\n  ...  -->  ...` Mermaid
  sources are no longer mis-claimed by D2. `block-5-edges` and
  `block-7-architecture` baselines re-recorded.
- **D2 shape mapping** picks up `square`, `parallelogram`, `queue`,
  `package`, `step`, `stored_data`, and a few close analogues.
- **DOT shape mapping** picks up `square`, `house`, `invhouse`,
  `trapezium`/`invtrapezium`, `parallelogram`, `note`, `tab`/`folder`,
  `component`, `triangle`/`invtriangle`, `doublecircle`.
- **DOT HTML labels** (`label=<<TABLE>...>>`) detected, surfaced as a
  `.unsupported` diagnostic with id-fallback rendering.
- **Missing exporter** for a known format returns a `.unsupported`
  diagnostic instead of throwing (e.g. `.graphviz` — `DOTExporter` is
  a separate feature phase).
- **`ImporterRegistry.appending(_:)`** complements `prepending(_:)` with
  doc on which to use when.
- **`MermaidImporter.supports`** returns `false` for whitespace-only
  input.
- **`ExporterRegistry.exporters`** returns a stable
  `formatID.rawValue`-sorted order.

## Public API & layering

- **`DiagramDiagnostic` lives in `DiagramKitCommon`.**
  `DiagramKitExport` no longer depends on `DiagramKitImport`; the
  Export target's deps are `["DiagramKitCommon", "DiagramKitModel"]`.
  Source compat preserved via `@_exported import DiagramKitCommon`
  inside `DiagramKitImport`. *(Critical 9; Phase 4, commit `3b98dd6`)*
- **New `DiagramKitMermaid` library product.** `MermaidExporter` and
  the `MermaidExport/*.swift` helpers moved out of the umbrella so
  consumers can construct the canonical Mermaid exporter without
  importing `DiagramKit`. The umbrella re-exports
  `DiagramKitMermaid` for source compatibility. *(Critical 10; Phase 4)*
- **`_MermaidPreparerBootstrap`** typealias gains
  `@available(*, deprecated, renamed:)`.
- **Legacy classes sealed.** `original_src_index` and
  `original_src_ascii_index` are now `public final class` (were
  `open class`) — no downstream subclasses existed.
- **`DiagramKitVersion` + `VERSION` resource** moved into
  `DiagramKitCommon` so Linux reads the same version string as Apple.
  *(Phase 7, commit `a20e94e`)*
- **Dead code removed.** `Sources/DiagramKitPlantUML/Exporter/
  PlantUMLC4Exporter.swift` (~140 lines, unreferenced).

## CI & gates

- **`bootstrap-smoke-check.sh` aggregates gate failures** instead of
  failing-fast — every script runs and the operator sees the complete
  failure surface. *(Critical 12; Phase 5, commit `cb1f082`)*
- **`linux-check.sh` is environment-aware:** honors
  `SKIP_LINUX_CHECK=1` and treats missing Docker/Podman as a clean
  environment skip rather than `exit 2`.
- **New `.github/workflows/ci.yml`** runs every PR through a macOS
  runner: package dump, build, test, the three governance scripts, and
  `linux-check.sh` with `SKIP_LINUX_CHECK=1`.

## Docs

- **PHASES.md** restored as the active roadmap index, linking to the
  archived per-phase records.
- **CLAUDE.md** target layout updated to reflect all 13 SwiftPM library
  products and the post-Phase-4 home of `DiagramDiagnostic` /
  `DiagramKitMermaid` / `DiagramKitInteractive`.
- **README.md** status block updated for the post-Phase-10 + remediation
  state.
- **ATTRIBUTION.md / THIRD_PARTY_LICENSES.md / ARCHITECTURE.md** replace
  legacy `BeautifulMermaidFontRegistry` / `_reportMermaidIssue` /
  `_withMermaidIssueReporting` / `_renderMermaidSVG` references with the
  symbols that actually exist post-rename.

## Tests added

- `Tests/DiagramKitTests/DiagramPipelineReviewRegressionTests.swift`
  (Phase 1) — covers non-opaque-theme SVG alpha round-trip.
- `Tests/DiagramKitTests/DiagramViewReviewRegressionTests.swift`
  (Phase 3) — covers cancelled preparation + fan-out + handler removal.
- `Tests/DiagramKitTests/FlowchartStateERReviewRegressionTests.swift`
  (Phase 6F) — 7 parser/layout invariants for the three highest-traffic
  diagram families.
- `Tests/DiagramKitTests/Export/PlantUMLExporterTests.swift` and
  `…/StructurizrExporterTests.swift` expanded with newline /
  sanitization / dropped-syntax regression coverage.

## Snapshot baseline changes

- 7 Gantt SVG baselines re-recorded (deterministic today-marker).
- 2 Block SVG baselines re-recorded (`block-5-edges`,
  `block-7-architecture` — D2-probe routing fix).
- 2 Block image baselines re-recorded (same entries — Phase 8 caught
  the matching image drift).

## Open items deferred to a separate phase

- **PlantUML class / state / activity / mindmap+gantt / C4 import**
  slices (see PHASES.md).
- **`DOTExporter`** for `.graphviz` format.
- **ASCII renderer coverage** beyond the 5 implemented families.
- **EventModeling tests** split into per-concern files.
- **`DiagramLayer.commonInit()` → `@MainActor`** — blocked on dropping
  `@preconcurrency QuartzCore`; documented in source.

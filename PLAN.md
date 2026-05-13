# DiagramKit Review Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the release-blocking findings in `REVIEW.md`, then burn down the important correctness, layering, test, gate, and documentation risks in PR-sized phases.

**Architecture:** The plan keeps high-risk behavioral changes isolated from API and documentation work. Phases 1-5 are release blockers and should land before a v1.0 cut; Phases 6-8 can be split into parallel follow-up PRs after the blockers are green. Every phase starts with targeted regression coverage and ends with the narrowest useful SwiftPM or script verification before the full merge gate.

**Tech Stack:** Swift 6.3, SwiftPM, XCTest plus swift-testing, SnapshotTesting, Bash governance scripts, Docker or Podman for Linux checks, and GitHub Actions for CI.

---

## Ground Rules

- Preserve the worker-thread invariant: no thread pool, no cooperative-pool rendering entry point, and no `Task.detached` replacement for `DiagramEngine._runOnWorker` or `DiagramWorkerThread.run`.
- Preserve snapshot determinism: `DiagramFontRegistry.registerBundledFontsIfNeeded()` remains first in every pipeline method.
- Preserve parser dispatch order: narrower `hasPrefix` replacements must precede broader fallbacks.
- Preserve type safety: pattern-match `DiagramDocument.payload`, `typedPayload`, and `PositionedGraph.content`; do not cast payloads through `Any`.
- Preserve color semantics: do not compare or round-trip colors through `hexString`; use RGBA components or `bmColorEquals()` where equality is involved.
- Record SVG/image snapshots only for intentional renderer or fixture changes. Use `SNAPSHOT_DIAGRAM_IDS` chunks for corpus recording.

## Phase Overview

| Phase | Scope | Review Items | Release Gate |
| --- | --- | --- | --- |
| 0 | Baseline and tracking | All | Required |
| 1 | Renderer correctness and Gantt determinism | Critical 1, 2, 11 | Required |
| 2 | Exporter data-loss fixes | Critical 6, 7, 8 | Required |
| 3 | View-layer strict-concurrency fixes | Critical 3, 4, 5 | Required |
| 4 | Public API and layering cleanup | Critical 9, 10 | Required |
| 5 | Gate trust and CI | Critical 12 plus CI gap | Required |
| 6 | Important correctness and robustness backlog | Important sections | Recommended before v1.0 |
| 7 | Documentation and minor cleanup | Documentation plus Minor sections | Recommended before v1.0 |
| 8 | Release verification | All | Required before release tag |

## File Ownership Map

- `Sources/DiagramKit/DiagramPipeline.swift` - pipeline-level SVG theme conversion and default exporter registry.
- `Sources/DiagramKitModel/CrossPlatform.swift` - native color component helpers.
- `Sources/DiagramKitModel/src_block_renderer.swift` and `Sources/DiagramKitRenderingCG/DiagramRenderer+Block.swift` - block SVG/CG parity.
- `Sources/DiagramKitModel/src_gantt_layout.swift` and `Tests/DiagramKitTests/GanttLayoutTests.swift` - Gantt reference-date determinism.
- `Sources/DiagramKitStructurizr/StructurizrExporter.swift` and `Tests/DiagramKitTests/Export/StructurizrExporterTests.swift` - Structurizr round-trip fixes.
- `Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift` and `Tests/DiagramKitTests/Export/PlantUMLExporterTests.swift` - PlantUML newline escaping.
- `Sources/DiagramKitViews/DiagramLayer.swift`, `Sources/DiagramKitViews/DiagramNativeView.swift`, and `Sources/DiagramKitViews/DiagramView.swift` - view callback and actor isolation.
- `Sources/DiagramKitCommon/`, `Sources/DiagramKitImport/`, `Sources/DiagramKitExport/`, `Sources/DiagramKit/Exporter/`, and `Package.swift` - layering and Mermaid exporter relocation.
- `Scripts/bootstrap-smoke-check.sh`, `Scripts/linux-check.sh`, and `.github/workflows/ci.yml` - gate behavior and CI.
- `CLAUDE.md`, `AGENTS.md`, `ARCHITECTURE.md`, `README.md`, `ATTRIBUTION.md`, `THIRD_PARTY_LICENSES.md`, and `docs/archive/PHASES.md` - documentation alignment.

---

## Phase 0 - Baseline and Tracking

**Outcome:** Establish a clean baseline, split the work into landable branches or PRs, and avoid mixing release blockers with backlog cleanup.

**Files:**
- Create or update: issue tracker entries or PR descriptions outside the source tree.
- Read only: `REVIEW.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `BASELINES.md`, `docs/archive/PHASES.md`.

- [ ] Create a branch for release blockers, for example `codex/review-release-blockers`.
- [ ] Confirm the worktree is clean with `git status --short`.
- [ ] Run `swift package dump-package`.
  - Expected: exits 0.
- [ ] Run `swift build --build-tests`.
  - Expected: exits 0.
- [ ] Record any environmental skips before starting:
  - Docker/Podman unavailable: record Linux check as skipped by environment.
  - Missing Xcode platform runtimes: record platform build as skipped by environment.
- [ ] Keep one commit per phase, or one commit per critical finding if a phase becomes large.

---

## Phase 1 - Renderer Correctness and Gantt Determinism

**Review items:** Critical 1, Critical 2, Critical 11.

**Outcome:** SVG theme colors stop losing alpha, block `.round` shapes render consistently across CG and SVG, and Gantt snapshots no longer depend on the runner's current date.

**Files:**
- Modify: `Sources/DiagramKitModel/CrossPlatform.swift`
- Modify: `Sources/DiagramKit/DiagramPipeline.swift`
- Modify: `Sources/DiagramKitModel/src_block_renderer.swift`
- Modify: `Sources/DiagramKitModel/src_gantt_layout.swift`
- Modify: `Tests/DiagramKitTests/BlockSvgTests.swift`
- Modify: `Tests/DiagramKitTests/GanttLayoutTests.swift`
- Modify: `Tests/DiagramKitTests/CorpusSnapshotTests.swift`
- Create: `Tests/DiagramKitTests/DiagramPipelineReviewRegressionTests.swift`
- Update snapshot baselines for intentional output changes: `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/*block*`, `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/*gantt*`

### Task 1.1 - Preserve alpha when SVG colors are derived from `DiagramTheme`

- [ ] Add an Apple-gated regression test in `Tests/DiagramKitTests/DiagramPipelineReviewRegressionTests.swift` that renders SVG with a theme containing a non-opaque `BMColor` and asserts the SVG output preserves alpha with an `rgba(...)` or `#RRGGBBAA` representation.
- [ ] Add a `BMColor` helper in `Sources/DiagramKitModel/CrossPlatform.swift` that reads RGBA components directly and serializes for CSS without using `hexString`.
- [ ] Replace the `theme.*.hexString` calls in both `DiagramPipeline.renderSVG(source:)` and `DiagramPipeline.renderSVG(positioned:)` with the new helper.
- [ ] Leave `renderASCII` unchanged in this phase; ASCII alpha support is outside the Critical 1 fix.
- [ ] Run `swift test --filter DiagramPipelineReviewRegressionTests`.
  - Expected: pass.

### Task 1.2 - Match Block `.round` shape radius between CG and SVG

- [ ] Add a focused assertion in `Tests/DiagramKitTests/BlockSvgTests.swift` for a block diagram using a `.round` node, checking that the emitted `<rect>` includes non-zero `rx` and `ry`.
- [ ] Update `Sources/DiagramKitModel/src_block_renderer.swift` so `.round` maps to a rounded rectangle with the same default radius used by the CG path, currently 6 points through `ShapeRenderer`.
- [ ] Keep explicit `node.rx` and `node.ry` values authoritative when present.
- [ ] Run `swift test --filter BlockSvgTests`.
  - Expected: pass.
- [ ] Run a block snapshot chunk:

```bash
SNAPSHOT_DIAGRAM_IDS=block-1-simple,block-2-columns,block-3-nested swift test --filter CorpusSnapshotTests
```

Expected: only intentional block SVG/image diffs.

### Task 1.3 - Make Gantt today-marker snapshots deterministic

- [ ] Add a deterministic reference-date path in `Sources/DiagramKitModel/src_gantt_layout.swift`, using `DIAGRAMKIT_GANTT_TODAY=YYYY-MM-DD` when present and falling back to `Date()` otherwise.
- [ ] Parse the environment value with a POSIX Gregorian calendar and a fixed time zone so the same input resolves identically on every runner.
- [ ] Update `Tests/DiagramKitTests/GanttLayoutTests.swift` to set `DIAGRAMKIT_GANTT_TODAY` for today-marker tests and assert the resulting x-coordinate is stable for a known task range.
- [ ] Update `Tests/DiagramKitTests/CorpusSnapshotTests.swift` so corpus snapshot rendering sets a fixed `DIAGRAMKIT_GANTT_TODAY` before Gantt entries render.
- [ ] Run `swift test --filter GanttLayoutTests`.
  - Expected: pass.
- [ ] Run a Gantt snapshot chunk:

```bash
SNAPSHOT_DIAGRAM_IDS=gantt-1-basic,gantt-2-full-syntax,gantt-3-compact swift test --filter CorpusSnapshotTests
```

Expected: only intentional Gantt SVG/image diffs.

### Phase 1 Verification

- [ ] Run `swift test --filter DiagramPipelineReviewRegressionTests`.
- [ ] Run `swift test --filter BlockSvgTests`.
- [ ] Run `swift test --filter GanttLayoutTests`.
- [ ] Run `swift build --build-tests`.
- [ ] Commit with a message like `fix: restore deterministic renderer behavior`.

---

## Phase 2 - Exporter Data-Loss Fixes

**Review items:** Critical 6, Critical 7, Critical 8.

**Outcome:** Structurizr exports are parser-compatible and explicit about dropped metadata, and PlantUML sequence exports keep multiline fields inside the line-oriented PlantUML model.

**Files:**
- Modify: `Sources/DiagramKitStructurizr/StructurizrExporter.swift`
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift`
- Modify: `Tests/DiagramKitTests/Export/StructurizrExporterTests.swift`
- Modify: `Tests/DiagramKitTests/Export/PlantUMLExporterTests.swift`
- Modify: `Tests/DiagramKitTests/Export/ExportMatrixTests.swift`

### Task 2.1 - Sanitize Structurizr aliases consistently

- [ ] Add tests covering aliases with spaces, dots, and hyphens in `StructurizrExporterTests`.
- [ ] Implement `sanitizeStructurizrIdentifier(_:)` in `StructurizrExporter.swift`.
- [ ] Build an alias map once per export and use it for element definitions, relationship endpoints, view scopes, and include statements.
- [ ] Emit a `.warning` `DiagramDiagnostic` for each alias rewrite, including the original and rewritten alias.
- [ ] Run `swift test --filter StructurizrExporterTests`.
  - Expected: pass.

### Task 2.2 - Stop emitting Structurizr syntax the bundled parser cannot round-trip

- [ ] Add tests proving exported source can be re-imported by `StructurizrImporter` when source C4 data contains tags and boundaries.
- [ ] Stop emitting `alias tags "..."` lines until the parser supports element-scoped tags.
- [ ] Stop emitting `group ... include ...` inside `model` until the parser supports groups there.
- [ ] Emit `.unsupported` diagnostics for tags and boundary/group structure that are intentionally not represented in the parser-compatible output.
- [ ] Run `swift test --filter StructurizrExporterTests`.
  - Expected: pass.
- [ ] Run `swift test --filter StructurizrImporterTests`.
  - Expected: pass.

### Task 2.3 - Normalize newlines in PlantUML sequence escaping

- [ ] Add tests in `PlantUMLExporterTests` for multiline `title`, `note`, `group`, `box`, and `else` labels.
- [ ] Update `PlantUMLSequenceExport.escape(_:)` to match the newline normalization behavior already used by `PlantUMLC4Export.escape(_:)`.
- [ ] Ensure carriage returns, CRLF pairs, and line separators collapse to spaces rather than producing raw PlantUML lines.
- [ ] Run `swift test --filter PlantUMLExporterTests`.
  - Expected: pass.

### Phase 2 Verification

- [ ] Run `swift test --filter StructurizrExporterTests`.
- [ ] Run `swift test --filter StructurizrImporterTests`.
- [ ] Run `swift test --filter PlantUMLExporterTests`.
- [ ] Run `swift test --filter ExportMatrixTests`.
- [ ] Commit with a message like `fix: make exported formats round-trip safely`.

---

## Phase 3 - View-Layer Strict-Concurrency Fixes

**Review items:** Critical 3, Critical 4, Critical 5.

**Outcome:** `DiagramLayer` updates main-actor state only on the main actor, cancelled preparation tasks cannot publish stale completion callbacks, and SwiftUI binding updates no longer clobber host-installed layer callbacks.

**Files:**
- Modify: `Sources/DiagramKitViews/DiagramLayer.swift`
- Modify: `Sources/DiagramKitViews/DiagramNativeView.swift`
- Modify: `Sources/DiagramKitViews/DiagramView.swift`
- Create: `Tests/DiagramKitTests/DiagramViewReviewRegressionTests.swift`

### Task 3.1 - Keep `DiagramLayer.commonInit()` actor-isolated

- [ ] Remove `nonisolated` from `DiagramLayer.commonInit()`.
- [ ] Keep every write to `needsDisplayOnBoundsChange` and `contentsScale` in `commonInit()` on `@MainActor`.
- [ ] Run `Scripts/strict-concurrency-check.sh`.
  - Expected: pass.

### Task 3.2 - Publish preparation results from a main-actor task

- [ ] Change `preparationTask` creation in `DiagramLayer.prepareDiagram()` to use a main-actor task body for all state mutation after the awaited preparation returns.
- [ ] Preserve the background preparation behavior by continuing to call `DiagramViewPreparerEnvironment.current` or `DiagramPreparation.prepare(...)`; do not move parsing/layout onto the cooperative pool.
- [ ] Add `Task.isCancelled` guards before setting `preparedDiagram`, `diagramBounds`, `parseError`, `setNeedsDisplay()`, and completion notifications.
- [ ] Add a regression test that changes `source` twice and proves the stale first task cannot fire a final completion after cancellation.
- [ ] Run `swift test --filter DiagramViewReviewRegressionTests`.
  - Expected: pass on Apple platforms, skipped by compile gates on Linux.

### Task 3.3 - Replace single callback ownership with fan-out preparation observers

- [ ] Add a layer-owned observer registration API, for example `addPrepareCompletionHandler(_:)` and `removePrepareCompletionHandler(_:)`, while preserving `onPrepareComplete` as the compatibility callback.
- [ ] Update `DiagramNativeView.commonInit()` to register its invalidation callback through the fan-out API.
- [ ] Update `DiagramView` to install its binding publisher once through a `Coordinator`, not on every `updateUIView` or `updateNSView`.
- [ ] Add a regression test proving a host-installed callback and a SwiftUI binding callback both run for one preparation event.
- [ ] Run `swift test --filter DiagramViewReviewRegressionTests`.
  - Expected: pass on Apple platforms.

### Phase 3 Verification

- [ ] Run `swift build --build-tests`.
- [ ] Run `Scripts/strict-concurrency-check.sh`.
- [ ] Run `swift test --filter MermaidPreparationWorkerTests`.
- [ ] Run `swift test --filter DiagramViewReviewRegressionTests`.
- [ ] Commit with a message like `fix: make diagram views strict-concurrency safe`.

---

## Phase 4 - Public API and Layering Cleanup

**Review items:** Critical 9, Critical 10.

**Outcome:** `DiagramKitExport` no longer depends on `DiagramKitImport`, and `MermaidExporter` is available without importing the umbrella target.

**Files:**
- Move: `Sources/DiagramKitImport/DiagramDiagnostic.swift` to `Sources/DiagramKitCommon/DiagramDiagnostic.swift`
- Modify: `Sources/DiagramKitImport/DiagramImportResult.swift`
- Modify: `Sources/DiagramKitExport/DiagramExportResult.swift`
- Modify: `Sources/DiagramKitExport/DiagramExporter.swift`
- Modify: `Sources/DiagramKitExport/DiagramExportError.swift`
- Move: `Sources/DiagramKit/Exporter/` to `Sources/DiagramKitMermaid/Exporter/`
- Modify: `Package.swift`
- Modify: `Sources/DiagramKit/DiagramPipeline.swift`
- Modify: `Sources/DiagramKit/ReExports.swift`
- Modify: `Tests/DiagramKitTests/Export/MermaidExporterTests.swift`
- Modify: `Tests/DiagramKitTests/Export/MermaidEscapeTests.swift`
- Modify: `Tests/DiagramKitTests/Export/ExportMatrixTests.swift`
- Modify: tests that instantiate `MermaidExporter()` directly.

### Task 4.1 - Hoist `DiagramDiagnostic` to Common

- [ ] Move `DiagramDiagnostic` into `DiagramKitCommon`.
- [ ] Update import statements so `DiagramKitImport` and `DiagramKitExport` import `DiagramKitCommon` for diagnostics.
- [ ] Remove the `DiagramKitImport` dependency from the `DiagramKitExport` target in `Package.swift`.
- [ ] Run `swift package dump-package`.
  - Expected: exits 0.
- [ ] Run `swift build --target DiagramKitExport`.
  - Expected: pass.
- [ ] Run `swift test --filter DiagramExportInfrastructureTests`.
  - Expected: pass.

### Task 4.2 - Promote Mermaid exporting into its own product target

- [ ] Add a `DiagramKitMermaid` library product and target in `Package.swift`.
- [ ] Move `MermaidExporter.swift` and the `MermaidExport/` helper files from the umbrella target into `Sources/DiagramKitMermaid/Exporter/`.
- [ ] Make `DiagramKitMermaid` depend on `DiagramKitCommon`, `DiagramKitModel`, and `DiagramKitExport`.
- [ ] Update `DiagramPipeline.defaultExportRegistry` to import and register `MermaidExporter` from `DiagramKitMermaid`.
- [ ] Re-export `DiagramKitMermaid` from the umbrella `DiagramKit` target so existing `import DiagramKit` callers keep source compatibility.
- [ ] Update direct exporter tests to import `DiagramKitMermaid` instead of relying on the umbrella.
- [ ] Run `swift test --filter MermaidExporterTests`.
  - Expected: pass.
- [ ] Run `swift test --filter MermaidEscapeTests`.
  - Expected: pass.
- [ ] Run `swift test --filter ExportMatrixTests`.
  - Expected: pass.

### Phase 4 Verification

- [ ] Run `swift package dump-package`.
- [ ] Run `swift build --build-tests`.
- [ ] Run `swift test --filter DiagramExportInfrastructureTests`.
- [ ] Run `swift test --filter ExportMatrixTests`.
- [ ] Commit with a message like `refactor: separate export diagnostics and mermaid exporter`.

---

## Phase 5 - Gate Trust and CI

**Review items:** Critical 12, Important "No CI/automation runs the governance gates".

**Outcome:** Local smoke checks aggregate failures instead of failing fast, missing container runtimes are treated as environment skips, and PRs run the governance gates automatically.

**Files:**
- Modify: `Scripts/bootstrap-smoke-check.sh`
- Modify: `Scripts/linux-check.sh`
- Create: `.github/workflows/ci.yml`
- Modify: `CONTRIBUTING.md`
- Modify: `BASELINES.md`

### Task 5.1 - Make `bootstrap-smoke-check.sh` aggregate all gate failures

- [ ] Add a `run_gate` helper that runs a named command and sets `status=1` on failure without aborting the rest of the script.
- [ ] Route `swift package dump-package`, `swift test`, `check-file-sizes.sh`, `strict-concurrency-check.sh`, `check-sendable-annotations.sh`, and `linux-check.sh` through `run_gate`.
- [ ] Keep `run_build` behavior for missing Xcode runtimes as an environment skip.
- [ ] Run `bash -n Scripts/bootstrap-smoke-check.sh`.
  - Expected: exits 0.

### Task 5.2 - Make `linux-check.sh` skip cleanly when no runtime is available

- [ ] Add `SKIP_LINUX_CHECK=1` support that prints a skip message and exits 0.
- [ ] When neither Docker nor Podman is found, print the documented skip reason and exit 0.
- [ ] Keep actual Docker/Podman build failures as non-zero exits.
- [ ] Run `SKIP_LINUX_CHECK=1 Scripts/linux-check.sh`.
  - Expected: exits 0 with a skip message.
- [ ] Run `bash -n Scripts/linux-check.sh`.
  - Expected: exits 0.

### Task 5.3 - Add PR CI for build, tests, and governance scripts

- [ ] Create `.github/workflows/ci.yml` with pull request and push triggers.
- [ ] Use a macOS runner for SwiftPM build/test and governance scripts.
- [ ] Run `swift package dump-package`.
- [ ] Run `swift build --build-tests`.
- [ ] Run the governance scripts individually so failures are easy to identify.
- [ ] Run `Scripts/linux-check.sh` with `SKIP_LINUX_CHECK=1` in the initial PR workflow, and leave real container execution to local merge gates or a later runner with Docker/Podman installed.
- [ ] Document CI scope in `CONTRIBUTING.md` and local merge-gate caveats in `BASELINES.md`.

### Phase 5 Verification

- [ ] Run `bash -n Scripts/bootstrap-smoke-check.sh`.
- [ ] Run `bash -n Scripts/linux-check.sh`.
- [ ] Run `SKIP_LINUX_CHECK=1 Scripts/linux-check.sh`.
- [ ] Run `swift build --build-tests`.
- [ ] Commit with a message like `ci: enforce governance gates`.

---

## Phase 6 - Important Correctness and Robustness Backlog

**Outcome:** Reduce the long-tail risks called out by `REVIEW.md` after release blockers are fixed. These subphases are independent enough to split across multiple workers or PRs.

### Phase 6A - Concurrency backlog

**Files:**
- Modify: `Sources/DiagramKitModel/Theme.swift`
- Modify: `Sources/DiagramKitModel/ArchitectureIconRegistry.swift`
- Modify: `Scripts/check-sendable-annotations.sh`
- Modify: `Sources/DiagramKit/DiagramEngine.swift`
- Create: `Tests/DiagramKitTests/SendableAnnotationScriptTests.swift`

- [ ] Convert mutable `DiagramTheme.background` storage to immutable state plus a builder-style API, then remove the related `@unchecked Sendable` allowance.
- [ ] Add a "Concurrency Contract" banner near the `ArchitectureIconRegistry` sendability annotation.
- [ ] Extend `check-sendable-annotations.sh` so future `actor Foo: @unchecked Sendable` annotations are caught.
- [ ] Extract the Linux worker-thread stack constant shared by `DiagramEngine._runOnWorker` and `DiagramWorkerThread.run` into a portable location without introducing a pool.
- [ ] Verify with `Scripts/check-sendable-annotations.sh`.
- [ ] Verify with `Scripts/strict-concurrency-check.sh`.

### Phase 6B - Parser and layout robustness

**Files:**
- Modify: `Sources/DiagramKitModel/src_gitgraph_layout.swift`
- Modify: `Sources/DiagramKitModel/src_kanban_parser.swift`
- Modify: `Sources/DiagramKitModel/src_layout.swift`
- Modify: `Sources/DiagramKitModel/src_ishikawa_layout.swift`
- Modify: `Sources/DiagramKitModel/DiagramSourceNormalizer.swift`
- Modify: `Sources/DiagramKit/MermaidImporter.swift`
- Create: `Tests/DiagramKitTests/ParserRobustnessReviewTests.swift`
- Modify: `Tests/DiagramKitTests/GitGraphLayoutTests.swift`
- Modify: `Tests/DiagramKitTests/KanbanParserTests.swift`
- Modify: `Tests/DiagramKitTests/IshikawaLayoutTests.swift`
- Modify: `Tests/DiagramKitTests/MermaidSourceNormalizerTests.swift`
- Modify: `Tests/DiagramKitTests/MermaidImporterTests.swift`

- [ ] Replace reachable `fatalError()` in gitGraph layout with a throwing `GitGraphLayoutError` or `DiagramError.malformedSource(message:)`.
- [ ] Replace the duplicate-node `print(...)` in Kanban parsing with issue reporting.
- [ ] Add a soft recursion cap for nested subgraph and Ishikawa traversal, starting at 1024, and throw a user-facing error when exceeded.
- [ ] Extend `DiagramSourceNormalizer.rawLines` to normalize U+2028, U+2029, and form-feed line separators.
- [ ] Tighten permissive Mermaid header detection for `pie`, `block`, and `gantt` to token boundaries while preserving existing parser fallback order.
- [ ] Verify with targeted parser/layout suites, then `swift build --build-tests`.

### Phase 6C - Renderer drift backlog

**Files:**
- Modify: `Sources/DiagramKitModel/src_block_renderer.swift`
- Modify: `Sources/DiagramKitRenderingCG/DiagramRenderer+Flow.swift`
- Modify: `Sources/DiagramKitModel/RenderTokens.swift`
- Create: `Tests/DiagramKitTests/RendererDriftReviewTests.swift`
- Modify: `Tests/DiagramKitTests/BlockSvgTests.swift`
- Modify: `Tests/DiagramKitTests/FlowchartVisualDiffTests.swift`

- [ ] Replace hardcoded SVG `stroke-width="1.5"` block literals with the corresponding `RenderTokens` value.
- [ ] Align block edge-label corner radius between CG and SVG.
- [ ] Replace the 1000pt multiline text box in `DiagramRenderer+Flow.swift` with measured or bounded layout behavior.
- [ ] Document the current ASCII renderer gap as an explicit limitation, with a separate follow-up needed before promising 28-family ASCII coverage.
- [ ] Verify with block, flow, and affected corpus snapshot chunks.

### Phase 6D - Importer and exporter backlog

**Files:**
- Modify: `Sources/DiagramKitD2/D2Shapes.swift`
- Modify: `Sources/DiagramKitGraphviz/DOTParser.swift`
- Modify: `Sources/DiagramKitGraphviz/DOTMapper.swift`
- Modify: `Sources/DiagramKitExport/DiagramExportLoader.swift`
- Modify: `Sources/DiagramKitImport/DiagramLoader.swift`
- Modify: `Sources/DiagramKitImport/ImporterRegistry.swift`
- Modify: `Sources/DiagramKit/MermaidImporter.swift`
- Modify: `Tests/DiagramKitTests/D2ParserTests.swift`
- Modify: `Tests/DiagramKitTests/DOTParserTests.swift`
- Modify: `Tests/DiagramKitTests/DOTImporterTests.swift`
- Modify: `Tests/DiagramKitTests/Export/DiagramExportLoaderTests.swift`
- Modify: `Tests/DiagramKitTests/ImporterRegistryTests.swift`
- Modify: `Tests/DiagramKitTests/MermaidImporterTests.swift`

- [ ] Add D2 shape mappings for `square`, `parallelogram`, `queue`, `package`, `step`, and `stored_data`, mapping direct analogues first.
- [ ] Add DOT HTML-label detection with a clear unsupported diagnostic; full `<<TABLE>...>` parsing remains a separate feature phase.
- [ ] Extend DOT shape mapping for common Graphviz shapes listed in `REVIEW.md`.
- [ ] Make missing Graphviz export produce a helpful `.unsupported` diagnostic; `DOTExporter` remains a separate feature phase.
- [ ] Introduce `.unrecognizedFormat` for no-matching-importer cases in `DiagramLoader.parse`.
- [ ] Replace broad DOT `notYetImplemented` fatal parse errors with `.malformedSource(message:)`.
- [ ] Add `ImporterRegistry.appending(_:)` and document fallback ordering.
- [ ] Make `MermaidImporter.supports(source:)` return false for empty or whitespace-only input.
- [ ] Verify with importer/exporter targeted tests and `swift test --filter ProbeCollisionMatrixTests`.

### Phase 6E - Views and interactive backlog

**Files:**
- Modify: `Sources/DiagramKitModel/DiagramBoundsLookup.swift`
- Modify: `Sources/DiagramKitModel/DiagramBoundsLookup+Flowchart.swift`
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift`
- Modify: `Sources/DiagramKitViews/DiagramNativeView.swift`
- Modify: `Tests/DiagramKitTests/Interactivity/DiagramBoundsLookupRegressionTests.swift`
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorMutationTests.swift`
- Modify: `Tests/DiagramKitTests/Interactive/DiagramEditorFlowchartTests.swift`

- [ ] Make `DiagramBoundsLookup.element(at:)` use the minY index it already builds, then preserve z-order hit behavior.
- [ ] Convert fixed edge hit-padding from diagram-space pixels to zoom-aware screen-space padding where the caller has zoom context.
- [ ] Extract synthetic edge-ID generation into one helper shared by editor mutations and bounds lookup.
- [ ] Add a DEBUG `assertionFailure` or proactive bootstrap path for `DiagramNativeView` when the preparer environment is not configured.
- [ ] Verify with interactivity and editor suites.

### Phase 6F - Test coverage backlog

**Files:**
- Create: `Tests/DiagramKitTests/FlowchartParserLayoutReviewTests.swift`
- Create: `Tests/DiagramKitTests/StateParserLayoutReviewTests.swift`
- Create: `Tests/DiagramKitTests/ERParserLayoutReviewTests.swift`
- Modify: `Tests/DiagramKitTests/EventModelingTests.swift`
- Modify: `Tests/DiagramKitTests/MermaidPreparationWorkerTests.swift`
- Modify: `Tests/DiagramKitTests/MermaidPlaygroundRegressionTests.swift`
- Modify: `Examples/MermaidPlayground/Resources/test-diagrams.json`.

- [ ] Add dedicated parser/layout tests for flowchart, state, and ER beyond corpus snapshots.
- [ ] Split the monolithic eventmodeling tests into parser, layout, renderer, and corpus-fixture coverage.
- [ ] Replace `Task.sleep` timing in preparation-worker and playground regression tests with deterministic expectations or injected clocks.
- [ ] Treat ASCII coverage gaps as a documented limitation for this remediation plan; do not add broad ASCII baselines until a dedicated ASCII expansion phase is scoped.

---

## Phase 7 - Documentation and Minor Cleanup

**Outcome:** Documentation matches the actual package layout and current roadmap, and small legacy names no longer mislead maintainers.

**Files:**
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `ARCHITECTURE.md`
- Modify: `README.md`
- Modify: `ATTRIBUTION.md`
- Modify: `THIRD_PARTY_LICENSES.md`
- Modify: `docs/archive/PHASES.md`
- Create: `PHASES.md`
- Modify: `Sources/DiagramKit/DiagramEngine.swift`
- Modify: `Sources/DiagramKit/DiagramPreparerWiring.swift`
- Modify: `Sources/DiagramKitTestSupport/DiagramKitTestSupport.swift`
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLC4Exporter.swift`
- Modify: `Sources/DiagramKitD2/D2Mapper.swift`
- Modify: `Sources/DiagramKitExport/ExporterRegistry.swift`

- [ ] Fix stale `CLAUDE.md` paths, target counts, product list, and omissions for `DiagramKitPlantUML` and `DiagramKitInteractive`.
- [ ] Restore root `PHASES.md` as the active roadmap index, linking to `docs/archive/PHASES.md` for historical phases and summarizing current PlantUML/exporter work.
- [ ] Update `README.md` status language so it reflects the current post-Phase-10 state.
- [ ] Replace legacy BeautifulMermaid and Mermaid issue-reporting symbol references in attribution and architecture docs.
- [ ] Rename the worker thread from `"BeautifulMermaid worker"` to a DiagramKit name.
- [ ] Replace the hard-coded Linux `version` value with the same resource-backed version path used on Apple.
- [ ] Deprecate `_MermaidPreparerBootstrap` typealias consistently.
- [ ] Keep the empty `DiagramKitTestSupport` public enum as a compatibility shim and document that role in a short doc comment.
- [ ] Delete `PlantUMLC4Exporter.swift` from `Sources/DiagramKitPlantUML/Exporter/` and remove stale references from tests or docs.
- [ ] Clarify `D2Mapper.normalizeEndpoint` by rewriting the inverted guard.
- [ ] Make `ExporterRegistry.exporters` return deterministic order.
- [ ] Seal legacy `original_src_index` and `original_src_ascii_index` classes by changing `open class` to `public final class` before v1.0.
- [ ] Verify with `swift build --build-tests`.

---

## Phase 8 - Release Verification

**Outcome:** Every release-blocking review item has a merged fix, documentation reflects the actual state, and the full merge gate is either green or has explicit environment skips.

**Files:**
- Modify: `BASELINES.md`
- Modify: `README.md`

- [ ] Re-read `REVIEW.md` and mark every Critical item with the phase and commit that closed it.
- [ ] Re-run targeted suites from Phases 1-5.
- [ ] Attempt `swift test`; when the known signal-10 issue appears, record it and rely on the targeted suites plus chunked corpus commands above.
- [ ] Run the snapshot chunks affected by renderer and Gantt changes.
- [ ] Run `Scripts/check-file-sizes.sh`.
- [ ] Run `Scripts/check-sendable-annotations.sh`.
- [ ] Run `Scripts/strict-concurrency-check.sh`.
- [ ] Run `Scripts/linux-check.sh`, recording an environment skip when no Docker or Podman runtime is available.
- [ ] Run `Scripts/bootstrap-smoke-check.sh`, recording Xcode platform runtime skips separately from source failures.
- [ ] Update `BASELINES.md` with any changed counts, snapshot totals, or gate caveats.
- [ ] Prepare a release-note summary grouped by correctness, concurrency, API/layering, CI, and docs.

## Final Acceptance Criteria

- All 12 Critical items from `REVIEW.md` are either fixed or explicitly documented as a deliberate non-release scope decision.
- `swift build --build-tests` passes.
- Targeted tests for renderer, Gantt, exporter, views, export infrastructure, and governance-script changes pass.
- Governance scripts aggregate failures and treat missing Linux container runtime as an environment skip.
- `DiagramKitExport` no longer imports or depends on `DiagramKitImport`.
- `MermaidExporter` is constructible from a non-umbrella product while remaining available to existing `import DiagramKit` consumers.
- Documentation no longer references missing root roadmap files, old product names, or removed Mermaid-prefixed SPI symbols.

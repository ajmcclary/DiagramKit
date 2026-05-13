# DiagramKit — Comprehensive Code Review

**Scope:** 379 Swift sources across 13 SwiftPM targets, 188 test files, 1044 snapshot baselines, governance scripts, and documentation. Reviewed in parallel by eight focused subagents (public API, concurrency, parsers/layouts, renderers, importers/exporters, tests/gates, views/interactive, docs).

**Overall assessment:** Architecture is sound and the hard concurrency invariant holds. There are **12 Critical** items that need attention before a v1.0 cut, and a long tail of Important fixes around layering, drift hazards, and CI hygiene. Nothing is on fire — the codebase is in good shape — but several items are silently corroding correctness.

---

## CRITICAL — fix before next release

### Renderer correctness

1. **`DiagramPipeline.renderSVG` round-trips theme colors through `.hexString`** — direct violation of the CLAUDE.md invariant ("do not compare/round-trip colors through `hexString`"). Every theme color is converted via `theme.background.hexString` to build `DiagramColors`, which truncates alpha and forces `.deviceRGB` normalization.
   - `Sources/DiagramKit/DiagramPipeline.swift:140-146, 178-184`
   - Fix: thread `BMColor` through to SVG renderers (or compute hex once on the originating `DiagramColors`).

2. **Block CG vs SVG render `.round` shapes differently** — CG draws a 6pt rounded rect; SVG emits `rx="0"` (plain rectangle). Visible divergence for the same source.
   - CG: `Sources/DiagramKitRenderingCG/DiagramRenderer+Block.swift:167-168` → `ShapeRenderer.swift:109-110`
   - SVG: `Sources/DiagramKitModel/src_block_renderer.swift:405, 230`

### View-layer concurrency hazards (masked today by `@preconcurrency QuartzCore`)

3. **`DiagramLayer.preparationTask` writes `@MainActor` properties from a non-isolated `Task`**, with cancellation guard only inside the `do` branch — stale `onPrepareComplete` can fire after source changed.
   - `Sources/DiagramKitViews/DiagramLayer.swift:118-137`
   - Fix: `Task { @MainActor [weak self] in ... }` and wrap the final two lines in a `Task.isCancelled` guard.

4. **`DiagramLayer.commonInit()` is `nonisolated` but writes main-actor CALayer state** — will break under full Swift 6 strict concurrency.
   - `Sources/DiagramKitViews/DiagramLayer.swift:51-79`

5. **`DiagramView.bindPreparationUpdates` overwrites `mermaidLayer.onPrepareComplete` on every `updateUIView`/`updateNSView`** — silently clobbers any host-installed callback, churns the closure on every state change.
   - `Sources/DiagramKitViews/DiagramView.swift:45,62-65,115,131-135`
   - Fix: install once via a `Coordinator`, or build a fan-out registration in the layer.

### Multi-format round-trip data loss

6. **`StructurizrExporter` interpolates aliases without sanitization** — any C4 diagram imported from Mermaid (which permits spaces/dots/hyphens in aliases) emits DSL the Structurizr parser rejects.
   - `Sources/DiagramKitStructurizr/StructurizrExporter.swift:52, 54, 67, 69, 75`
   - Fix: add `sanitizeStructurizrIdentifier`; emit diagnostic on rewrite.

7. **`StructurizrExporter` emits `tags` and `group ... include` syntax the bundled parser actively skips/rejects** — data is silently lost on re-import.
   - `StructurizrExporter.swift:59, 65-71`; parser at `StructurizrParser.swift:75-98`

8. **`PlantUMLSequenceExport.escape` does not normalize newlines** — multi-line `title`, `note`, `group label`, `box title`, `else label` break the `@startuml/@enduml` line model.
   - `Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift:184-188` (compare `PlantUMLC4Export.escape:137`)

### Public API & layering

9. **`DiagramKitExport → DiagramKitImport` dependency contradicts the documented layering** (CLAUDE.md says they are peers). Driven by `DiagramDiagnostic` living in Import.
   - `Package.swift:101-104`; `Sources/DiagramKitExport/DiagramExportError.swift:2`, `DiagramExporter.swift:2`
   - Fix: hoist `DiagramDiagnostic` into `DiagramKitCommon`, or update docs to reflect Export→Import.

10. **`MermaidExporter` lives inside the `DiagramKit` umbrella target, not `DiagramKitExport`** — consumers importing only `DiagramKitExport` cannot construct the canonical exporter. Asymmetric with D2/Structurizr/PlantUML exporters.
    - `Sources/DiagramKit/Exporter/MermaidExporter.swift`
    - Fix: move to `DiagramKitMermaid` (preferred) or document `DiagramKitExport` as protocol-only.

### Tests & gates

11. **Gantt corpus SVG snapshots embed `Date()`-dependent today-marker x-coordinates** — every baseline ticks toward divergence at the runner's next midnight. Latent time-bomb.
    - `Sources/DiagramKitModel/src_gantt_layout.swift:293-297` (also `Calendar.current`/`TimeZone.current` at 257, 375-377, 386, 406)
    - Fix: inject a fixed reference date via env var, or quantize/disable today-marker for non-today-specific corpus entries.

12. **`bootstrap-smoke-check.sh` fail-fast vs `linux-check.sh` no-Docker policy mismatch** — under `set -euo pipefail`, the first failing gate kills the script and subsequent platform builds + final `exit $status` never execute. Only `check-sendable-annotations.sh` is guarded with `|| status=1`. Meanwhile `linux-check.sh:14` exits 2 when Docker/Podman is absent, contradicting CLAUDE.md's documented "skip" policy.
    - `Scripts/bootstrap-smoke-check.sh:35-40`, `Scripts/linux-check.sh:14`
    - Fix: guard every gate call with `|| status=1`; add `SKIP_LINUX_CHECK=1` or graceful `exit 0` when no container runtime is on PATH.

---

## IMPORTANT

### Concurrency
- `DiagramTheme` exposes `var background: BMColor` (non-Sendable class). Allowlisted yellow with sunset 2027-06-30 — convert to `let` + builder API and drop `@unchecked`. `Sources/DiagramKitModel/Theme.swift:14`
- `ArchitectureIconRegistry` allowlisted but lacks the Concurrency Contract banner the file should self-document. `Sources/DiagramKitModel/ArchitectureIconRegistry.swift:28`
- `check-sendable-annotations.sh` regex matches `class|struct|enum|extension` — won't catch a future `actor Foo: @unchecked Sendable`. `Scripts/check-sendable-annotations.sh:79`
- Linux branch of `_runOnWorker` duplicates `DiagramWorkerThread.run` and the `8 * 1024 * 1024` constant; extract to `DiagramKitCommon`. `Sources/DiagramKit/DiagramEngine.swift:165-182`

### Public API & layering
- `MermaidParser` deprecation is missing `renamed:` — no Fix-it for adopters. `Sources/DiagramKit/Parser.swift:6-16`
- `original_src_index` / `original_src_ascii_index` are `open class` and `public`, leaking legacy JS-port shapes into the public surface. `Sources/DiagramKit/src_index.swift:398`, `src_ascii_index.swift:221`
- `DiagramKitInteractive` is not re-exported by the umbrella — consumers must import it separately. `Sources/DiagramKit/ReExports.swift`
- Underscore-prefixed SPI (`_withDiagramIssueReporting`, `_reportDiagramIssue`, ~15 `_clip…`, `_renderXXXSvgCase`, etc.) lacks any `/// SPI:` doc marker.
- `DiagramPipeline.runPipeline`'s `registerFonts: Bool` parameter is always called with `true` — dead parameter.
- `DiagramKit/Parser.swift` is a 16-line shim — rename or fold into `MermaidImporter.swift`.

### Parsers & layouts
- `fatalError()` in gitGraph layout reachable from malformed input. Replace with throwing `GitGraphLayoutError`. `Sources/DiagramKitModel/src_gitgraph_layout.swift:267-268`
- Stray `print(...)` for duplicate-node warning bypasses issue reporting. `Sources/DiagramKitModel/src_kanban_parser.swift:196`
- No depth cap on recursive subgraph / Ishikawa traversal — depends entirely on the 8 MB worker stack for safety. Add a soft cap (e.g., 1024) that throws. `Sources/DiagramKitModel/src_layout.swift:319-330, 873-882`, `src_ishikawa_layout.swift:124-149`
- `DiagramSourceNormalizer.rawLines` only normalizes `\r\n` and `\r`; misses U+2028/U+2029 and form-feed. `Sources/DiagramKitModel/DiagramSourceNormalizer.swift:11-17`
- Permissive `hasPrefix("pie"|"block"|"gantt")` matchers — tighten to `^pie(\s|$)` etc.

### Renderers
- SVG renderers hardcode `stroke-width="1.5"` literals; CG side reads from `RenderTokens`. Any future tweak to `strokeWidthInnerBox` won't propagate. `Sources/DiagramKitModel/src_block_renderer.swift` (16 sites)
- ASCII renderers throw `notYetImplemented` for 23/28 families (matches 174 baselines). Either fill the gap or document the policy.
- Block edge-label corner radius: CG uses `tokens.edgeLabelCornerRadius` (2), SVG hardcodes `rx="3"`. `DiagramRenderer+Flow.swift:246, 280` vs `src_block_renderer.swift:379`
- `DiagramRenderer+Flow.swift:155` hardcodes a 1000pt multiline text box — labels wider clip silently in CG only.
- `DiagramPipeline.runPipeline` (line 32-34) and `DiagramRenderer.init` (line 39) both call `registerBundledFontsIfNeeded` — idempotent but wasted work per render.

### Importers/exporters
- `D2Shapes.mapD2Shape` is missing `square`, `parallelogram`, `queue`, `package`, `step`, `stored_data` — first three have direct `NodeShape` analogues.
- DOT parser has **no HTML-label support** (`<<TABLE>...>`) — common in real-world graphs.
- `DOTMapper` handles 11 shapes; misses `record`, `Mrecord`, `polygon`, `triangle`, `house`, `parallelogram`, `note`, `tab`, `folder`, `component`, etc.
- No `DOTExporter` exists; calling `DiagramExportLoader.export(to: .graphviz, ...)` throws an unhelpful "No exporter registered" with no hint to the caller. Document or implement.
- `DiagramLoader.parse` throws `DiagramError.notYetImplemented` when no importer matches — misleading. Introduce `.unrecognizedFormat`.
- `DOTParser` throws plain `notYetImplemented` for every fatal parse error — should be `.malformedSource(message:)`.
- `ImporterRegistry` only has `prepending(_:)` — add `appending(_:)` with doc comment about fallback ordering.
- `MermaidImporter.supports(source:)` returns `true` for empty/whitespace input despite the comment promising non-empty filtering.

### Views & Interactive
- `DiagramBoundsLookup.element(at:)` is O(N) and ignores the sort-by-minY index it claims to use. `Sources/DiagramKitModel/DiagramBoundsLookup.swift:77-95`
- Edge hit-pad is a fixed 8 px in diagram coordinates — under-padded at high zoom, over-padded at low. `DiagramBoundsLookup+Flowchart.swift:44`
- Synthetic edge-ID logic is duplicated between `DiagramEditor+Mutations.swift:205-228` and `DiagramBoundsLookup+Flowchart.swift:26-29` — extract a single helper.
- Bootstrap timing: instantiating `DiagramNativeView` before `DiagramEngine.bootstrap()` results in `notConfigured`, but the failure is silent if no issue reporter is wired. Add an `assertionFailure` in DEBUG or proactively bootstrap from `commonInit`.

### Tests & gates
- **No CI/automation runs the governance gates** — no `.github/workflows/`. `bootstrap-smoke-check.sh` is "the local merge gate" but nothing enforces it on PRs.
- ASCII coverage: 22 of 28 families have **zero** baselines (`architecture`, `block`, `c4`, `gantt`, `gitGraph`, `kanban`, `mindmap`, …). Either record or document the policy.
- No dedicated parser/layout tests for **flowchart**, **state**, **er** — the three most-trafficked families rely entirely on corpus snapshots.
- `eventmodeling` has one monolithic test file for 12 corpus entries.
- `Task.sleep`-based timing in preparation-worker and playground regression tests (50ms, 450ms, 20ms) — flaky under load.

### Documentation
- CLAUDE.md:167 — wrong directory name `Sources/DiagramKitExporter/`; actual target is `DiagramKitExport`.
- CLAUDE.md "What Lives Where" omits `Sources/DiagramKitPlantUML/` and `Sources/DiagramKitInteractive/` (both ship as products).
- CLAUDE.md "Target Layout" says "six layered targets" — actually 13 library products.
- PHASES.md line 10 lists "Phases 0, 1, 2, 3, 4, 5, 6A, 7, 8, and 9 are implemented" — Phase 10 is missing despite being complete elsewhere. Phase-doc index also omits `PHASE-10.md`.
- PHASES.md:110 claims "396 SVG, 396 image" baselines (current truth: 435/435/174) and PHASES.md:99-101 says "real corpus file is still Mermaid-only" — both stale.
- README.md status block describes a pre-Phase-10 stage model from ANALYSIS.md.
- ATTRIBUTION.md:25 and THIRD_PARTY_LICENSES.md:9 reference `BeautifulMermaidFontRegistry` (actual: `DiagramFontRegistry`).
- ATTRIBUTION.md:75 references `_reportMermaidIssue` / `_withMermaidIssueReporting` (actual: `_reportDiagramIssue` / `_withDiagramIssueReporting`).
- ARCHITECTURE.md:158 SPI example uses `_renderMermaidSVG` — symbol no longer exists.

---

## MINOR

- Thread name still `"BeautifulMermaid worker"`. `DiagramEngine.swift:177`
- Linux `version` hard-coded to `"0.1.1"`. `DiagramEngine.swift:25`
- `_MermaidPreparerBootstrap` typealias undeprecated. `DiagramPreparerWiring.swift:62`
- `DiagramKitTestSupport.swift` is an empty `public enum DiagramKitTestSupport {}` stub from "Stage 1." Delete.
- Eleven test files reinvent `test-diagrams.json` loading instead of using `DiagramKitTestSupport.CorpusEntry`.
- `PlantUMLC4Exporter.swift` is ~140 lines of unreferenced dead code.
- `D2Mapper.normalizeEndpoint` has an inverted guard that reads as a bug. `D2Mapper.swift:107-112`
- `ExporterRegistry.exporters` returns `Array(values)` — non-deterministic order.
- ASCII snapshot naming inconsistency: `-ascii` suffix in `named:` vs format-name suffix for multi-format snapshots.
- `bootstrap-smoke-check.sh` runs unfiltered `swift test` despite the project's own memory file warning against it (signal-10 caveat).
- `original_src_index`/`original_src_ascii_index` `open class` declarations carry no extensible members — seal them.

---

## What's working well

- The hard concurrency invariant (fresh 8 MB-stack `Thread` per dispatch; no thread pool) is consistently enforced. Zero `DispatchQueue.global`, `Task.detached`, or `withTaskGroup` in `Sources/`.
- Every `@unchecked Sendable` is either allowlisted or carries a Concurrency Contract banner.
- Renderer wiring is complete: 28 diagram types, full CG/SVG parity in `SVGRenderRegistry.all`.
- No raw color `==` comparisons in renderer code paths; `bmColorEquals` discipline is honored.
- `DiagramPayload` is a closed enum; no `as? Any` casts in `Sources/`.
- Apple-only file boundary holds (no CG imports leak into `DiagramKitModel`).
- Allowlists are clean — no drift; every line still points at a real annotation/file.
- Round-trip exporter tests exist for D2, Structurizr, PlantUML, Mermaid.
- The recent commit `04a880f` substantially tightened exporter escape semantics.

---

## Recommended sequencing

1. **First** (correctness bombs): #1 SVG hexString round-trip, #2 Block round-shape mismatch, #11 Gantt today-marker determinism, #6/#7/#8 exporter data-loss paths.
2. **Then** (Swift-6 strictness): #3/#4/#5 view-layer concurrency before someone drops the `@preconcurrency QuartzCore`.
3. **Then** (API hygiene before v1.0): #9 Export→Import layering, #10 MermaidExporter relocation.
4. **Then** (gate trust): #12 `bootstrap-smoke-check.sh` guards + Linux skip policy, plus standing up a CI workflow that runs it.
5. **Documentation sweep** can run in parallel — purely mechanical.

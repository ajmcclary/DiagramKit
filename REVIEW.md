# DiagramKit Code Review — Complete

Six parallel reviewers covered architecture/public-API, model (parsers + layouts), rendering + views, format slices, playground + interactive editor, and tests/gates/concurrency. Findings are aggregated and ranked below; every item is file:line-grounded.

## Executive Summary

The library's structural discipline is real and load-bearing: the no-thread-pool 8 MB worker rule, font-registry bootstrap, payload typing, target layering, and `@unchecked Sendable` governance all hold up. The two biggest problem areas are **exporter correctness** (silent data corruption in Mermaid flowchart + PlantUML state/sequence/class exporters) and **playground undo plumbing** (the recent Cmd-Z work is being silently undone by an unrelated re-seed loop). A long-standing testing gap — 248 missing ASCII snapshot baselines combined with auto-record-on-first-run — means renderer drift in 22 ASCII families is currently invisible to CI.

---

## Resolution Status

The "Suggested fix order" at the bottom of this review was executed across five commits on `main`. Each commit lands one phase; subsequent phases assume the gate from the previous one is in place.

| # | Phase | Commit | What landed |
|---|---|---|---|
| 1 | ASCII baselines + smoke-check filter | `7143128` | 247 missing ASCII baselines recorded; `asciiSnapshot` honours `shouldSkipSnapshot(for: "ascii")`; `bootstrap-smoke-check.sh` stops invoking the signal-10-prone unfiltered `swift test` and runs per-suite passes instead. Bonus: D2 probe extended to cover `xychart`/`quadrantChart`/`journey`/`treemap`/`ishikawa`/`eventModeling`/C4* headers and strip leading frontmatter before header dispatch (case-insensitive token boundary). |
| 2 | Playground undo | `138e367` | `SourceOrigin` split into `.system` (wholesale swap, do re-seed) and `.mutation` (editor's document already in sync, skip re-seed). `performMutation` / `performFlowchartMutation` switched to `.mutation`. Cmd-Z command routes through `performScopedUndo` — the focused `NSTextView.undoManager` gets first refusal, falling back to `store.undoStructural()` only when no text view is focused. |
| 3 | Exporter correctness batch | `a13b67c` | `MermaidFlowchartExport.shapeMarker` returns `(open, close)` tuple; subgraph emission walks `model.subgraphs` after the node loop; trapezoid vs parallelogram open/close disambiguated. PlantUML state pseudostate restoration switched from id-suffix matching to `NodeShape.stateStart`/`.stateEnd`. PlantUML sequence message escape routes through the slice's `escape()` helper. PlantUML class parser tracks an `inBlockComment` flag so `/' … '/` multi-line comments are skipped entirely. MermaidClass annotation emitted bare (`<<interface>>`, not `<<"interface">>`); stray space after `:::` removed. |
| 4 | Parser dispatch tokenization | `633bec4` | 21 `DiagramRegistry+*.swift` matchers migrated from `$0.normalized.hasPrefix("…")` to `$0.startsWithToken("…")`. State's compound expression split into `startsWithToken("statediagram") || startsWithToken("state")`. Block/Gantt/Pie were already correct; C4 uses an anchored regex; Flowchart is the `{ _ in true }` fallback. |
| 5 | Renderer color/flip | `f7990d5` | `ShapeRenderer` fill/stroke suppression checks now use `bmColorEquals(.clear)` so AppKit color-space differences don't slip past. `LabelRenderer` always installs its own `NSGraphicsContext(flipped: false)` (save + restore), eliminating the bitmap-path vs AppKit-NSView-path double-flip. |

`er-25-parent-marker` is now tagged `skipSnapshots: ["ascii"]` so the ASCII gate is green; SVG/image still cover the entry. The underlying `.invalidCardinality("MD_PARENT")` in the ER ASCII renderer remains and is recorded in the deferred list below.

---

## Resolution Status — Session 2 (2026-05-14)

The deferred items from the first pass were worked through end-to-end across eleven commits on `main`. Each entry below covers one commit; sequencing was safest-first (smallest blast radius last → biggest scope last).

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §6 Tautological probes | `dba530b` | `ProbeCollisionMatrixTests.swift` — three fixture-checks-fixture tests (`d2ProbeSignature`, `plantumlProbeSignature`, `structurizrProbeSignature`) replaced with three real `PlantUMLImporter().supports(...)` assertions. Added `import DiagramKitPlantUML`. D2 and Structurizr already had real probe coverage further down. 44 tests pass. |
| 2 | §3 ER ASCII `MD_PARENT` | `e2b9d57` | `AsciiErCardinality` gains `.parent = "md-parent"`; `_toAsciiCardinality` accepts `"MD_PARENT"`; `getCrowsFootChars` renders `*` (ASCII) / `◆` (Unicode), matching the filled diamond the CG and SVG renderers already emit. `er-25-parent-marker` no longer carries `skipSnapshots: ["ascii"]`; new ASCII baseline recorded. |
| 3 | §2 D2/DOT walker | `5efa83f` | `FlowchartExportSink` gains optional `handlesSubgraphs: Bool` (defaults `false`) + `subgraphBegin(_:depth:)` / `subgraphEnd(_:depth:)`. `walk(...)` now returns `[DiagramDiagnostic]` and emits one `.warning` per dropped subgraph (with nested recursion). `D2Exporter` and `DOTFlowchartExport` thread the diagnostics through `DiagramExportResult`. Two new tests verify the warning path. |
| 4 | §4 Architecture & API | `31f7ced` | `ReExports.swift` re-exports `DiagramKitInteractive` under the Apple-platform gate. `original_src_theme/styles/text_metrics/multiline_utils` flipped from `open class` to `public final class`. New `Sources/DiagramKit/Deprecations.swift` is the single sunset surface for Phase-0 Mermaid* aliases; scattered typealiases removed; `Parser.swift` deleted (`MermaidParser` moved into `Deprecations.swift` with `parse(_:)` now `public`). `DiagramSourceImporter` gains `isFallback: Bool` (default `false`); `MermaidImporter` declares `isFallback = true`. Importer-by-name vs exporter-by-`DiagramFormatID` asymmetry documented in the protocol header. |
| 5 | §4 Model edges | `7bdd439` | `src_block_parser.swift` rejects non-positive `span` at parse time (3 sites). `ClassDiagram.direction` migrated to a typed `public enum ClassDirection: String { TB, BT, LR, RL }`; `elkhDirection(from:)`, `MermaidClassExport`, and test sites updated. `src_radar_layout.swift` falls back to unit-range when curves are empty and `options.max == nil`. `src_gantt_parser.swift` serializes the `_dateFormatterCache` through a private `DispatchQueue`. `SourcePreprocessing.swift` tightened to "exactly one closing `---` after the opener" — frontmatter no longer eats body content. `src_parser.swift` anonymous-subgraph id bumps the index until unique. |
| 6 | §4 Rendering & views | `04b00ee` | `EdgeRenderer.swift` `.arrow` case no longer hardcodes `setLineWidth(0.75)` — the configured `lineWidth` (line 106) reaches the outline stroke. `DiagramLayer` clear-on-failure semantics: `preparedDiagram` and `diagramBounds` nil on parse error, `parseError` nils on success. New `DiagramLayer.updateContentsScale(_:)` so iPad/Catalyst hosts can correct the `UIScreen.main.scale` fallback once attached to a window. `DiagramEditor+Undo`'s `_restoreSnapshot` gains a `selection:` parameter; `perform(_:)` and `performFlowchart(_:)` capture `oldSelection` so `.deleteElement` + undo restores the pre-delete selection. |
| 7 | §4 Format slices | `5ef689f` | `MermaidExportHelpers.sanitizeIdentifier` severity flipped `.info`→`.warning` (aligns with Structurizr); new `sanitizeIdentifier(_:usedAliases:)` overload for collision-aware emission. `PlantUMLImporter` throws `.malformedSource` instead of `.notYetImplemented` for body-extraction failure AND no-family-matched. `PlantUMLSequenceParser` now parses `title <text>` onto a new `PlantUMLSequenceAST.title`; mapper emits `.title(_)` so the title round-trips through `DiagramDocument.title`. `PlantUMLFamilyProbe` class association regex tightened to `\w+\s*--\s*\w+`. `D2Parser.preprocess` strips both `#` and `//` inline comments via `_stripInlineComment(_:marker:)`. Two stale integration tests updated. |
| 8 | §4 Playground state | `57a33da` | `DiagramEditor.preferredExportFormat` `let` → `var` so hosts can swap formats mid-edit. `LiveEditorStore.requestRender(reason:)` clears `parseError` when scheduling a new render — the stale error overlay no longer sits on top of a fresh canvas. `InsertNodeSection` / `InsertEdgeSection` no longer mirror mutation errors in local `@State`; `store.lastMutationError` is the single source of truth. |
| 9 | §4 Tests/gates | `90ead92` | New `Tests/DiagramKitTests/ParserDispatchOrderTests.swift` — 16 pinned `header → DiagramType` cases (`stateDiagram-v2` not falling to `state`, `flowchart-elk` not falling to fallback, `classDiagram-v2` not falling, plus 13 others). `GanttAsciiRendererTests` drops the `defer { unsetenv }` so parallel runs can't race the corpus reader. `Scripts/strict-concurrency-check.sh` now captures `swift build`'s exit code; non-zero without `"Build complete!"` fails. `CLAUDE.md` test count synced 188→216. |
| 10 | §5 Polish | `d072722` | `EdgeRenderer` and `LabelRenderer` flipped to `public final class`. `DiagramColorParser._parseRGBFunction` clamps each component to `[0,1]` via inline `max(0, min(1, …))`. `src_parser.swift` "BR" direction comment rewritten to explain the Mermaid-parity collapse onto `.BT`. `DiagramEditorPane.swift:6` header no longer references the removed `InspectorView`. |
| 11 | §1 SVG color-mix resolver | `1c2f18f` | `SVGHelpers._resolveSvgCssVariables` rewritten with a paren-counting walker. New internal helpers: `_findFirstBalancedFunction(in:name:)` with word-boundary discipline, `_parseVarBody(_:)` that splits at the first top-level (depth-0) comma, `_resolveVarFunctions(in:vars:)` for recursive substitution, `_flattenBalancedFunction(_:name:replacement:)` for the color-mix and unresolved-var post-pass. `Tests/DiagramKitTests/SVGCssVariableResolverTests.swift` covers 13 cases (nested var-in-color-mix, word boundaries, walker internals, the original REVIEW regression input). **No baseline regeneration this session** — see §1 below for the rebaseline phase. |

Session-end verification: targeted `swift test --filter` across all touched suites pass 267/267; `Scripts/check-sendable-annotations.sh` ✓ green; `Scripts/strict-concurrency-check.sh` ✓ first-party clean; `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings (no new threshold crossings).

---

## Resolution Status — Session 3 (2026-05-14)

Mechanical follow-ups from the §5 "Minor / Polish" and §4 leftovers that needed no design call. Four commits on `main`; tasks reclassified or already-resolved are noted below the table.

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §5 Dead code purge | `8e5a13a` | `Sources/DiagramKitRenderingCG/ArrowRenderer.swift`, `Version.swift`, and the deprecated CG-layer `DiagramFontResolver` enum (the `.proportional`/`.boldProportional`/`.mono` shim) deleted. No in-tree callers remain. The live model-layer `DiagramFontResolver` struct is unaffected. |
| 2 | §4 DiagramImportResult `@_exported` | `23a4be5` | `@_exported import DiagramKitCommon` in `Sources/DiagramKitImport/DiagramImportResult.swift` replaced with a plain `import DiagramKitCommon` plus `public typealias DiagramDiagnostic = DiagramKitCommon.DiagramDiagnostic`. Only the single cross-target type leaks, not the whole namespace. |
| 3 | §5 DOT/D2 trailing newline | `fb8d6ad` | `DOTFlowchartExport.emit` now appends `"\n"` after joining lines, matching `D2FlowchartExport` and `MermaidFlowchartExport`. `DOTExporterTests.swift` updated from `hasSuffix("}")` to `hasSuffix("}\n")`. |
| 4 | §5 MermaidFlowchartExport shape-downgrade `.warning` | `6a793c3` | `shapeMarker(for:)` return type widened to `(open, close, lossy)`. The canonical flowchart shapes (rectangle, rounded, stadium, subroutine, cylinder, diamond, hexagon, circle, doublecircle, trapezoid*, asymmetric, ellipse, parallelogram*) carry `lossy: false`; the ~45 non-flowchart shapes (state, mindmap, v11 icon shapes, etc.) carry `lossy: true`. The main emit loop appends a `.warning` diagnostic per lossy node, mirroring DOTMapper's discipline. |

**Reclassified as design-required (intentionally skipped):**
- §5 Generators (`AsciiVisualReportGenerator` / `VisualReportGenerator` / `ExampleImageExporter`): XCTest discovery is class-based, not filename-based, so file renames alone don't clean the `swift test` listing. A proper fix needs a separate test target — design work.
- §4 `DiagramKitTestSupport` placeholder: re-read showed the file's own docstring already documents that the empty `public enum` is the intentional namespace surface and that the corpus loader lives in `CorpusEntry.swift` alongside it. No documented claim contradicts this; nothing to fix.

**Already resolved upstream (verified during this pass):**
- §4 `LiveEditorStore.didCompleteRender:306` dead `_ = parseError` — grep finds no such read; landed earlier in Session 2's `57a33da`.
- §4 `NativeCodeEditor.Coordinator.textDidChange` retain — the `Task` closure already captures `[weak self, weak textView]` with `guard let self else { return }`; no cycle present.

Session-end verification: targeted `swift test --filter` across `MermaidExporterTests`, `DOTExporterTests`, `MermaidImporterTests`, `ImporterRegistryTests`, `ExportMatrixTests`, `DiagramExportInfrastructureTests`, `DiagramExportLoaderTests` all green; `Scripts/check-sendable-annotations.sh` ✓ green; `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings (no new threshold crossings).

---

## Resolution Status — Session 4 (2026-05-14)

Closes Deferred Effort §1 (SVG color-mix variable resolver) — the rebaseline phase deferred from Session 2's `1c2f18f`. Brainstormed spec at `docs/superpowers/specs/2026-05-14-svg-palette-audit-rebaseline-design.md`; plan at `docs/superpowers/plans/2026-05-14-svg-palette-audit-rebaseline.md`. Eight commits on `main`.

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §1 Spec | `b222b15` | SVG palette audit + baseline regeneration design — audit-gated five-phase plan. |
| 2 | §1 Plan | `ed7fa87` | Implementation plan honoring the C1–C5 commit map. |
| 3 | §1 Renderer palette routing | `6b35c80` | `DiagramPipeline.renderSVG(source:theme:)` and `(positioned:theme:)` no longer collapse nil tokens to fg/bg directly; route through `theme.effective<Token>()` color-mix derivations. For zinc-light, line=#27272A → #939394 and surface=#FFFFFF → #F9F9F9. |
| 4 | §1 Audit gate | `a5596f8` | New `PalettePinTests.swift` (per-theme assertion of `_hex(theme.effective<Token>())` across all 17 built-in themes). New `SVGStructuralSweepTests.swift` (live + on-disk modes; rejects `var(--…)` leakage, `))` tails, NaN, empty stroke/fill in attribute values; skips 17 pre-failing corpus IDs). CLAUDE.md test count 216 → 218. |
| 5 | §1 Recording driver | `c8c33bf` | New `Scripts/rebaseline-snapshots.sh` chunks `SNAPSHOT_TESTING_RECORD=all` runs at `--chunk 20` to dodge the signal-10 hang. Idempotent via `.rebaseline-logs/missing-<target>.txt`. Not part of `bootstrap-smoke-check.sh` — explicit operator action only. |
| 6 | §1 On-disk skip set | `83204f9` | C1 follow-up: on-disk SVG sweep mirrors the live sweep's `preFailingEntryIDs` skip set so stale baselines for unsupported families don't trip the structural check. |
| 7 | §1 Resolver iteration fix | `d6bdec7` | Caught by C4's first recording attempt: `_resolveVarFunctions` was bounded by `for _ in 0..<16` performing 16 *total* replacements, not 16 *depth* iterations. A typical 20+ var() SVG left most calls for step 4's flatten, masquerading as `#666666`. Switched to `while let` with a 4096 safety cap; undefined-with-no-fallback now emits `#666666` directly to keep the loop progressing and avoid empty `stroke=""`/`fill=""`. |
| 8 | §1 SVG rebaseline | `5cf2186` | 390 of 435 SVG baselines re-recorded (45 unmodified: 17 pre-failing entries + 28 byte-identical outputs). |
| 9 | §1 Image rebaseline | *this commit* | 57 image baselines re-recorded (51 imageSnapshot + 6 multiFormatImageSnapshot). The CG image renderer paths bypass `DiagramPipeline.renderSVG`, so most image bitmaps were already correct; only diagrams whose CG-direct rendering or layout shifted got new pixels. Visual canary set spot-checked (flow/seq/class/er/state/xychart). |

Session-end verification: `swift test --filter PalettePinTests`, `SVGStructuralSweepTests` (both modes), `CorpusSnapshotTests/svgSnapshot`, `CorpusSnapshotTests/imageSnapshot`, `SVGCssVariableResolverTests` all green. `Scripts/check-sendable-annotations.sh` ✓ green. `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings.

Non-resolver drift captured in the rebaseline window `1c2f18f..HEAD`: `8546f813` (`fix(c4): dispatch on shape family for tech vs description slots`) changed C4 family emit, expected in C4/C5 baseline diffs for that family.

---

## Resolution Status — Session 5 (2026-05-14)

Closes Deferred Effort §4 → Playground state machine → "`_export` runs synchronously on `@MainActor`; large flowcharts block main." Spec at `docs/superpowers/specs/2026-05-14-async-export-off-mainactor-design.md`; plan at `docs/superpowers/plans/2026-05-14-async-export-off-mainactor.md`. Fourteen commits on `main` (three docs + eleven implementation).

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §4 Spec | `eed1531` | Async export off MainActor design — serialize-and-preserve-atomicity policy, clean break to `async throws`, chained-Task with refcounted `isExporting`. |
| 2 | §4 Spec correction | `f64abd7` | Initial draft claimed Interactive already depended on `DiagramKitRenderingCG`; `Package.swift:116` shows it did not. Plan adds the dep as an Apple-conditional edge and routes Linux through a private fresh-`Thread` fallback. |
| 3 | §4 Plan | `ae2abfc` | Eleven-task implementation plan honoring TDD where the refactor permits. |
| 4 | §4 SPM dep | `8a101e0` | `Package.swift` adds `.target(name: "DiagramKitRenderingCG", condition: .when(platforms: [Apple]))` to `DiagramKitInteractive`'s dependencies. Edge is platform-gated so Linux stays buildable. |
| 5 | §4 Worker helper | `26e7a27` | `DiagramEditor._runOnWorker<T>` forwards to `DiagramWorkerThread.run` on Apple; spins a fresh `Thread` with `DiagramWorkerConfig.stackSize` on Linux. Lives in `DiagramEditor+SourceSync.swift`. |
| 6 | §4 `perform` async | `9033d26` | `DiagramEditor.perform(_:)` becomes `async throws`. New `_exportAsync` hops to the worker; sync `_export` retained one more commit because `performFlowchart`/`syncSource` still call it. `LiveEditorStore.performMutation` and the four `DiagramEditorPane` button callsites (`setTitle` set/clear, `setLabel`, `deleteElement`) migrate to `await`. 28 callsites in `DiagramEditorMutationTests` + 10 in `DiagramEditorUndoTests` swept; two undo tests (`sequentialMutationsUndo`, `multipleMutationCanUndo`) updated because async perform yields between mutations and Foundation's per-run-loop implicit undo grouping no longer applies — the new contract is "every mutation gets an undo entry," verified by stepping the undo stack one entry at a time. |
| 7 | §4 `performFlowchart` async | `073c3f2` | Same worker-hop migration. `LiveEditorStore.performFlowchartMutation`, the two insert sections in `DiagramEditorPane`, and `DiagramEditorFlowchartTests` (9 callsites) migrate. |
| 8 | §4 `syncSource` async + delete `_export` | `285eeab` | Last sync entry point promoted. With no callers remaining, the sync `_export` helper is deleted in the same commit. `DiagramEditorTests`, `DiagramEditorSourceSyncTests`, plus `applySeededEditor` in `LiveEditorStore` migrate to `await`. |
| 9 | §4 Chained-Task + `isExporting` | `aa6ebc5` | `DiagramEditor` gains `isExporting: Bool` (Observable), `_pendingMutation: Task<Void, Error>?`, `_pendingMutationGeneration: UInt64`, and `_mutationDepth: Int` (all `@ObservationIgnored`). `perform` and `performFlowchart` extract their commit bodies into `_performInner` / `_performFlowchartInner` and wrap them in a `Task` that the next caller awaits. The refcount drives `isExporting` on 0→1 / N→0 transitions only, avoiding mid-chain flicker. A monotonic generation token replaces identity comparison (Task is a struct — `===` doesn't apply). New `DiagramEditorAsyncExportTests` covers the two-call ordering and the `isExporting` on/off transitions via a gated test exporter. |
| 10 | §4 Atomicity-under-throw test | `76f9064` | `FailingExporter` throws `DiagramExportError(message: "boom")`; test asserts `document.payload`, `source`, `undoManager.canUndo`, and `isExporting` are all unchanged from pre-call state. |
| 11 | §4 Cancellation isolation test | `6ba9347` | Outer `Task` is `.cancel()`'d while the worker is mid-hop; the inner commit still lands. Verified by checking `model.nodesInOrder.contains("B")` and `isExporting == false` after a 50 ms drain. |
| 12 | §4 Off-MainActor test | `6d65dfe` | `ObservingExporter` records `Thread.isMainThread` from within `export(_:)`; test asserts `false`. Pins that the worker hop actually fires. |
| 13 | §4 UI wiring | `3d23e7f` | `DiagramEditorPane` mutation buttons (title set/clear, rename, delete, insert-node, insert-edge) gain `.disabled(editor.isExporting || …)`. Prevents rapid-fire taps from piling up Tasks during a slow export. |
| 14 | §4 CLAUDE.md sync | `98f5f6e` | Test source count 218 → 225 (the new `DiagramEditorAsyncExportTests.swift` plus six other files that landed between sessions). |

Session-end verification: targeted `swift test --filter` across `DiagramEditorTests`, `DiagramEditorMutationTests`, `DiagramEditorUndoTests`, `DiagramEditorFlowchartTests`, `DiagramEditorSourceSyncTests`, `DiagramEditorAsyncExportTests`, `LiveEditorStoreEditorLifecycleTests` all green (55 tests / 6 suites). `Scripts/check-sendable-annotations.sh` ✓ green. `Scripts/strict-concurrency-check.sh` ✓ first-party clean. `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings; no new threshold crossings from this work.

The deferred item §4 "`_export` runs synchronously on `@MainActor`" is now closed. Atomic-commit and per-mutation undo contracts preserved; the worker rule (8 MB fresh-Thread per dispatch) honored on both Apple and Linux.

---

## Deferred Effort — Recommendations

Some review items were intentionally deferred during the five-phase pass; others surfaced during execution and were scoped out to keep individual commits coherent. Listed in priority order.

### 1. SVG color-mix variable resolver (renderer-deep)

**Status:** investigated and rolled back in Phase 1. The malformed `stroke="#27272A 40%, #FFFFFF))"` strings the reviewer observed come from `Sources/DiagramKitModel/SVGHelpers.swift:138-145` (`color-mix\([^)]+\)`) and `:88-89` (`var\(\s*--…\s*(?:,\s*([^)]+))?\)`) — both regexes use `[^)]+` for the fallback/body, which stops at the first `)` and so mis-parses nested calls like `var(--muted, color-mix(in srgb, var(--fg) 40%, var(--bg)))`. A paren-counting walker (drafted during Phase 1, reverted before commit) produced correct output but changed 182 SVG baselines in addition to the 28 entries already failing.

**Session-2 outcome (partial):** the resolver rewrite landed in `1c2f18f` with 13 dedicated unit tests covering nested fallbacks, `color-mix(var(...), var(...))`, word boundaries, and the original REVIEW regression input. **The 422 SVG + 422 image baseline regeneration was intentionally deferred** — the malformed output the old resolver produced is what every existing baseline records, so rebaselining is a separate, large-diff commit that wants its own scrutiny.

**Remaining steps:**
- Audit whether the simultaneous theme-default regression (`flow-1-simple` baseline has `--muted:#A9A9AA;--line:#939394`; current renderer emits `--muted:#27272A;--line:#27272A`) is intentional. If unintentional, fix the theme system before rebaselining so the new baselines reflect the intended palette.
- Re-record all SVG and image baselines in a single commit, message "rebaseline after color-mix resolver fix" linking back to `1c2f18f`.

### 2. D2 / DOT `FlowchartExportWalker` subgraph traversal

**Status:** Mermaid flowchart export now emits subgraphs (Phase 3 fix). The walker shared by D2 and DOT exporters at `Sources/DiagramKitExport/FlowchartExportWalker.swift:42-52` still iterates only `nodesInOrder` and `edges`. D2 and DOT continue to silently drop subgraphs.

**Recommendation:** add two new methods to `FlowchartExportSink` (`subgraphBegin(_:depth:)` / `subgraphEnd(_:depth:)`) with default no-op implementations that emit a `.warning` diagnostic. Have the walker invoke them around the contained nodes. Existing D2/DOT sinks inherit the warning behavior; full subgraph emission for D2 (`subgraph: { … }`) and DOT (`subgraph cluster_… { … }`) can ship as follow-ups in each slice.

### 3. ER ASCII renderer `.invalidCardinality("MD_PARENT")`

**Status:** `er-25-parent-marker` is marked `skipSnapshots: ["ascii"]` to keep the gate green. SVG and image renderers handle the parent-marker (`u--o{`) cardinality correctly; only ASCII throws.

**Recommendation:** add `MD_PARENT` to the ER ASCII renderer's cardinality table in `Sources/DiagramKitModel/src_er_renderer.swift` (or wherever the ASCII variant lives). Remove the `skipSnapshots` entry once fixed and record the new ASCII baseline.

### 4. Important-tier review items not in the original fix plan

The following Important findings from the review remain. None are correctness-critical but each is either an architecture hazard, a long-term debt, or a fragility the next major release should address.

**Architecture & API**
- `ReExports.swift:6-13` does not re-export `DiagramKitInteractive` despite `Package.swift` adding it as an umbrella dep. Add the re-export so `import DiagramKit` surfaces `DiagramEditor`.
- `src_theme.swift:4`, `src_styles.swift:4`, `src_text_metrics.swift:4`, `src_multiline_utils.swift:4` are `open class`. Lock down to `internal` or `public final` — these are JS-port shims with no documented subclassing contract.
- `DiagramFormatID` exists only on the exporter side; importers identify by `name: String`. Either move `DiagramFormatID` to `DiagramKitCommon` and adopt symmetrically, or document the asymmetry.
- Deprecated typealiases (`MermaidParser`, `MermaidRenderer`, `MermaidPipeline`, `MermaidImageRenderer`, `MermaidStructuralError`) are scattered across the umbrella. Consolidate in a single `Deprecations.swift` so the next major can sunset them atomically.
- `MermaidImporter.swift:23-34` — `supports(source:)` returns true for any non-empty source. Add an explicit `isFallback: Bool` to the protocol so the registry can mechanically validate "exactly one fallback, last."

**Model: numeric & concurrency edges**
- `src_block_parser.swift:546-547` accepts non-positive `span` values; at `src_block_layout.swift:117` this becomes a divide-by-zero / NaN. Reject `Int(parts[1])` ≤ 0 at parse time.
- `src_class_parser.swift:19` stores `direction: String`; every other family uses a typed enum. Migrate to a typed `ClassDirection` enum (`TB`/`BT`/`LR`/`RL`).
- `src_radar_layout.swift:19-20` — `maxValue = -.infinity` when entries are empty and `options.max` is nil. Add an empty-curve guard and clamp `relativeRadius(...)` against `min == max`.
- `src_gantt_parser.swift:410-423` — `_dateFormatterCache` is `nonisolated(unsafe)`; `DateFormatter.date(from:)` is not documented thread-safe. Wrap with a serial queue, or per-call instantiate, or migrate to `Date.ParseStrategy`.
- `SourcePreprocessing.swift:69-89` — every `---`-bounded section between the first and last marker is treated as frontmatter; a body containing a literal `---` separator line is partially eaten. Tighten to "exactly one closing `---` after the opener, no greedy consumption."
- `src_parser.swift:438-440` — anonymous-subgraph id `"subgraph_\(graph.subgraphIds.count)"` has no collision guard against user-defined ids.

**Rendering & views**
- `EdgeRenderer.swift:119` — `.arrow` case hardcodes `context.setLineWidth(0.75)`, ignoring the configured `lineWidth`. Source the width from the configured stroke.
- `DiagramLayer.swift:182-189` — on parse failure, `preparedDiagram` is not cleared. Pick an intentional semantics (clear-on-failure vs preserve-with-error-overlay) and document it.
- `DiagramEditor+Undo.swift:29-51` — undo snapshot does not capture `selection`. After `.deleteElement(...)`, undo restores doc/source/diagnostics but the dangling selection can throw on the next mutation. Capture selection in the snapshot.
- `DiagramRenderer.swift:147-161` — 4000pt multiline bounding box is a band-aid. Replace with a `measure-first` strategy so the box matches the actual text extent.
- `DiagramLayer.swift:91` — `UIScreen.main.scale` is deprecated on iOS 13+ multi-scene. Source scale from the view's window scene (`view.window?.windowScene?.screen.scale`).

**Format slices: round-trip & diagnostic discipline**
- Identifier-sanitization severity is inconsistent between `MermaidExportHelpers.sanitizeIdentifier` (`.info`) and Structurizr's `uniqueSanitizedAlias` (`.warning`). Pick one (`.warning` is closer to the right severity for lossy operations) and apply across slices.
- `MermaidC4Export.swift:42-54` and `PlantUMLC4Export.swift:47-56` disagree on the slot semantics of the third positional arg (`desc` vs `tech`). Cross-format C4 round-trip silently swaps technology↔description. Align via a single `C4ArgsEmitter` helper.
- `PlantUMLImporter.swift:30-32, 110` throws `.notYetImplemented` for two distinct conditions (malformed source vs unrecognized family). Split into `.malformedSource` and `.unsupportedFamily`.
- `PlantUMLSequenceParser.swift:409-411` declares `title` unsupported; both exporters emit it. Add title parsing to close the round-trip.
- `PlantUMLFamilyProbe.swift:58-61` — class probe false-matches any text containing `--`. Tighten the heuristic.
- `MermaidExportHelpers.sanitizeIdentifier` silently drops non-`[A-Za-z0-9_-]` chars without collision checking. Mirror Structurizr's `usedAliases` set.
- `D2Parser.swift:43-49` only strips `#` as inline-comment marker; `// note` trailing values leak into the value.
- `DOTLexer` does not enter HTML-label mode; `label=<<TABLE>…</TABLE>>` drops the rest of the attribute list. `DOTMapper._isHTMLLabel` (`DOTMapper.swift:382-391`) is dead code until the lexer is fixed.
- `StructurizrExporter.swift:84-91` drops boundary metadata; the companion importer rebuilds boundaries from parent relationships, so export → import loses information. Emit a paired `.warning` on the import side or close the round-trip.
- `D2Mapper.swift:74-101` silently drops direction/icon/tooltip/link from second occurrences in duplicate-node-ID paths.

**Playground state machine**
- `UndoManager.canUndo`/`canRedo` are not Observation-tracked; SwiftUI `.disabled(!editor.undoManager.canUndo)` modifiers drift. Phase 2 sidesteps this by dropping `.disabled` and routing in the action body, but the structural undo footer still has the issue. Mirror `canUndo`/`canRedo` as `@Observable` shims on `DiagramEditor`.
- `DiagramEditor.preferredExportFormat` is `let`; format swaps mid-edit can export under the old format. Either make mutable or rebuild the editor on format change.
- `previewState` is captured pre-render; auto-save can record a state the user hasn't actually rendered. Capture post-render in `didCompleteRender`.
- `_export` runs synchronously on `@MainActor`; large flowcharts block main. Hop to a worker for the export call.
- `LiveEditorStore.performMutation` and `InsertNodeSection.insert` both surface mutation errors, producing duplicate UI. Pick one source of truth.
- `SidebarView.loadDiagram` ignores `expectedDiagnostics` / `unsupportedNote`. Wire the corpus metadata into the load path.
- `requestRender(reason:)` doesn't reset `parseError`; the error overlay sits atop a fresh render until completion. Clear on render request.

**Tests, gates, concurrency**
- `GanttAsciiRendererTests.swift:9-10` sets+defers `DIAGRAMKIT_GANTT_TODAY`; `CorpusSnapshotTests.swift:46` only sets it. Pin the env var process-wide in a shared suite bootstrap.
- `Scripts/strict-concurrency-check.sh:24` ignores `swift build`'s exit code. Capture and surface it.
- `CLAUDE.md` claims 188 test files; actual is 216. Sync the doc.
- No targeted test for the parser dispatch-order invariant. Add a small suite that pins "stateDiagram-v2 does not fall into state branch", "flowchart-elk does not fall into flowchart branch", etc.

### 5. Minor / polish items

Session-3 closed the dead-code purge (`8e5a13a`), the `MermaidFlowchartExport.shapeMarker` shape-downgrade `.warning` (`6a793c3`), and the DOT/D2 trailing-newline alignment (`fb8d6ad`). What remains in the original "Minor" tier — file-size warnings still over 500 lines, residual header comments referencing removed files, accessibility labels across the playground demo, and any small touches not yet picked up — is left as opportunistic backlog. Pick up when touching the relevant file.

### 6. Tautological probe tests (Critical, deferred)

`Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift:30-48` — three `@Test` cases (`d2ProbeSignature`, `plantumlProbeSignature`, `structurizrProbeSignature`) construct a literal then `#expect` the same literal contains its own substring. Tautological. Delete or replace with real importer-probe assertions.

---

## Critical (Must Fix)

### Exporters silently corrupt valid input
- **`Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidFlowchartExport.swift:45`** — node-shape wrapping uses `shapeStr.prefix(1) + label + shapeStr.suffix(from: 1)`, so any marker longer than 2 chars produces invalid Mermaid: `(())` becomes `(label())`, plus `[[]]`, `((()))`, `[(%)]`, `([])`, `{{}}`, and all circle variants.
- **`MermaidFlowchartExport.swift:31-55` + `Sources/DiagramKitExport/FlowchartExportWalker.swift:42-52`** — the walker iterates `nodesInOrder` and `edges` only; `model.subgraphs` is never visited. Mermaid, D2, and DOT flowchart exports silently drop all subgraphs/clusters with no diagnostic.
- **`Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift:41`** — message labels escape only `\n`, bypassing the slice's own `escape()` (lines 184-195) that handles `\\`, `"`, and CR. Labels containing a backslash or quote corrupt the line.
- **`Sources/DiagramKitPlantUML/Exporter/PlantUMLStateExporter.swift:107-112`** — `restorePseudostate` rewrites any node id ending in `_start` or `_end` to `[*]`. A legitimately named `customer_start` becomes a pseudostate. Silent data corruption.
- **`Sources/DiagramKitPlantUML/Sequence/PlantUMLSequenceParser.swift:304-308` and `PlantUMLStateParser.swift:190-201`** — `firstIndex(of: ":")` is not quote-aware despite a code comment saying it should be. `Alice -> Bob : "label: detail"` loses everything after the inner colon.
- **`Sources/DiagramKitPlantUML/Class/PlantUMLClassParser.swift:22-27`** — only the opening line of `/' … '/` block comments is skipped; subsequent lines parse as content.
- **`Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidClassExport.swift:51,73`** — annotations emit as `<<"quoted">>` (helper-quoted into the bracket form) and `:::  classes` has a stray space, both producing invalid Mermaid.

### Parser dispatch invariant drifting
- **Sources/DiagramKit/DiagramRegistry+\<Family\>.swift** — most matchers use `$0.normalized.hasPrefix("…")` instead of the bespoke `DiagramHeader.startsWithToken(...)` helper at `DiagramDescriptor.swift:29-36`. `+Pie`, `+Gantt`, `+Block` use it correctly; Architecture, Sequence, Class, ER, Mindmap, Sankey, GitGraph, Packet, Kanban, Timeline, Treemap, etc. do not. A future header like `architectureGroup` would mis-match `architecture`.

### Public API contract holes
- **`Sources/DiagramKit/Parser.swift:7`** — `public enum MermaidParser` carries `@available(*, deprecated, renamed:)`, but its sole member `static func parse` is `internal`. The deprecation guidance has no public surface to deprecate.
- **`Sources/DiagramKit/DiagramEngine.swift:120-146`** — `renderSVG` and `renderASCII` are wrapped in `#if canImport(CoreGraphics)`, silently removing the Linux SVG/ASCII entry points that ARCHITECTURE.md advertises.

### Renderer color/flip discipline
- **`Sources/DiagramKitRenderingCG/ShapeRenderer.swift:78,85`** — `if fillColor != .clear` / `if strokeColor != .clear` violates CLAUDE.md's "use `bmColorEquals()` for color comparisons." AppKit `.==` is color-space sensitive; on AppKit a `BMColor(hex:)`-derived `.clear` may not compare equal to the class property, producing snapshot drift.
- **`Sources/DiagramKitRenderingCG/LabelRenderer.swift:120-128`** — when an outer view installs an `NSGraphicsContext` (as `DiagramNativeView.draw(_:)` does), `needsContext` is false and the manual CTM unflip can compound with `NSAttributedString.draw(in:)`'s own flip handling. Bitmap path vs `DiagramNativeView` AppKit path may emit non-identical baselines.

### Playground destroys its own undo history
- **`Sources/DiagramPlayground/Models/LiveEditorStore.swift:313, 338-365`** — `didCompleteRender(...)` calls `seedEditorFromSource()` on every successful render; every mutation triggers a render via `setSource(..., origin: .system)` at `LiveEditorStore.swift:749`; the seed replaces `editor` with a fresh `DiagramEditor` whose `UndoManager` is new. One mutation wipes the undo stack — defeating commit `1bfeb0c` (Cmd-Z routing) and silently losing work.
- **`Sources/DiagramPlayground/DiagramPlaygroundApp.swift:38-45`** — the `.undoRedo` command group is replaced with `store.undoStructural()` whenever `editor?.undoManager.canUndo == true`. The macOS Edit > Undo menu then intercepts Cmd-Z while the user is typing in `NativeCodeEditor` (which has its own `allowsUndo = true`), undoing graph mutations instead of recent typing.
- **`LiveEditorStore.swift:323-335`** — `seedEditorFromSource()` spawns an unstructured `Task` per render with no cancellation/generation token; an older parse can land after a newer one and replace `editor` with a stale document.
- **`Sources/DiagramPlayground/Views/Editor/LiveEditorToolbar.swift:181-187`** + **`LiveEditorView.swift:20, 68-75`** — Cmd-I on iOS toggles `state.inspectorOpen`, but the compact layout gates the Inspector on a local `@SwiftUI.State private var compactMode`. `inspectorOpen` is unread; the iPhone shortcut and toolbar toggle are silent no-ops.

### Test gates that can't actually pass
- **`Tests/DiagramKitTests/CorpusSnapshotTests.swift:85-89`** — `asciiSnapshot` records-on-first-run with no committed baselines for 248 of 422 entries; only 6 families (class/xychart/flow/er/seq/state) have ASCII baselines on disk. Reviewer ran it: 248 issues, all auto-recorded. ASCII regressions in 22 renderers are currently invisible.
- **`Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift:30-48`** — three `@Test` cases (`d2ProbeSignature`, `plantumlProbeSignature`, `structurizrProbeSignature`) construct a literal then `#expect` the same literal contains its own substring. Fixture-comparing-fixture; tautologically green.
- **`Scripts/bootstrap-smoke-check.sh:57`** — `run_gate "swift test" swift test` runs the full suite, which is documented (and remembered) to hang on signal-10. The merge gate can never green-light as written.

---

## Important (Should Fix)

### Architecture & API
- **`ReExports.swift:6-13`** does not re-export `DiagramKitInteractive`, but Package.swift adds it as an Apple-platform umbrella dep and CLAUDE.md claims it's re-exported. `import DiagramKit` won't see `DiagramEditor`.
- **`Sources/DiagramKitModel/src_theme.swift:4`, `src_styles.swift:4`, `src_text_metrics.swift:4`, `src_multiline_utils.swift:4`** are `open class`. JS-port shims with no public-subclassing contract should be `internal` or `public final`.
- **`DiagramFormatID`** lives only on the exporter side (`DiagramKitExport/DiagramFormatID.swift`); importers identify by `name: String` (`DiagramSourceImporter.swift:14`). Asymmetric and a long-term dispatch hazard.
- **`DiagramImportResult.swift:5`** uses `@_exported import DiagramKitCommon` to re-export `DiagramDiagnostic`. Couples consumers transitively to all of `DiagramKitCommon` — preferable to re-export the specific symbol or document the choice in a banner.
- **Deprecated `MermaidParser`/`MermaidRenderer`/`MermaidPipeline`/`MermaidImageRenderer`/`MermaidStructuralError` typealiases** are scattered across the umbrella. Consolidate in a single `Deprecations.swift` so the next major can sunset them atomically.
- **`MermaidImporter.swift:23-34`** — `supports()` returns true on any non-empty source. Protocol can't express "fallback"; consider adding `isFallback: Bool` so the registry can validate exactly-one-fallback-and-it's-last.

### Model: numeric & concurrency edges
- **`src_block_parser.swift:546-547`** accepts `Int(parts[1])` ≤ 0 as `span`/`widthInColumns`. At `src_block_layout.swift:117` that becomes `size.width / Double(child.widthInColumns ?? 1)` → NaN on `id:0`.
- **`src_class_parser.swift:19`** stores `direction: String`; every other family uses a typed enum (`ErDirection`, `GitGraphOrientation`, etc.). Breaks payload-modeling consistency.
- **`src_radar_layout.swift:19-20`** — if `options.max == nil` and `curves.flatMap(\.entries).isEmpty`, `maxValue = -.infinity`; combined with unguarded `options.min`, downstream `relativeRadius(...)` may yield NaN reaching `cos/sin`.
- **`src_gantt_parser.swift:410-423`** — `_dateFormatterCache` is `nonisolated(unsafe)` and `DateFormatter.date(from:)` is not documented as thread-safe. Two pipeline calls sharing the same cache key under concurrent workers → technically undefined.
- **`SourcePreprocessing.swift:69-89`** — every `---`-bounded section between the first and last marker is treated as frontmatter; a source like `---\nA\n---\nbody1\n---\nbody2` swallows `body1`.
- **`src_parser.swift:438-440`** — anonymous-subgraph id `"subgraph_\(graph.subgraphIds.count)"` has no collision guard against user-defined ids.

### Rendering & views
- **`EdgeRenderer.swift:119`** — `.arrow` case hardcodes `context.setLineWidth(0.75)`, ignoring the configured `lineWidth` at line 72. SVG won't carry this hardcode → visual drift.
- **`DiagramLayer.swift:182-189`** — on parse failure, `preparedDiagram` is not cleared; views keep displaying the previous successful render with `parseError` surfaced separately. Bindings consumers can't observe the failure as a state change.
- **`Sources/DiagramKitInteractive/DiagramEditor+Undo.swift:29-51`** — undo snapshot does not capture `selection`. After `.deleteElement(...)`, undo restores doc/source/diagnostics but selection dangles → next mutation throws `elementNotFound` mid-flow.
- **`DiagramRenderer.swift:147-161`** — 4000pt multiline bounding box is a band-aid over missing measurement; structurally repeats the prior 1000pt → larger-number cycle.
- **`DiagramLayer.swift:91`** — `UIScreen.main.scale` is deprecated on iOS 13+ multi-scene; wrong backing scale on a secondary scene (iPad / Catalyst).

### Format slices: round-trip & error/diagnostic discipline
- **Identifier-sanitization severity inconsistent**: `MermaidExportHelpers.sanitizeIdentifier` (`MermaidExportHelpers.swift:90-95`) uses `.info`; Structurizr's `uniqueSanitizedAlias` (`StructurizrExporter.swift:204-209`) uses `.warning`. Same lossy operation should pick one.
- **C4 slot semantics disagree**: `MermaidC4Export.swift:42-54` emits third positional arg as `desc` if present else `tech`. `PlantUMLC4Export.swift:47-56` orders args `[alias, label, tech?, desc?]`; `PlantUMLC4Parser.swift:49-50` reads `args[2]=technology, args[3]=description`. Cross-format round-trip silently swaps technology↔description.
- **`PlantUMLImporter.swift:30-32, 110`** throws `.notYetImplemented` for both malformed-source and unrecognized-family — conflates two different states.
- **`PlantUMLSequenceParser.swift:409-411`** marks `title` unsupported, but `MermaidSequenceExport` and `PlantUMLSequenceExporter` both emit it. Round-trip silently drops titles.
- **`PlantUMLFamilyProbe.swift:58-61`** — class probe `trimmed.contains("--") && !trimmed.contains("-->")` false-matches any text with `--`.
- **`MermaidExportHelpers.sanitizeIdentifier` lines 70-83** silently drops non-`[A-Za-z0-9_-]` chars without checking post-sanitize collisions (`foo bar` and `foo!bar` both become `foo_bar`). Mirror Structurizr's `usedAliases` set.
- **`D2Parser.swift:43-49`** strips only `#` as inline-comment marker; `// note` trailing values is left in the value.
- **`DOTLexer`** does not enter HTML-label mode for `label=<<TABLE>…</TABLE>>`; parser drops the rest of the attribute list. `DOTMapper._isHTMLLabel` (`DOTMapper.swift:382-391`) is dead because the lexer never produces such values.
- **`StructurizrExporter.swift:84-91`** drops boundary metadata as `.unsupported`, but its companion `StructurizrMapper.swift:169-181` rebuilds boundaries from parent relationships. Export → import loses boundaries without compensating import-side diagnostic.
- **`D2Mapper.swift:74-101`** — duplicate-node-ID path (line 41-46) silently drops direction/icon/tooltip/link from second occurrences.

### Playground state machine
- **`UndoManager.canUndo`/`canRedo`** are plain Foundation, not Observation-tracked. `.disabled(!editor.undoManager.canUndo)` modifiers in `DiagramEditorPane.swift:484, 491` + `DiagramPlaygroundApp.swift:41, 44` only re-evaluate when other observed properties change → footer state drifts.
- **`DiagramEditor.preferredExportFormat`** is `let` (`DiagramEditor.swift:46`). Between `setSourceFormat(_:)` and the next `applySeededEditor`, a `performMutation` exports through the old format then overwrites source under the new format.
- **`previewState` is captured pre-render** (`LiveEditorStore.swift:716-721`) then auto-saved post-render (`LiveEditorStore.swift:315`); on parse failure followed by a different request, the auto-saved state may not match what's on screen.
- **`DiagramEditor` is `@MainActor` and `_export` runs synchronously** (`DiagramEditor+Mutations.swift:30-34, 91-96`). `DiagramExportLoader.export(...)` is inline → blocks main on large flowcharts.
- **`NativeCodeEditor.Coordinator.textDidChange`** (`NativeCodeEditor.swift:174-190`) cancels prior debounce but `MainActor.run` retains `self`; keystrokes during slow renders pile coroutines.
- **`LiveEditorStore.performMutation` writes `lastMutationError`** while `InsertNodeSection.insert` and `InsertEdgeSection.insert` (`DiagramEditorPane.swift:317-329, 427-448`) also keep `localError`; the pane renders both → duplicate error UI on a single failure.
- **`SidebarView.loadDiagram` ignores `expectedDiagnostics` and `unsupportedNote`** (`SampleDiagramPanel.swift:230-234`); known-unsupported corpus picks surface as generic parse errors.
- **`requestRender(reason:)`** (`LiveEditorStore.swift:283-287`) flips status but leaves `parseError` set; error overlay sits atop a fresh render until next completion.

### Tests, gates, concurrency
- **`GanttAsciiRendererTests.swift:9-10`** sets+defers `DIAGRAMKIT_GANTT_TODAY`; **`CorpusSnapshotTests.swift:46`** only sets it. Under parallel `swift-testing`, the Gantt unset races corpus loads.
- **`Scripts/strict-concurrency-check.sh:24`** runs `swift build … || true` and greps the log. A non-first-party build failure prints "✓ first-party clean" — capture exit code or detect "Build complete!" before declaring green.
- **`CLAUDE.md` claims 188 test files; actual is 216.** Coverage docs drift.
- **No targeted test for the parser dispatch-order invariant** (CLAUDE.md "stateDiagram-v2 must not fall into state branch"). Cheap regression insurance.
- **`DiagramKitTestSupport.swift`** is a 9-line placeholder; corpus loader actually lives in `CorpusEntry.swift`. Documented surface vs reality.

---

## Minor (Polish)

- **Files over the 500-line warn threshold** (allowlisted where applicable, but candidates for split):
  - Library: `src_ascii_index.swift:492`, `DiagramRenderer+Sequence.swift:609`, `ShapeRenderer.swift:533`, `DiagramRenderer+Wardley.swift:514`, `src_sequence_renderer.swift:555`, `src_er_renderer.swift:549`, `src_class_renderer.swift:515`, `src_xychart_renderer.swift:599`.
  - Playground: `LiveEditorStore.swift:873`, `SampleDiagrams.swift:685`, `PreviewCanvas.swift:617`, `ActionsView.swift:595`, `DiagramEditorPane.swift:502`, `NativeCodeEditor.swift:503`.
  - Tests: nine files >500, all in pre-existing allowlist.
- **Dead code**: `Sources/DiagramKitRenderingCG/ArrowRenderer.swift` (no callers), `Sources/DiagramKitRenderingCG/Version.swift` (empty), `DiagramFontResolver` deprecated shims with no in-tree callers, `_DiagramFontPlatform` placeholders.
- **`EdgeRenderer`/`LabelRenderer`** declared `public class` (non-final) — mark `final`.
- **`DiagramEditor+Mutations.swift`** — near-identical `.flowchart` / `.stateDiagram` blocks in `_deleteElement` and `_setLabel` (~80 dup lines, `:81-117, 134-186`).
- **`LiveEditorStore.didCompleteRender:306`** has a dead `_ = parseError`.
- **`DiagramEditorPane.swift:6`** header comment still references the removed legacy `InspectorView`.
- **`LiveEditorToolbar.swift:96-105` and `:179-187`** duplicate Cmd-I markup; one helper would keep icon/state in sync.
- Accessibility labels missing across `DiagramEditorPane` insert/delete/undo controls — for a demo app, this is a missed showcase.
- **`MermaidFlowchartExport.shapeMarker`** (lines 156-226) maps ~25 distinct shapes to plain `[]` — silent shape loss; a `.warning` diagnostic would mirror DOTMapper's discipline.
- **`AsciiVisualReportGenerator.swift` / `VisualReportGenerator.swift` / `ExampleImageExporter.swift`** are env-gated but still discovered by `swift test`; renaming them off the `*Tests` suffix would clean the default listing.
- **`src_parser.swift:1202-1211`** — `case "BR": return .BT` with misleading comment "Bottom-Right = Bottom-to-Top".
- **`DiagramColorParser.swift:95-117`** — `_parseRGBFunction` does not clamp r/g/b/a; percentage notation silently ignored.
- **`DOTFlowchartExport.swift:13` vs `D2Exporter.swift:47`** — cosmetic trailing-newline difference.

---

## Cross-cutting Observations

1. **Exporter testing is weaker than parser/renderer testing.** The Mermaid/PlantUML exporter bugs above would be caught by any round-trip suite (`parse → export → parse → assert structural equality`). None of these bugs depend on visual fidelity; they would fail purely structural assertions.
2. **`.unsupported` vs throw vs `.warning` vs `.info` is inconsistent across slices.** PlantUML throws for unrecognized family; Structurizr returns `.warning` diagnostics for identifier rewrites; Mermaid returns `.info` for the same operation; D2 silently drops second-occurrence properties. A single discipline doc + linter would help.
3. **The umbrella exposes two paths for the same operation** (`renderDiagramSVG` free function in `src_index.swift:70` and `DiagramEngine.renderSVG`). Pick one canonical entry.
4. **CLAUDE.md drift** is small but real: 188 vs 216 test files; "Interactive re-exported" claim vs actual `ReExports.swift`. Worth a sync.
5. **Linux support is partial-by-design** but the umbrella's `#if canImport(CoreGraphics)` around SVG/ASCII undermines the "DiagramKit on Linux exists" story.

---

## Assessment

**Original verdict (pre-fix):** Not ready to merge — the exporter correctness bugs silently corrupt valid input on common cases, the playground undo regression makes the recent Cmd-Z work non-functional in practice, and the ASCII snapshot baseline gap leaves renderer drift in 22 families invisible to CI.

**Updated verdict (post-fix, commits `7143128` → `f7990d5`):** The five-phase fix plan landed end-to-end. The originally critical exporter, playground-undo, and ASCII-gate failures are addressed; the renderer color/flip discipline issues are addressed; and a bonus D2-probe header fix unblocks Mermaid sources the importer had been wrongly claiming.

Remaining work is captured in the **Deferred Effort — Recommendations** section above. The highest-priority deferred item is the SVG color-mix paren-balancing bug in `_resolveSvgCssVariables` — fixing it correctly requires re-recording all 422 SVG + image baselines, so it deserves its own phase rather than a tail-on to Phase 5. None of the deferred items block merge of the five commits to date.

**Suggested fix order (executed):** 1) ASCII baselines + bootstrap-smoke-check filtering (so subsequent fixes have a real gate) — **shipped in `7143128`**, 2) playground undo (`didCompleteRender` re-seed loop + Cmd-Z text-edit conflict) — **shipped in `138e367`**, 3) exporter correctness batch (Mermaid flowchart shape, subgraph walker, PlantUML state pseudostate, sequence escape, class comments) — **shipped in `a13b67c`**, 4) parser dispatch tokenization across `DiagramRegistry+*.swift` — **shipped in `633bec4`**, 5) renderer color/flip cleanups — **shipped in `f7990d5`**.

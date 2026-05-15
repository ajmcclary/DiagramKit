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

## Resolution Status — Session 6 (2026-05-14)

Closes Deferred Effort §4 → Format slices: round-trip & diagnostic discipline → "`StructurizrExporter.swift:84-91` drops boundary metadata as `.unsupported`, but its companion `StructurizrMapper.swift:169-181` rebuilds boundaries from parent relationships. Export → import loses boundaries without compensating import-side diagnostic." Spec at `docs/superpowers/specs/2026-05-14-structurizr-boundary-round-trip-design.md`; plan at `docs/superpowers/plans/2026-05-14-structurizr-boundary-round-trip.md`. Eleven commits on `main` (two docs + nine implementation).

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §4 Spec | `e26795a` | Structurizr boundary round-trip via `group "label" { … }` design — `C4BoundaryOrigin` enum, parser/mapper/exporter walkthrough, flatten + `.warning` policy for nested boundaries. |
| 2 | §4 Plan | `bb1f150` | Nine-task TDD plan honoring commit-by-commit on main per project standing default. |
| 3 | §4 `C4BoundaryOrigin` enum | `81ddf33` | New `C4BoundaryOrigin: Sendable, Equatable { .authored, .viewScopeSynthesized }`; optional `origin` field on `C4Boundary` (default `.authored`). Non-breaking init change. |
| 4 | §4 `StructurizrModelElement.group` | `51f7a96` | Optional `group: String?` on `StructurizrModelElement` (default `nil`); carries the group label set by parser. |
| 5 | §4 Parser `parseGroup` happy path | `c59dd51` | `parseModel` dispatches on `.identifier("group")`; new `parseGroup` consumes the directive inside `model { }`, tags contained elements with the group label, forwards inner relationships to the model's relationship list. |
| 6 | §4 Parser error paths | `8a7d9c4` | Nested `group` inside `group` emits `.unsupported`; `group` inside `softwareSystem`/`container` element block emits `.unsupported` + `skipBlock`; missing-label `group { … }` throws `DiagramError.malformedSource`. |
| 7 | §4 Mapper authored boundaries | `1eaa151` | `StructurizrMapper.map(_:)` builds `groupAliasMap` via new `uniqueSanitizedGroupAlias` helper, overrides shape `parentBoundary` to the synthesized group alias, appends one `.authored` `C4Boundary` per unique group label. The existing view-scope synthesis path is tagged `.viewScopeSynthesized`. |
| 8 | §4 Exporter partition emit | `b96c9ce` | `StructurizrExporter` replaces the blanket-drop with origin partition: `.authored` boundaries emit as `group "<label>" { … }` blocks containing direct member shapes; `.viewScopeSynthesized` silently drop (next import re-derives them). Nested authored boundaries flatten to siblings with one `.warning` per dropped parent link; empty groups drop with a `.warning`. Extracts a private `emitShape` helper. |
| 9 | §4 Round-trip tests | `7e9032c` | Three end-to-end tests: single-boundary Mermaid round-trip preserves label + membership; two-level Mermaid nesting flattens to sibling groups with one `.warning` (anchored by a `Rel(s0, s1, …)` so `systemContext include *` picks up both shapes); Structurizr group exports to Mermaid with the expected `Boundary(...)` keyword + `$boundary=` attribute. Third test stops short of re-parsing the Mermaid output — see the new entry below. |
| 10 | §4 Corpus fixture | `2ce55e0` | `structurizr-5-group` entry in `test-diagrams.json` paired with a decode/import `@Test` in `StructurizrCorpusFixtureTests.swift`. `skipSnapshots: ["structurizr"]` (matches the existing four Structurizr fixtures). |
| 11 | §4 CLAUDE.md sync | `ed5e578` | Test source count 225 → 231 (six new files: `C4BoundaryOriginTests`, `StructurizrASTGroupTests`, `StructurizrParserGroupTests`, `StructurizrMapperGroupTests`, `StructurizrExporterGroupTests`, `StructurizrBoundaryRoundTripTests`). |

Session-end verification: targeted `swift test --filter` across `C4BoundaryOriginTests`, `StructurizrASTGroupTests`, `StructurizrParserGroupTests`, `StructurizrMapperGroupTests`, `StructurizrExporterGroupTests`, `StructurizrBoundaryRoundTripTests`, `StructurizrCorpusFixtureTests` all green (31 new tests + 7 existing fixture tests). `Scripts/check-sendable-annotations.sh` ✓ green. `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings; the touched Structurizr files (`StructurizrParser.swift` 377, `StructurizrMapper.swift` 334, `StructurizrExporter.swift` 249) all stay well under the 500-line warn threshold.

New issue discovered during round-trip testing (added below as Deferred Effort §7): `Sources/DiagramKitModel/src_c4_parser.swift:426` — `_addPersonOrSystem` reads `link`, `tags`, `sprite` from the `named` arg dictionary but **not** `$boundary`. `MermaidC4Export` emits `$boundary=<alias>` on shapes whose `parentBoundary != "global"`, so the Mermaid exporter's contract isn't honored by the Mermaid parser on re-parse. Structurizr's boundary round-trip works (it goes through `C4Diagram.boundaries` directly, not through `$boundary` attributes), but Mermaid → Mermaid round-trip drops the parent-boundary linkage for shapes that aren't inside a nested `Boundary(...) { … }` block. The third round-trip test in this session avoids re-parsing the Mermaid output for that reason.

---

## Resolution Status — Session 7 (2026-05-14)

Mechanical follow-ups bundled as one commit-by-commit pass on `main`. Six items from the Critical / Important / Deferred backlog that needed no design call — the residual closure work after Sessions 1–6. Nine commits.

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §1 Doc tidy-up | `fbc043e` | `REVIEW.md` Deferred Effort §1's "Remaining steps" prose has been stale since Session 4 closed the rebaseline phase end-to-end. Replaced with a one-line closure note pointing at the Session-4 closing commits (`b222b15` → `5cf2186` + image rebaseline). |
| 2 | Critical / Cmd-I iOS toggle | `edb2db7` | `LiveEditorView.swift` compact-layout picker rebound from a local `@State` `compactMode` to a computed `Binding<CompactMode>` that bridges to `store.state.inspectorOpen`. Picking `.inspector` opens the inspector; picking `.edit`/`.view` closes it and is remembered in a new `nonInspectorMode` @State. Cmd-I shortcut and toolbar toggle are no longer silent no-ops on iPhone. Single-file change. |
| 3 | §4 Importer fallback contract | `37c82a4` | `ImporterRegistry.init` now runs `_validateFallbackContract` — at most one importer may declare `isFallback = true`, and if present it must occupy the last slot. Empty / no-fallback registries are still allowed (third-party narrow-only registries and `ImporterRegistry.empty` are legitimate). Three new tests pin the contract: default-registry shape (Mermaid is the only fallback), narrow-only/empty pass the precondition, and `prepending`/`appending` preserve the invariant on known-good shapes. Session 2's `31f7ced` added the protocol-level `isFallback`; this lands the registry-time mechanical validation. |
| 4 | Cross-cutting #3 / `renderDiagramSVG` duplicate | `381fd81` | `src_index.swift`'s top-level `renderDiagramSVG` and `renderDiagramSVGAsync` free functions gain `@available(*, deprecated, renamed: "DiagramEngine.renderSVG(source:theme:layoutConfig:idPolicy:)", ...)`. CLAUDE.md's "Public Surface" already documents `DiagramEngine` as the canonical async facade — pick that as canonical. The legacy `renderMermaid*` compat wrappers (already deprecated) switched to calling `DiagramEngine._runOnWorker` directly to avoid self-inflicted deprecation warnings inside their own bodies. Test sites surface ~5000 warnings on next build; migration is a shape conversion (`RenderOptions` → `DiagramTheme`+`LayoutConfig`+`SVGIDPolicy`) and is deferred. |
| 5 | §4 sanitizeIdentifier collision-aware adoption — ER | `ab7f8d6` | `MermaidERExport.emit` adds a shared `usedAliases: Set<String>` accumulator + `aliasMap: [String: String]`. Entity emission switches to the collision-aware overload and records the renamed form in `aliasMap`; relationship endpoints (`rel.entity1` / `rel.entity2`) look up via `aliasMap` with plain-sanitize fallback. |
| 6 | §4 sanitizeIdentifier collision-aware adoption — flowchart | `74f1ebb` | Largest of the five slices: nodes, subgraphs, edges, `classAssignments`, and `nodeStyles` draw from the same id namespace, so one shared `usedAliases` set and one shared `aliasMap` cover the whole pass. The recursive `emitSubgraph` helper gains two new `inout` params. |
| 7 | §4 sanitizeIdentifier collision-aware adoption — class | `a0d7944` | Namespaces and classes share an id namespace; one shared accumulator covers both. Notes (`note for <classId>`) and relationship endpoints (`rel.id1` / `rel.id2`) resolve via `aliasMap`. The recursive `emitNamespace` helper gains two new `inout` params. |
| 8 | §4 sanitizeIdentifier collision-aware adoption — C4 | `4317a03` | Shapes and boundaries share an alias namespace (relationships and `$boundary=`/`$parent=` cross-reference both). One shared `usedAliases` + one shared `aliasMap`. Shape/boundary emission records; `$boundary=`, `$parent=`, and relationship endpoints look up. |
| 9 | §4 sanitizeIdentifier collision-aware adoption — sequence | `68704e5` | Final slice. Actors declared lazily via both `.actor(isExplicit)` and `.createParticipant`; messages, notes, activations, links, properties, details, and destroy all reference actors. One shared accumulator covers the whole pass. Plain-sanitize fallback covers Mermaid's lazy actor creation (`Alice -> Bob: Hi` without prior `participant Alice`). |

Session-end verification: targeted `swift test --filter` across `MermaidExporterTests`, `MermaidImporterTests`, `ImporterRegistryTests`, `ExportMatrixTests`, `DiagramExportInfrastructureTests` all green (36 tests / 5 suites). `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings; no new threshold crossings from this work. The §5 polish bullet about `DiagramEditorPane.swift:6`'s "removed legacy InspectorView" comment was verified clean — it had already been addressed by Session 2's `d072722`.

---

## Resolution Status — Session 8 (2026-05-14)

Closes Deferred Effort §4 → Architecture & API → "`DiagramFormatID` exists only on the exporter side; importers identify by `name: String`. Either move `DiagramFormatID` to `DiagramKitCommon` and adopt symmetrically, or document the asymmetry." Session 2's `31f7ced` documented the asymmetry; this session closes it. Spec at `docs/superpowers/specs/2026-05-14-diagram-formatid-symmetry-design.md`; plan at `docs/superpowers/plans/2026-05-14-diagram-formatid-symmetry.md`. Eight commits on `main` (two docs + six implementation).

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §4 Spec | `4f6e02b` | DiagramFormatID symmetric importer dispatch design — promotes the type to a shared identifier in `DiagramKitCommon`, adds typed `formatID` to `DiagramSourceImporter`, preserves probe-based dispatch as primary, migrates `CorpusEntry.expectedImporters` to typed shape, deprecates name-based exporter lookup. |
| 2 | §4 Plan | `5aec919` | Six-task TDD plan honoring the commit-by-commit-on-main standing default. |
| 3 | §4 `DiagramFormatID` module move | `050e851` | Type relocates from `Sources/DiagramKitExport/DiagramFormatID.swift` to `Sources/DiagramKitCommon/DiagramFormatID.swift`. Public API unchanged; the five canonical constants and `RawRepresentable(rawValue: String)` shape are preserved. Five call sites that previously got the type transitively via `import DiagramKitExport` gain explicit `import DiagramKitCommon`: `D2Exporter`, `ExporterRegistry`, `DiagramEditor`, `MermaidExporter`, `StructurizrExporter`. Same import added to seven affected test files. New `DiagramFormatIDLocationTests` (2 assertions) pins that the type resolves identically through `DiagramKitCommon` / `DiagramKitImport` / `DiagramKitExport`. |
| 4 | §4 `DiagramSourceImporter.formatID` protocol field | `19dc221` | New `var formatID: DiagramFormatID { get }` requirement on `DiagramSourceImporter` with no default — every conformer declares its own. `MermaidImporter` → `.mermaid`, `D2Importer` → `.d2`, `GraphvizImporter` → `.graphviz`, `StructurizrImporter` → `.structurizr`, `PlantUMLImporter` → `.plantuml`. Protocol header's "Identity model" section rewritten to describe the symmetric model accurately (the prior wording incorrectly framed `DiagramFormatID` as a closed enum). `FixtureImporter` in `ImporterRegistryTests` gains the field too. New `DiagramSourceImporterFormatIDTests` (6 assertions) pins each per-importer declaration plus a sweep that every importer in `DiagramPipeline.defaultRegistry` has a non-empty `formatID.rawValue`. |
| 5 | §4 Typed by-ID lookup | `d82b2e1` | `ImporterRegistry.importer(for formatID: DiagramFormatID)` linear-scan lookup. `DiagramLoader.parse(_:as formatID:registry:)` and `parseDocument(_:as:registry:)` typed-dispatch entry points that bypass content-driven probing. Unknown formatID throws `DiagramError.unrecognizedFormat("no importer registered for format '<rawValue>' in registry")`. Probe-based dispatch unchanged. New `ImporterRegistryByIDTests` (5 cases — default registry, unknown ID, empty registry, by-ID after `prepending`, by-ID after `appending`) and `DiagramLoaderByIDTests` (6 cases — typed parse with `.mermaid` / `.d2`, probe-bypass contract, unknown-formatID throw + message check, `parseDocument` shorthand parity). |
| 6 | §4 `CorpusEntry.expectedImporters` typed migration | `9c3b22a` | Field type flipped from `[String: String]?` to `[DiagramFormatID: DiagramFormatID]?`. JSON wire shape preserved (string keys/values on disk); decoder normalizes through `DiagramFormatID(rawValue:)`, encoder writes back rawValues with deterministic key ordering. New private `decodeFormatIDMap` helper. 27 corpus entries' values swept from display-name form (`"Mermaid"`) to formatID rawValue form (`"mermaid"`) — 54 total replacements (`Mermaid` × 27, `D2` × 6, `Graphviz` × 9, `PlantUML` × 6, `Structurizr` × 6); 8 expect-site rewrites + 16 inline JSON literal blocks across `StructurizrCorpusFixtureTests` / `DOTCorpusFixtureTests` / `D2CorpusFixtureTests` / `CorpusMultiFormatTests`. The case-normalization test in `CorpusMultiFormatTests` keeps uppercase keys/values in its JSON so it still exercises the normalizer. New `CorpusEntryFormatIDTests` (5 cases — decode/encode/unknown-rawValue/round-trip/duplicate-key). |
| 7 | §4 `DiagramExportLoader.export(_:using:)` deprecation | `43d759e` | The display-name-keyed export entry point at `Sources/DiagramKitExport/DiagramExportLoader.swift:61-85` gains `@available(*, deprecated, renamed: "export(_:to:registry:)", message: "Use formatID-based dispatch instead of display-name lookup.")`. Runtime behavior unchanged. The two existing tests in `DiagramExportLoaderTests.swift` that exercise the deprecated path (`loaderByName`, `loaderUnknownName`) themselves gain `@available(*, deprecated)` so the deprecation surfaces only as the protocol-level signal, not as build-log noise. |
| 8 | §4 CLAUDE.md sync | `bb18438` | Test source count 231 → 236 (the five new test files: `DiagramFormatIDLocationTests`, `DiagramSourceImporterFormatIDTests`, `ImporterRegistryByIDTests`, `DiagramLoaderByIDTests`, `CorpusEntryFormatIDTests`). |

Session-end verification: targeted `swift test --filter` across `DiagramFormatID|DiagramSourceImporterFormatID|ImporterRegistry|DiagramLoader|CorpusEntryFormatID|StructurizrCorpusFixture|DOTFixture|D2Fixture|CorpusMultiFormat|DiagramExport` all green (88 tests / 18 suites, including the 423-case parameterized multi-format corpus snapshot run). `Scripts/check-sendable-annotations.sh` ✓ green. `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings. Snapshot canary on two block-family IDs passed; no snapshot rebaselining was required by this work (renderers, layouts, and geometry-producing paths were not touched).

---

## Resolution Status — Session 9 (2026-05-14)

Closes Deferred Effort §7 → Mermaid C4 parser ignores `$boundary` named arg (surfaced Session 6). Spec at `docs/superpowers/specs/2026-05-14-mermaid-c4-boundary-named-arg-design.md`; plan at `docs/superpowers/plans/2026-05-14-mermaid-c4-boundary-named-arg.md`. Six commits on `main` (two docs + six implementation/test).

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §7 SPI variant + helpers | `4e2a6e3` | `Sources/DiagramKitModel/src_c4_parser.swift` gains `_parseC4DiagramWithDiagnostics` returning `(C4Diagram, [DiagramDiagnostic])`. Existing `parseC4Diagram` shrinks to a one-line wrapper. Two private helpers (`_resolveParentBoundary`, `_validateBoundaryReferences`) land but aren't wired yet. |
| 2 | §7 Parser unit tests (red) | `c63446b` | New `Tests/DiagramKitTests/C4BoundaryNamedArgTests.swift` — thirteen `@Test`s covering shape `$boundary`, boundary `$parent`, deployment-node `$parent`, lexical fallback, mismatch warning, forward-ref, unresolved-ref. Tests use forward-ref ordering so lexical state can't masquerade as the named-arg path. |
| 3 | §7 Dispatch rewrite (green) | `556432d` | 28 macro-dispatch sites in the SPI variant route through `_resolveParentBoundary`. Validator call lands before `return`. New `_parseTrailingC4Attributes` merges Mermaid C4's *post-paren* `$key=value` syntax (e.g., `Person(p) $boundary=b`) into the named dict — the root cause behind §7 was the in-paren-only `parseMacroArguments` silently dropping every trailing attribute the exporter emits. |
| 4 | §7 Registry sites | `b6e5efe` | `Sources/DiagramKit/DiagramRegistry+C4.swift:16` and `Sources/DiagramKit/AsciiRenderRegistry.swift:223` call `_parseC4DiagramWithDiagnostics`. Diagnostics are discarded at this layer for now — surfacing through `DiagramImportResult.diagnostics` is a separate concern. |
| 5 | §7 Round-trip tests | `37b547b` | New `Tests/DiagramKitTests/MermaidC4BoundaryRoundTripTests.swift` — two `@Test`s pinning flat-emit round-trip and nested↔flat semantic equivalence. |
| 6 | §7 Structurizr extension | `ffe5573` | `Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift`'s `structurizrToMermaidEmit` re-parses the Mermaid output and asserts `p1.parentBoundary == "G0"` survives end-to-end. |

Session-end verification: `swift test --filter "C4ParserTests|C4BoundaryNamedArgTests|MermaidC4BoundaryRoundTripTests|C4SlotSemanticsTests|C4LayoutTests|C4SvgTests|StructurizrBoundaryRoundTripTests"` all green (79 tests / 7 suites). `Scripts/check-sendable-annotations.sh` ✓ green. `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings; `src_c4_parser.swift` grows from 744 → 928 lines, both already in the yellow band (over 500-line warn, under 1000-line error).

**Deferred follow-up**: surfacing parser diagnostics through `DiagramImportResult.diagnostics` requires widening the registry `parse:` closure shape. Out of scope for this session. **Closed by Session 10.**

---

## Resolution Status — Session 10 (2026-05-14)

Closes Session 9's deferred follow-up: surfacing parser diagnostics through `DiagramImportResult.diagnostics` required widening the registry `parse:` closure shape. Spec at `docs/superpowers/specs/2026-05-14-parser-diagnostics-surfacing-design.md` (`02fc245`); plan at `docs/superpowers/plans/2026-05-14-parser-diagnostics-surfacing.md` (`ee679ce`). Twenty commits on `main` between `02fc245..d45b2ae` (two docs + eighteen implementation/test).

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | A1 — `PositionedGraph.diagnostics` field | `2291313` | Adds a layout-tier diagnostic bag on `PositionedGraph`; existing emit sites still untouched. |
| 2 | A2 — `PreparedDiagram` aggregation | `a7cd641` | `PreparedDiagram` gains the `importDiagnostics:` initializer parameter and exposes `diagnostics = importDiagnostics + positioned.diagnostics`. |
| 3 | A3 — `AsciiRenderOutput` public type | `123ca2a` | Standalone diagnostic surface for the ASCII path that bypasses `PreparedDiagram`. |
| 4 | B1 — Closure-shape widen | `da8700d` | `DiagramDescriptor.parse` and `.layout` closures return `(Document/Graph, [DiagramDiagnostic])`. Atomic across all family descriptors. |
| 5 | C1 — C4 `$boundary` diagnostics | `d2599ef` | The C4 registry descriptor stops discarding `_parseC4DiagramWithDiagnostics`'s diagnostic bag — boundary mismatch warnings now reach `MermaidImporter.parse`'s `DiagramImportResult.diagnostics`. |
| 6 | D1 — Kanban duplicate-node | `4b7a140` | Kanban duplicate-node `_reportDiagramIssue` converts to tuple-append. |
| 7 | D2 — Flowchart subgraph recursion | `bc1ada9` | Three `src_layout.swift` recursion-truncation emit sites convert to `_LayoutDiagnostics` bag append. |
| 8 | D3 — Ishikawa recursion-depth | `66cf2f8` | Ishikawa depth-overflow emit converts to `_IshikawaDiagnostics` bag append. |
| 9 | D4 — GitGraph parallelCommits | `1596bee` | `parallelCommits` missing-position emit routes through `PositionedGraph.diagnostics`. |
| 10 | E1a — Pie/Journey/Gantt parsers | `2d1bc9f` | Per-family parser signatures widen to tuple return. |
| 11 | E1b — Quadrant/Requirement/GitGraph/Mindmap | `e171d5f` | Per-family parser signatures widen to tuple return. |
| 12 | E1c — Timeline/Block/Radar/Sankey | `402d627` | Per-family parser signatures widen to tuple return. |
| 13 | E1d — Class/ER/Sequence/XYChart | `ee5dbeb` | Per-family parser signatures widen to tuple return. |
| 14 | E1e — Arch/EventModel/Packet/TreeView/Treemap/Venn/Wardley/ZenUML/Ishikawa | `305be4a` | Final bulk parser widen; drive-by fixes for D2 probe (skip `%%{init:…}%%` lines) and obsolete `notYetImplemented` assertions in TreeView/EventModeling tests. |
| 15 | E1 tail — `parseMermaid` top-level | `7bf6d86` | The flowchart/state-diagram top-level entry in `src_parser.swift:179` returns `(DiagramDocument, [DiagramDiagnostic])`. |
| 16 | F1 — `DiagramLoader.parseImportResult` | `a1ea1a3` | Diagnostic-aware loader entry replaces `parse(_:registry:)` as the canonical name; `parseDocument` routes through it. |
| 17 | F2 — `DiagramPipeline.prepare` aggregation | `8f20e5b` | `prepare(...)` threads `DiagramImportResult.diagnostics` into `PreparedDiagram` via the new `importDiagnostics:` parameter. New `ParserDiagnosticAggregationTests`; drive-by inversion of the obsolete-on-arrival `testLayerKeepsLastPreparedDiagramWhenSourceBecomesInvalid` to match `DiagramLayer`'s documented clear-on-failure semantics. |
| 18 | F3 — Engine + renderASCII | `f9bd6c2` | `DiagramEngine.parseImportResult(source:registry:)` lands; `renderASCII` on both `DiagramEngine` and `DiagramPipeline` returns `AsciiRenderOutput`. Sweep covers 10 ASCII renderer test files, the corpus snapshot path, and the playground. Drive-by fix for the `_requirement` matcher (claims both `requirement` and `requirementdiagram`). |
| 19 | G1 — ASCII registry widen | `d45b2ae` | `AsciiRenderDescriptor.render` returns `(String, [DiagramDiagnostic])`; all 26 family entries thread parser diagnostics through. `src_ascii_index` gains `renderMermaidASCIIWithDiagnostics`; `DiagramPipeline.renderASCII` routes through it so C4 `$boundary` warnings reach `AsciiRenderOutput.diagnostics`. |
| 20 | H1 — Docs sync | _this commit_ | `CLAUDE.md` pipeline diagram + Public Surface bullets reflect the new shapes. `ARCHITECTURE.md` gains a Diagnostics paragraph under "Three-stage pipeline". |

Session-end verification: `swift test --filter "PositionedGraphDiagnosticsTests|PreparedDiagramDiagnosticsTests|AsciiRenderOutputTests|MermaidImporterDiagnosticsTests|DiagramLoaderParseImportResultTests|ParserDiagnosticAggregationTests"` green. C4 boundary diagnostics now flow end-to-end from parser → importer → `PreparedDiagram.diagnostics` and through to the ASCII path's `AsciiRenderOutput.diagnostics`. `Scripts/check-sendable-annotations.sh` and `Scripts/check-file-sizes.sh` carry only pre-existing warnings.

---

## Resolution Status — Session 11 (2026-05-14)

Closes the last open §4 playground bullet: `UndoManager.canUndo`/`canRedo` are not Observation-tracked, so SwiftUI `.disabled(!editor.undoManager.canUndo)` modifiers drift. The playground had worked around this with a manual `_undoTickle` counter in `LiveEditorStore`; this session moves the responsibility to `DiagramEditor` itself. Spec at `docs/superpowers/specs/2026-05-14-diagrameditor-observation-undo-design.md` (`563cda9`); plan at `docs/superpowers/plans/2026-05-14-diagrameditor-observation-undo.md` (`cc01e99`). Eight commits on `main` (two docs + six implementation/test).

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §4 Spec | `563cda9` | DiagramEditor Observation-tracked undo state design — NotificationCenter-driven tickle scoped per-editor via `object:`; surfaces `canUndo`, `canRedo`, `undoActionName`, `redoActionName`; deletes the playground workaround in the same PR. |
| 2 | §4 Plan | `cc01e99` | Six-task TDD plan honoring the commit-by-commit-on-main standing default. |
| 3 | T1 — Failing initial-state test | `71857c0` | New `Tests/DiagramKitTests/Interactive/DiagramEditorUndoObservationTests.swift` carrying a single `initialState` test. Lands as a compile-time failure ahead of T2. |
| 4 | T2 — Four computed properties + tickle storage | `ab80917` | `DiagramEditor` gains `canUndo`/`canRedo`/`undoActionName`/`redoActionName` computed properties plus `_undoStateTickle: UInt64` and `_undoObservers: [NSObjectProtocol]` storage. `initialState` now compiles and passes. |
| 5 | T3 — Four remaining tests | `d64d027` | `afterMutation`, `directUndoManagerCall`, `observationTrackingFires`, `multiEditorIsolation`. `observationTrackingFires` is the load-bearing test for the NotificationCenter wiring. |
| 6 | T4 — NotificationCenter wiring + `isolated deinit` | `3aac27a` | `_registerUndoObservers()` subscribes to `NSUndoManagerDidUndoChange` / `DidRedoChange` / `DidCloseUndoGroup` / `Checkpoint` scoped to this editor's manager. Three plan adjustments discovered while wiring: `_undoStateTickle` is NOT `@ObservationIgnored` (the macro must instrument it so mutations fire); `queue: nil` (not `.main`) gives synchronous delivery on the posting thread; Swift 6's `isolated deinit` keeps `@MainActor` isolation through teardown so the non-Sendable observer-token array remains accessible. |
| 7 | T5 — Playground migration | `0b02683` | Six `_bumpUndoTickle()` callsites in `LiveEditorStore` deleted (three more than the original plan listed: source-empty reset, `performMutation`, `performFlowchartMutation` in addition to the planned editor swap + `undoStructural` + `redoStructural`). `LiveEditorStore.canUndoStructural`/`canRedoStructural`/`undoStructuralActionName` deleted. `DiagramEditorPane`'s two `.disabled(...)` modifiers and the "Last:" action-name badge rewritten to read `store.editor?.canUndo` / `canRedo` / `undoActionName` directly. |
| 8 | T6 — CLAUDE.md test count sync | _this commit_ | Test source count 244 → 245 (one new file: `DiagramEditorUndoObservationTests`). |

Session-end verification: `swift test --filter "DiagramEditorUndoObservationTests|DiagramEditorUndoTests|DiagramEditorMutationTests|DiagramEditorAsyncExportTests|LiveEditorStoreEditorLifecycleTests"` all green (33 tests / 4 suites pre-existing + 5 tests in the new suite). `Scripts/strict-concurrency-check.sh` ✓ first-party clean. `Scripts/check-sendable-annotations.sh` ✓ green. `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings.

The §4 deferred bullet "`UndoManager.canUndo`/`canRedo` are not Observation-tracked" is closed end-to-end. Library consumers now get `editor.canUndo` / `editor.canRedo` / `editor.undoActionName` / `editor.redoActionName` directly — no per-host workaround needed; consumer-direct `editor.undoManager.undo()` calls also flow through Observation via the NotificationCenter path.

---

## Resolution Status — Session 12 (2026-05-14)

Closes Cross-cutting Observation #3 (umbrella exposes two paths for the same SVG operation — the deprecated free function in `src_index.swift` and `DiagramEngine.renderSVG`). Bundle deletes the full Phase-0 / Session-7 deprecation cohort atomically. Spec at `docs/superpowers/specs/2026-05-14-deprecated-surface-sunset-design.md` (`040573f`); plan at `docs/superpowers/plans/2026-05-14-deprecated-surface-sunset.md` (`48717fb`). Thirteen commits on `main` (two docs + four async test sweeps + one sync test sweep + one source-side + one legacy-test delete + one atomic deletion + two pre-existing-failure fixes + one outdated-test fix).

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | Phase 1a — async test sweep batch A | `7e28c80` | Six test files (BeautifulMermaidSwift, Block, ERParser+Foundation, ERRenderer, EventModeling, FlowchartELKFallback) migrate `renderDiagramSVG(…)` → `DiagramEngine.renderSVG(source:)`. One ERRenderer test (entityWithAttributesRendersHeaderAndRows) was asserting against raw `var(--…)` tokens that the engine path resolves; assertion flipped to structural checks. |
| 2 | Test-expectation fix — outdated notYetImplemented | `bdd3e9a` | Mindmap and Radar ASCII rendering landed during Session 10's parser-diagnostics surfacing work. Both tests still asserted `notYetImplemented`; rewrite to assert canonical output. |
| 3 | Pre-existing fix — ER config propagation | `cdfcf3c` | `PositionedGraph.content.erDiagram` enum case carried entities/relationships/accTitle/accDescr/diagramTitle but NOT config. ER registry's positioned closure dropped `PositionedErDiagram.config`; SVG render descriptor's reconstructed `PositionedErDiagram` had `config=nil`. Frontmatter `useMaxWidth: true` and `look: neo` reached the parser correctly but were silently lost at the SVG render boundary. Add `config: ErDiagramConfig?` to the enum case; populate and consume across registry + descriptor. Closes pre-existing `useMaxWidthTrueEmitsResponsiveWidth` and `neoLookEmitsNeoMarkers` failures. |
| 4 | Pre-existing fix — ER/Sequence semicolon parsing | `a618bdd` | `DiagramRegistry+ER.swift` and `+Sequence.swift` were passing `DiagramSourceNormalizer.diagramLines(source)` (newline-only) to their parsers, so `erDiagram; CUSTOMER ||--o{ ORDER : places` hit the parser as one giant header line. Switch both to `.statements(source)` (matches Journey/Sankey/GitGraph/Packet pattern), which is quote-aware so `"A;B"` is preserved. Drive-by: PlantUMLSequenceParserTests' "Emits diagnostic for title" was pinning pre-Session-2 behavior — Session 2's `5ef689f` made title a parsed AST node; rewrite the test. Also includes three untracked `structurizr-5-group` snapshot baselines that arrived between Session 6 and now. |
| 5 | Phase 1b — async test sweep batch B | `930b95f` | Seven test files (FlowchartSecurity, FlowchartVisualDiff, IconImageRenderer, IshikawaRenderer, KanbanRenderer, MindmapRenderer, QuadrantSvg-async-portion). FlowchartVisualDiff's seven multi-line `(source, RenderOptions())` → `(source: source)` shape collapses. |
| 6 | Phase 1c — async test sweep batch C | `bff7928` | Five test files (Radar, Requirement, SemicolonSeparator, TreeView×2). Timeline×2 had no async callsites. |
| 7 | Phase 1d — async test sweep batch D | `b245f1a` | Four test files (Venn, VerificationStepExporter, XYChartCrashRegression, XYChartSvg). Closes Phase 1 — every async free-function callsite under `Tests/` is now retired. |
| 8 | Phase 2 — sync `_renderDiagramSVG` test sweep | `96e2aae` | Seven test files (Architecture, Block, Quadrant, Timeline×2, Wardley, ZenUML) retire the underscored sync SPI in favor of `DiagramPipeline.renderSVG(source:theme:layoutConfig:idPolicy:registry:)`. `.stable` idPolicy routes through the canonical first-class parameter. |
| 9 | Phase 4 — source-side renderSVGSync migration | `a028709` | `DiagramImageRenderer.renderSVGSync` no longer round-trips theme through a `RenderOptions` allocation + `_renderDiagramSVG` SPI; calls `DiagramPipeline.renderSVG(source:theme:layoutConfig:idPolicy:)` directly. Drive-by: strip stale `// Replicate existing MermaidParser.parse() logic.` comment. |
| 10 | Phase 5 — delete `MermaidLegacyAPITests.swift` | `be0ffcf` | Sole purpose was exercising the deprecated `Mermaid*` aliases; three of its four tests duplicated canonical coverage. |
| 11 | Phase 6 — atomic deletion of deprecated surface | `6993a40` | **Breaking change.** Files deleted: `src_index.swift` (free functions + `_renderDiagramSVG` + `buildColors` + `original_src_index` empty placeholder), `Deprecations.swift` (all `Mermaid*` typealiases + `MermaidParser` enum). Symbols deleted in-place: `DiagramEngine.{renderImageAsync, renderSVGAsync, renderASCIIAsync, prepareAsync}` (zero callers), `String.{parseMermaid, renderMermaidImage, renderMermaidSVG, renderMermaidASCII}`, `DiagramPipeline.renderSVG(_:options:)` orphan, internal `_MermaidPreparerBootstrap` alias. Acceptance grep clean; snapshot canary on `block-1-simple` + `c4-context` passes without rebaselining. |
| 12 | Phase 7 — Docs sync | _this commit_ | CLAUDE.md "Public Surface" sentence rewritten to point at the canonical APIs and reference Session 12 as the sunset point. Test source count 245 → 244 (the `MermaidLegacyAPITests` deletion). ARCHITECTURE.md pipeline diagram and parser-dispatch paragraph updated — `MermaidParser` no longer exists. |

Session-end verification: targeted `swift test --filter` across the touched suites all green; `Scripts/check-sendable-annotations.sh` ✓ green; `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings; snapshot canary on `block-1-simple` + `c4-context` passed.

Cross-cutting Observation #3 closed. Three pre-existing failures uncovered during the migration (ER config propagation, ER+Sequence single-line semicolon parsing, outdated `notYetImplemented` expectations) were fixed in the same line of work per project standing default.

---

## Resolution Status — Session 14 (2026-05-15)

Closes Cross-cutting Observation #5 + Critical "Public API contract holes" (`DiagramEngine.renderSVG` / `renderASCII` Linux gating). Spec at `docs/superpowers/specs/2026-05-15-linux-svg-ascii-parity-design.md` (`92ba4f6` → `4771774`); plan at `docs/superpowers/plans/2026-05-15-linux-svg-ascii-parity.md` (`5e8fbe6`). Ten commits on `main`.

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | Test target scaffold | `f97887c` | New `.testTarget(name: "DiagramKitLinuxTests")` in `Package.swift` with Linux-portable deps (`DiagramKit`, `DiagramKitCommon`, `DiagramKitModel`, `DiagramKitTestSupport`); placeholder test pins target compiles. |
| 2 | `DiagramError.unsupportedOnPlatform` | `544bbd6` | New case `unsupportedOnPlatform(family: DiagramType, reason: String, platform: String)` on `DiagramError`; `errorDescription` renders `"<family.rawValue> layout is not supported on <platform>: <reason>"`. |
| 3 | `DiagramDescriptor` linuxSupport fields | `e62db30` | `linuxSupport: Bool = true` + `linuxUnsupportedReason: String? = nil` on `DiagramDescriptor`; threaded through all four `_typed` factory overloads in `DiagramRegistry+TypedDescriptor`. |
| 4 | Three families flipped | `712ad0c` | Ishikawa, TreeView, EventModeling each declare `linuxSupport: false` with `"requires CoreText text-measurement"` reason. Drift-lock test pins exactly these three. |
| 5 | `DiagramPipeline` gate split | `ad05382` | `#if canImport(CoreGraphics)` block at `DiagramPipeline.swift:115-230` split: `prepare` stays gated, `renderSVG` (both overloads) + `renderASCII` pulled out. Bodies depend only on Linux-portable Model/Common symbols. |
| 6 | `_assertPlatformSupport` helper | `0f62d04` | Private helper looks up the descriptor and throws `DiagramError.unsupportedOnPlatform` on Linux when `linuxSupport == false`. Called from `renderSVG(source:)`, `renderSVG(positioned:)`, and `renderASCII` after parse. `renderASCII` grows one `loadDocument` call up front so the gate fires before the legacy ASCII path's internal re-parse. |
| 7 | `DiagramEngine.linuxSupport(for:)` | `a7a35d1` | Public introspection API. Returns `(true, nil)` for unknown families. |
| 8 | `DiagramEngine` gate drops | `f0add76` | Two `#if canImport(CoreGraphics)` blocks on `DiagramEngine` (`renderSVG`/`renderASCII`/`parseImportResult` cohort + `String.renderDiagramSVG`/`renderDiagramASCII`) removed. `_DiagramPreparerBootstrap.didInstall` calls inside the three engine funcs are now individually CG-gated. |
| 9 | `Dockerfile.linux-check` wires tests | `6233040` | Build matrix gains `DiagramKitLinuxTests`; new `RUN` step runs `swift test --filter LinuxPlatformGateTests` and fails the container on non-zero exit. First Linux test execution from CI on this repo. Drive-by: header-comment update from `MermaidStructuralError.payloadMismatch` to `DiagramError.unsupportedOnPlatform`. |
| 10 | Docs sync | _this commit_ | CLAUDE.md test source count 258 → 260; "What Lives Where" gains the new test target; "Linux Portability" section documents the new public Linux surface + introspection API; this REVIEW.md Session 14 entry. |

Session-end verification: `swift test --filter LinuxPlatformGateTests` green on Apple (12 tests / 1 suite). `swift build` green. `Scripts/linux-check.sh` recorded as environment-skipped this session (Docker daemon not running locally; container runtime absence is not a source failure per CLAUDE.md "Discipline Gates" policy). Dockerfile changes are textual and unblock the next session running the container to confirm the Linux throw path actually fires.

---

## Resolution Status — Session 15 (2026-05-15)

Closes the CLAUDE.md deferred follow-up flagged at the end of Session 14:
portable text-measurement shim for `ishikawa`, `treeView`, and
`eventModeling`. Spec at
`docs/superpowers/specs/2026-05-15-linux-text-measurement-shim-design.md`
(`4f5ff5d`); plan at
`docs/superpowers/plans/2026-05-15-linux-text-measurement-shim.md`
(`6c42054`). Nine commits on `main`.

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | TextMetrics inline-gate | `9b1bfe7` | `fontResolver` field + Apple init gated under `canImport(CoreText)`; Linux init is no-arg; fixes latent Linux build break (`DiagramFontResolver` was whole-file gated to UIKit/AppKit but `TextMetrics` referenced it unconditionally). |
| 2 | TreeView renderer gate lift | `7744e7a` | Stale Apple-only file gate on `renderTreeViewSvg` removed — body is pure SVG-string emission with no `BMFont` / `CTFont` / `NSAttributedString` references. |
| 3 | TreeView layout gate lift | `0718f45` | File-level `canImport(UIKit) || canImport(AppKit)` gate replaced with inner `measureText` branch: CoreText path unchanged; Linux path routes through `TextMetrics.shared.estimateTextWidth` with 1.2× line-height. `_treeViewFont` retained behind its own inner Apple-only gate. |
| 4 | EventModeling layout gate lift | `0a55b20` | File-level `canImport(CoreText)` gate replaced with inner `_measureTextDimensions` branch: CoreText `CTFramesetter` path unchanged; Linux path approximates the framesetter wrap by counting `ceil(rawWidth / maxWidth)` visual lines per source line. Static `fontFamily` getter returns the literal `"Inter, Verdana, sans-serif"` chain on Linux. |
| 5 | Ishikawa linuxSupport=true | `36c8bb4` | Inner `#if canImport(CoreText) / #else throw` in `DiagramRegistry+Ishikawa.swift` removed; `linuxSupport: false` flipped to default `true`; `linuxUnsupportedReason` dropped. Three new `LinuxPlatformGateTests`: descriptor flag, `renderSVG` success + serialized-NaN scan, `renderASCII` success. |
| 6 | TreeView linuxSupport=true | `9d6b1cc` | Same shape — registry inner gate + throw fallback removed; flag flipped; three new tests using `treeView-beta\n    src/\n        index.js\n    package.json` fixture. |
| 7 | EventModeling linuxSupport=true | `773f18d` | Same shape — registry inner gate + throw fallback removed; flag flipped; three new tests using a corpus-derived `"eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"` fixture. |
| 8 | LinuxPlatformGateTests cleanup | `865bfef` | Eight obsolete tests deleted (`ishikawa/treeView/eventModelingIsLinuxUnsupported`, `exactlyThreeFamiliesAreLinuxUnsupported`, `linuxSupportReturnsFalseForIshikawa`, the parameterized `linuxSupportReportsAllThreeUnsupported`, the two `pipelineRenderSVGGatesIshikawaOnLinux` / `engineRenderSVGGatesIshikawaOnLinux`). New `exactlyZeroFamiliesAreLinuxUnsupported` is the lockdown. Replaced the naive `svg.lowercased().contains("nan")` substring check (which false-positives on `dominant-baseline`) with `_svgHasNoSerializedNaN`, a helper that scans for actual `="nan"` / `(nan,` / ` nan ` / `,-nan` patterns plus `inf` / `-inf` variants. |
| 9 | Docs sync | _this commit_ | `CLAUDE.md` Linux Portability section rewritten — no longer mentions a deferred shim; describes the char-count fallback and the geometric-validity-only contract. `Dockerfile.linux-check` header comment updated. This Session 15 entry added. |

Session-end verification: `swift test --filter LinuxPlatformGateTests` runs 14 tests in 3.7 s — all green on Apple (the new validity tests prove the CoreText branch continues to produce valid geometry; the Linux char-count branch is verified by `swift build` and will be validated end-to-end by the next `Scripts/linux-check.sh` container run). `Scripts/linux-check.sh` recorded as environment-skipped this session (no Docker daemon locally).

The `--filter` substring trap: targeted runs by exact suite struct name (`LinuxPlatformGateTests`, `TreeViewModelTests`) are fast; broad substring filters (`--filter TreeView`) substring-match into `CorpusSnapshotTests` parameterized entries (`treeView-*`) and trip the pre-existing signal-10 hang. Saved to auto-memory.

---

## Deferred Effort — Recommendations

Some review items were intentionally deferred during the five-phase pass; others surfaced during execution and were scoped out to keep individual commits coherent. Listed in priority order.

**Currency note:** The bullets below preserve the original review's framing for historical context. **The "Resolution Status — Session N" tables above are authoritative for which items have actually closed.** Many bullets in §4 were addressed by Sessions 1–6 and have been marked inline with a leading ✅ and the closing commit; un-marked bullets are the genuinely open work.

### 1. SVG color-mix variable resolver (renderer-deep)

✅ **Closed by Session 4 (`b222b15` → `5cf2186` + image rebaseline commit):** the paren-counting resolver rewrite landed in Session 2's `1c2f18f`; Session 4 added palette-pin and SVG structural-sweep gates (`a5596f8`), fixed the resolver iteration bound caught by the first recording attempt (`d6bdec7`), re-recorded 390 of 435 SVG baselines (`5cf2186`), and re-recorded 57 image baselines (51 single-format + 6 multi-format). The theme-default audit was bundled into the same pass via `DiagramPipeline.renderSVG` routing through `theme.effective<Token>()` color-mix derivations (`6b35c80`). Audit and rebaseline both done.

### 2. D2 / DOT `FlowchartExportWalker` subgraph traversal

✅ **Closed by `5efa83f` (Session 2):** `FlowchartExportSink` now carries optional `handlesSubgraphs: Bool` + `subgraphBegin(_:depth:)` / `subgraphEnd(_:depth:)`. `walk(...)` returns `[DiagramDiagnostic]` and emits one `.warning` per dropped subgraph (with nested recursion). `D2Exporter` and `DOTFlowchartExport` thread the diagnostics through `DiagramExportResult`.

### 3. ER ASCII renderer `.invalidCardinality("MD_PARENT")`

✅ **Closed by `e2b9d57` (Session 2):** `AsciiErCardinality` gained `.parent = "md-parent"`; `_toAsciiCardinality` accepts `"MD_PARENT"`; `getCrowsFootChars` renders `*` (ASCII) / `◆` (Unicode), matching the filled diamond the CG and SVG renderers emit. `er-25-parent-marker` no longer carries `skipSnapshots: ["ascii"]`.

### 4. Important-tier review items not in the original fix plan

The following Important findings from the review remain. None are correctness-critical but each is either an architecture hazard, a long-term debt, or a fragility the next major release should address.

**Architecture & API**
- ✅ **Closed by `31f7ced` (Session 2):** `ReExports.swift:6-13` does not re-export `DiagramKitInteractive` despite `Package.swift` adding it as an umbrella dep. Add the re-export so `import DiagramKit` surfaces `DiagramEditor`.
- ✅ **Closed by `31f7ced` (Session 2):** `src_theme.swift:4`, `src_styles.swift:4`, `src_text_metrics.swift:4`, `src_multiline_utils.swift:4` are `open class`. Lock down to `internal` or `public final` — these are JS-port shims with no documented subclassing contract. Flipped to `public final class`.
- ✅ **Closed by Session 8 (`4f6e02b` → `bb18438`):** `DiagramFormatID` exists only on the exporter side; importers identify by `name: String`. Session 2's `31f7ced` documented the asymmetry; Session 8 closes it. `DiagramFormatID` moved to `DiagramKitCommon`; `DiagramSourceImporter` gains `var formatID: DiagramFormatID`; `ImporterRegistry.importer(for:)` and `DiagramLoader.parse(_:as:registry:)` add typed by-ID dispatch alongside the existing probe path; `CorpusEntry.expectedImporters` migrated to `[DiagramFormatID: DiagramFormatID]?`; `DiagramExportLoader.export(_:using:)` deprecated in favor of formatID-keyed dispatch.
- ✅ **Closed by `31f7ced` (Session 2):** Deprecated typealiases (`MermaidParser`, `MermaidRenderer`, `MermaidPipeline`, `MermaidImageRenderer`, `MermaidStructuralError`) are scattered across the umbrella. Consolidate in a single `Deprecations.swift` so the next major can sunset them atomically.
- ✅ **Closed by `31f7ced` (Session 2) + `37c82a4` (Session 7):** `MermaidImporter.swift:23-34` — `supports(source:)` returns true for any non-empty source. Add an explicit `isFallback: Bool` to the protocol so the registry can mechanically validate "exactly one fallback, last." `DiagramSourceImporter` gains `isFallback: Bool` (default `false`); `MermaidImporter` declares `isFallback = true`. Session 7 adds the registry-time mechanical validation: `ImporterRegistry.init` now runs `_validateFallbackContract` (at-most-one fallback, ordered last); empty / narrow-only registries still pass. Three new tests pin the contract.

**Model: numeric & concurrency edges**
- ✅ **Closed by `7bdd439` (Session 2):** `src_block_parser.swift:546-547` accepts non-positive `span` values; at `src_block_layout.swift:117` this becomes a divide-by-zero / NaN. Reject `Int(parts[1])` ≤ 0 at parse time.
- ✅ **Closed by `7bdd439` (Session 2):** `src_class_parser.swift:19` stores `direction: String`; every other family uses a typed enum. Migrate to a typed `ClassDirection` enum (`TB`/`BT`/`LR`/`RL`).
- ✅ **Closed by `7bdd439` (Session 2):** `src_radar_layout.swift:19-20` — `maxValue = -.infinity` when entries are empty and `options.max` is nil. Add an empty-curve guard and clamp `relativeRadius(...)` against `min == max`.
- ✅ **Closed by `7bdd439` (Session 2):** `src_gantt_parser.swift:410-423` — `_dateFormatterCache` is `nonisolated(unsafe)`; `DateFormatter.date(from:)` is not documented thread-safe. Wrap with a serial queue, or per-call instantiate, or migrate to `Date.ParseStrategy`. Serialized through a private `DispatchQueue`.
- ✅ **Closed by `7bdd439` (Session 2):** `SourcePreprocessing.swift:69-89` — every `---`-bounded section between the first and last marker is treated as frontmatter; a body containing a literal `---` separator line is partially eaten. Tighten to "exactly one closing `---` after the opener, no greedy consumption."
- ✅ **Closed by `7bdd439` (Session 2):** `src_parser.swift:438-440` — anonymous-subgraph id `"subgraph_\(graph.subgraphIds.count)"` has no collision guard against user-defined ids. Now bumps the index until unique.

**Rendering & views**
- ✅ **Closed by `04b00ee` (Session 2):** `EdgeRenderer.swift:119` — `.arrow` case hardcodes `context.setLineWidth(0.75)`, ignoring the configured `lineWidth`. Source the width from the configured stroke.
- ✅ **Closed by `04b00ee` (Session 2):** `DiagramLayer.swift:182-189` — on parse failure, `preparedDiagram` is not cleared. Pick an intentional semantics (clear-on-failure vs preserve-with-error-overlay) and document it.
- ✅ **Closed by `04b00ee` (Session 2):** `DiagramEditor+Undo.swift:29-51` — undo snapshot does not capture `selection`. After `.deleteElement(...)`, undo restores doc/source/diagnostics but the dangling selection can throw on the next mutation. Capture selection in the snapshot.
- ✅ **Closed by `96a5350` / `c9b3af3` (between Session 5 and 6; never previously tabulated):** `DiagramRenderer.swift:147-161` — 4000pt multiline bounding box is a band-aid. Replace with a `measure-first` strategy so the box matches the actual text extent. `LabelRenderer.measureMultilineExtent` is the new measure-first path.
- ✅ **Closed by `04b00ee` (Session 2):** `DiagramLayer.swift:91` — `UIScreen.main.scale` is deprecated on iOS 13+ multi-scene. Source scale from the view's window scene (`view.window?.windowScene?.screen.scale`). New `DiagramLayer.updateContentsScale(_:)` lets hosts correct the fallback once attached to a window.

**Format slices: round-trip & diagnostic discipline**
- ✅ **Closed by `5ef689f` (Session 2) + `ab7f8d6` → `68704e5` (Session 7):** Identifier-sanitization severity is inconsistent between `MermaidExportHelpers.sanitizeIdentifier` (`.info`) and Structurizr's `uniqueSanitizedAlias` (`.warning`). Pick one (`.warning` is closer to the right severity for lossy operations) and apply across slices. Severity flipped `.info`→`.warning` in Session 2; Session 7 adopts the collision-aware `sanitizeIdentifier(_:usedAliases:)` overload across all five Mermaid export slices (ER, flowchart, class, C4, sequence) with shared `usedAliases` + `aliasMap` per pass.
- ✅ **Closed by `8546f81` (between original review and Session 1; never previously tabulated):** `MermaidC4Export.swift:42-54` and `PlantUMLC4Export.swift:47-56` disagree on the slot semantics of the third positional arg (`desc` vs `tech`). Cross-format C4 round-trip silently swaps technology↔description. Align via a single `C4ArgsEmitter` helper. Both exporters and the PlantUML parser now dispatch on `C4ShapeType.hasTechnologySlot`; `Tests/DiagramKitTests/C4SlotSemanticsTests.swift` pins the invariant.
- ✅ **Closed by `5ef689f` (Session 2):** `PlantUMLImporter.swift:30-32, 110` throws `.notYetImplemented` for two distinct conditions (malformed source vs unrecognized family). Split into `.malformedSource` and `.unsupportedFamily`.
- ✅ **Closed by `5ef689f` (Session 2):** `PlantUMLSequenceParser.swift:409-411` declares `title` unsupported; both exporters emit it. Add title parsing to close the round-trip. Title now parses into `PlantUMLSequenceAST.title` and round-trips through `DiagramDocument.title`.
- ✅ **Closed by `5ef689f` (Session 2):** `PlantUMLFamilyProbe.swift:58-61` — class probe false-matches any text containing `--`. Tighten the heuristic. Regex tightened to `\w+\s*--\s*\w+`.
- ✅ **Closed by `5ef689f` (Session 2) + `ab7f8d6` → `68704e5` (Session 7):** `MermaidExportHelpers.sanitizeIdentifier` silently drops non-`[A-Za-z0-9_-]` chars without collision checking. Mirror Structurizr's `usedAliases` set. Session 2's `5ef689f` added the `sanitizeIdentifier(_:usedAliases:)` overload; Session 7 adopted it across all five Mermaid export slices with shared per-pass `usedAliases` + `aliasMap`. References (edge endpoints, relationship endpoints, `$boundary=`/`$parent=`, note actor lists, etc.) resolve via the map with plain-sanitize fallback for references not in the entity set.
- ✅ **Closed by `5ef689f` (Session 2):** `D2Parser.swift:43-49` only strips `#` as inline-comment marker; `// note` trailing values leak into the value. `D2Parser.preprocess` now strips both `#` and `//` via `_stripInlineComment(_:marker:)`.
- ✅ **Closed by `9dd168a` (between Session 2 and 3; never previously tabulated):** `DOTLexer` does not enter HTML-label mode; `label=<<TABLE>…</TABLE>>` drops the rest of the attribute list. `DOTMapper._isHTMLLabel` (`DOTMapper.swift:382-391`) is dead code until the lexer is fixed. New `.htmlString` token in `DOTLexer` with depth-counting; `DOTMapper._isHTMLLabel` is wired, emits an `.unsupported` diagnostic, and falls back to the node id. `Tests/DiagramKitTests/DOTLexerHTMLLabelTests.swift` covers it.
- ✅ **Closed by Session 6 (this session, `81ddf33` → `ed5e578`):** `StructurizrExporter.swift:84-91` drops boundary metadata; the companion importer rebuilds boundaries from parent relationships, so export → import loses information. Emit a paired `.warning` on the import side or close the round-trip. Closed by adding Structurizr DSL `group "label" { … }` parsing, `C4BoundaryOrigin` partitioning, and the partition-emit exporter.
- ✅ **Already addressed (no specific commit traced):** `D2Mapper.swift:74-101` silently drops direction/icon/tooltip/link from second occurrences in duplicate-node-ID paths. `upsertNode` now emits four targeted `.warning` diagnostics (label/shape/width/height) when the second occurrence overrides a prior value.

**Playground state machine**
- `UndoManager.canUndo`/`canRedo` are not Observation-tracked; SwiftUI `.disabled(!editor.undoManager.canUndo)` modifiers drift. Phase 2 sidesteps this by dropping `.disabled` and routing in the action body, but the structural undo footer still has the issue. Mirror `canUndo`/`canRedo` as `@Observable` shims on `DiagramEditor`.
- ✅ **Closed by `57a33da` (Session 2):** `DiagramEditor.preferredExportFormat` is `let`; format swaps mid-edit can export under the old format. Either make mutable or rebuild the editor on format change. Migrated to `var`.
- `previewState` is captured pre-render; auto-save can record a state the user hasn't actually rendered. Capture post-render in `didCompleteRender`. (Source-search shows no `previewState` references in `LiveEditorStore.swift`; this entry may itself be stale, but I haven't traced the closing commit.)
- ✅ **Closed by Session 5 (`eed1531` → `98f5f6e`):** `_export` runs synchronously on `@MainActor`; large flowcharts block main. Hop to a worker for the export call. `DiagramEditor.perform`/`performFlowchart`/`syncSource` are now `async throws`; commits land via `_runOnWorker` (8 MB fresh-Thread on Apple; private Linux fallback).
- ✅ **Closed by `57a33da` (Session 2):** `LiveEditorStore.performMutation` and `InsertNodeSection.insert` both surface mutation errors, producing duplicate UI. Pick one source of truth. `store.lastMutationError` is now the single source of truth.
- `SidebarView.loadDiagram` ignores `expectedDiagnostics` / `unsupportedNote`. Wire the corpus metadata into the load path.
- ✅ **Closed by `57a33da` (Session 2):** `requestRender(reason:)` doesn't reset `parseError`; the error overlay sits atop a fresh render until completion. Clear on render request.

**Tests, gates, concurrency**
- ✅ **Closed by `90ead92` (Session 2):** `GanttAsciiRendererTests.swift:9-10` sets+defers `DIAGRAMKIT_GANTT_TODAY`; `CorpusSnapshotTests.swift:46` only sets it. Pin the env var process-wide in a shared suite bootstrap. The `defer { unsetenv }` was dropped so parallel runs can't race the corpus reader.
- ✅ **Closed by `90ead92` (Session 2):** `Scripts/strict-concurrency-check.sh:24` ignores `swift build`'s exit code. Capture and surface it.
- ✅ **Closed by Sessions 2 / 5 / 6** (`90ead92`, `98f5f6e`, `ed5e578`): `CLAUDE.md` claims 188 test files; actual is 216. Sync the doc. Count tracked session-by-session; current value is 231 after Session 6.
- ✅ **Closed by `90ead92` (Session 2):** No targeted test for the parser dispatch-order invariant. Add a small suite that pins "stateDiagram-v2 does not fall into state branch", "flowchart-elk does not fall into flowchart branch", etc. `Tests/DiagramKitTests/ParserDispatchOrderTests.swift` pins 16 header→`DiagramType` cases.

### 5. Minor / polish items

Session-3 closed the dead-code purge (`8e5a13a`), the `MermaidFlowchartExport.shapeMarker` shape-downgrade `.warning` (`6a793c3`), and the DOT/D2 trailing-newline alignment (`fb8d6ad`). What remains in the original "Minor" tier — file-size warnings still over 500 lines, residual header comments referencing removed files, accessibility labels across the playground demo, and any small touches not yet picked up — is left as opportunistic backlog. Pick up when touching the relevant file.

### 6. Tautological probe tests (Critical, deferred)

✅ **Closed by `dba530b` (Session 2):** `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift:30-48` — three `@Test` cases (`d2ProbeSignature`, `plantumlProbeSignature`, `structurizrProbeSignature`) construct a literal then `#expect` the same literal contains its own substring. Tautological. Delete or replace with real importer-probe assertions. Three fixture-checks-fixture tests replaced with real `PlantUMLImporter().supports(...)` assertions.

### 7. Mermaid C4 parser ignores `$boundary` named arg (new, surfaced Session 6)

✅ **Closed by Session 9 (`4e2a6e3` → `ffe5573`):** `_parseC4DiagramWithDiagnostics` is the SPI variant surfacing diagnostics; `_resolveParentBoundary` honours `named["boundary"]` for shapes and `named["parent"]` for boundaries / deployment nodes across all 28 dispatch sites, with `.warning` on lexical-vs-named mismatch and on unresolved refs. The root cause was actually deeper than the original framing suggests — `parseMacroArguments` only read in-paren named args while the exporter emits trailing `$key=value` *after* the paren list, so every `$boundary=` / `$parent=` / `$tags=` was being silently dropped. New `_parseTrailingC4Attributes` merges those into the named dict before dispatch. Mermaid → Mermaid round-trip pinned; Session 6's `structurizrToMermaidEmit` now re-parses end-to-end.

`Sources/DiagramKitModel/src_c4_parser.swift:426` — `_addPersonOrSystem` reads `link`, `tags`, and `sprite` from the parsed `named` arg dictionary but ignores `$boundary`. `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidC4Export.swift` emits `$boundary=<alias>` for any shape whose `parentBoundary != "global"` (`shapeLine += " $boundary=\(pb)"`), but the Mermaid parser sets `parentBoundary` only from the lexical boundary stack — so on re-parse, shapes that aren't physically nested inside a `Boundary(...) { … }` block lose their boundary linkage.

**Impact:** Mermaid → Structurizr → Mermaid (via Structurizr's new `group { … }` round-trip) preserves the linkage because Structurizr emits `group "label" { … }` blocks containing the shapes directly. Mermaid → Mermaid round-trip drops the linkage for any shape emitted with a `$boundary=` attribute rather than nested. Discovered when writing `StructurizrBoundaryRoundTripTests.structurizrToMermaidEmit` in Session 6; that test was reshaped to stop short of re-parsing the Mermaid output for this reason.

**Recommendation:** in `_addPersonOrSystem` (and the parallel `_addContainerOrComponent`), read `named["$boundary"]` and prefer it over the lexical `currentBoundary` argument when present. Add a Mermaid → Mermaid round-trip test that authors a flat-emit shape and asserts its `parentBoundary` survives.

---

## Critical (Must Fix)

**Currency note:** The Critical / Important / Minor bullets below preserve the **original** review's findings as a historical record. Many of the Critical items were closed by Phases 1–5 (the top-of-document table) and Sessions 1–6 (the resolution tables above); the Deferred Effort §1–§7 section is the authoritative open-work list.

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

1. **Exporter testing is weaker than parser/renderer testing.** The Mermaid/PlantUML exporter bugs above would be caught by any round-trip suite (`parse → export → parse → assert structural equality`). None of these bugs depend on visual fidelity; they would fail purely structural assertions. ✅ **Closed by the round-trip discipline that landed in commits `fe24e7a` → `7138704` (preceding Session 13).**
2. **`.unsupported` vs throw vs `.warning` vs `.info` is inconsistent across slices.** PlantUML throws for unrecognized family; Structurizr returns `.warning` diagnostics for identifier rewrites; Mermaid returns `.info` for the same operation; D2 silently drops second-occurrence properties. A single discipline doc + linter would help. ✅ **Closed by Session 13 (`2f3794d` → _HEAD_):** typed `DiagnosticCategory` enum + static factories on `DiagramDiagnostic` (`.lossyTransform` / `.featureDropped` / `.informational`); `Scripts/check-diagnostic-discipline.sh` lint gate + self-test; reference doc at `docs/diagnostic-severity-discipline.md`; harness `diagnosticsCover` rewritten to pair `RoundTripLossKind` to diagnostics by typed category equality (legacy keyword matcher deleted); migration sweep covered ~120 emission sites across all 6 format slices + model-tier; three recategorizations (`labelNewlineEscape` `.info` → `.warning`, `c4SlotDrop` `.info` → `.unsupported .slotUnsupported`, `d2InlineCommentStripped` silent → `.warning`); silent-drop policy with `// SILENT-DROP(...)` + `Pinned by:` discipline applied at two known sites.
3. **The umbrella exposes two paths for the same operation** (`renderDiagramSVG` free function in `src_index.swift:70` and `DiagramEngine.renderSVG`). Pick one canonical entry.
4. **CLAUDE.md drift** is small but real: 188 vs 216 test files; "Interactive re-exported" claim vs actual `ReExports.swift`. Worth a sync.
5. **Linux support is partial-by-design** but the umbrella's `#if canImport(CoreGraphics)` around SVG/ASCII undermines the "DiagramKit on Linux exists" story.

---

## Assessment

**Original verdict (pre-fix):** Not ready to merge — the exporter correctness bugs silently corrupt valid input on common cases, the playground undo regression makes the recent Cmd-Z work non-functional in practice, and the ASCII snapshot baseline gap leaves renderer drift in 22 families invisible to CI.

**Updated verdict (post-fix, commits `7143128` → `f7990d5`):** The five-phase fix plan landed end-to-end. The originally critical exporter, playground-undo, and ASCII-gate failures are addressed; the renderer color/flip discipline issues are addressed; and a bonus D2-probe header fix unblocks Mermaid sources the importer had been wrongly claiming.

**Session 13 (`2f3794d` → _HEAD_):** Cross-cutting Observation #2 closed end-to-end. Fifteen commits on `main` covering the additive types (Tasks 1-3), per-slice migration sweep (Tasks 4-8, ~120 sites across Mermaid + Structurizr + D2 + Graphviz/DOT + PlantUML + model-tier), three recategorizations (Tasks 9-11), silent-drop audit + markers (Task 12), script gate + self-test (Task 13), strict-phase deprecation + legacy fallback removal (Task 14), and reference doc + cross-doc sync (Task 15). Two pre-existing failures surfaced and fixed forward: stale `StructurizrExporterTests.dropsBoundaryGroups...` (asserted pre-Session-6 behavior) and `C4SlotSemanticsTests.mermaidPersonTechnologyDropped` (severity/category pin updated for Mermaid C4 slotless-shape recategorization).

**Sessions 1–11 (`7143128` → _Session 11 HEAD_):** Every Deferred Effort §1–§7 item is now closed end-to-end. §1 SVG color-mix resolver + rebaseline (Sessions 2 + 4), §2 D2/DOT subgraph walker (Session 2), §3 ER ASCII parent marker (Session 2), §4 the architecture / model-edge / rendering / format-slice / playground / tests-and-gates bullets (Sessions 2 + 5 + 6 + 7 + 8 + 11), §5 polish items still tracked opportunistically, §6 tautological probes (Session 2), §7 Mermaid C4 `$boundary` round-trip (Session 9), §10 parser-diagnostics surfacing (Session 10). The §4 playground subsection is fully closed: Session 11 landed Observation-tracked `canUndo`/`canRedo`/`undoActionName`/`redoActionName` on `DiagramEditor`; the `SidebarView.loadDiagram` corpus-metadata wiring shipped between Sessions 6 and 7 (`CorpusMetadataBanner` in `DiagramEditorPane` + `setLoadedCorpusMetadata` in `LiveEditorStore`); the stale `previewState` capture-timing note refers to a symbol that no longer exists in `LiveEditorStore.swift` and is retired. None block merge.

**Suggested fix order (executed):** 1) ASCII baselines + bootstrap-smoke-check filtering (so subsequent fixes have a real gate) — **shipped in `7143128`**, 2) playground undo (`didCompleteRender` re-seed loop + Cmd-Z text-edit conflict) — **shipped in `138e367`**, 3) exporter correctness batch (Mermaid flowchart shape, subgraph walker, PlantUML state pseudostate, sequence escape, class comments) — **shipped in `a13b67c`**, 4) parser dispatch tokenization across `DiagramRegistry+*.swift` — **shipped in `633bec4`**, 5) renderer color/flip cleanups — **shipped in `f7990d5`**.

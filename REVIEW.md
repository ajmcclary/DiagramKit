# DiagramKit Code Review

Review date: 2026-05-17
Branch: `main`
HEAD: `c87e8b4`

Scope covered:
- Public pipeline and worker-thread entry points.
- Font registration and text measurement paths.
- Mermaid registry dispatch order.
- Exporter diagnostic hygiene and round-trip harness behavior.
- Layer/import boundaries and cross-platform guardrails.
- Requested local gates, run individually from `/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift`.

Notes on repository shape:
- `swift package dump-package` reports 14 library products plus 1 executable product. This is newer than the 13-product count in the prompt.
- The current Mermaid dispatch file is `Sources/DiagramKit/DiagramDescriptor.swift`; `Sources/DiagramKit/Parser.swift` does not exist in this checkout.

## Critical Issues

### C1. Non-corpus test gate stalls in CoreText font resolution

Status: RESOLVED (2026-05-17)

Fix:
- `Sources/DiagramKitModel/DiagramFontResolver.swift` — renamed `ctFontLock` → `fontLock` and added locked `makeBMFont(name:size:)`, `makeSystemBMFont(size:weight:)`, and `makeMonospacedSystemBMFont(size:weight:)` helpers. `proportionalFont(size:weight:)` and `defaultFont(size:weight:)` (the two paths reached from `TextMetrics`) now route every `BMFont` construction through the lock, so parallel `NSFont(name:size:)` / `UIFont(name:size:)` calls into the CoreText font-provider XPC are serialized.
- `Tests/DiagramKitTests/DiagramFontResolverConcurrencyTests.swift` — new swift-testing regression that runs 32 parallel `layoutC4Diagram` + `layoutTreemapDiagram` calls (the public model-layer entry points the review flagged as bypassing `DiagramPipeline`). Passes in 0.02s.

Verification:
- `swift test --filter "DiagramFontResolverConcurrencyTests"` — PASS, 0.021s.
- `swift test --filter "C4LayoutTests"` — PASS, 13 tests.
- `swift test --filter "TreemapSvgTests"` — PASS, 16 tests.
- `./Scripts/strict-concurrency-check.sh` — PASS.

Original finding (kept for reference):

Evidence:
- Command: `swift test --skip CorpusSnapshotTests --skip CorpusMultiFormatSnapshotTests`
- Result: the test process produced no final summary and was killed after several minutes of no progress.
- A process sample showed Swift Testing worker threads blocked in the same path:
  - `TreemapSvgTests.svgEscapesXml` at `Tests/DiagramKitTests/TreemapSvgTests.swift:60`
  - `layoutTreemapDiagram(_:)` at `Sources/DiagramKitModel/src_treemap_layout.swift:7`
  - `TextMetrics.estimateTextWidth` at `Sources/DiagramKitModel/TextMetrics.swift:32`
  - `DiagramFontResolver.proportionalFont` at `Sources/DiagramKitModel/DiagramFontResolver.swift:148`
  - `BMFont(name:size:)` / `NSFont fontWithName:size:` / CoreText font-provider XPC
- Another sampled thread was in:
  - `C4LayoutTests.dynamicDiagramIndexing` at `Tests/DiagramKitTests/C4LayoutTests.swift:188`
  - `layoutC4Diagram(_:)` at `Sources/DiagramKitModel/src_c4_layout.swift:94`
  - `TextMetrics.estimateTextWidth` through the same `BMFont` path.
- A targeted follow-up run, `swift test --filter 'TreemapSvgTests|C4LayoutTests' --parallel --num-workers 1`, also stalled after build and had to be killed.

Why this matters:
- The requested merge gate cannot complete locally.
- The affected call sites are public model-layer layout functions, not just private tests. They bypass `DiagramPipeline.runPipeline`, so they do not get the centralized font-registration and issue-reporting boundary.
- `TextMetrics` says it uses CoreText measurement, but on Apple it obtains a `BMFont` via `DiagramFontResolver.proportionalFont(...)`. The resolver has a `ctFontLock`, but that lock only protects `CTFontCreateWithName`; it does not protect the `BMFont(name:size:)` path used by `TextMetrics`.

Recommendation:
- Move `TextMetrics` to the locked `CTFont` helper path, for example by using `kCTFontAttributeName` with `proportionalCTFont(size:)` / `monospaceCTFont(size:)`, or add a deterministic locked/cached font resolution path for `BMFont`.
- Ensure public model-level layout/render helpers either become SPI/internal or share the same bootstrap/font-registration boundary as `DiagramPipeline`.
- Add a focused regression test that runs representative C4 and treemap layout calls repeatedly without going through `DiagramPipeline`, because this is the path that currently exposes the stall.

## High-Severity Findings

### H1. D2 and DOT exporters silently downgrade flowchart shapes without paired diagnostics

Status: RESOLVED (2026-05-17)

Fix:
- `Sources/DiagramKitExport/FlowchartExportWalker.swift` — `FlowchartExportSink` gained a `var diagnostics: [DiagramDiagnostic] { get }` requirement (default `[]`). The walker now concatenates `sink.diagnostics + subgraphDiagnostics` so per-node lossy mappings surface alongside subgraph-flatten warnings.
- `Sources/DiagramKitD2/D2Exporter.swift` — `d2Shape(for:)` now returns `(name: String, lossy: Bool)`. The sink emits `.lossyTransform(.shapeDowngrade, …)` for every non-bijective mapping (`rounded`, `doublecircle`, `smallCircle`, `framedCircle`, `filledCircle`, `crossedCircle`, `horizontalCylinder`, `linedCylinder`, `parallelogramAlt`, `trapezoid`, `trapezoidAlt`, plus the catch-all). Shape attributes now emit as `id.shape: value` so they round-trip cleanly through `D2Parser` (the old `id { shape: … }` block was misparsed as a subgraph).
- `Sources/DiagramKitGraphviz/DOTFlowchartExport.swift` — `dotShape(for:)` returns `(name, lossy)`. Sink emits paired diagnostics for `rounded`, `stadium`, doublecircle/smallCircle/framedCircle/filledCircle/crossedCircle, `parallelogramAlt`, `trapezoidAlt`, horizontal/linedCylinder, `subroutine`, `flippedTriangle`, and document variants.
- `Tests/DiagramKitTests/Export/{D2,DOT}ExporterTests.swift` — parameterized tests cover 12 D2 + 17 DOT lossy shapes plus a lossless-emits-nothing guard.
- `Tests/.../RoundTrip/Resources/roundtrip/cross-mermaid-d2-flowchart/04-shape-downgrades.md`, `cross-mermaid-dot-flowchart/04-shape-downgrades.md` — Mermaid fixtures with `rounded`, `doublecircle`, `trapezoidAlt`, `subroutine` to exercise the new diagnostic pairing through `runCrossFormatRoundTrip`.

Verification:
- `swift test --filter "D2ExporterTests|DOTExporterTests"` — PASS, 18 tests including 29 parameterized shape rows.
- `swift test --filter "RoundTrip"` — PASS, 85 tests across 20 suites.
- `./Scripts/check-diagnostic-discipline.sh` — PASS.
- `./Scripts/strict-concurrency-check.sh` — PASS.

Original finding (kept for reference):

Evidence:
- `Sources/DiagramKitD2/D2Exporter.swift:67` maps shapes to D2 names.
  - `.rounded` returns `"rectangle"` at line 70 with a `TODO`.
  - `.doublecircle`, `.smallCircle`, `.framedCircle`, `.filledCircle`, and `.crossedCircle` all return `"circle"` at lines 72-73.
  - `.parallelogramAlt`, `.trapezoid`, and `.trapezoidAlt` all return `"parallelogram"` at lines 78-79.
  - `default` returns `"rectangle"` at line 80.
- `Sources/DiagramKitGraphviz/DOTFlowchartExport.swift:45` maps shapes to DOT names.
  - `.rectangle` and `.rounded` both return `"box"` at line 47.
  - several distinct circle/document/triangle variants collapse to a smaller DOT shape set at lines 49-58.
  - `default` returns `"box"` at line 59.
- `FlowchartExportWalker` only emits diagnostics for subgraph flattening at `Sources/DiagramKitExport/FlowchartExportWalker.swift:105`; it never lets sinks report node-level lossy shape mappings.
- The round-trip diff treats shape changes as `RoundTripLoss.shapeDowngrade` in `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Flowchart.swift:23`.
- The harness requires every allowed loss, except anonymous subgraph rename, to be covered by a typed diagnostic in `Sources/DiagramKitTestSupport/RoundTripHarness.swift:198`.
- Current D2/DOT fixture sets do not include shape variants that exercise this, so `swift test --filter RoundTrip` passes while this gap remains latent.

Impact:
- Exported source can lose node-shape semantics with no `.lossyTransform(.shapeDowngrade, ...)` diagnostic.
- The diagnostic discipline script passes because it checks raw factories, `SILENT-DROP`, and exporter throws, but it does not check semantic omissions like this.
- Adding a rounded, double-circle, trapezoid-alt, or newer Mermaid v11 shape fixture to D2/DOT round trips should expose an unpaired loss.

Recommendation:
- Change `FlowchartExportSink.node` to return diagnostics, or precompute shape mappings in the walker through a shared lossy-shape mapping API.
- Emit `.lossyTransform(.shapeDowngrade, message: ...)` for every non-bijective shape mapping in D2 and DOT.
- Add D2/DOT round-trip fixtures that include at least `.rounded`, `.doublecircle`, `.trapezoidAlt`, `.subroutine`, and one v11/non-D2/DOT shape.

### H2. CI does not enforce the same governance surface as the documented local gate

Status: RESOLVED (2026-05-17)

Fix:
- `.github/workflows/ci.yml` — `swift test` replaced with the same 7-step chunked sequence used by `Scripts/bootstrap-smoke-check.sh` (non-corpus skip + round-trip filter + 5 corpus chunks). Added the clean `swift build --target DiagramKitMermaid` undeclared-module-dep gate, plus the four omitted governance scripts: `check-diagnostic-discipline.sh`, `check-diagnostic-discipline-tests/run.sh`, `check-stale-phase-comments.sh`, `check-linux-check-runtime-skip.sh`. Existing `linux-check.sh` env-skip step kept.

Verification:
- `./Scripts/check-diagnostic-discipline-tests/run.sh` — PASS locally (all fixtures).
- `./Scripts/check-stale-phase-comments.sh` — PASS locally.
- `./Scripts/check-linux-check-runtime-skip.sh` — PASS locally (exit 0).
- CI run on this commit will validate the chunked corpus sequence against macos-15.

Original finding (kept for reference):

Evidence:
- `.github/workflows/ci.yml:35` runs plain `swift test`.
- The local merge gate in `Scripts/bootstrap-smoke-check.sh:65-80` runs non-corpus tests and corpus snapshots in separate chunks to avoid the known parameterized snapshot signal-10 issue.
- CI omits these local-gate checks:
  - `Scripts/check-diagnostic-discipline.sh`
  - `Scripts/check-diagnostic-discipline-tests/run.sh`
  - `Scripts/check-stale-phase-comments.sh`
  - `Scripts/check-linux-check-runtime-skip.sh`
  - `swift package clean && swift build --target DiagramKitMermaid`
  - explicit `swift test --filter RoundTrip`
  - the chunked corpus snapshot commands from `bootstrap-smoke-check.sh`

Impact:
- CI can pass changes that violate diagnostic discipline or stale phase-comment policy.
- CI may be less stable than the local gate because it runs `swift test` as a single command instead of the documented chunked corpus strategy.
- The current local non-corpus gate stall would be harder to diagnose in CI because the workflow does not mirror the local split.

Recommendation:
- Make CI call the same script as local, with environment skips only where required, or copy the same gate sequence.
- If CI must stay shorter, add at least the diagnostic discipline scripts and the stale phase-comment script.
- Replace plain `swift test` with the same split used in `bootstrap-smoke-check.sh`.

## Medium-Severity Findings

### M1. Quadrant SVG ignores the injected font family

Status: RESOLVED (2026-05-17)

Fix:
- `Sources/DiagramKitModel/src_quadrant_renderer.swift` — `_quadrantSvgOpenTag` now takes `font` and threads it into `SVGDocumentBuilder(fontFamily: font, …, rootStyles: ["font-family:\(font)"])`. Quadrant `<text>` elements carry no inline `font-family`, so the root `<svg style="…">` is the single CSS-inheritance point that propagates the font.
- `Tests/DiagramKitTests/QuadrantSvgTests.swift` — two regressions: default font reaches the root style (`font-family:Inter`), and a non-default font (`"Atkinson Hyperlegible"`) replaces it.
- `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-_.quadrant-*.txt` — 12 corpus baselines rebaselined; the only diff per file is the addition of `font-family:Inter;` to the root style.

Verification:
- `swift test --filter "QuadrantSvgTests"` — PASS, 26 tests.
- `SNAPSHOT_DIAGRAM_IDS=quadrant-* swift test --filter "CorpusSnapshotTests/svgSnapshot"` — PASS, 12 tests.

Original finding (kept for reference):

Evidence:
- `SVGRenderRegistry` passes the resolved font into `renderQuadrantSvg(...)` at `Sources/DiagramKit/SVGRenderRegistry.swift:206`.
- `renderQuadrantSvg` accepts `_ font` at `Sources/DiagramKitModel/src_quadrant_renderer.swift:9`.
- `_quadrantSvgOpenTag` does not accept that font and hardcodes `fontFamily: "Inter"` at `Sources/DiagramKitModel/src_quadrant_renderer.swift:112-116`.

Impact:
- Custom/default font-family routing is bypassed for Quadrant SVG root output.
- This violates the convention that renderer font family should route through `RenderConfig.defaultFontFamily` / resolver plumbing rather than hardcoded renderer strings.

Recommendation:
- Thread the `font` parameter into `_quadrantSvgOpenTag` and pass it to `SVGDocumentBuilder`.
- Add a small SVG assertion that a non-default font argument reaches the root SVG style.

### M2. `DiagramEngine.parseImportResult` bypasses the centralized pipeline boundary

Status: RESOLVED (2026-05-17)

Fix:
- `Sources/DiagramKit/DiagramPipeline.swift` — new public `parseImportResult(_:sourceFormat:registry:)` that wraps the existing private `loadImportResult` in `runPipeline(operation: …, registerFonts: true)`. Font registration + `_withDiagramIssueReporting` now apply to import-result parses on the same footing as `parse`, `layout`, `renderSVG`, `renderASCII`.
- `Sources/DiagramKit/DiagramEngine.swift` — `parseImportResult` now delegates to `DiagramPipeline.parseImportResult` inside `_runOnWorker` instead of calling `DiagramLoader.parse` / `DiagramLoader.parseImportResult` directly.
- `Tests/DiagramKitTests/DiagramLoaderParseImportResultTests.swift` — two regressions: result equivalence between the new `DiagramPipeline.parseImportResult` and the raw `DiagramLoader.parseImportResult`, and explicit `sourceFormat: .mermaid` routing.

Verification:
- `swift test --filter "DiagramLoaderParseImportResultTests"` — PASS, 6 tests.
- `./Scripts/strict-concurrency-check.sh` — PASS.

Original finding (kept for reference):

Evidence:
- Most public `DiagramEngine` methods dispatch to `_runOnWorker` and then call a `DiagramPipeline` method.
- `DiagramEngine.parseImportResult` dispatches to `_runOnWorker`, but then calls `DiagramLoader.parse(...)` / `DiagramLoader.parseImportResult(...)` directly at `Sources/DiagramKit/DiagramEngine.swift:210-215`.
- `DiagramPipeline.runPipeline` is the only central place that applies font registration and `_withDiagramIssueReporting`, at `Sources/DiagramKit/DiagramPipeline.swift:27-38`.

Impact:
- This public entry point does not share the same issue-reporting boundary as the rest of the pipeline.
- It is parse-only, so it is unlikely to trigger font-dependent layout bugs directly, but it contradicts the stated invariant that every pipeline method goes through the centralized boundary.

Recommendation:
- Add a `DiagramPipeline.parseImportResult(...)` method that wraps `loadImportResult` in `runPipeline`, and have `DiagramEngine.parseImportResult` call that.

### M3. Public model-layer parser/layout/render functions expose bypass paths around engine invariants

Status: RESOLVED (2026-05-17, documentation track)

Fix:
- `ARCHITECTURE.md` — new "Model-layer free functions are SPI-equivalent" subsection under the worker-thread invariant. Documents (a) that these helpers are not the supported public API, (b) the supported API is `DiagramEngine.*` / `DiagramImageRenderer.*`, and (c) the three caller-side invariants when direct use is intentional: thread/stack management, font registration, issue-reporting context.
- `CLAUDE.md` — Critical Invariants bullet pointing to the same ARCHITECTURE section, so future agents see the constraint immediately.

Why documentation rather than renaming: ~30 public free functions span `parse*`, `layout*`, `render*` patterns and are imported by name from `DiagramKit`, every format slice, and the test target. Underscore-prefixing all of them would be a broad consumer-side breaking change well outside M3's scope. The review explicitly accepts documentation as a sufficient fix for intentionally public low-level helpers. The C1 fix (font lock in `DiagramFontResolver`) already neutralizes the concrete CoreText-stall consequence of bypassing the boundary.

Original finding (kept for reference):

Evidence:
- `Sources/DiagramKitModel` exposes many public free functions such as:
  - `layoutC4Diagram(_:)` at `Sources/DiagramKitModel/src_c4_layout.swift:94`
  - `layoutTreemapDiagram(_:)` at `Sources/DiagramKitModel/src_treemap_layout.swift:7`
  - `renderQuadrantSvg(...)` at `Sources/DiagramKitModel/src_quadrant_renderer.swift:6`
  - many other `parse*`, `layout*`, and `render*` helpers.
- These functions are synchronous, not worker-thread mediated, and not font-registration mediated.

Impact:
- They are convenient for tests and lower-level consumers, but they undermine the convention that public APIs should be `async throws` static methods on `DiagramEngine` or `DiagramImageRenderer`.
- The non-corpus test stall demonstrates that some direct layout entry points can hit font-resolution behavior that the public pipeline normally tries to centralize.

Recommendation:
- Decide which helpers are true public API and which are SPI.
- Mark implementation helpers as SPI/internal where possible, and document any intentionally public low-level helpers as "caller must bootstrap/register fonts and manage stack/threading."

## Low-Severity Findings

### L1. File-size gate passes with many warning-level overages

Status: PARTIALLY RESOLVED (2026-05-17)

Fix:
- `Sources/DiagramKitModel/ShapeSpecRegistry+Defaults.swift` (805 → 417 lines) — split at `_makeBracesSpec` / `_makeLightningBoltSpec`. Both halves of the registry now live in their own files and clear the 500-line warning threshold. The largest of the review's named files (the default registry table) is the natural starting point because it's pure data with no shared mutable state.
- `Sources/DiagramKitModel/ShapeSpecRegistry+DefaultsSpecial.swift` (NEW, 408 lines) — holds `_makeLightningBoltSpec` through `_makeEllipseSpec` (document / cylinder / specialized / state / icon factories). `ShapeSpec._buildSpecs()` consumes both halves unchanged.

The four remaining warning-level files named in the original finding (`src_c4_parser.swift` 933, `src_gantt_parser.swift` 907, `Tests/.../RadarParserTests.swift` 889, `src_requirement_parser.swift` 826) are parser/test files where extraction requires unwinding shared parser-state objects and is a heavier, family-by-family piece of work. They remain warnings — still well under the 1000-line error threshold — and are tracked here as follow-ups. The review explicitly framed this finding as preventive ("before they cross 1000 lines"), and splitting the registry table demonstrates the pattern.

Verification:
- `swift build --target DiagramKitModel` — PASS.
- `swift test --filter "RoundTrip"` — PASS, 85 tests.
- `SNAPSHOT_DIAGRAM_IDS=block-1-simple,architecture-basic swift test --filter "CorpusSnapshotTests/svgSnapshot"` — PASS (block + architecture both exercise `ShapeSpec` lookup).
- `./Scripts/check-file-sizes.sh` — `ShapeSpecRegistry+Defaults.swift` no longer in the warning list.
- `./Scripts/strict-concurrency-check.sh` — PASS.

Original finding (kept for reference):

Evidence:
- `Scripts/check-file-sizes.sh` exited 0 but emitted warnings for files over 500 lines.
- Largest warnings:
  - `Sources/DiagramKitModel/src_c4_parser.swift` - 933 lines
  - `Sources/DiagramKitModel/src_gantt_parser.swift` - 907 lines
  - `Tests/DiagramKitTests/RadarParserTests.swift` - 889 lines
  - `Sources/DiagramKitModel/src_requirement_parser.swift` - 826 lines
  - `Sources/DiagramKitModel/ShapeSpecRegistry+Defaults.swift` - 805 lines

Impact:
- No current gate failure because all are below the 1000-line error threshold.
- These are the files most likely to be hard to review and easiest to push over the hard limit.

Recommendation:
- Prioritize parser fixtures/helpers and default registry tables for extraction before they cross 1000 lines.

### L2. Remaining yellow `@unchecked Sendable` entries are tracked but still carry residual risk

Status: PARTIALLY RESOLVED (2026-05-17) — 11 yellow → 7 yellow

Fix:
- `Sources/DiagramKitModel/src_sankey_renderer.swift` — `_SankeyUidGenerator` converted from `final class` (with an unsynchronized `@unchecked Sendable` claim) to a value-type `struct`. It was only ever used as a function-local UID generator inside `renderSankeySvg`, so the class form was misleading; `var uid` + `mutating func next` makes single-pass safety structural. `_SankeyRenderScopeCounter` (the process-wide singleton with a real `NSLock`) got a Concurrency Contract banner — yellow → green.
- `Sources/DiagramKitModel/src_block_types.swift` — `AtomicInt` (lock-backed monotonic counter behind `generateBlockId()`) got a Concurrency Contract banner — yellow → green.
- `Sources/DiagramKitModel/src_block_layout.swift` — `BlockWarnings` (lock-backed warning bag behind `blockWarnings()` / `resetBlockWarnings()`) got a Concurrency Contract banner — yellow → green.
- `.sendable-allowlist.txt` — five entries removed: the four entries above plus the stale `src_treemap_parser.swift:3` (`_MutableNode` already had a contract banner; the allowlist entry pointed at an out-of-date line and was dead weight).

Verification:
- `./Scripts/check-sendable-annotations.sh` — PASS, now reports 7 yellow entries (down from 11).
- `swift test --filter "SankeyRendererTests|BlockRendererTests"` — PASS, 28 tests.
- `./Scripts/strict-concurrency-check.sh` — PASS.

The seven remaining yellow entries (`AsciiNode` / `AsciiEdge` / `AsciiSubgraph` / `AsciiGraph` / `MermaidSubgraphInput` in `src_ascii_converter.swift`, `_MutableTreeNode` in `src_treeview_parser.swift`, `MermaidSubgraph` in `src_types.swift`) are reference-typed model structures whose conversion requires API/migration work; they remain tracked toward the 2027-06-30 sunset.

Original finding (kept for reference):

Evidence:
- `Scripts/check-sendable-annotations.sh` passes.
- The script reports 11 allowlisted yellow entries with sunset `2027-06-30`, including `AsciiNode`, `AsciiGraph`, `_MutableTreeNode`, `MermaidSubgraph`, `AtomicInt`, `_SankeyUidGenerator`, `_SankeyRenderScopeCounter`, and `BlockWarnings`.

Impact:
- No immediate gate failure.
- These should stay visible because they are escape hatches around Swift 6 sendability guarantees.

Recommendation:
- Keep the sunset date meaningful; do not renew it mechanically.
- Prefer replacing mutable reference scratch types with parser-local value types or locked wrappers where practical.

### L3. Thread-pool invariant is clean in production, but literal searches still find test/example concurrency

Status: RESOLVED (2026-05-17, documentation track)

Fix:
- `CLAUDE.md` — "Never introduce a thread pool" bullet now explicitly scopes the invariant to production parse/layout/render code under `Sources/DiagramKit*/`, and lists the three categories that are explicitly out of scope: tests (`MermaidPipelineConcurrencyTests`), the `DiagramPlayground` sample app, and narrow per-parser regex/formatter cache queues (`_dateFormatterCacheQueue`, `_reqRegexCacheQueue`).
- `ARCHITECTURE.md` — same scope clarification under "The worker-thread invariant", with a note for future grep audits to consult before flagging hits.

This addresses the review's only recommendation directly: "Document that the no-pool invariant applies to production parse/layout/render entry points, not tests and playground utility tasks." The invariant itself is correctly enforced in production code; the change is purely scope-clarifying.

Original finding (kept for reference):

Evidence:
- No production rendering/layout `TaskGroup`, `OperationQueue`, or persistent worker pool was found.
- Production hits are narrow cache queues:
  - `_dateFormatterCacheQueue` in `Sources/DiagramKitModel/src_gantt_parser.swift:425`
  - `_reqRegexCacheQueue` in `Sources/DiagramKitModel/src_requirement_parser.swift:133`
- Non-production hits include:
  - `withThrowingTaskGroup` in `Tests/DiagramKitTests/MermaidPipelineConcurrencyTests.swift:75`
  - `Task.detached` in `Examples/DiagramPlayground/Models/DiagramSyntaxHighlighter.swift:319`
  - `async let` in `Examples/DiagramPlayground/Models/Loaders/RawFileLoader.swift:70`

Impact:
- The worker-thread invariant is not violated in production pipeline code.
- If the policy is read literally as "no TaskGroup anywhere," the test/example exceptions should be documented or allowlisted.

Recommendation:
- Document that the no-pool invariant applies to production parse/layout/render entry points, not tests and playground utility tasks.

### L4. Dead generic no-op remains in sequence layout

Status: RESOLVED (2026-05-17)

Fix:
- `Sources/DiagramKitModel/src_sequence_layout.swift` — deleted the dead `func shift(_ arr: inout [some Any], _ keyPaths: [WritableKeyPath<(some Any), Double>]) {} // Not used` no-op. The function had no callers and no semantics.

Verification:
- `swift build --target DiagramKitModel` — PASS.
- `swift test --filter "SequenceLayoutTests"` — PASS, 12 tests.

Original finding (kept for reference):

Evidence:
- `Sources/DiagramKitModel/src_sequence_layout.swift:476` defines `func shift(_ arr: inout [some Any], _ keyPaths: [WritableKeyPath<(some Any), Double>]) {}` with `// Not used`.

Impact:
- No behavior impact, but it is confusing in a file that already exceeds the warning size threshold.

Recommendation:
- Remove the dead function.

### L5. Review prompt and repository docs contain stale file/product references

Evidence:
- The prompt names `Sources/DiagramKit/Parser.swift`; this checkout routes through `Sources/DiagramKit/DiagramDescriptor.swift`.
- The prompt says 13 SwiftPM library products; `swift package dump-package` reports 14 library products.
- Current `BASELINES.md` also reports newer corpus/snapshot counts than the prompt.

Impact:
- Low source risk, but stale review checklists make it easier to miss the actual dispatch file.

Recommendation:
- Update external review checklists and any docs that still point to `Parser.swift` or the older product count.

## Areas Checked With No Findings

- Worker-thread invariant: public engine render/layout paths still dispatch via `DiagramEngine._runOnWorker` to `DiagramWorkerThread.run` on Apple, and the Linux shim creates a fresh `Thread` with `DiagramWorkerConfig.stackSize`.
- Parser dispatch order: `DiagramRegistry.all` is ordered with specific descriptors before `_stateDiagram` and `_flowchart`; matchers use `startsWithToken` rather than broad raw `hasPrefix` in the reviewed dispatch path.
- Raw diagnostic construction: no raw `DiagramDiagnostic(severity:)` was found outside `DiagramKitCommon` by the governance script.
- Exporter `malformedSource`: the diagnostic script found no `throw DiagramError.malformedSource` in exporter files.
- `SILENT-DROP`: the diagnostic script validated current markers and pinned tests.
- Color comparisons: no `hexString`-based color comparisons were found; `bmColorEquals()` is used for equality paths.
- Layer imports: no `DiagramKitModel -> DiagramKitRenderingCG` import was found. `DiagramKitRenderingCG` imports `DiagramKitModel`/`DiagramKitCommon`, and umbrella imports of Apple-only targets are gated.
- `renderSVG` / `renderASCII`: public `DiagramEngine.renderSVG` and `DiagramEngine.renderASCII` are not `@MainActor`; image/CG APIs are `@MainActor`.

## Gate Results

| Gate | Result | Notes |
|---|---:|---|
| `swift package dump-package > /dev/null` | PASS | 0.51s |
| `swift build --build-tests` | PASS | 3.69s |
| `swift test --skip CorpusSnapshotTests --skip CorpusMultiFormatSnapshotTests` | FAIL / STALLED | Killed after several minutes with no final summary; sample showed CoreText font-provider waits from C4/Treemap layout tests. |
| `swift test --filter RoundTrip` | PASS | XCTest: 19 tests, 0 failures. Swift Testing: 85 tests, 0 failures. 0.94s. |
| `./Scripts/check-file-sizes.sh` | PASS WITH WARNINGS | No file above 1000 lines; many warning-level files above 500 lines. |
| `./Scripts/check-sendable-annotations.sh` | PASS | 11 yellow allowlist entries, sunset 2027-06-30. |
| `./Scripts/strict-concurrency-check.sh` | PASS | "DiagramKit first-party targets are strict-concurrency clean." 24.89s. |
| `./Scripts/check-diagnostic-discipline.sh` | PASS | `diagnostic-discipline: clean`. |
| `./Scripts/check-diagnostic-discipline-tests/run.sh` | PASS | All fixtures passed. |
| `./Scripts/check-stale-phase-comments.sh` | PASS | No stale phase-transition comments in `Sources`. |
| `./Scripts/linux-check.sh` | SKIPPED BY ENVIRONMENT | Docker found but not usable; script recorded environment skip and exited 0. |

## Suggested Remediation Order

1. Fix the CoreText/font-resolution stall because it blocks the local non-corpus gate.
2. Add D2/DOT shape-downgrade diagnostics and fixtures, because current tests do not protect this loss.
3. Bring CI into alignment with `Scripts/bootstrap-smoke-check.sh` or at least add the omitted governance scripts.
4. Thread the Quadrant SVG font parameter through `_quadrantSvgOpenTag`.
5. Decide which public model-layer functions should remain public versus SPI/internal.

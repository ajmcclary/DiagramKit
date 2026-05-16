# DiagramKit Code Review — Consolidated Findings

**Method.** Six parallel agents reviewed: (1) architecture/layering/portability, (2) concurrency, (3) invariants + dual-renderer symmetry, (4) diagnostics + error handling, (5) code quality, (6) correctness/perf/test coverage. Critical and high-impact findings were spot-verified against the working tree. The diagnostic-discipline and `@unchecked Sendable` gates pass clean; the worker-thread invariant, `@MainActor` placement, `bmColorEquals`, type-safe payloads, retain cycles, cross-format round-trip matrix, and empty-source handling all checked out with no findings.

**Summary.** 1 Critical (verified build break) — **resolved**, 10 High (10 resolved), 13 Medium (+2 added during follow-up; 12 resolved, 0 deferred), 7 Low (6 resolved).

---

## CRITICAL

### [Severity: Critical] ~~`DiagramKitMermaid` clean build fails — 9 files import an undeclared module~~ — RESOLVED
**Files:** `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift#L4`, plus 8 sibling files under `Sources/DiagramKitMermaid/Exporter/MermaidExport/*.swift#L3`
**Category:** Architecture
**Problem:** Every file in the Mermaid exporter has `import DiagramKitImport`, but `Package.swift#L109-113` declares `DiagramKitMermaid`'s deps as only `["DiagramKitCommon", "DiagramKitModel", "DiagramKitExport"]`. Verified — `swift package clean && swift build --target DiagramKitMermaid` fails with `error: no such module 'DiagramKitImport'`. Incremental builds mask this because cached module artifacts survive. A grep for `DiagramImportResult|ImporterRegistry|DiagramSourceImporter|DiagramLoader` across `Sources/DiagramKitMermaid/` returns zero hits — the Mermaid exporter does not actually need anything from `DiagramKitImport`.
**Fix applied.** The original review claim that the imports were "unused" was off: 7 of the 9 files reference `DiagramDiagnostic`, which `DiagramKitImport` re-exposes only via `public typealias DiagramDiagnostic = DiagramKitCommon.DiagramDiagnostic` (`Sources/DiagramKitImport/DiagramImportResult.swift#L8`). The actual type lives in `DiagramKitCommon`. Resolution:
- `MermaidExporter.swift`, `MermaidExport/MermaidGanttExport.swift`: already imported `DiagramKitCommon`, so `import DiagramKitImport` was dropped outright.
- The remaining 7 files swapped `import DiagramKitImport` → `import DiagramKitCommon` (the home of `DiagramDiagnostic` per `CLAUDE.md`).
- `Scripts/bootstrap-smoke-check.sh` now runs `swift package clean && swift build --target DiagramKitMermaid` as a discipline gate so an undeclared-module-dep regression on any format slice fails the merge gate loudly.

Verified: clean `swift build --target DiagramKitMermaid` succeeds; full `swift build` succeeds; `swift test --filter MermaidExport` runs 11 tests in 2 suites green.

---

## HIGH

### [Severity: High] ~~Recursive layouts/renderers have no depth caps; 8 MB stack is bounded~~ — RESOLVED (truncate + IssueReporting, not throw)
**Files:** `Sources/DiagramKitModel/src_treeview_layout.swift#L100-119`, `Sources/DiagramKitModel/src_ascii_tree_utils.swift#L26-59`, `Sources/DiagramKitModel/src_layout.swift#L323-341`
**Category:** Performance / Correctness
**Problem:** `processNode` (TreeView), `appendNode` (shared ASCII tree util used by mindmap/treeView/Ishikawa), and `_collectAllChildren` (ELK compound traversal) all recurse on Swift's call stack with no depth caps. The 8 MB worker-stack invariant is treated as adequate but never quantified. A pathological 50k-deep mindmap/treeview source crashes the process with SIGSEGV rather than throwing.
**Fix applied.** Added `Sources/DiagramKitCommon/RecursionGuard.swift` with `_recursionGuard(depth:limit:location:) -> Bool` and `_diagramDefaultRecursionLimit: Int = 1024`. Wired into all three recursion sites: `processNode` (treeview), `appendNode` (ascii tree util — also added explicit `depth: Int` parameter; existing `renderAsciiTree` callers unchanged), and `_collectAllChildren` (ELK; new optional `depth: Int = 0` parameter, default keeps existing callers working).

The fix deviates from the reviewer's specific suggestion ("throws `DiagramError.depthLimitExceeded`") in two ways:
1. **Truncate instead of throw.** Making three internal helpers throwing would force `throws` to ripple through every layout/render top-level (`layoutTreeViewDiagram`, `renderAsciiTree`, `_finalizePositionedGraph`, …) — a public-API break across multiple files. Truncation at the depth cap preserves a partial render, which is strictly better UX for the adversarial-input scenario than failing the whole document, and avoids the API ripple.
2. **`_reportDiagramIssue` instead of a typed error.** The truncation is surfaced via the existing `IssueReporting` channel — same path the codebase already uses for soft failures. In tests, the truncation appears as an `Issue` that can be captured with `withKnownIssue`; in production it surfaces wherever the IssueReporting reporter is configured. No new error case was added to `DiagramError`.

`Tests/DiagramKitTests/RecursionGuardTests.swift` pins the contract: returns `true` under the limit, returns `false` and reports at the limit, custom limits work, and a recursive walk that would normally run away (50-deep with a limit of 50) terminates at exactly the limit with one reported issue. The reviewer's "corpus entry pinning the typed error" was redirected into these direct unit tests because (a) corpus entries can't carry `withKnownIssue` capture, and (b) a 2 k-deep corpus source would inflate the JSON without adding signal beyond the unit tests.

Verified: full build green; mindmap, treeview, ishikawa unit suites green; corpus ASCII snapshots for those families green.

### [Severity: High] ~~Char-count width estimates corrupt layout for CJK / emoji / combining marks~~ — RESOLVED (Apple path; Linux follow-up tracked)
**Files:** `Sources/DiagramKitModel/src_c4_layout.swift#L527-538`, `Sources/DiagramKitModel/src_architecture_layout.swift#L272`, `Sources/DiagramKitModel/src_gitgraph_layout.swift#L64,L528`, `Sources/DiagramKitModel/src_treemap_layout.swift#L397-554`
**Category:** Correctness
**Problem:** Four layouts compute `Double(text.count) * fontSize * 0.6`. `String.count` is grapheme-cluster count. CJK ideographs (~1.0–1.1× em-width) clip, emoji (~2.0×) clip, and combining marks (0×) leak whitespace. `TextMetrics.shared.estimateTextWidth` exists and is used by `src_treeview_layout.swift` on Linux; these four bypass it.
**Fix applied.** Audit surfaced eight `Double(.count) * fontSize * 0.6` (and `0.65`) sites across five files, not the four originally flagged — added `src_pie_layout.swift#L216` and two more `src_treemap_layout.swift` sites (L492, L496) plus the second `src_architecture_layout.swift` site (L347). All eight now route through `TextMetrics.shared.estimateTextWidth(text, fontSize: fontSize, fontWeight: original_src_styles.FONT_WEIGHTS.<role>)`. Imports of `DiagramKitCommon` were added to the four layouts that didn't already pull it in.

The reviewer's `NARROW_CHARS`/`WIDE_CHARS` table extension is not needed: `Sources/DiagramKitCommon/src_text_metrics.swift` already has `isFullwidth(_ code: UInt32)` covering the full CJK / Hangul / Kana ranges plus `isCombiningMark` and an `EMOJI_REGEX`. CoreText handles all of this natively on Apple. The remaining gap is that `TextMetrics.estimateTextWidth`'s Linux branch is still the naive `count * fontSize * 0.55`; for CJK-aware Linux output it would need to route into `original_src_text_metrics.measureTextWidth`. Tracked as a smaller Medium follow-up — out of scope for this commit.

Snapshot drift was the expected geometric tightening of containers when CoreText replaced `count * 0.6`. 6 entries went outside the 0.99 image precision threshold and got rebaselined (image + SVG): `c4-context`, `c4-component`, `c4-container`, `c4-deployment`, `c4-dynamic`, `architecture-external-icons`. Adding gitgraph's branch-label site widened the scope to all 18 git corpus entries — likewise rebaselined image + SVG. Pie and treemap corpus entries stayed within precision tolerance and didn't need rebaselining. Added `c4-cjk-emoji` corpus entry (Japanese + emoji labels) as a regression pin; SVG output confirms CJK and emoji glyphs render with correct measured widths.

`venn-three-set` SVG snapshot is flaky (2 of 3 runs pass against the same baseline) — pre-existing, unrelated to this change, worth a separate Medium finding if it stays flaky.

### [Severity: High] Quadrant SVG renderer ignores its `font` parameter
**File:** `Sources/DiagramKitModel/src_quadrant_renderer.swift#L9,L119`
**Category:** Architecture
**Problem:** Verified — `renderQuadrantSvg` accepts `font: String`, but `_quadrantSvgOpenTag` builds `SVGDocumentBuilder(... fontFamily: "Inter", ...)` instead of forwarding `font`. Every other SVG family threads `font` through. Today both end up as `"Inter"`, but the moment `DiagramFontResolver.svgProportionalFamily` or `RenderTokens.defaultProportionalFontFamily` changes, quadrant diverges silently.
**Fix:** Thread `font` into `_quadrantSvgOpenTag` and pass it to `SVGDocumentBuilder`. Drop the `"Inter"` literal.

### [Severity: High] ~~Dual-renderer drift in sequence self-loop geometry~~ — RESOLVED
**Files:** `Sources/DiagramKitRenderingCG/DiagramRenderer+Sequence.swift#L179-L193` vs `Sources/DiagramKitModel/src_sequence_renderer.swift#L464-L469`
**Category:** Correctness (invariant #4 — dual-renderer symmetry)
**Problem:** Verified — CG hardcodes `loopW=28, loopH=20, labelGap=+4`; SVG hardcodes `loopW=30, loopH=20, labelGap=+8`. Same `PositionedSequenceMessage.x1/x2` input produces shapes that differ by 2 px in width and 4 px in label gap between CG and SVG output. Snapshot tests cannot catch this since they use independent baselines per format.
**Fix applied.** Could not use `RenderTokens+Sequence.swift` directly — that file is Apple-gated (`#if canImport(UIKit) || canImport(AppKit)`) and the SVG renderer is Linux-portable. Followed the existing `BlockRenderConstants` pattern instead: created `Sources/DiagramKitCommon/SequenceRenderConstants.swift` with plain-`Double` constants reachable from both targets. CG reads `CGFloat(SequenceRenderConstants.selfLoopWidth/Height/LabelGap)`; SVG reads the `Double` values directly. SVG values (`w=30, h=20, gap=+8`) were chosen as canonical — they give the label more breathing room and are already what the Linux-supported path produces.

Affected snapshots (CG/image only — SVG values unchanged): `seq-5-activations`, `seq-6-self-messages`, `seq-16-self-notes`. All three image baselines rebaselined in the same commit; SVG baselines were already on these values and pass unchanged.

### [Severity: High] ~~SVG renderers bypass `RenderTokens` font sizes — parallel sources of truth~~ — RESOLVED (drift hazard; override-gap remains)
**Files:** `Sources/DiagramKitModel/src_renderer.swift`, `src_sequence_renderer.swift`, `src_class_renderer.swift`, plus most other `src_*_renderer.swift`
**Category:** Architecture
**Problem:** Two parallel constant tables: `RenderTokens.fontSizeNodeLabel = 13` (Model) and `original_src_styles.FONT_SIZES = FontSizes(nodeLabel: 13, edgeLabel: 11, groupHeader: 12)` (Common). CG renderers read `RenderTokens` (responding to `RenderConfig` overrides); SVG renderers read `original_src_styles.FONT_SIZES` directly (ignoring overrides). Equal today, drift hazard the next time someone bumps a `RenderTokens` default. Same applies to `FONT_WEIGHTS`, `STROKE_WIDTHS`, `NODE_PADDING`, `GROUP_HEADER_CONTENT_PAD`, `ARROW_HEAD`.
**Fix applied — drift hazard.** The reviewer's first option ("make `original_src_styles.FONT_SIZES` derive from `RenderTokens.shared`") isn't directly feasible because `RenderTokens` is Apple-gated and `original_src_styles` is Linux-portable; the Linux side has to be the source. Inverted the derivation instead: every `RenderTokens` field whose value is also present in `original_src_styles` (font sizes, font weights, stroke widths, node padding, arrow-head dimensions, `groupHeaderContentPad`) now has its default sourced from the matching `original_src_styles.*` constant. Bumping any shared default requires editing exactly one number in `Sources/DiagramKitCommon/src_styles.swift`; CG (via `RenderConfig.tokens`) and SVG (directly off `original_src_styles`) pick it up together. Docstring on `RenderTokens` updated to document the contract. Values byte-identical to before — full non-corpus suite (1776 tests in 161 suites) green, sequence/class/ER/flow image and SVG corpus spot-checks green, full SVG corpus shows only the pre-existing 17 stale-baseline mismatches (no new drift).
**Follow-up — runtime override gap (Medium, separate concern).** SVG renderers reading `original_src_styles.FONT_SIZES.nodeLabel` directly still ignore mutations to `RenderConfig.tokens` at runtime; only CG output responds to overrides. The reviewer's second option (route SVG through `DiagramFontResolver` for sizing) closes that gap but is a larger refactor and was not in scope here. Worth tracking as its own item; until then, "configurable" effectively means "configurable for the CG path only" for these constants.

### [Severity: High] ~~Duplicated hex-to-color parsers across CG renderers~~ — RESOLVED
**Files:** `Sources/DiagramKitRenderingCG/DiagramRenderer+C4.swift#L208-219` (`_c4CGColor`), `+ER.swift#L216-227` (`_parseCGColor`), `+Mindmap.swift#L384-393` (`_cgColor(from:)`), `+Mindmap.swift#L406-417` (`_bmColor(from:)`)
**Category:** Code Quality / Correctness
**Problem:** Four private helpers implement the same 6-line "strip `#`, `Scanner.scanHexInt64`, shift-and-mask into RGB CGFloat / 255" routine. The canonical `DiagramColorParser.cgHex(_:)` / `.hexColor(_:)` in `Sources/DiagramKitModel/DiagramColorParser.swift` is already used by `+Timeline/+Journey/+TreeView`. C4/ER/Mindmap missed the migration and have drifted on edge cases — `_c4CGColor` handles `"none"`/empty for `allowClear`; Mindmap trims whitespace; ER returns optional; C4 forces a value.
**Fix applied.** Extended `DiagramColorParser` with `cgHex(_:allowClear:)` for the C4 boundary case (sentinel `"none"`/empty → `CGColor` with α=0). Deleted all four local helpers. C4 callsites inline `DiagramColorParser.cgHex(...) ?? BMColor.black.cgColor` (preserving the previous silent-fall-back-to-black behavior when the input was malformed) and `DiagramColorParser.hexColor(...) ?? theme.foreground` for the BMColor variant. ER's `_extractCGStyleValue` now routes directly through `DiagramColorParser.cgHex`; the `_parseCGColor` helper is gone. Mindmap retains two one-line wrappers `_mindmapCgColor` / `_mindmapBmColor` (8 callsites, so the wrappers avoid `?? BMColor.black.cgColor` noise — they're not duplicated logic, just thin adapters over the canonical parser).

Image snapshots drifted on 16 entries: 5 c4 + 8 mindmap + 1 c4-cjk-emoji + 1 er-22-styles + the c4-cjk corpus baseline added in the CJK fix. Cause is the canonical `BMColor → cgColor` path going through deviceRGB normalization where the old direct `CGColor(red:…)` used genericRGB — same RGB values, different colour space, pixel-level drift below visual perception. All 16 rebaselined; SVG snapshots are byte-identical (SVG path doesn't go through these CG helpers). The deviceRGB color space is now consistent with how every other renderer creates colors per the codebase's standing concurrency-contract note about `bmColorEquals`.

ER's `_parseCGColor` used to require exactly 6 hex chars; `DiagramColorParser.hexColor` accepts 3/6/8. ER's CSS style values are uniformly 6-char in the corpus, so no behavior change observed, but malformed-3-char inputs (`"#fff"`) will now succeed where they used to fail silently — strictly better behavior.

### [Severity: High] ~~Duplicated block-style string parsing between CG and SVG renderers~~ — RESOLVED
**Files:** `Sources/DiagramKitRenderingCG/DiagramRenderer+Block.swift#L122-150` vs `Sources/DiagramKitModel/src_block_renderer.swift#L428-448`
**Category:** Code Quality (dual-renderer drift)
**Problem:** Both strip `"fill:"/"stroke:"/"color:"` prefixes with identical `replacingOccurrences(of: "...", with: "").trimmingCharacters(...)` chains. CG path inlines `BMColor(hex: "#e8f0fe")` as a default while the SVG path uses different defaults. Any new style key must be added in two places.
**Fix applied.** Added `Sources/DiagramKitCommon/BlockStyleDecoder.swift` with `fillHex(from:)`, `strokeHex(from:)`, and `textColorHex(labelStyle:styles:)` — pure string-extraction, returns `nil` when no matching style is present so each renderer keeps its own default. CG side (`_cgBlockFill` / `_cgBlockStroke` / `_cgBlockTextColor`) now reads `BlockStyleDecoder.<helper>(...) ?? <its-CG-default>`; SVG side (`resolveBlockFill` / `resolveBlockStroke` / `resolveBlockTextColor`) collapses to `BlockStyleDecoder.<helper>(...) ?? defaultColor`. The `textColorHex` decoder keeps the `fill:`-in-`labelStyle` wins over `color:` precedence both renderers had inlined.

This is the last of the dual-renderer-drift items from the original review. Verified: block corpus snapshots (image + SVG, all 12 entries) pass unchanged — pure-refactor with byte-identical output. CG's idiosyncratic `BMColor(hex: "#e8f0fe")` fill default stays in CG; SVG's theme-derived defaults stay in SVG.

### [Severity: High] ~~Gantt parser silently swallows date-parse errors with no diagnostic plumbing~~ — RESOLVED
**File:** `Sources/DiagramKitModel/src_gantt_parser.swift#L728-748`
**Category:** Diagnostics
**Problem:** `_compileTasks` swallows `getStartDate` errors at L736-738 (`catch { startTime = nil }`) and `_getEndDate` errors at L748 (`try?`). Public entry `parseGanttDiagram` at L31 returns `(GanttDiagram, [DiagramDiagnostic])` and hardcodes `[]` for the diagnostics slot at L32. Unreported data loss on the parse path — exactly what diagnostic discipline forbids.
**Fix applied.** Threaded `diagnostics: inout [DiagramDiagnostic]` through `_parseGanttDiagramEntry` and `_compileTasks`. The previously-hardcoded `[]` diagnostics slot on `parseGanttDiagram` now carries the accumulated diagnostics. Both date-parse catches in `_compileTasks` emit `.lossyTransform(.configDrop, message: "Gantt task '\(id)' start-date parse failed (\(input)): \(error)")` (and the matching end-date variant) before nil-ing out the field.

Investigation surfaced that `_getEndDate` is permissive — it falls back to `prevTime` on inputs it can't parse as a date / `until` reference / duration — so the end-date catch is unreachable on canonical sources today. Kept the catch as defensive plumbing for any future refactor that adds a throwing validation path; documented the unreachable status in the test file's comment block.

Three new tests pin the contract: malformed start date emits a `.configDrop` diagnostic naming the task id and the offending input; well-formed source produces zero diagnostics; the unreachable end-date case is documented (no asserting test). The full `GanttParserTests` suite (66 tests) passes.

### [Severity: High] ~~SPI underscore types crossing module boundary without public typealias~~ — RESOLVED
**File:** `Sources/DiagramKitRenderingCG/DiagramRenderer+Flow.swift#L167,L202,L216,L300`
**Category:** Architecture
**Problem:** RenderingCG references `_PositionedGroupPayload` and `_PositionedNodePayload` (defined in `Sources/DiagramKitModel/PositionedPayloads.swift#L13-53`) directly. CLAUDE.md: "Use public typealiases such as `PositionedNode` outside the defining module." The typealiases (`PositionedGroup`, `PositionedNode`, `PositionedEdge`, `PositionedPoint`) exist at `Sources/DiagramKitModel/Types.swift#L232-238`. Every other cross-module callsite uses the alias; only this file violates.
**Fix applied.** Replaced `_PositionedGroupPayload` → `PositionedGroup` (3 sites) and `_PositionedNodePayload` → `PositionedNode` (1 site) in the four function signatures. Build clean; flowchart corpus image snapshots (sample of 4) pass unchanged. Verified by grep — no `_Positioned*Payload` references remain in any non-defining module (`DiagramKitRenderingCG`, `DiagramKitViews`, `DiagramKitInteractive`, `DiagramKitImport`, `DiagramKitExport`, `DiagramKitMermaid`, `DiagramKit`).

### [Severity: High] ~~Public API missing docstrings — canonical surface is undocumented~~ — RESOLVED
**Files:** `Sources/DiagramKit/DiagramImageRenderer.swift#L16-230` (~14 public decls), `Sources/DiagramKit/DiagramPipeline.swift#L108-262` (7 of 9 public methods undocumented: `parse` x3, `layout` x2, `prepare`, `renderASCII`), `Sources/DiagramKit/DiagramEngine.swift#L243-290` (the 4 canonical `String` helpers `parseDiagram`/`renderDiagramImage`/`renderDiagramSVG`/`renderDiagramASCII`), `Sources/DiagramKit/DiagramDescriptor.swift#L235-245` (`DiagramStructuralError`)
**Category:** Code Quality
**Problem:** CLAUDE.md lists exactly these as the canonical public surface. `DiagramImageRenderer` has zero `///` comments — including stored vars (`theme`, `layoutConfig`, `scale`, `sourceFormat`), every `renderImage` overload, `renderPNG`, `renderJPEG`, and the static `render(_:)`. The README's quick-start examples lean on these.
**Fix applied.** Added one-line `///` summaries to every flagged public symbol:
- `DiagramImageRenderer`: class header + 4 stored properties + `init` + `prepare` + 3 `renderImage` overloads + `renderSVG` + `renderPNG` + `renderJPEG` (UIKit + AppKit branches) + 2 static `render` overloads.
- `DiagramPipeline`: 3 `parse` overloads + 2 `layout` overloads + `prepare` + `renderASCII`. (The two `renderSVG` variants already had docstrings.)
- `DiagramEngine` `String` extension: `parseDiagram`, `renderDiagramImage`, `renderDiagramSVG`, `renderDiagramASCII`.
- `DiagramStructuralError`: struct header + `expectedType` property + `payloadMismatch` factory.

Each comment leads with the WHY (when to use, what input shape, what's returned) rather than restating the name. Build clean.

---

## MEDIUM

### [Severity: Medium] ~~`MainActor.assumeIsolated` in `NotificationCenter` observer can crash off-main~~ — RESOLVED
**File:** `Sources/DiagramKitInteractive/DiagramEditor.swift#L185-210`
**Category:** Concurrency
**Problem:** `_registerUndoObservers()` uses `NotificationCenter.default.addObserver(...queue: nil) { ... MainActor.assumeIsolated { ... } }`. `queue: nil` delivers synchronously on the posting thread. `UndoManager` itself is documented as thread-safe but not typed `@MainActor`; any notification posted off-main trips `assumeIsolated`'s precondition.
**Fix applied.** Picked neither of the reviewer's two specific options outright — both have a real downside. `OperationQueue.main` makes delivery async on every post, breaking the test-determinism property the existing comment block (L193-198) relies on (the synchronous tickle has to fire before `await perform(_:)` returns or `@Observable` subscribers race). `Task { @MainActor in ... }` likewise loses synchronous delivery on the typical (on-main) post path. Used a conditional split instead: `if Thread.isMainThread { MainActor.assumeIsolated { ... } } else { Task { @MainActor in ... } }`. The fast path preserves the documented synchronous tickle the comment guards; the slow path schedules safely on MainActor so the off-main precondition trap is impossible. Rewrote the comment to reflect the new policy. Full editor suite (63 tests across 7 suites — including `DiagramEditorUndoObservationTests` which exercises the tickle) passes.

### [Severity: Medium] ~~Subgraph-layout ELK fallback silently rebuilds as flat graph~~ — RESOLVED
**File:** `Sources/DiagramKitModel/src_layout.swift#L1233-1247` and `#L1461-1475`
**Category:** Error Handling
**Problem:** Two ELK call sites `catch` and silently rebuild a flat graph (second site comment: `// Fallback: fully flat layout`). User receives geometrically different output (subgraph nesting collapsed) with no diagnostic. `PositionedGraph.diagnostics` is the channel for exactly this case.
**Fix applied.** Added `diagnostics.warn("ELK nested layout failed; falling back to flat layout (subgraph nesting collapsed): \(error.localizedDescription)")` at the start of each catch block — before the fallback `_buildFlatElkGraph` call runs. `_LayoutDiagnostics.warn(_:)` already routes to `.lossyTransform(.subgraphFlatten, ...)`, the typed category that exactly matches the lossy transform happening here. The diagnostic flows through the existing `positioned.diagnostics = diagnostics.items` line that both fallback paths already had, surfacing on `PositionedGraph.diagnostics` for downstream consumers (and through `PreparedDiagram.diagnostics` for the umbrella facade).

No pinning test added: the fallback path only fires when the ELK adapter throws, which requires a graph shape it can't handle, and no corpus entry exercises that case today (otherwise they'd already be producing silently-flattened output). Documenting the contract through the typed diagnostic was the actionable part; constructing a synthetic ELK-failing graph is out of scope. Spot-check on flowchart snapshots (4 entries including the subgraph-heavy `flow-16-subgraphs` and `flow-21-cicd-pipeline`) passes unchanged — pure diagnostic-channel addition, no geometric drift.

### [Severity: Medium] ~~XY chart ASCII renderer encodes parse errors as user-visible output text~~ — RESOLVED
**File:** `Sources/DiagramKitModel/src_ascii_xychart.swift#L70-74`
**Category:** Error Handling
**Problem:** Returns `"XY Chart parse error: \(error.localizedDescription)"` as the rendered ASCII string on failure. Bypasses the canonical `AsciiRenderOutput { text, diagnostics }` shape — no diagnostic, no exception, just an error sentinel in the output that consumers cannot distinguish from real output.
**Fix applied.** Made `renderXYChartAscii` throw — removed the inline `do/catch` that swallowed `parseXYChart` failures into the rendered string. Updated the registry caller (`AsciiRenderRegistry.xyChart`) to `try renderXYChartAscii(...)`, matching the existing pattern for `.er` and `.pie`. Failures now propagate through `DiagramPipeline.renderASCII`, which already routes them through `_withDiagramIssueReporting` so the IssueReporting reporter sees them.

New `XYChartAsciiRendererTests` (2 tests) pin the contract: a basic vertical bar chart renders with no `"XY Chart parse error"` substring; malformed source throws (captured with `withKnownIssue` since the reporter records an Issue before re-throwing). XYChart corpus ASCII spot-check (3 entries) byte-identical — only the previously-buggy path changes behavior.

### [Severity: Medium] ~~`FlowchartSubgraphMutation.slugify` drops characters with no diagnostic~~ — RESOLVED
**File:** `Sources/DiagramKitInteractive/FlowchartSubgraphMutation.swift#L80-95`
**Category:** Diagnostics
**Problem:** `slugify` is used to derive a subgraph id from a user-provided `title`. Characters that aren't letters/numbers/space/`_`/`-` are dropped silently. The discipline calls this id-sanitization (`.lossyTransform(.idSanitization, ...)`). The id is surfaced back to the user (collision check, error).
**Fix applied.** Restructured the slug pipeline to carry diagnostics through the mutation result:
- `slugify(_:)` returns `(slug: String, diagnostics: [DiagramDiagnostic])`. Tracks whether any non-alphanumeric/non-`_-` characters were dropped and whether the slug emptied out (forcing the `"subgraph"` fallback). When either condition fires, emits `.lossyTransform(.idSanitization, message: "Subgraph title '<input>' sanitized to id slug '<slug>'")`. A pure lowercase + whitespace→underscore mapping is round-trip recoverable and does *not* emit a diagnostic.
- `DiagramEditor.subgraphID(title:members:)` now returns `(id: String, diagnostics: [DiagramDiagnostic])` and forwards the slug diagnostics.
- `_groupIntoSubgraph(...)` returns `(DiagramDocument, [DiagramDiagnostic])`.
- `_applyFlowchart(_:to:)` returns `(DiagramDocument, [DiagramDiagnostic])` — other flowchart mutations (`insertNode`, `insertEdge`, `setEdgeStyle`) return `(doc, [])`. The commit site concatenates mutation-tier and export-tier diagnostics: `_commitDiagnostics(mutationDiagnostics + exportResult.diagnostics)`. Users see the sanitization on `editor.lastExportDiagnostics`.

Four new tests pin the contract: clean titles emit no diagnostic; titles with dropped characters emit `.idSanitization` naming both input and slug; the empty-slug fallback (`"!!!"` → `"subgraph"`) emits a diagnostic; the full `groupIntoSubgraph` path surfaces the diagnostic onto `editor.lastExportDiagnostics`. The existing `subgraphIDDeterministic` test updated for the new tuple return. All 9 `FlowchartSubgraphMutationTests` pass.

### [Severity: Medium] ~~Sequence block tab height open-coded in SVG~~ — RESOLVED
**File:** `Sources/DiagramKitModel/src_sequence_renderer.swift#L493` vs `Sources/DiagramKitRenderingCG/DiagramRenderer+Sequence.swift#L82` + `RenderTokens+Sequence.swift#L14`
**Category:** Code Quality (dual-renderer drift)
**Problem:** SVG hardcodes `tabHeight = 18.0`; CG reads `cfg.sequenceTabHeight` (= 18). Equal today; same drift hazard as the self-loop above.
**Fix applied.** Added `SequenceRenderConstants.blockTabHeight: Double = 18` to the Linux-portable enum I introduced when fixing the self-loop geometry (High #4). SVG now reads `SequenceRenderConstants.blockTabHeight` directly. `RenderTokens+Sequence.swift` updated so `sequenceTabHeight` and `sequenceLoopH` both derive from `SequenceRenderConstants` (`CGFloat(SequenceRenderConstants.blockTabHeight)` / `selfLoopHeight`) — that closes the loop on the Apple-side too, so the value is sourced in one place no matter which renderer you read it from.

Pure refactor: 5 block-using sequence corpus entries (`seq-7-loop`, `seq-8-alt`, `seq-9-opt`, `seq-10-par`, `seq-11-critical`, `seq-21-box-groups`) pass byte-identical image + SVG. This was the last residual dual-renderer drift item from the review.

### [Severity: Medium] ~~Class-title font weight literal in SVG~~ — RESOLVED
**File:** `Sources/DiagramKitModel/src_class_renderer.swift#L213`
**Category:** Code Quality
**Problem:** SVG class title uses literal `font-weight="700"`; CG uses `.bold` via the resolver. There's no `FONT_WEIGHTS.classTitle` token; the rest of the file uses `original_src_styles.FONT_WEIGHTS.nodeLabel` (500). The `700` is the only weight in the file that bypasses the token table.
**Fix applied.** Extended `original_src_styles.FontWeights` with `classTitle: Int = 700` (defaulted on the initializer so the existing call sites for `FONT_WEIGHTS` keep compiling). SVG class renderer now interpolates `original_src_styles.FONT_WEIGHTS.classTitle` instead of the `"700"` literal. CG class renderer (`DiagramRenderer+Class.swift`) replaced `weight: .bold` with `weight: original_src_styles.FONT_WEIGHTS.classTitle` on the `proportionalFont(size:weight:)` int overload — same effective weight (700), just sourced from one place.

Skipped adding a separate `RenderTokens.classTitleFontWeight` field per the reviewer's hint — the token would just forward `FONT_WEIGHTS.classTitle`, and the CG path can reach the constant directly through `DiagramKitCommon` without going through `RenderTokens`. Less indirection for the same outcome.

Pure refactor: 4 class corpus entries (`class-1-basic`, `class-2-visibility`, `class-3-interface`, `class-16-full-hierarchy`) pass byte-identical image + SVG.

### [Severity: Medium] ~~Hardcoded fallback hex literals in CG renderers~~ — RESOLVED (high-impact clusters; single-literal sites kept inline)
**Files:** `+C4.swift#L35-173` (`#1168BD`, `#3C7FC0`, `#FFFFFF`, `#444444` x4); `+Block.swift#L125` (`#e8f0fe`); `+Journey.swift#L156` and `src_journey_renderer.swift#L183,L287` (`#8FBC8F` — duplicated CG↔SVG); `+XYChart.swift#L39,L274` (`#3b82f6`); `+Sankey.swift#L88` and `+Radar.swift#L20` (`#27272A`); `+Pie.swift#L30` (`#ECECFF`); `+Packet.swift#L29` (`#efefef`); `+Kanban.swift#L38` (`#a1a1aa`)
**Category:** Code Quality
**Problem:** Fallback colors inlined as raw hex in renderer bodies. Domain-specific (C4 brand colors) and cross-renderer fallbacks (`#27272A`) should live on `DiagramTheme` or per-family constants.
**Fix applied — high-impact clusters.**
- **C4** (4 constants, 8 callsites — biggest cluster): new `Sources/DiagramKitCommon/C4RenderConstants.swift` enum with `defaultShapeFill`, `defaultShapeBorder`, `defaultShapeTextColor`, `defaultBoundaryAndRelColor`. `DiagramRenderer+C4.swift` routes all eight previous hex literals through it.
- **Journey** (1 constant, but duplicated CG↔SVG — the cross-renderer drift hazard the reviewer specifically flagged): new `Sources/DiagramKitCommon/JourneyRenderConstants.swift` with `defaultActorColor`. CG `+Journey.swift` and SVG `src_journey_renderer.swift` both route through it — three callsites collapsed onto one constant.

**Skipped — single-literal-per-family sites.** `+Block.swift`'s `#e8f0fe`, `+XYChart.swift`'s `#3b82f6`, `+Sankey.swift`/`+Radar.swift`'s `#27272A`, `+Pie.swift`'s `#ECECFF`, `+Packet.swift`'s `#efefef`, `+Kanban.swift`'s `#a1a1aa` each appear at exactly one inline `?? "#hex"` fallback site and are not duplicated across renderers. The reviewer's per-family-constants pattern adds three lines of declaration + import for each one to save zero duplication. Inline fallbacks at a single site stay legible and don't pose a drift hazard.

**`DiagramTheme` extension also skipped.** `#27272A` is used in Sankey + Radar as a "if `theme.foreground.hexString` returned nil for some reason, fall through to this near-black" defensive fallback. Hoisting it onto `DiagramTheme` as a class-level static would conflate theme data with fallback constants. Two inline literals at two distinct files is acceptable.

C4 + Journey corpus snapshot spot-check (5 C4 entries + 2 Journey entries) byte-identical image + SVG.

### [Severity: Medium] ~~EventModeling font fallback chain hardcodes family names and duplicates resolver logic~~ — RESOLVED
**File:** `Sources/DiagramKitRenderingCG/DiagramRenderer+EventModeling.swift#L271-291`
**Category:** Code Quality (invariant #7 — font routing)
**Problem:** `_emFont` / `_emBoldFont` re-implement `BMFont(name: "TrebuchetMS", ...) ?? BMFont(name: "Trebuchet MS", ...) ?? BMFont.systemFont(...)` — the only `"Trebuchet*"` strings in `DiagramKitRenderingCG` and the only file that duplicates the fallback ladder that already lives in `DiagramFontResolver.proportionalFont(size:weight:)`.
**Fix applied.**
- Added `eventModelingFontFamily: String? = "Trebuchet MS"` to `RenderTokens` — the EventModeling-specific font-family token that previously lived as `"TrebuchetMS"` / `"Trebuchet MS"` string literals inside the renderer.
- Added `DiagramFontResolver.eventModelingFont(size:weight:)` that walks the three-step fallback ladder (`defaultProportionalFontFamily` → `eventModelingFontFamily` → system) for both regular and bold weights. Preserves the legacy fallback candidates by trying both with-space (`"Trebuchet MS"`) and without-space (`"TrebuchetMS"`) forms plus the `"-BoldMS"` PostScript suffix variant that the renderer used to attempt.
- Reduced `DiagramRenderer+EventModeling.swift` `_emFont` / `_emBoldFont` to one-line delegates to `fontResolver.eventModelingFont(size:weight:)`. Bold variant uses `FONT_WEIGHTS.classTitle` (700) — same value the original `boldSystemFont` fallback resolved to.

Skipped going further and inlining `fontResolver.eventModelingFont(...)` at the 12 call sites in `+EventModeling.swift` — keeping `_emFont` / `_emBoldFont` as one-line indirections preserves all the existing call sites and keeps the local "we use Trebuchet here" intent visible in the renderer's own file.

Pure refactor: 4 EventModeling corpus entries (`eventmodeling-simple-state-change`, `eventmodeling-multi-relation`, `eventmodeling-all-entity-types`, `eventmodeling-state-view`) byte-identical image + SVG.

### [Severity: Medium] ~~Mermaid State same-format round-trip cell missing from the matrix~~ — RESOLVED
**File:** `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift#L19-122`
**Category:** Test Coverage
**Problem (original).** Mermaid cells existed for flowchart, sequence, class, ER, c4, gantt. PlantUML had `plantumlState`, but there was no `mermaidState`. Adding the cell as the reviewer originally specified would have produced empty output and immediately failed: `.stateDiagram` was commented out of `MermaidExporter.supportedDiagramTypes` (line 23) and the `switch document.payload` default arm returned an empty source with a `.diagramFamilyUnsupported` diagnostic. There was no state emission to round-trip against.
**Fix applied.** Implemented the missing `MermaidStateExport` slice and wired the round-trip cell.
- **New file `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidStateExport.swift`** (320 lines). Mirrors the per-family-emit pattern of `MermaidFlowchartExport`/`MermaidSequenceExport`/etc. Emits `stateDiagram-v2` header, simple/labeled transitions, `[*]` start/end sentinels (detected by `.stateStart`/`.stateEnd` *shape* not id suffix — same convention `PlantUMLStateExport` uses to avoid corrupting user-authored ids like `customer_start`), `state "Name" as id` aliasing, `state foo <<choice>>`/`<<fork>>`/`<<join>>` pseudo-states, and `note left/right of <target> : <text>` (notes are reconstructed from the `.stateNote` shape + the dotted edges the parser emits in `_addStateNote`). Composite states (`state Foo { ... }`) are emitted recursively, matching `PlantUMLStateExport.emitSubgraph`. Concurrency dividers (`--`), `classDef`/`class`/`style`/`click`, and `accTitle`/`accDescr` are deferred from v1 — they surface via `.subgraphFlatten` / `.styleDrop` / `.accessibilityDrop` diagnostics on `DiagramExportResult` so the discipline gate still holds.
- **`MermaidExporter.swift`**: added `.stateDiagram` to `supportedDiagramTypes` and a `case .stateDiagram(let model): result = try MermaidStateExport.emit(model)` arm to the dispatch switch.
- **`Tests/DiagramKitTests/Export/MermaidStateExportTests.swift`** (9 tests): empty diagram → header-only output; `[*]` pseudostate round-trip via shape; `state "Name" as id` alias round-trip; labeled transitions; `<<choice>>` pseudo-state; `note left of` round-trip; `nodeStyles` → `.styleDrop` diagnostic; `accTitle` → `.accessibilityDrop` diagnostic.
- **Round-trip cell**: `RoundTripCellRegistry.mermaidState` with `allowedLosses: [.idSanitization]`, plus a parameterized `mermaidState` test in `SameFormatRoundTripTests.swift` pointed at `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-state/{01-basic,02-aliased,03-notes}.md`. All 3 fixtures round-trip clean.

Verified: 9 `MermaidStateExportTests` pass; 3 `mermaidState` round-trip cells pass; full 16-cell `SameFormatRoundTripTests` passes (no neighbor disturbance); `MermaidExporterTests` (10) unchanged; `Scripts/check-diagnostic-discipline.sh` clean; `Scripts/check-file-sizes.sh` — new file at 320 lines (under 500-line warning threshold).

The closed `MermaidExporter`'s state arm now matches the other supported families and the round-trip matrix is symmetric for state across `mermaid ↔ mermaid` and `plantuml ↔ plantuml`. Cross-format state round-trip (`mermaid ↔ plantuml`) remains a future addition once both sides cover composites equivalently.

### [Severity: Medium] Several families have far fewer dedicated test files than peers
**Path:** `Tests/DiagramKitTests/`
**Category:** Test Coverage
**Problem:** State: 2 (Review/VisualDiff only); ER: 2; EventModeling: 1 (54 `@Test`s in a 603-line file); Architecture: 3. Compare to Class: 11, TreeView/Timeline/XYChart/Treemap/Mindmap/GitGraph/C4: 6+ each. State and ER carry diagnostic emission and frontmatter binding — the thinness is a real gap.
**Fix:** Add `StateParserTests`, `StateLayoutTests`, `StateSvgTests`, `StateAsciiRendererTests`, `ERLayoutTests`, `ERSvgTests`. Split `EventModelingTests` into `Parser/Layout/Renderer/Svg` files.

### [Severity: Medium] ~~Stale SVG baselines: 16 requirement-family entries pin a collapsed theme palette~~ — RESOLVED
**Files:** `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-_.req-1-basic.txt` plus `req-2` through `req-17` (16 total)
**Category:** Test Coverage
**Problem:** Surfaced while verifying the sequence self-loop fix. All 16 `req-*` SVG baselines have a single-line drift in the `<svg style=...>` CSS variables — baseline pins `--line:#27272A;--muted:#27272A;--surface:#FFFFFF;--border:#27272A` (every theme variable collapsed to one near-black hex), while current renderer output produces `--line:#939394;--muted:#A9A9AA;--surface:#F9F9F9;--border:#D4D4D4` (the intended softer palette). Identical drift signature across all 16 entries, so single root cause: baselines were recorded before a theme-defaults change landed and were never refreshed. Body of every SVG (geometry, text, markers) is unchanged.
**Fix applied.** Rebaselined all 16 `req-*` SVG snapshots via `SNAPSHOT_TESTING_RECORD=all`. All now pin the current (correct) palette.

### [Severity: Medium] ~~Stale SVG baseline: `er-23-neo-look` pins old `er-onlyOne*` marker IDs~~ — RESOLVED
**File:** `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-_.er-23-neo-look.txt`
**Category:** Test Coverage
**Problem:** Same provenance as the `req-*` drift above. Baseline has `<marker id="er-onlyOneStart" ...>`; current output emits `<marker id="er-onlyOne_neoStart" ...>`. The marker IDs were renamed (presumably to disambiguate the neo-look variants) but the one ER neo-look baseline wasn't rebaselined. Distinct root cause from the requirement drift, hence a separate entry.
**Fix applied.** Rebaselined `er-23-neo-look` SVG snapshot. Verified via full `CorpusSnapshotTests/svgSnapshot` run — zero remaining mismatches across the whole SVG corpus. The `_neoStart` marker rename was already consistent across the rest of the corpus; no lurking under-tolerance mismatches found.

### [Severity: Medium] ~~Frontmatter parser silently drops escaped quotes and tab indentation~~ — RESOLVED (3 of 5 cases; 2 deferred)
**File:** `Sources/DiagramKitModel/FrontmatterDocumentParser.swift#L19-63`
**Category:** Correctness
**Problem:** `flatten(_:)` computes indent via `prefix(while: { $0 == " " }).count` — tabs collapse to depth 0. Quote stripping (`key.hasPrefix("\"") && key.hasSuffix("\"")`) doesn't handle escaped inner quotes. No mid-line `#` comment stripping. Malformed YAML (e.g. `key: "unterminated`) is accepted without a diagnostic. Test fixtures contain none of these cases.
**Fix applied.**
- **Tab indent.** Indent counting now walks `\t` as 2 columns and `" "` as 1 column, matching the 2-space-per-level convention. Tab-only and mixed-tab/space indent now nest correctly. Comment block in the function documents the contract.
- **Escaped quotes.** Inside double-quoted values, `\"` → `"` and `\\` → `\`. Single-quoted values stay literal per YAML's single-quote semantics.
- **Mid-line `#` comments.** Added `_stripTrailingComment(_:)` that drops ` # …` from unquoted scalars (requires whitespace before `#` so `color: #abc123` hex literals survive). `#` inside quoted values is preserved.

**Deferred from the reviewer's list** with rationale:
- *Unterminated quote diagnostic*: the parser is a pure `(lines) -> [(path, value)]` function with no diagnostic channel. Threading one through would touch every binding callsite. Out of scope for the cleanup cadence.
- *`null` / `~` scalars*: these are about `FrontmatterValue.raw` semantics (treating the string `"null"` as `nil`), not the parser's tokenization. Separate change, separate type.

New `FrontmatterDocumentParserTests` (8 tests) pin all three fixes: tab-indent equivalence with space-indent; mixed indent; escaped `\"` and `\\` unescape in double quotes; single-quote literal semantics; trailing comment stripped; hex literal preserved (no whitespace before `#`); `#` inside a quoted value preserved. Existing frontmatter-using corpus entries (`class-60-frontmatter-title`, `class-61-frontmatter-config`, `xychart-18-config-size`, `xychart-19-data-labels`) pass byte-identical image + SVG.

---

## LOW

### [Severity: Low] `DiagramEngine.renderSVG`/`renderASCII` parameter list uses Apple-only `DiagramTheme` — DEFERRED (needs Docker access to choose between stub or gate)
**Files:** `Sources/DiagramKit/DiagramEngine.swift#L151-190` references `DiagramTheme = .default` (lines 153, 177); `Sources/DiagramKitModel/Theme.swift#L2,L301` wraps the entire file in `#if canImport(UIKit) || canImport(AppKit) ... #endif`
**Category:** Portability
**Problem:** Verified — `DiagramTheme` is the only declaration in the codebase and is entirely Apple-gated. The `DiagramEngine.renderSVG`/`renderASCII` overloads that reference it cannot exist on Linux as written, yet CLAUDE.md states these entry points are Linux-available. Either the umbrella `DiagramKit` target is not actually buildable on Linux (and docs need updating), or a Linux stub for `DiagramTheme` is missing.
**Investigation.** Audited the gating in `DiagramEngine.swift` and `DiagramPipeline.swift`: `prepare`, `render(in:context:)`, and the two `renderImage` overloads ARE inside `#if canImport(CoreGraphics)` blocks (Engine L88-148 + Pipeline L168-196). `renderSVG` (Engine L151, Pipeline L189, L228) and `renderASCII` (Engine L175, Pipeline L262) are NOT gated, yet they take `theme: DiagramTheme = .default` parameters. The `Dockerfile.linux-check` matrix builds the umbrella target with `swift build --target DiagramKit … || echo "RESULT: $tgt FAIL"` — failure is recorded but doesn't block the run, so the umbrella likely already fails on Linux without anyone noticing.

**Status: deferred.** The reviewer offered two paths: (a) Linux-side `DiagramTheme` stub, or (b) guard the affected overloads on Apple platforms. Picking between them needs the actual Linux build outcome verified in Docker first, plus a design pass on which API surface the stub has to expose (`renderSVG` reads `.background.cssColorString` / `.effectiveLine()` / etc.; `renderASCII` reads `.hexString`-shaped values; both call chains need the stub to be type-compatible with `BMColor` everywhere they touch shared types). That's stub-design + container verification, not the small-scope cleanup the rest of the Low tier has been. Tracked here rather than rushed.

### [Severity: Low] ~~`_RecoverableDiagramError` marker protocol can hide structural errors centrally~~ — RESOLVED
**File:** `Sources/DiagramKitCommon/IssueReportingSupport.swift#L32-37`
**Category:** Error Handling
**Problem:** `_reportDiagramIssueIfNeeded` skips `reportIssue(...)` for any `_RecoverableDiagramError` and `CancellationError`. The protocol is empty (`public protocol _RecoverableDiagramError: Error {}`), so adopting it is a one-line opt-out from telemetry. No audit trail.
**Fix applied.** Picked the documentation option (the explicit-switch alternative would have required a closed set, which doesn't fit a protocol that third-party importers / parsers also adopt). Added a docstring to `_RecoverableDiagramError` enumerating every adopter found in the tree at the time of writing: `DiagramError`, `DiagramEditorError`, `DiagramExportError`, the 5 importer error types (Mermaid/D2/Graphviz/Structurizr/PlantUML), and the 8 parser error types. Notes that new adopters should be added to the list when they land. Grep-based audit (`grep -rn ": _RecoverableDiagramError"`) was used to enumerate; the protocol stays cheap to adopt but every adoption is now visible in one place.

### [Severity: Low] ~~`try!` for regex in `+TreeView` renderer~~ — RESOLVED
**File:** `Sources/DiagramKitRenderingCG/DiagramRenderer+TreeView.swift#L273-275`
**Category:** Error Handling
**Problem:** `_tokenizeSVGPath` uses `try! NSRegularExpression(pattern: pattern)` for a compile-time constant. Safe today, but a future edit to the regex string is a footgun. Other parsers consistently use `guard let regex = try? ... else { return [] }`.
**Fix applied.** Swapped to `guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }`. Returns an empty token array on the impossible-today bad-pattern path, matching the prevailing convention.

### [Severity: Low] ~~Requirement-parser regex cache has a benign TOCTOU race with no documented contract~~ — RESOLVED (folded into Low #5)
**File:** `Sources/DiagramKitModel/src_requirement_parser.swift#L125-140`
**Category:** Concurrency
**Problem:** `_reqCachedRegex` locks for read, unlocks, compiles outside the lock, then re-locks for write. Two threads can compile the same pattern twice (correctness preserved since `NSRegularExpression` is stateless once compiled). Missing the "Concurrency Contract" banner that every other locked cache carries (e.g., gantt cache at L410-422).
**Fix applied.** Folded into the Low #5 migration below — the TOCTOU race goes away entirely when the cache moves to `NSCache + DispatchQueue.sync` (atomic get-or-insert).

### [Severity: Low] ~~`_reqCompiledRegex` cache has no eviction~~ — RESOLVED
**File:** `Sources/DiagramKitModel/src_requirement_parser.swift#L127-140`
**Category:** Performance
**Problem:** Plain `[String: NSRegularExpression]` keyed on user-controllable strings, grows unbounded under varied inputs. `_dateFormatterCache` in `src_gantt_parser.swift#L422-440` already uses `NSCache` for the same problem; this is the only outlier.
**Fix applied.** Replaced the `NSLock` + `[String: NSRegularExpression]` pair with `NSCache<NSString, NSRegularExpression>` + a private serial `DispatchQueue` — mirroring the `_dateFormatterCache` shape in the Gantt parser exactly. The `DispatchQueue.sync` block makes the get-or-insert atomic (closes the TOCTOU race from Low #4), and `NSCache` caps its own size so user-controllable input patterns can't grow the cache unbounded. Concurrency Contract banner documents the design. All 30 `RequirementParserTests` pass.

### [Severity: Low] ~~`DiagramLayer.preparedDiagram` clear-on-failure relies on `Task.isCancelled` alone~~ — RESOLVED
**File:** `Sources/DiagramKitViews/DiagramLayer.swift#L169-228`
**Category:** Correctness
**Problem:** Inside `prepareDiagram()`, parse failure clears state. Ordering between three rapid `source` writes is guarded solely by `Task.isCancelled` at L208. Today MainActor isolation makes the race practically unreachable; a future split that lifts publication off MainActor would break it silently.
**Fix applied.** Added `private var preparationGeneration: UInt64 = 0` on `DiagramLayer`, bumped (`&+=`) at the top of `prepareDiagram()`, captured into a local `myGeneration` before kicking off the task. The publication guard now reads `guard !Task.isCancelled, let self, self.preparationGeneration == myGeneration else { return }` — a task whose generation has already been superseded drops its result on the floor instead of publishing stale state. Docstring on the new property documents the contract explicitly so a future move of publication off MainActor can't silently regress it.

Full `DiagramLayer`-touching test suite (6 tests across `DiagramViewReviewRegressionTests` + `DiagramViewBoundsLookupBindingTests`, including the `cancelledPreparationDoesNotFireCallback` test that exercises rapid-double-call cancellation) passes.

### [Severity: Low] ~~`DiagramFontResolver.svgProportionalFamily` documented intent vs callsites~~ — RESOLVED
**File:** `Sources/DiagramKitModel/DiagramFontResolver.swift` (the comment-documented `"Inter"` hardcode)
**Category:** Code Quality
**Problem:** The resolver intentionally pins SVG font-family to `"Inter"` (with rationale that SVG `font-family` is a hint while measurement comes from `RenderTokens.defaultProportionalFontFamily`). But several `src_*_renderer.swift` files still have their own `_ font: String = "Inter"` default parameter. If SVG font policy ever changes, callers all need updates.
**Fix applied.** Picked the third option (the reviewer offered two: drop the default, or runtime-assert): the literal `"Inter"` default expression on every SVG renderer entry point now reads `DiagramFontResolver.shared.svgFontFamily`. Same effective default today (still `"Inter"`); the moment the resolver's value changes, every renderer's default tracks automatically. Public API stays compatible — callers that omit the parameter still work — and no runtime check needs to be threaded.

Replaced across 12 files: `src_class_renderer`, `src_er_renderer`, `src_quadrant_renderer`, `src_xychart_renderer`, `src_pie_renderer`, `src_renderer`, `src_radar_svg`, `src_timeline_renderer`, `src_journey_renderer`, `src_sequence_renderer`, `src_sankey_renderer`, `src_requirement_svg`. SVG corpus spot-check (flow / class / sequence / ER / pie, one entry each) passes byte-identical.

---

## Notes for the maintainers

- **CLAUDE.md drift.** The doc says parser dispatch is via a cascading `firstLine.hasPrefix(...)` chain in `Sources/DiagramKit/Parser.swift`. Actual dispatch is data-driven via `DiagramRegistry.detect` / `DiagramHeader.detect` (`Sources/DiagramKit/DiagramDescriptor.swift#L142-188`); the regex anchoring for `stateDiagram-v2` lives in `src_parser.swift#L194`. Invariant #3 is satisfied, but the description in CLAUDE.md no longer matches the implementation. Worth updating.
- **Clean assertions about what's solid.** Worker-thread invariant, font-registration call-site coverage, type-safe payload usage (zero `Any` casts), `bmColorEquals` usage, retain cycles in views/editor, cross-format round-trip matrix, empty-source handling, registry thread-safety, `@unchecked Sendable` discipline, and the diagnostic-discipline gate all check out clean.
- **Suggested ordering.** Fix the Critical build break first (one-line removal × 9 files). Then tackle the two dual-renderer drift items (sequence self-loop, SVG `RenderTokens` bypass) before they accumulate more drift in PRs. The CJK width and depth-cap findings are user-visible bugs worth addressing before claiming production readiness on internationalized or adversarial inputs.

# DiagramKit Code Review — Consolidated Findings

**Method.** Six parallel agents reviewed: (1) architecture/layering/portability, (2) concurrency, (3) invariants + dual-renderer symmetry, (4) diagnostics + error handling, (5) code quality, (6) correctness/perf/test coverage. Critical and high-impact findings were spot-verified against the working tree. The diagnostic-discipline and `@unchecked Sendable` gates pass clean; the worker-thread invariant, `@MainActor` placement, `bmColorEquals`, type-safe payloads, retain cycles, cross-format round-trip matrix, and empty-source handling all checked out with no findings.

**Summary.** 1 Critical (verified build break) — **resolved**, 10 High (3 resolved), 13 Medium (+2 added during follow-up), 7 Low.

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

### [Severity: High] Recursive layouts/renderers have no depth caps; 8 MB stack is bounded
**Files:** `Sources/DiagramKitModel/src_treeview_layout.swift#L100-119`, `Sources/DiagramKitModel/src_ascii_tree_utils.swift#L26-59`, `Sources/DiagramKitModel/src_layout.swift#L323-341`
**Category:** Performance / Correctness
**Problem:** `processNode` (TreeView), `appendNode` (shared ASCII tree util used by mindmap/treeView/Ishikawa), and `_collectAllChildren` (ELK compound traversal) all recurse on Swift's call stack with no depth caps. The 8 MB worker-stack invariant is treated as adequate but never quantified. A pathological 50k-deep mindmap/treeview source crashes the process with SIGSEGV rather than throwing.
**Fix:** Add a `_recursionGuard(depth: Int, limit: 1024)` helper in `DiagramKitCommon` that throws `DiagramError.depthLimitExceeded`. Wire it through the three recursion sites and add a corpus entry pinning the typed error.

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

### [Severity: High] Duplicated hex-to-color parsers across CG renderers
**Files:** `Sources/DiagramKitRenderingCG/DiagramRenderer+C4.swift#L208-219` (`_c4CGColor`), `+ER.swift#L216-227` (`_parseCGColor`), `+Mindmap.swift#L384-393` (`_cgColor(from:)`), `+Mindmap.swift#L406-417` (`_bmColor(from:)`)
**Category:** Code Quality / Correctness
**Problem:** Four private helpers implement the same 6-line "strip `#`, `Scanner.scanHexInt64`, shift-and-mask into RGB CGFloat / 255" routine. The canonical `DiagramColorParser.cgHex(_:)` / `.hexColor(_:)` in `Sources/DiagramKitModel/DiagramColorParser.swift` is already used by `+Timeline/+Journey/+TreeView`. C4/ER/Mindmap missed the migration and have drifted on edge cases — `_c4CGColor` handles `"none"`/empty for `allowClear`; Mindmap trims whitespace; ER returns optional; C4 forces a value.
**Fix:** Delete the four helpers; route through `DiagramColorParser`. If `allowClear` is needed, extend with `cgHex(_:allowClear:)`.

### [Severity: High] Duplicated block-style string parsing between CG and SVG renderers
**Files:** `Sources/DiagramKitRenderingCG/DiagramRenderer+Block.swift#L122-150` vs `Sources/DiagramKitModel/src_block_renderer.swift#L428-448`
**Category:** Code Quality (dual-renderer drift)
**Problem:** Both strip `"fill:"/"stroke:"/"color:"` prefixes with identical `replacingOccurrences(of: "...", with: "").trimmingCharacters(...)` chains. CG path inlines `BMColor(hex: "#e8f0fe")` as a default while the SVG path uses different defaults. Any new style key must be added in two places.
**Fix:** Add a shared `BlockStyleDecoder` (or extend `BlockRenderConstants`) in `DiagramKitCommon`/`Model` with `fillHex/strokeHex/colorHex(from:)`. Both renderers call into it; defaults live next to the parser.

### [Severity: High] Gantt parser silently swallows date-parse errors with no diagnostic plumbing
**File:** `Sources/DiagramKitModel/src_gantt_parser.swift#L728-748`
**Category:** Diagnostics
**Problem:** `_compileTasks` swallows `getStartDate` errors at L736-738 (`catch { startTime = nil }`) and `_getEndDate` errors at L748 (`try?`). Public entry `parseGanttDiagram` at L31 returns `(GanttDiagram, [DiagramDiagnostic])` and hardcodes `[]` for the diagnostics slot at L32. Unreported data loss on the parse path — exactly what diagnostic discipline forbids.
**Fix:** Thread a diagnostics sink into `_compileTasks` and emit `.lossyTransform(.configDrop, message: "Gantt task '\(id)' date parse failed: \(error)")`. Return through the existing tuple slot. If the path is provably unreachable on canonical sources, add a `SILENT-DROP` marker with a real test reference instead.

### [Severity: High] SPI underscore types crossing module boundary without public typealias
**File:** `Sources/DiagramKitRenderingCG/DiagramRenderer+Flow.swift#L167,L202,L216,L300`
**Category:** Architecture
**Problem:** RenderingCG references `_PositionedGroupPayload` and `_PositionedNodePayload` (defined in `Sources/DiagramKitModel/PositionedPayloads.swift#L13-53`) directly. CLAUDE.md: "Use public typealiases such as `PositionedNode` outside the defining module." The typealiases (`PositionedGroup`, `PositionedNode`, `PositionedEdge`, `PositionedPoint`) exist at `Sources/DiagramKitModel/Types.swift#L232-238`. Every other cross-module callsite uses the alias; only this file violates.
**Fix:** Replace `_PositionedGroupPayload` → `PositionedGroup`, `_PositionedNodePayload` → `PositionedNode` in the four signatures.

### [Severity: High] Public API missing docstrings — canonical surface is undocumented
**Files:** `Sources/DiagramKit/DiagramImageRenderer.swift#L16-230` (~14 public decls), `Sources/DiagramKit/DiagramPipeline.swift#L108-262` (7 of 9 public methods undocumented: `parse` x3, `layout` x2, `prepare`, `renderASCII`), `Sources/DiagramKit/DiagramEngine.swift#L243-290` (the 4 canonical `String` helpers `parseDiagram`/`renderDiagramImage`/`renderDiagramSVG`/`renderDiagramASCII`), `Sources/DiagramKit/DiagramDescriptor.swift#L235-245` (`DiagramStructuralError`)
**Category:** Code Quality
**Problem:** CLAUDE.md lists exactly these as the canonical public surface. `DiagramImageRenderer` has zero `///` comments — including stored vars (`theme`, `layoutConfig`, `scale`, `sourceFormat`), every `renderImage` overload, `renderPNG`, `renderJPEG`, and the static `render(_:)`. The README's quick-start examples lean on these.
**Fix:** Add one-line `///` summaries to each public symbol. The file headers on `DiagramEngine`/`DiagramPipeline` give a template.

---

## MEDIUM

### [Severity: Medium] `MainActor.assumeIsolated` in `NotificationCenter` observer can crash off-main
**File:** `Sources/DiagramKitInteractive/DiagramEditor.swift#L185-210`
**Category:** Concurrency
**Problem:** `_registerUndoObservers()` uses `NotificationCenter.default.addObserver(...queue: nil) { ... MainActor.assumeIsolated { ... } }`. `queue: nil` delivers synchronously on the posting thread. `UndoManager` itself is documented as thread-safe but not typed `@MainActor`; any notification posted off-main trips `assumeIsolated`'s precondition.
**Fix:** Use `OperationQueue.main` as the observer's `queue:`, or wrap the body in `Task { @MainActor in ... }`. The hop cost is negligible — body is a counter increment.

### [Severity: Medium] Subgraph-layout ELK fallback silently rebuilds as flat graph
**File:** `Sources/DiagramKitModel/src_layout.swift#L1233-1247` and `#L1461-1475`
**Category:** Error Handling
**Problem:** Two ELK call sites `catch` and silently rebuild a flat graph (second site comment: `// Fallback: fully flat layout`). User receives geometrically different output (subgraph nesting collapsed) with no diagnostic. `PositionedGraph.diagnostics` is the channel for exactly this case.
**Fix:** Append `.lossyTransform(.subgraphFlatten, message: "ELK nested layout failed; falling back to flat: \(error)")` before the fallback runs.

### [Severity: Medium] XY chart ASCII renderer encodes parse errors as user-visible output text
**File:** `Sources/DiagramKitModel/src_ascii_xychart.swift#L70-74`
**Category:** Error Handling
**Problem:** Returns `"XY Chart parse error: \(error.localizedDescription)"` as the rendered ASCII string on failure. Bypasses the canonical `AsciiRenderOutput { text, diagnostics }` shape — no diagnostic, no exception, just an error sentinel in the output that consumers cannot distinguish from real output.
**Fix:** Throw and let `DiagramEngine.renderASCII` aggregate the diagnostic, or thread a diagnostics-out parameter and emit `.lossyTransform(.configDrop, ...)`.

### [Severity: Medium] `FlowchartSubgraphMutation.slugify` drops characters with no diagnostic
**File:** `Sources/DiagramKitInteractive/FlowchartSubgraphMutation.swift#L80-95`
**Category:** Diagnostics
**Problem:** `slugify` is used to derive a subgraph id from a user-provided `title`. Characters that aren't letters/numbers/space/`_`/`-` are dropped silently. The discipline calls this id-sanitization (`.lossyTransform(.idSanitization, ...)`). The id is surfaced back to the user (collision check, error).
**Fix:** When `slugify(title)` differs from `title.lowercased()` modulo whitespace, emit `.lossyTransform(.idSanitization, message: "Subgraph title '\(title)' sanitized to id '\(slug)'")` onto the mutation result.

### [Severity: Medium] Sequence block tab height open-coded in SVG
**File:** `Sources/DiagramKitModel/src_sequence_renderer.swift#L493` vs `Sources/DiagramKitRenderingCG/DiagramRenderer+Sequence.swift#L82` + `RenderTokens+Sequence.swift#L14`
**Category:** Code Quality (dual-renderer drift)
**Problem:** SVG hardcodes `tabHeight = 18.0`; CG reads `cfg.sequenceTabHeight` (= 18). Equal today; same drift hazard as the self-loop above.
**Fix:** Promote `sequenceTabHeight` to an SVG-visible token namespace and reference from both renderers.

### [Severity: Medium] Class-title font weight literal in SVG
**File:** `Sources/DiagramKitModel/src_class_renderer.swift#L213`
**Category:** Code Quality
**Problem:** SVG class title uses literal `font-weight="700"`; CG uses `.bold` via the resolver. There's no `FONT_WEIGHTS.classTitle` token; the rest of the file uses `original_src_styles.FONT_WEIGHTS.nodeLabel` (500). The `700` is the only weight in the file that bypasses the token table.
**Fix:** Add `FONT_WEIGHTS.classTitle` and `RenderTokens.classTitleFontWeight`; reference from both renderers.

### [Severity: Medium] Hardcoded fallback hex literals in CG renderers
**Files:** `+C4.swift#L35-173` (`#1168BD`, `#3C7FC0`, `#FFFFFF`, `#444444` x4); `+Block.swift#L125` (`#e8f0fe`); `+Journey.swift#L156` and `src_journey_renderer.swift#L183,L287` (`#8FBC8F` — duplicated CG↔SVG); `+XYChart.swift#L39,L274` (`#3b82f6`); `+Sankey.swift#L88` and `+Radar.swift#L20` (`#27272A`); `+Pie.swift#L30` (`#ECECFF`); `+Packet.swift#L29` (`#efefef`); `+Kanban.swift#L38` (`#a1a1aa`)
**Category:** Code Quality
**Problem:** Fallback colors inlined as raw hex in renderer bodies. Domain-specific (C4 brand colors) and cross-renderer fallbacks (`#27272A`) should live on `DiagramTheme` or per-family constants.
**Fix:** Promote per-family constants into `<Family>Constants` siblings; expose cross-renderer fallbacks on `DiagramTheme`.

### [Severity: Medium] EventModeling font fallback chain hardcodes family names and duplicates resolver logic
**File:** `Sources/DiagramKitRenderingCG/DiagramRenderer+EventModeling.swift#L271-291`
**Category:** Code Quality (invariant #7 — font routing)
**Problem:** `_emFont` / `_emBoldFont` re-implement `BMFont(name: "TrebuchetMS", ...) ?? BMFont(name: "Trebuchet MS", ...) ?? BMFont.systemFont(...)` — the only `"Trebuchet*"` strings in `DiagramKitRenderingCG` and the only file that duplicates the fallback ladder that already lives in `DiagramFontResolver.proportionalFont(size:weight:)`.
**Fix:** Add an `eventModelingFont(size:weight:)` helper to `DiagramFontResolver` driven from `RenderTokens.eventModelingFontFamily`. Delete the local helpers.

### [Severity: Medium] Mermaid State same-format round-trip cell missing from the matrix
**File:** `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift#L19-122`
**Category:** Test Coverage
**Problem:** Mermaid cells exist for flowchart, sequence, class, ER, c4, gantt. PlantUML has `plantumlState`, but there is no `mermaidState`. State is a first-class supported family with its own diagnostic discipline; without a same-format round-trip, regressions in `MermaidExporter`'s state emission stay silent until snapshot drift catches them.
**Fix:** Add `mermaidState = RoundTripCell(importer: MermaidImporter(), exporter: MermaidExporter(), family: .stateDiagram, allowedLosses: [.idSanitization])` and wire into `SameFormatRoundTripTests`.

### [Severity: Medium] Several families have far fewer dedicated test files than peers
**Path:** `Tests/DiagramKitTests/`
**Category:** Test Coverage
**Problem:** State: 2 (Review/VisualDiff only); ER: 2; EventModeling: 1 (54 `@Test`s in a 603-line file); Architecture: 3. Compare to Class: 11, TreeView/Timeline/XYChart/Treemap/Mindmap/GitGraph/C4: 6+ each. State and ER carry diagnostic emission and frontmatter binding — the thinness is a real gap.
**Fix:** Add `StateParserTests`, `StateLayoutTests`, `StateSvgTests`, `StateAsciiRendererTests`, `ERLayoutTests`, `ERSvgTests`. Split `EventModelingTests` into `Parser/Layout/Renderer/Svg` files.

### [Severity: Medium] Stale SVG baselines: 16 requirement-family entries pin a collapsed theme palette
**Files:** `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-_.req-1-basic.txt` plus `req-2` through `req-17` (16 total)
**Category:** Test Coverage
**Problem:** Surfaced while verifying the sequence self-loop fix. All 16 `req-*` SVG baselines have a single-line drift in the `<svg style=...>` CSS variables — baseline pins `--line:#27272A;--muted:#27272A;--surface:#FFFFFF;--border:#27272A` (every theme variable collapsed to one near-black hex), while current renderer output produces `--line:#939394;--muted:#A9A9AA;--surface:#F9F9F9;--border:#D4D4D4` (the intended softer palette). Identical drift signature across all 16 entries, so single root cause: baselines were recorded before a theme-defaults change landed and were never refreshed. Body of every SVG (geometry, text, markers) is unchanged.
**Fix:** `SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=req-1-basic,req-2-all-requirement-types,req-3-all-risk-levels,req-4-all-verify-methods,req-5-empty-bodies,req-6-all-relationships,req-7-reverse-relationships,req-8-directions,req-9-accessibility,req-10-styles,req-11-classDef-and-class,req-12-shorthand-classes,req-13-full-sysml,req-15-neo-look,req-16-neo-theme,req-17-markdown-labels swift test --filter "CorpusSnapshotTests/svgSnapshot"`. Then commit. Also worth git-blaming the offending theme change to add a note about rebaselining the corpus when palette defaults shift.

### [Severity: Medium] Stale SVG baseline: `er-23-neo-look` pins old `er-onlyOne*` marker IDs
**File:** `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-_.er-23-neo-look.txt`
**Category:** Test Coverage
**Problem:** Same provenance as the `req-*` drift above. Baseline has `<marker id="er-onlyOneStart" ...>`; current output emits `<marker id="er-onlyOne_neoStart" ...>`. The marker IDs were renamed (presumably to disambiguate the neo-look variants) but the one ER neo-look baseline wasn't rebaselined. Distinct root cause from the requirement drift, hence a separate entry.
**Fix:** `SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=er-23-neo-look swift test --filter "CorpusSnapshotTests/svgSnapshot"`. While there, verify the rename's full callsite coverage in ER's `_arrowMarkerDefs`-equivalent so other neo-look ER entries don't have lurking marker mismatches that the precision threshold is hiding.

### [Severity: Medium] Frontmatter parser silently drops escaped quotes and tab indentation
**File:** `Sources/DiagramKitModel/FrontmatterDocumentParser.swift#L19-63`
**Category:** Correctness
**Problem:** `flatten(_:)` computes indent via `prefix(while: { $0 == " " }).count` — tabs collapse to depth 0. Quote stripping (`key.hasPrefix("\"") && key.hasSuffix("\"")`) doesn't handle escaped inner quotes. No mid-line `#` comment stripping. Malformed YAML (e.g. `key: "unterminated`) is accepted without a diagnostic. Test fixtures contain none of these cases.
**Fix:** Either reject tab indent with a diagnostic or normalize to 2 spaces. Strip escapes inside quoted values. Add a `FrontmatterDocumentParserTests` suite covering tab indent, escaped quote, mid-line `#`, unterminated quote, and `null`/`~` scalars.

---

## LOW

### [Severity: Low] `DiagramEngine.renderSVG`/`renderASCII` parameter list uses Apple-only `DiagramTheme`
**Files:** `Sources/DiagramKit/DiagramEngine.swift#L151-190` references `DiagramTheme = .default` (lines 153, 177); `Sources/DiagramKitModel/Theme.swift#L2,L301` wraps the entire file in `#if canImport(UIKit) || canImport(AppKit) ... #endif`
**Category:** Portability
**Problem:** Verified — `DiagramTheme` is the only declaration in the codebase and is entirely Apple-gated. The `DiagramEngine.renderSVG`/`renderASCII` overloads that reference it cannot exist on Linux as written, yet CLAUDE.md states these entry points are Linux-available. Either the umbrella `DiagramKit` target is not actually buildable on Linux (and docs need updating), or a Linux stub for `DiagramTheme` is missing.
**Fix:** Add a Linux-side `DiagramTheme` stub (hex-only, no `BMColor`, `Sendable` not `@unchecked`), or guard the affected overloads on Apple platforms. Either way, run `Scripts/linux-check.sh` end-to-end to confirm what the current state actually is.

### [Severity: Low] `_RecoverableDiagramError` marker protocol can hide structural errors centrally
**File:** `Sources/DiagramKitCommon/IssueReportingSupport.swift#L32-37`
**Category:** Error Handling
**Problem:** `_reportDiagramIssueIfNeeded` skips `reportIssue(...)` for any `_RecoverableDiagramError` and `CancellationError`. The protocol is empty (`public protocol _RecoverableDiagramError: Error {}`), so adopting it is a one-line opt-out from telemetry. No audit trail.
**Fix:** Either replace with an explicit `switch` over known adoption cases, or document adopters and rationale in the protocol's doc comment.

### [Severity: Low] `try!` for regex in `+TreeView` renderer
**File:** `Sources/DiagramKitRenderingCG/DiagramRenderer+TreeView.swift#L273-275`
**Category:** Error Handling
**Problem:** `_tokenizeSVGPath` uses `try! NSRegularExpression(pattern: pattern)` for a compile-time constant. Safe today, but a future edit to the regex string is a footgun. Other parsers consistently use `guard let regex = try? ... else { return [] }`.
**Fix:** Switch to the `try?` + guard pattern for consistency.

### [Severity: Low] Requirement-parser regex cache has a benign TOCTOU race with no documented contract
**File:** `Sources/DiagramKitModel/src_requirement_parser.swift#L125-140`
**Category:** Concurrency
**Problem:** `_reqCachedRegex` locks for read, unlocks, compiles outside the lock, then re-locks for write. Two threads can compile the same pattern twice (correctness preserved since `NSRegularExpression` is stateless once compiled). Missing the "Concurrency Contract" banner that every other locked cache carries (e.g., gantt cache at L410-422).
**Fix:** Add a Concurrency Contract banner documenting the lock-release-compile-relock pattern as intentional.

### [Severity: Low] `_reqCompiledRegex` cache has no eviction
**File:** `Sources/DiagramKitModel/src_requirement_parser.swift#L127-140`
**Category:** Performance
**Problem:** Plain `[String: NSRegularExpression]` keyed on user-controllable strings, grows unbounded under varied inputs. `_dateFormatterCache` in `src_gantt_parser.swift#L422-440` already uses `NSCache` for the same problem; this is the only outlier.
**Fix:** Convert to `NSCache<NSString, NSRegularExpression>` for parity.

### [Severity: Low] `DiagramLayer.preparedDiagram` clear-on-failure relies on `Task.isCancelled` alone
**File:** `Sources/DiagramKitViews/DiagramLayer.swift#L169-228`
**Category:** Correctness
**Problem:** Inside `prepareDiagram()`, parse failure clears state. Ordering between three rapid `source` writes is guarded solely by `Task.isCancelled` at L208. Today MainActor isolation makes the race practically unreachable; a future split that lifts publication off MainActor would break it silently.
**Fix:** Tag each task with a monotonic generation ID; ignore publication when the live generation has advanced. Document the invariant on the file header.

### [Severity: Low] `DiagramFontResolver.svgProportionalFamily` documented intent vs callsites
**File:** `Sources/DiagramKitModel/DiagramFontResolver.swift` (the comment-documented `"Inter"` hardcode)
**Category:** Code Quality
**Problem:** The resolver intentionally pins SVG font-family to `"Inter"` (with rationale that SVG `font-family` is a hint while measurement comes from `RenderTokens.defaultProportionalFontFamily`). But several `src_*_renderer.swift` files still have their own `_ font: String = "Inter"` default parameter. If SVG font policy ever changes, callers all need updates.
**Fix:** Either drop the default parameter on the SVG renderer entrypoints (force callers to thread through `fontResolver.svgFontFamily`), or assert at runtime that the passed `font` equals the resolver's value.

---

## Notes for the maintainers

- **CLAUDE.md drift.** The doc says parser dispatch is via a cascading `firstLine.hasPrefix(...)` chain in `Sources/DiagramKit/Parser.swift`. Actual dispatch is data-driven via `DiagramRegistry.detect` / `DiagramHeader.detect` (`Sources/DiagramKit/DiagramDescriptor.swift#L142-188`); the regex anchoring for `stateDiagram-v2` lives in `src_parser.swift#L194`. Invariant #3 is satisfied, but the description in CLAUDE.md no longer matches the implementation. Worth updating.
- **Clean assertions about what's solid.** Worker-thread invariant, font-registration call-site coverage, type-safe payload usage (zero `Any` casts), `bmColorEquals` usage, retain cycles in views/editor, cross-format round-trip matrix, empty-source handling, registry thread-safety, `@unchecked Sendable` discipline, and the diagnostic-discipline gate all check out clean.
- **Suggested ordering.** Fix the Critical build break first (one-line removal × 9 files). Then tackle the two dual-renderer drift items (sequence self-loop, SVG `RenderTokens` bypass) before they accumulate more drift in PRs. The CJK width and depth-cap findings are user-visible bugs worth addressing before claiming production readiness on internationalized or adversarial inputs.

# DiagramKit Code Review — Consolidated Findings

**Method.** Six parallel agents reviewed: (1) architecture/layering/portability, (2) concurrency, (3) invariants + dual-renderer symmetry, (4) diagnostics + error handling, (5) code quality, (6) correctness/perf/test coverage. Critical and high-impact findings were spot-verified against the working tree. The diagnostic-discipline and `@unchecked Sendable` gates pass clean; the worker-thread invariant, `@MainActor` placement, `bmColorEquals`, type-safe payloads, retain cycles, cross-format round-trip matrix, and empty-source handling all checked out with no findings.

**Summary.** 1 Critical (verified build break) — **resolved**, 10 High, 11 Medium, 7 Low.

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

### [Severity: High] Char-count width estimates corrupt layout for CJK / emoji / combining marks
**Files:** `Sources/DiagramKitModel/src_c4_layout.swift#L527-538`, `Sources/DiagramKitModel/src_architecture_layout.swift#L272`, `Sources/DiagramKitModel/src_gitgraph_layout.swift#L64,L528`, `Sources/DiagramKitModel/src_treemap_layout.swift#L397-554`
**Category:** Correctness
**Problem:** Four layouts compute `Double(text.count) * fontSize * 0.6`. `String.count` is grapheme-cluster count. CJK ideographs (~1.0–1.1× em-width) clip, emoji (~2.0×) clip, and combining marks (0×) leak whitespace. `TextMetrics.shared.estimateTextWidth` exists and is used by `src_treeview_layout.swift` on Linux; these four bypass it.
**Fix:** Route through `TextMetrics.shared.estimateTextWidth(...)`. Extend the `NARROW_CHARS`/`WIDE_CHARS` tables in `src_text_metrics.swift` for CJK ranges. Add a per-family corpus entry with non-Latin labels.

### [Severity: High] Quadrant SVG renderer ignores its `font` parameter
**File:** `Sources/DiagramKitModel/src_quadrant_renderer.swift#L9,L119`
**Category:** Architecture
**Problem:** Verified — `renderQuadrantSvg` accepts `font: String`, but `_quadrantSvgOpenTag` builds `SVGDocumentBuilder(... fontFamily: "Inter", ...)` instead of forwarding `font`. Every other SVG family threads `font` through. Today both end up as `"Inter"`, but the moment `DiagramFontResolver.svgProportionalFamily` or `RenderTokens.defaultProportionalFontFamily` changes, quadrant diverges silently.
**Fix:** Thread `font` into `_quadrantSvgOpenTag` and pass it to `SVGDocumentBuilder`. Drop the `"Inter"` literal.

### [Severity: High] Dual-renderer drift in sequence self-loop geometry
**Files:** `Sources/DiagramKitRenderingCG/DiagramRenderer+Sequence.swift#L179-L193` vs `Sources/DiagramKitModel/src_sequence_renderer.swift#L464-L469`
**Category:** Correctness (invariant #4 — dual-renderer symmetry)
**Problem:** Verified — CG hardcodes `loopW=28, loopH=20, labelGap=+4`; SVG hardcodes `loopW=30, loopH=20, labelGap=+8`. Same `PositionedSequenceMessage.x1/x2` input produces shapes that differ by 2 px in width and 4 px in label gap between CG and SVG output. Snapshot tests cannot catch this since they use independent baselines per format.
**Fix:** Lift to shared tokens (e.g., `RenderTokens+Sequence.sequenceSelfLoopWidth/Height/LabelGap`). Pick one canonical value, rebaseline both formats in the same commit.

### [Severity: High] SVG renderers bypass `RenderTokens` font sizes — parallel sources of truth
**Files:** `Sources/DiagramKitModel/src_renderer.swift`, `src_sequence_renderer.swift`, `src_class_renderer.swift`, plus most other `src_*_renderer.swift`
**Category:** Architecture
**Problem:** Two parallel constant tables: `RenderTokens.fontSizeNodeLabel = 13` (Model) and `original_src_styles.FONT_SIZES = FontSizes(nodeLabel: 13, edgeLabel: 11, groupHeader: 12)` (Common). CG renderers read `RenderTokens` (responding to `RenderConfig` overrides); SVG renderers read `original_src_styles.FONT_SIZES` directly (ignoring overrides). Equal today, drift hazard the next time someone bumps a `RenderTokens` default. Same applies to `FONT_WEIGHTS`, `STROKE_WIDTHS`, `NODE_PADDING`, `GROUP_HEADER_CONTENT_PAD`, `ARROW_HEAD`.
**Fix:** Make `original_src_styles.FONT_SIZES` derive from `RenderTokens.shared` via computed properties, or route SVG renderers through `DiagramFontResolver` for sizing the way CG does.

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

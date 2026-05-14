# SVG Palette Audit + Baseline Regeneration — Design

**Status:** Design approved 2026-05-14. Ready for implementation plan.
**Drives:** REVIEW.md Deferred Effort #1 ("SVG color-mix variable resolver (renderer-deep)").
**Antecedent:** `1c2f18f` landed the paren-counting `var()`/`color-mix()` resolver in Session 2 but explicitly deferred baseline regeneration.

## Goal

Close out the SVG color-mix rebaseline by doing two things, in this order:

1. **Audit.** Prove the post-`1c2f18f` renderer emits the palette `Theme.effective<Token>()` says it should. Ship the proof as two new permanent XCTest suites that do not depend on `__Snapshots__/` baselines.
2. **Rebaseline.** Regenerate the 435 SVG and 435 image baselines so `CorpusSnapshotTests` is green against the corrected renderer output, in two reviewable commits. (The 422 corpus entries produce 435 snapshots per family because multi-format entries are recorded once per format.)

## Non-Goals

- ASCII baselines (174 files). They carry no color and are not drift-correlated to the resolver fix.
- Theme redesign. `Theme.effective<Token>()` math (`Theme.swift:140-144`) is treated as canonical; this work verifies the renderer matches it, not the other way around.
- Multi-platform recording. Existing snapshot precision (`precision: 0.99, perceptualPrecision: 0.98`) tolerates cross-arch rasterizer drift. One macOS recording session is sufficient.
- Refactoring `Sources/DiagramKitModel/SVGHelpers.swift` further. The resolver is treated as final.
- New themes or color tokens.

## Source of Truth

`DiagramTheme.effectiveLine() / effectiveMuted() / effectiveAccent() / effectiveSurface() / effectiveBorder()` define what hex SHOULD appear in rendered SVG for each token. For `zinc-light` (fg=#27272A, bg=#FFFFFF) this produces `#939394` (line, 50% mix), `#A9A9AA` (muted, 40% mix), and so on — the same values the OLD baselines record before resolver corruption stripped them into malformed `))` strings.

A rendered SVG is "correct" iff every color-token attribute equals the hex its `_hex(theme.effective<Token>())` returns, and the SVG contains no malformed leftovers (`var(--…)`, `))` tails, `NaN`, unhex-suffixed `#`, empty stroke/fill).

## Phase Plan

Five phases, each a single PR-sized commit. Phase 2 may be a no-op.

| # | Subject | Files touched | Gate before commit |
|---|---|---|---|
| C1 | `test(svg): pin palette math + structural sweep` | +`Tests/DiagramKitTests/PalettePinTests.swift`, +`Tests/DiagramKitTests/SVGStructuralSweepTests.swift` | both green via `swift test --filter` |
| C2 *(conditional)* | `fix(svg): <specific palette regression>` | renderer source, no baselines | C1 suites green |
| C3 | `chore(scripts): rebaseline-snapshots.sh` | +`Scripts/rebaseline-snapshots.sh`, +CLAUDE.md Commands entry | script `--dry-run` clean; no behavior change |
| C4 | `test(snapshots): rebaseline SVG after color-mix resolver fix` | 435 `__Snapshots__/svgSnapshot-*.txt` | `CorpusSnapshotTests/svgSnapshot` green; `SVGStructuralSweepTests` green in both live-render and on-disk modes |
| C5 | `test(snapshots): rebaseline image after color-mix resolver fix` | 435 `__Snapshots__/imageSnapshot-*.png` | `CorpusSnapshotTests/imageSnapshot` green |

C2's existence is determined by C1's outcome:
- C1 passes on `main` → renderer is already correct; C2 skipped. Proceed to C3.
- C1 fails on `main` → audit succeeded at its real job. Diagnose to one cell of the (theme × token) matrix. Candidate fix sites: `_hex()` color-space round-trip (`SVGHelpers.swift:13-35`), `_flattenKnownSvgTokens` replacement order (`SVGHelpers.swift:37-69`), `_resolveSvgCssVariables` walker (post-`1c2f18f`), `BMColor.mixed`. Ship as one commit per failing cell; do not batch unrelated regressions.

## Test Architecture

Two new XCTest files under `Tests/DiagramKitTests/`. Both Apple-only — the SVG render path itself is gated `#if canImport(UIKit) || canImport(AppKit)` in `SVGHelpers.swift:1`.

### A. `PalettePinTests.swift` (~80 lines)

Per built-in theme × per token, render a hard-coded canary diagram and assert the rendered SVG carries the exact hex returned by `_hex(theme.effective<Token>())`. The canary source is `"flowchart TD\nA-->B"` and is inlined in the test so it cannot drift.

```swift
final class PalettePinTests: XCTestCase {
    func testPalettePinAcrossThemes() throws {
        for theme in _builtInThemesUnderTest() {  // ~14 themes
            let svg = try _renderCanarySVG(theme: theme)
            try _assertHex(svg, equals: _hex(theme.effectiveLine())!,    attribute: .stroke, role: .edgeLine)
            try _assertHex(svg, equals: _hex(theme.effectiveMuted())!,   attribute: .fill,   role: .edgeLabel)
            try _assertHex(svg, equals: _hex(theme.effectiveAccent())!,  attribute: .fill,   role: .arrowHead)
            try _assertHex(svg, equals: _hex(theme.effectiveSurface())!, attribute: .fill,   role: .nodeBody)
            try _assertHex(svg, equals: _hex(theme.effectiveBorder())!,  attribute: .stroke, role: .nodeOutline)
            try _assertNoForeignHex(svg, forRole: .edgeLine,    notIn: [otherEffectiveHexes(theme, except: .line)])
            // …same negative check for each role; prevents collapsed-to-fg passing a permissive substring match
        }
    }
}
```

- Helper `_renderCanarySVG(theme:)` invokes the same public theme-injection path corpus snapshots use (`renderDiagramSVG(_:theme:)` or the `DiagramEngine.renderSVG` equivalent), so a path-specific regression surfaces here too. The implementer selects whichever single entry point the corpus tests already use; no new public API is introduced.
- `_builtInThemesUnderTest()` enumerates `DiagramTheme.zincLight, .tokyoNight, .nord, .catppuccin, …` and the other static vars defined in `Sources/DiagramKitModel/Theme.swift:213+`. If no public collection exists, the helper defines the list inline. Adding a public `DiagramTheme.allBuiltIn` is out of scope.
- `_assertNoForeignHex(...)` is the half that catches "all tokens collapsed to fg" — without it, a renderer that emits fg everywhere would pass every positive check.
- Wall-clock target: < 1 s; runnable repeatedly under `swift test --filter PalettePinTests` during fix iteration.

### B. `SVGStructuralSweepTests.swift` (~60 lines)

Walks the full corpus (`CorpusEntry.loadAll()` from `DiagramKitTestSupport`), renders each entry to SVG, asserts no malformed patterns appear in any attribute:

1. No literal `var(--` in the rendered output.
2. No `))` tail after a hex color in any `stroke=`/`fill=`/`style=` attribute (regex on the parsed attribute value).
3. No `NaN` / `nan` substrings.
4. No empty `stroke=""` or `fill=""`.
5. No `#` followed by a non-hex character that isn't a known terminator (`"`, `)`, ` `, `;`).

Each violation reports `entry.id` and the first ~60-char offending substring, so future regressions point at one corpus entry without manual grep.

**On-disk mode.** A second test in the same file, gated by an env flag `SVG_SWEEP_ON_DISK=1`, reads recorded SVG baselines from `Tests/DiagramKitTests/__Snapshots__/` directly and runs the same five checks. Used after C4 to catch a case where the live render is clean but the recorded file was truncated or corrupted.

### Suite layering

- New suites are XCTest, not `swift-testing`. The signal-10 hang documented in CLAUDE.md is associated with `swift-testing` parameterization at corpus scale; both new suites stay clear of it.
- Neither suite depends on `__Snapshots__/` files, so they remain stable across C4/C5.
- `CorpusSnapshotTests` continues to be the per-byte snapshot enforcer and will be red on `main` from the moment this work starts until C4/C5 land — expected behavior, called out in the C1 commit message body.

## Recording Driver

`Scripts/rebaseline-snapshots.sh` — bash, executable (`0755`), idempotent. Replaces ad-hoc `SNAPSHOT_DIAGRAM_IDS=…` invocations and gives the signal-10 hang a safe chunking strategy.

### Invocation

```bash
Scripts/rebaseline-snapshots.sh [--target svg|image|both] [--chunk N] [--dry-run]
# defaults: --target both, --chunk 20
```

### Behavior

1. Reads `Examples/DiagramPlayground/Resources/test-diagrams.json` for the ID list.
2. Partitions into chunks of `--chunk` size (default 20). Chunks of 20 stay well below the documented signal-10 trigger threshold (~422-entry full runs).
3. Per chunk, runs:
   ```
   SNAPSHOT_TESTING_RECORD=all \
   SNAPSHOT_DIAGRAM_IDS=<comma-list> \
   swift test --filter CorpusSnapshotTests/<svgSnapshot|imageSnapshot>
   ```
   For `--target both`, the script runs SVG chunks first, then image chunks — never interleaved in one process invocation, to keep failure attribution clean.
4. Captures stdout/stderr to `.rebaseline-logs/<target>-<chunk-idx>.log` (the `.rebaseline-logs/` directory is gitignored).
5. After each chunk, checks expected snapshot file paths exist on disk; missing IDs go to `.rebaseline-logs/missing-<target>.txt`.
6. Final report: count recorded, count missing, list of chunks whose `swift test` exited non-zero or timed out.

### Idempotence and recovery

Re-running picks up `missing-<target>.txt` if present and re-records only those IDs. A partial run is recoverable without re-recording everything.

No automatic retry on signal-10 — a chunk that hangs is logged and skipped; the operator decides whether to bisect. Automatic retry would mask root cause and risk infinite loops.

### Non-membership in gates

`Scripts/rebaseline-snapshots.sh` is NOT invoked by `Scripts/bootstrap-smoke-check.sh`. It's an explicit operator action, not a merge gate. Discoverability is through CLAUDE.md's Commands block.

## Commit Discipline

- **C1** message body links REVIEW.md §1 and `1c2f18f`. Subject is `test(svg): pin palette math + structural sweep` — purely test code, NOT a `fix(...)`.
- **C2** (if needed) subject names the specific regression, e.g. `fix(svg): _hex round-trip clamps line color to fg in non-deviceRGB color space`. One commit per (theme × token) cell that failed; no batched cleanup.
- **C3** subject `chore(scripts): rebaseline-snapshots.sh` mentions REVIEW.md §1 in body.
- **C4** subject `test(snapshots): rebaseline SVG after color-mix resolver fix`. Body links `1c2f18f` so a future bisector knows why ~422 binary baselines flipped at once.
- **C5** symmetric: `test(snapshots): rebaseline image after color-mix resolver fix`.

No `--no-verify`. Pre-commit hooks investigate failures, not skip them.

## Documentation Touch List

| File | Change | Lands in |
|---|---|---|
| `CLAUDE.md` | Add `Scripts/rebaseline-snapshots.sh ...` to Commands block | C3 |
| `CLAUDE.md` | Bump "Current test source count: 216" → 218 | C1 |
| `BASELINES.md` | Add rebaseline-event row linking `1c2f18f`, C4, C5 | C5 |
| `REVIEW.md` | Add §1 "Resolution Status — Session 4" row mirroring Sessions 2–3 table format | C5 (combined with the rebaseline) |
| `Scripts/check-file-sizes-allowlist.txt` | No change. Both new test files target < 100 lines. | — |

Baseline file counts in `CLAUDE.md` remain truthful: still 435 SVG + 435 image + 174 ASCII = 1044 total. Content changes; count does not.

## Risks & Rollback

**R1 — non-localized palette regression.** Worst-case Phase 1 reveals a regression touching `BMColor.mixed` (used by every `effective<Token>()`) or a shared helper, affecting many cells. Mitigation: matrix isolation makes failure cells visible; Phase 2 still ships per-cell commits even if multiple cells are diagnosed. If a single root cause produces multiple failing cells, Phase 2 lands as one fix referencing all affected cells.

**R2 — non-resolver drift recorded into baselines.** The window `1c2f18f..HEAD` is currently ~13 commits; any unrelated rendering change in that window will land in C4 and be visually attributed to the resolver. Mitigation: pre-C4, run `git log 1c2f18f..HEAD -- Sources/DiagramKitModel/ Sources/DiagramKitCommon/ Sources/DiagramKitRenderingCG/` and spot-check. If any suspect commit is in the window, capture a one-entry before/after diff and call it out in the C4 commit body.

**R3 — chunk hangs.** If a specific chunk hangs repeatedly, shrink chunk size (operator flag `--chunk 5`) or record IDs one at a time. `missing-<target>.txt` resume avoids re-recording previously-good chunks.

**R4 — a baseline records visually-worse output than the old buggy one.** Possible on entries where the malformed `))` happened to render with a tolerable color anyway. Mitigation: before C5, manually compare 6 canary entries — one per major family (flow, seq, class, er, state, xychart) — against their old image baselines. Canary IDs are pinned in C4's commit body so re-runs use the same comparison set.

### Rollback

| Commit | Revert effect |
|---|---|
| C1 | Drops the audit tests. Baselines and renderer untouched. Safe. |
| C2 | Requires reverting C4/C5 too (recorded against the fix). Operator does the three-way revert in one PR. |
| C3 | Drops the script. Baselines untouched. Safe. |
| C4 | SVG baselines drift red until re-recorded. Tolerable for hours, not days. |
| C5 | Image baselines drift red until re-recorded. Symmetric to C4. |

### Failure-to-launch case

If C1 passes on `main` with zero violations, AND C4's `swift test --filter CorpusSnapshotTests/svgSnapshot` shows zero diff against existing baselines — the resolver fix may have already been baselined by a prior pass missed by REVIEW.md. Stop. Verify `git status __Snapshots__/`. Abort without committing.

## Out of Scope (Tracked Elsewhere)

These came up during brainstorming but are deferred to other specs:
- DiagramRenderer multiline measure-first replacement (REVIEW §4 — separate design).
- C4 slot semantics alignment between Mermaid and PlantUML (REVIEW §4).
- DiagramEditor async export off MainActor (REVIEW §4).
- Generators test-target split for `AsciiVisualReportGenerator` et al. (Session 3 reclassification).
- Observation-tracked `canUndo`/`canRedo` (REVIEW §4 playground).

## Acceptance

This work is done when:

1. `swift test --filter PalettePinTests` green.
2. `swift test --filter SVGStructuralSweepTests` green (live render).
3. `SVG_SWEEP_ON_DISK=1 swift test --filter SVGStructuralSweepTests` green (on-disk baselines).
4. `swift test --filter CorpusSnapshotTests/svgSnapshot` green.
5. `swift test --filter CorpusSnapshotTests/imageSnapshot` green.
6. REVIEW.md §1 row added for Session 4 referencing C1–C5.
7. BASELINES.md rebaseline-event row added.
8. CLAUDE.md test count and Commands block updated.

No other gate (Linux check, Sendable annotations, file sizes, strict concurrency) is expected to flip on this work; if any does, treat as an unrelated regression and stop before commit.

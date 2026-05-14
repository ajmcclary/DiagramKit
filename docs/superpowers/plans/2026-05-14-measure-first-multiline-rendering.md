# Measure-First Multiline Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 4000×1000pt placeholder rect in `DiagramRenderer._drawTextInFlipped`'s multiline branch with a measure-first rect built from real text metrics, exposing the measurement primitive on `LabelRenderer` for future layout-time consumers.

**Architecture:** CG-renderer-internal change. Add `LabelRenderer.measureMultilineExtent` (public, mirrors existing `measureText` on the API). Rewrite `_drawTextInFlipped` to call it, build a tight `CGRect`, and hand it to the unchanged `drawMultilineText(in:)`. Output is byte-identical because `drawMultilineText` only consumes `rect.midY` and `rect.{minX|midX|maxX}` — all four invariant under the swap. SVG, ASCII, and Linux paths untouched.

**Tech Stack:** Swift 6, Core Graphics, Core Text via `NSAttributedString.size()`, XCTest for unit assertions, `CorpusSnapshotTests` for regression confirmation. Repo standing rule: commit directly on `main`; never run unfiltered `swift test`.

**Spec:** `docs/superpowers/specs/2026-05-14-measure-first-multiline-rendering-design.md`

---

## File Structure

| Path | Change | Responsibility |
|---|---|---|
| `Sources/DiagramKitRenderingCG/LabelRenderer.swift` | Add `public func measureMultilineExtent(_:font:lineSpacing:) -> CGSize` | Multiline measurement primitive (block width = widest line via `NSAttributedString.size()`, block height = `lines.count * pointSize * 1.3`) |
| `Sources/DiagramKitRenderingCG/DiagramRenderer.swift` | Rewrite multiline branch of `_drawTextInFlipped` at lines 144–161 | Build a tight rect from real metrics; delete the 1000→4000 history comment |
| `Tests/DiagramKitTests/LabelRendererMultilineTests.swift` | New (Apple-only, `#if canImport(CoreGraphics)`) | Single-line parity vs `measureText`; blank-line height; longest-line-wins |

No `Package.swift`, `CLAUDE.md`, or `ARCHITECTURE.md` changes. No new dependency.

---

## Task 1: Add failing tests for `measureMultilineExtent`

Write the test file first. The new method does not yet exist, so the test target's build will fail with "value of type 'LabelRenderer' has no member 'measureMultilineExtent'". This is the intended red state for TDD.

**Files:**
- Create: `Tests/DiagramKitTests/LabelRendererMultilineTests.swift`

- [ ] **Step 1: Create the test file**

Write the following content. The `BMFont.systemFont(ofSize:)` call works on both AppKit (`NSFont`) and UIKit (`UIFont`) — `BMFont` is the cross-platform alias defined in `DiagramKitCommon`. Tolerance of `0.0001` accommodates `CGFloat` round-trip noise without masking a real discrepancy.

```swift
#if canImport(CoreGraphics)
import XCTest
import DiagramKitCommon
@testable import DiagramKitRenderingCG

final class LabelRendererMultilineTests: XCTestCase {
    private var renderer: LabelRenderer!
    private var font: BMFont!

    override func setUp() {
        super.setUp()
        renderer = LabelRenderer()
        font = BMFont.systemFont(ofSize: 14)
    }

    override func tearDown() {
        renderer = nil
        font = nil
        super.tearDown()
    }

    // MARK: - Single-line parity

    func test_singleLine_widthMatchesMeasureText() {
        let extent = renderer.measureMultilineExtent("hi", font: font)
        let baseline = renderer.measureText("hi", font: font)
        XCTAssertEqual(extent.width, baseline.width, accuracy: 0.0001)
    }

    func test_singleLine_heightIsOneLineHeight() {
        let extent = renderer.measureMultilineExtent("hi", font: font)
        let expected = font.pointSize * 1.3
        XCTAssertEqual(extent.height, expected, accuracy: 0.0001)
    }

    // MARK: - Blank-line height

    func test_blankLineCountsTowardHeight() {
        let extent = renderer.measureMultilineExtent("A\n\nB", font: font)
        let expected = 3 * (font.pointSize * 1.3)
        XCTAssertEqual(extent.height, expected, accuracy: 0.0001)
    }

    func test_blankLineContributesZeroWidth() {
        let extent = renderer.measureMultilineExtent("A\n\nB", font: font)
        let aWidth = renderer.measureText("A", font: font).width
        let bWidth = renderer.measureText("B", font: font).width
        XCTAssertEqual(extent.width, max(aWidth, bWidth), accuracy: 0.0001)
    }

    // MARK: - Longest-line-wins

    func test_longestLineDeterminesWidth() {
        let extent = renderer.measureMultilineExtent("x\nlongest line here\ny", font: font)
        let middle = renderer.measureText("longest line here", font: font).width
        XCTAssertEqual(extent.width, middle, accuracy: 0.0001)
    }
}
#endif
```

- [ ] **Step 2: Run the build to confirm the test target fails to compile (intended red state)**

```bash
swift build --build-tests 2>&1 | tail -30
```

Expected: build error referencing `measureMultilineExtent` not found on `LabelRenderer`. Do NOT commit yet.

---

## Task 2: Implement `measureMultilineExtent` on `LabelRenderer`

Add the method directly below the existing `public func measureText(_:font:)` (currently the last public function before the closing `#endif` in `LabelRenderer.swift`). Body uses the same per-line `NSAttributedString.size()` primitive that `drawMultilineText` already uses internally — guarantees the snapshot byte-equivalence the spec relies on.

**Files:**
- Modify: `Sources/DiagramKitRenderingCG/LabelRenderer.swift` (insert after line 185 — the existing `measureText` body — and before the closing `#endif`)

- [ ] **Step 1: Read the area you're editing**

```bash
sed -n '180,188p' Sources/DiagramKitRenderingCG/LabelRenderer.swift
```

Expected: the existing `public func measureText` plus the closing brace of the class and the `#endif`.

- [ ] **Step 2: Add the new public method**

Insert immediately after the closing `}` of `measureText` (the one at the end of the class body), before the class's closing `}`. The class brace is followed by `#endif`.

```swift
    /// Block extent for a newline-delimited multiline string, used to size
    /// the rect handed to `drawMultilineText(in:)` from caller code. Width
    /// is the widest line's `NSAttributedString.size().width`; height is
    /// `lines.count * pointSize * 1.3` (matches `drawMultilineText`'s
    /// internal line-height). Blank lines contribute 0 to width but still
    /// bump the line count, mirroring the placement loop's row-index
    /// advance for skipped empty rows.
    ///
    /// `lineSpacing` is accepted for signature symmetry with
    /// `drawMultilineText` and is not consumed today (line-height already
    /// absorbs spacing). Default mirrors `drawMultilineText`'s default.
    public func measureMultilineExtent(
        _ text: String,
        font: BMFont,
        lineSpacing: CGFloat = 4
    ) -> CGSize {
        let lines = text.components(separatedBy: "\n")
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let maxWidth = lines.reduce(CGFloat(0)) { acc, line in
            let w = NSAttributedString(string: line, attributes: attributes).size().width
            return max(acc, w)
        }
        let lineHeight = font.pointSize * 1.3
        return CGSize(width: maxWidth, height: CGFloat(lines.count) * lineHeight)
    }
```

- [ ] **Step 3: Run the new test suite to confirm it passes**

```bash
swift test --filter LabelRendererMultilineTests 2>&1 | tail -20
```

Expected: 5 tests, all pass. If `test_singleLine_widthMatchesMeasureText` fails, that's a sign the per-line `NSAttributedString.size()` call in the new method drifted from `measureText`'s implementation — re-check the body matches the spec.

- [ ] **Step 4: Commit the new measurement primitive plus its tests**

```bash
git add Sources/DiagramKitRenderingCG/LabelRenderer.swift Tests/DiagramKitTests/LabelRendererMultilineTests.swift
git commit -m "$(cat <<'EOF'
feat(cg): LabelRenderer.measureMultilineExtent

Adds the measurement primitive measure-first multiline rendering will
consume. Width is the widest line's NSAttributedString.size().width;
height counts blank lines (mirrors drawMultilineText's row-advance for
skipped empty rows). Public for future layout-time node-bounds work.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Rewrite `_drawTextInFlipped`'s multiline branch

Replace the 4000×1000pt placeholder rect with a tight rect built from `measureMultilineExtent`. Output is byte-identical — see spec §"Output-equivalence argument" — so existing snapshots stay green.

**Files:**
- Modify: `Sources/DiagramKitRenderingCG/DiagramRenderer.swift:144-161`

- [ ] **Step 1: Read the current multiline branch**

```bash
sed -n '132,166p' Sources/DiagramKitRenderingCG/DiagramRenderer.swift
```

Expected: the `_drawTextInFlipped` function with the `if text.contains("\n")` branch containing `let width: CGFloat = 4000` and the comment block describing the 1000→4000 history.

- [ ] **Step 2: Replace the multiline branch**

Use the Edit tool to replace lines 144–161 (the `if text.contains("\n") { … }` block plus its leading comment block). The `else` branch and the `guard !text.isEmpty else { return }` above stay untouched.

Old code (lines 144–161):
```swift
        if text.contains("\n") {
            // Multiline label bounding box. The previous 1000pt cap silently
            // clipped wider labels (REVIEW.md: "DiagramRenderer+Flow.swift:155
            // hardcodes a 1000pt multiline text box"). Bumping to 4000pt is a
            // conservative bound: still finite (so CoreText can lay text out),
            // but far beyond any realistic diagram-label width.
            let width: CGFloat = 4000
            let x: CGFloat
            switch alignment {
            case .left:
                x = point.x
            case .center:
                x = point.x - width / 2
            case .right:
                x = point.x - width
            }
            let rect = CGRect(x: x, y: point.y - 500, width: width, height: 1000)
            labelRenderer.drawMultilineText(text, in: rect, context: context, color: color, font: font, alignment: alignment)
```

New code:
```swift
        if text.contains("\n") {
            let extent = labelRenderer.measureMultilineExtent(text, font: font)
            let x: CGFloat
            switch alignment {
            case .left:
                x = point.x
            case .center:
                x = point.x - extent.width / 2
            case .right:
                x = point.x - extent.width
            }
            let rect = CGRect(
                x: x,
                y: point.y - extent.height / 2,
                width: extent.width,
                height: extent.height
            )
            labelRenderer.drawMultilineText(text, in: rect, context: context, color: color, font: font, alignment: alignment)
```

- [ ] **Step 3: Build smoke**

```bash
swift build --build-tests 2>&1 | tail -10
```

Expected: `Build complete!`. No new warnings.

- [ ] **Step 4: Re-run the LabelRenderer unit tests to confirm the new method still works in situ**

```bash
swift test --filter LabelRendererMultilineTests 2>&1 | tail -10
```

Expected: 5 tests pass.

---

## Task 4: Snapshot regression confirmation

Spec asserts zero baseline diff. Verify by running existing `CorpusSnapshotTests` for entries that exercise the multiline path. The repo's standing rule forbids unfiltered `swift test`; use `SNAPSHOT_DIAGRAM_IDS` to scope the run.

**Files:**
- No file changes — verification only.

- [ ] **Step 1: Discover multiline-bearing corpus entries**

Multiline labels appear in sources containing `<br>` HTML breaks or literal `\n` escapes. Extract IDs from the corpus JSON:

```bash
jq -r '.[] | select(.source | test("<br|\\\\\\\\n"; "i")) | .id' \
  Examples/DiagramPlayground/Resources/test-diagrams.json \
  | head -40 \
  | tee /tmp/multiline-ids.txt
```

Expected: 20–40 IDs printed (entries from `flow-*`, `class-*`, `seq-*`, `kanban-*`, `state-*`, etc., wherever multiline labels exist in the corpus).

- [ ] **Step 2: Run image snapshot regression for those IDs**

```bash
SNAPSHOT_DIAGRAM_IDS=$(paste -sd, /tmp/multiline-ids.txt) \
  swift test --filter "CorpusSnapshotTests/imageSnapshot" 2>&1 | tail -20
```

Expected: all tests for the listed IDs pass. If any fail with a snapshot-mismatch message, that is a **defect**, not a rebaseline trigger — inspect the diff and reconcile against the spec's output-equivalence argument before proceeding.

- [ ] **Step 3: Run SVG snapshot regression for the same IDs**

The SVG renderer is untouched by this change, so this is a sanity check that nothing leaked across.

```bash
SNAPSHOT_DIAGRAM_IDS=$(paste -sd, /tmp/multiline-ids.txt) \
  swift test --filter "CorpusSnapshotTests/svgSnapshot" 2>&1 | tail -20
```

Expected: all tests pass.

- [ ] **Step 4: Commit the renderer change**

```bash
git add Sources/DiagramKitRenderingCG/DiagramRenderer.swift
git commit -m "$(cat <<'EOF'
refactor(cg): measure-first multiline in _drawTextInFlipped

Replaces the 4000x1000pt placeholder rect with a tight rect built from
LabelRenderer.measureMultilineExtent. drawMultilineText only consumes
rect.midY and rect.{minX|midX|maxX} -- all four invariant under the
swap, so output is byte-identical. Verified zero baseline diff for
multiline-bearing corpus entries (image + SVG).

Closes REVIEW.md §4 Rendering & views: "4000pt multiline bounding box
is a band-aid -- measure-first strategy so the box matches the actual
text extent."

Spec: docs/superpowers/specs/2026-05-14-measure-first-multiline-rendering-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Verify git state is clean**

```bash
git status --short
git log --oneline -3
```

Expected: no uncommitted changes from this plan's files (`LabelRenderer.swift`, `DiagramRenderer.swift`, `LabelRendererMultilineTests.swift`). Last two commits should be the `feat(cg):` measurement primitive commit and the `refactor(cg):` renderer rewrite commit. Pre-existing modified files in `Tests/.../__Snapshots__/` (visible at session start) are unrelated to this plan and stay untouched.

---

## Done When

- `LabelRenderer.measureMultilineExtent` exists, public, tested (5 unit tests pass).
- `DiagramRenderer._drawTextInFlipped`'s multiline branch no longer references `4000` or `1000` magic numbers; rect is sized from `measureMultilineExtent`.
- `CorpusSnapshotTests/imageSnapshot` and `…/svgSnapshot` pass for all multiline-bearing IDs with no baseline drift.
- Two commits on `main`: the measurement primitive + tests, then the renderer rewrite.

## Out of Scope (do not implement here)

- Removing the unused `contentHeight: CGFloat` parameter from `_drawTextInFlipped`. ~30 call sites; separate mechanical cleanup.
- Layout-time node-bounds-grow-to-fit. The primitive is public so this future work can call it directly; doing the layout-side fix is a separate spec.
- Touching `_drawAttributedStringInFlipped` (already measure-first via `boundingRect`).
- SVG or ASCII renderer changes.

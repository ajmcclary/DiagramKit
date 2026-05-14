# Measure-First Multiline Rendering — Design Spec

**Date:** 2026-05-14
**Status:** Approved (brainstorm phase). Ready for implementation-plan phase.
**REVIEW.md item:** §4 Rendering & views — *"`DiagramRenderer.swift:147-161` — 4000pt multiline bounding box is a band-aid… Replace with a measure-first strategy so the box matches the actual text extent."*

## Problem

`Sources/DiagramKitRenderingCG/DiagramRenderer.swift:144-161` — the multiline branch of `_drawTextInFlipped` invents a fake 4000×1000pt rect just to satisfy `LabelRenderer.drawMultilineText(in: rect, …)`:

```swift
if text.contains("\n") {
    let width: CGFloat = 4000
    let x: CGFloat
    switch alignment {
    case .left:   x = point.x
    case .center: x = point.x - width / 2
    case .right:  x = point.x - width
    }
    let rect = CGRect(x: x, y: point.y - 500, width: width, height: 1000)
    labelRenderer.drawMultilineText(text, in: rect, …)
}
```

`LabelRenderer.drawMultilineText` (`LabelRenderer.swift:134-178`) only consumes `rect.midY` (block-center anchor) and `rect.{minX|midX|maxX}` (per-line x via `alignment`). Each line's actual width is measured inside the loop with `NSAttributedString(string: line).size()`. The 4000pt width and 1000pt height never reach pixels.

The reviewer flagged this as "same hack, larger number" — `1000` was the previous magic; `4000` is today's. The strategy must change to measurement-driven sizing.

## Approach

CG-renderer-internal change.

1. Add a public measurement primitive on `LabelRenderer` alongside the existing single-line `measureText`.
2. In `_drawTextInFlipped`'s multiline branch, call that primitive to compute the true block extent, then build a tight rect anchored on `point`.
3. Hand the tight rect to the unchanged `drawMultilineText(in: rect, …)`.

The SVG renderer is unaffected — `original_src_multiline_utils.renderMultilineText` (`Sources/DiagramKitCommon/src_multiline_utils.swift`) already lays lines out per-`tspan` with `dy`, no synthetic rect. The ASCII renderers are also unaffected.

## New API

`Sources/DiagramKitRenderingCG/LabelRenderer.swift`, public API surface:

```swift
public func measureMultilineExtent(
    _ text: String,
    font: BMFont,
    lineSpacing: CGFloat = 4
) -> CGSize
```

**Semantics**

- `width` = max over `text.components(separatedBy: "\n")` of `NSAttributedString(string: line, attributes: [.font: font]).size().width`.
- `height` = `CGFloat(lines.count) * (font.pointSize * 1.3)`. The `1.3` multiplier matches `drawMultilineText`'s `lineHeight = fontSize * 1.3` (the upstream `LINE_HEIGHT_RATIO` constant in `original_src_text_metrics.swift:18`).
- Empty lines: contribute `0` to width but still bump the line count (and therefore height). Matches `drawMultilineText`'s placement loop, which skips drawing empty lines but advances the row index `i`.
- `lineSpacing`: reserved parameter for signature symmetry with `drawMultilineText`. Not consumed today (line-height already absorbs spacing). Default `4` mirrors `drawMultilineText`'s default.

**Why public, not private.** REVIEW.md leaves an open Important-tier item about node-bounds growing to actual multiline text extent at layout time. The measurement primitive that layout work will consume is exactly this one. Exposing now (a single one-line addition to the public surface) avoids one more visibility migration later. Sibling `measureText(_:font:) -> CGSize` is already public.

## `_drawTextInFlipped` rewrite

Replace lines 144–161 in `Sources/DiagramKitRenderingCG/DiagramRenderer.swift`:

```swift
if text.contains("\n") {
    let extent = labelRenderer.measureMultilineExtent(text, font: font)
    let x: CGFloat
    switch alignment {
    case .left:   x = point.x
    case .center: x = point.x - extent.width / 2
    case .right:  x = point.x - extent.width
    }
    let rect = CGRect(
        x: x,
        y: point.y - extent.height / 2,
        width: extent.width,
        height: extent.height
    )
    labelRenderer.drawMultilineText(
        text, in: rect, context: context,
        color: color, font: font, alignment: alignment
    )
}
```

Delete the multi-line comment block describing the 1000pt → 4000pt history. The new code is self-explanatory; no annotation needed.

## Output-equivalence argument

`drawMultilineText` uses `rect.midY` for vertical centering and `rect.{minX|midX|maxX}` keyed off `alignment` for per-line x:

| alignment | old anchor | new anchor |
|---|---|---|
| `.left`   | `rect.minX = point.x` | `rect.minX = point.x` |
| `.center` | `rect.midX = (point.x - 2000) + 2000 = point.x` | `rect.midX = (point.x - W/2) + W/2 = point.x` |
| `.right`  | `rect.maxX = (point.x - 4000) + 4000 = point.x` | `rect.maxX = (point.x - W) + W = point.x` |
| (any)     | `rect.midY = (point.y - 500) + 500 = point.y` | `rect.midY = (point.y - H/2) + H/2 = point.y` |

Every quantity `drawMultilineText` reads from the rect is invariant under the swap. Pixel output is byte-identical. Snapshot diff expected: **zero**. If any baseline shifts, that's a defect to investigate, not a rebaseline trigger.

## Out of scope

- **`_drawAttributedStringInFlipped`** (`DiagramRenderer.swift:167-185`). Already measure-first via `attrStr.boundingRect(with:options:)`. Correct.
- **`_drawTextInFlipped`'s `contentHeight: CGFloat` parameter.** Documented unused at lines 132-133 ("retained for call-site compatibility but is no longer used"). Removing it touches ~30 call sites across `DiagramRenderer+{Flow, Sequence, Kanban, Timeline, Radar, Architecture, …}.swift`. Outside this spec's scope; leave for a separate mechanical cleanup commit.
- **Layout-time node-bounds-grow-to-fit.** Important-tier review work. This spec exposes the primitive a layout-side fix will consume but does not change layouts or family bounds today.
- **SVG renderer (`renderMultilineText`)** and **ASCII renderers**. Already correct or use a different code path.
- **Cross-platform measurement parity.** `NSAttributedString.size()` returns marginally different metrics across AppKit and UIKit; this spec stays on the same primitive `drawMultilineText` already uses, so it neither inherits new drift nor fixes existing drift.

## Tests

New file `Tests/DiagramKitTests/LabelRendererMultilineTests.swift`, Apple-only (`#if canImport(CoreGraphics)`). Three families of assertions:

1. **Single-line parity.** `measureMultilineExtent("hi", font:)` returns the same `.width` as the existing `measureText("hi", font:)`, and `.height == font.pointSize * 1.3`.
2. **Blank lines count toward height.** `measureMultilineExtent("A\n\nB", font:)` height == `3 * font.pointSize * 1.3`. Width == max(width("A"), width("B")) — the blank middle line contributes 0.
3. **Longest line wins.** `measureMultilineExtent("x\nlongest line here\ny", font:)` width tracks the middle line.

**Regression confirmation.** Targeted `swift test --filter CorpusSnapshotTests/imageSnapshot` and `…/svgSnapshot` run against entries known to carry multiline labels (e.g., `flow-*-multiline`, `seq-*-note`, `kanban-*`, any `<br>`/`\n`-bearing IDs). Expected output: zero baseline diff. SVG slice is included as a sanity check even though the SVG path is unchanged — confirms cross-renderer equivalence wasn't accidentally severed.

## Risks

- **Hidden caller depending on the giant rect.** None expected — `drawMultilineText` is the only consumer and its access pattern is enumerated above. Mitigation: the zero-diff snapshot run in §Tests is the safety net.
- **Future drift if `drawMultilineText` starts consuming additional rect dimensions** (e.g., adding wrap-to-width). Spec's tight rect is exactly the block extent, so wrap-to-width would behave naturally; this is a feature, not a regression vector.

## Files touched

| Path | Change |
|---|---|
| `Sources/DiagramKitRenderingCG/LabelRenderer.swift` | + `public func measureMultilineExtent(_:font:lineSpacing:) -> CGSize` |
| `Sources/DiagramKitRenderingCG/DiagramRenderer.swift` | Replace lines 144–161 with the measure-first body; delete the 1000→4000 history comment |
| `Tests/DiagramKitTests/LabelRendererMultilineTests.swift` | New file (Apple-only) |

No `Package.swift`, `CLAUDE.md`, or `ARCHITECTURE.md` changes. No new dependency. No invariant change.

# Linux Text-Measurement Shim — Ishikawa / TreeView / EventModeling

Status: spec
Owner: ajmcclary
Date: 2026-05-15
Follows: [2026-05-15-linux-svg-ascii-parity-design.md](2026-05-15-linux-svg-ascii-parity-design.md) (Session 14)

## Problem

Session 14 landed Linux SVG/ASCII parity for 25 of 28 diagram families. The
remaining three — `ishikawa`, `treeView`, `eventModeling` — were flipped to
`linuxSupport: false` with `linuxUnsupportedReason: "requires CoreText
text-measurement"` because their layouts call `CTLineGetBoundsWithOptions` and
`NSString.size(withAttributes:)` directly. `Dockerfile.linux-check` names this
work as the **Stage 2.5** follow-up.

A second, hidden problem surfaces during the audit: `TextMetrics.swift`
references `DiagramFontResolver` unconditionally (lines 13, 15), but
`DiagramFontResolver` itself is whole-file gated to
`#if canImport(UIKit) || canImport(AppKit)`. Session 14's local `linux-check.sh`
was recorded as environment-skipped (Docker daemon not running). The next
container run will fail to build `DiagramKitModel` on Linux regardless of
whether we ship Stage 2.5 — this design fixes that bustage in the same pass.

## Goal

- Make `ishikawa`, `treeView`, and `eventModeling` parse → layout → renderSVG
  / renderASCII succeed on Linux.
- Make `TextMetrics.swift` actually compile on Linux.
- Output must be **geometrically valid** (no `NaN`, all widths/heights > 0,
  non-empty viewBox), not pixel-equal to Apple.

## Non-goals

- Pixel-exact (or near-pixel-exact) parity with Apple CoreText output. The
  Linux fallback uses char-count estimation; Apple output continues to use
  `CTLineGetBoundsWithOptions(.useOpticalBounds)`.
- Linux-specific snapshot baselines. No SVG / image / ASCII baselines are
  recorded under a Linux suffix.
- Linking a Linux text-shaper (HarfBuzz, FreeType). Out of scope per the
  "valid geometry only" decision.
- Making `DiagramFontResolver` Linux-portable. The resolver returns `BMFont`
  / `CTFont` from most of its methods; those types remain undefined on Linux.

## Design

### Architectural shape

```
DiagramKitModel (Linux + Apple)
├── TextMetrics.swift
│    ├── #if canImport(CoreText): fontResolver field + CTLineGetBounds path
│    └── #else: no fontResolver; char-count estimate (0.55 / 0.6 × fontSize)
├── src_ishikawa_layout.swift      (already routes through TextMetrics on #else)
├── src_treeview_layout.swift      (lift file gate; route through TextMetrics)
├── src_eventmodeling_layout.swift (lift file gate; route through TextMetrics)
├── src_ishikawa_renderer.swift    (audit; lift gate if no BMFont/CTFont deps)
├── src_treeview_renderer.swift    (lift gate or move Apple-only blocks inward)
└── src_eventmodeling_renderer.swift (lift gate or move Apple-only blocks inward)

DiagramKit (umbrella)
└── DiagramRegistry+{Ishikawa,TreeView,EventModeling}.swift
     └── linuxSupport: false → true; linuxUnsupportedReason: ... → nil
```

No new types. No new files. Every change is either a gate flip, a `#if`
re-scoping, or a redirect of an existing measurement call through
`TextMetrics`.

### `TextMetrics` inline-gate

`TextMetrics`'s Linux `#else` branches (`estimateTextWidth`,
`estimateMonoTextWidth`) already use pure char-count estimation — they
do not need `fontResolver`. The fix is honest about that:

```swift
public struct TextMetrics: Sendable {
#if canImport(CoreText)
    public let fontResolver: DiagramFontResolver

    public init(fontResolver: DiagramFontResolver = .shared) {
        self.fontResolver = fontResolver
    }
#else
    public init() {}
#endif

    public static let shared = TextMetrics()

    // estimateTextWidth, estimateMonoTextWidth, measureMonospaceMultiline
    // bodies unchanged — the existing #if canImport(CoreText) / #else split
    // already keeps the fontResolver references confined to the Apple branch.
}
```

Approach considered and rejected: splitting `DiagramFontResolver` into a
Linux-portable name struct (`svgFontFamily`, `svgMonoFamily`, ...) plus an
Apple-only font struct. Cleaner separation but ~22 callsites use the
existing umbrella resolver and would migrate. The inline-gate is surgical;
no callsite outside the three layouts changes shape.

### TreeView layout

Currently:

```swift
// src_treeview_layout.swift
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics
import CoreText
// ... entire file body ...
private func _treeViewFont(size: CGFloat) -> BMFont { ... }
#endif
```

After:

```swift
// src_treeview_layout.swift
import Foundation
import DiagramKitCommon
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit) || canImport(AppKit)
#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#endif

// Body un-gated. The internal measureText closure becomes:
func measureText(_ text: String, fontSize: Double) -> (width: Double, height: Double) {
#if canImport(CoreText)
    let font = _treeViewFont(size: CGFloat(fontSize))
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let size = (text as NSString).size(withAttributes: attributes)
    return (Double(size.width), Double(size.height))
#else
    let width = Double(TextMetrics.shared.estimateTextWidth(
        text, fontSize: CGFloat(fontSize), fontWeight: 400))
    let height = Double(fontSize * 1.2)   // matches Apple line-height ratio for treeView
    return (width, height)
#endif
}

#if canImport(UIKit) || canImport(AppKit)
private func _treeViewFont(size: CGFloat) -> BMFont {
    DiagramFontResolver.shared.proportionalFont(size: size, weight: .regular)
}
#endif
```

### EventModeling layout

Same pattern as TreeView. `_measureTextDimensions` becomes a two-branch
helper:

```swift
private func _measureTextDimensions(_ text: String, fontSize: Double, weight: Int = 400) -> (width: Double, height: Double) {
#if canImport(CoreText)
    let font = DiagramFontResolver().proportionalCTFont(size: CGFloat(fontSize))
    // existing CoreText measurement
#else
    let width = Double(TextMetrics.shared.estimateTextWidth(
        text, fontSize: CGFloat(fontSize), fontWeight: weight))
    let height = Double(fontSize * 1.2)
    return (width, height)
#endif
}
```

The file's top-level `#if canImport(CoreText)` gate lifts. Any inner Apple
helper (`DiagramFontResolver()`, `BMFont` literal) stays under an inner
`#if canImport(CoreText)` block.

### Ishikawa layout

No body changes needed. `_measureIshikawaText` already has the
`#if canImport(CoreText) / #else` split routing the Linux fallback through
`TextMetrics.shared.measureMonospaceMultiline`. The file compiles on Linux
today. Only the **registry** changes (`linuxSupport: false → true`).

### SVG renderer audit

For each of `src_ishikawa_renderer.swift`, `src_treeview_renderer.swift`,
`src_eventmodeling_renderer.swift`:

1. Identify every reference to `BMFont`, `CTFont`, `BMColor`, `BMBezierPath`,
   `NSAttributedString`, `(text as NSString)`, `DiagramFontResolver.{...font...}`.
2. If the renderer is SVG-string emission only (most likely case — SVG output
   needs *family names*, not font instances), lift the file-level gate.
   Family-name calls go through the Linux-portable methods of
   `DiagramFontResolver` *or* fall back to a hard-coded family chain.
3. If the renderer references Apple-only types in places that are reachable
   from `renderSVG`, those blocks move under an inner `#if`. The renderSVG
   entry point must compile and run on Linux.
4. CG-bitmap raster code in the renderer stays Apple-only — it's reached
   only by `DiagramRenderer` (`DiagramKitRenderingCG`, Apple-only target).

### Registry flips

For each of `Sources/DiagramKit/DiagramRegistry+Ishikawa.swift`,
`+TreeView.swift`, `+EventModeling.swift`:

```swift
// Before
linuxSupport: false,
linuxUnsupportedReason: "requires CoreText text-measurement"
// After
linuxSupport: true    // (parameter omitted — default is true; linuxUnsupportedReason drops)
```

`DiagramPipeline._assertPlatformSupport` is unchanged — the descriptor flip
alone disables the throw for these three families.

`DiagramEngine.linuxSupport(for:)` is unchanged. Callers asking
`DiagramEngine.linuxSupport(for: .ishikawa)` now receive `(true, nil)`.

## Data flow

```text
Linux: source "ishikawa\nProblem\nCause A"
  → DiagramLoader.parseImportResult (MermaidImporter probe)
  → DiagramImportResult { document, diagnostics }
  → GraphLayout(...).layout
      → layoutIshikawaDiagram(...)
         → _measureIshikawaText(lines, fontSize:)  // #else branch
            → TextMetrics.shared.measureMonospaceMultiline(...)
               → 0.6 × fontSize × text.count  (no CoreText)
  → PositionedGraph { content: .ishikawa(...), diagnostics }
  → DiagramPipeline.renderSVG(positioned:theme:)
      → _assertPlatformSupport(.ishikawa)  // no throw — linuxSupport == true
      → renderIshikawaSVG(positioned, theme:)  // SVG-string emission
  → "<svg>...</svg>"
```

On Apple, the path is unchanged from today.

## Testing

### `DiagramKitLinuxTests` — surgery on `LinuxPlatformGateTests`

Tests to **delete or invert** (they pin the old "three families throw"
contract that this work overturns):

- `ishikawaIsLinuxUnsupported`
- `treeViewIsLinuxUnsupported`
- `eventModelingIsLinuxUnsupported`
- `exactlyThreeFamiliesAreLinuxUnsupported`
- `linuxSupportReturnsFalseForIshikawa`
- `linuxSupportReportsAllThreeUnsupported` (parameterized)
- `pipelineRenderSVGGatesIshikawaOnLinux`
- `engineRenderSVGGatesIshikawaOnLinux`

Tests to **keep unchanged**:

- `unsupportedOnPlatformErrorDescription` — pins the error case shape;
  still exercises the general mechanism even when no family uses it.
- `descriptorDefaultsLinuxSupportToTrue` — descriptor field contract.
- `linuxSupportReturnsTrueForSupportedFamily` — `DiagramEngine.linuxSupport`
  contract.
- `parseImportResultDoesNotGateOnLinux` — parse is unconditional.

Tests to **add**:

- `exactlyZeroFamiliesAreLinuxUnsupported` — replaces the deleted "three
  families" assertion. Locks down the new state and catches regressions if
  someone re-introduces a CoreText-bound family.
- `ishikawaRendersOnLinux`, `treeViewRendersOnLinux`,
  `eventModelingRendersOnLinux` — each: parse → renderSVG succeeds;
  returned SVG string is non-empty and starts with `<svg`.
- `ishikawaRenderASCIIOnLinux`, `treeViewRenderASCIIOnLinux`,
  `eventModelingRenderASCIIOnLinux` — each: parse → renderASCII succeeds;
  returned `text` is non-empty.
- `ishikawaStructuralValidityOnLinux`, `treeViewStructuralValidityOnLinux`,
  `eventModelingStructuralValidityOnLinux` — each: SVG output contains no
  literal `nan`/`NaN`/`-nan`; viewBox numbers are all finite.

### Coverage strategy

- The new structural validity tests run on **both** Apple and Linux. On Apple
  they prove the CoreText branch still produces valid geometry (regression
  insurance for the broader refactor); on Linux they prove the char-count
  branch produces valid geometry (new coverage).
- The `os(Linux)`-gated branches of `pipelineRenderSVGGatesIshikawaOnLinux`
  / `engineRenderSVGGatesIshikawaOnLinux` are deleted along with those tests;
  they assert the throw the new code path no longer produces.
- No new corpus snapshot baselines on Linux. The decision is "valid geometry,
  not pixel parity" — pinning Linux output by snapshot would lock in
  whatever the char-count estimate produces today, which is the wrong
  contract to maintain.

### Apple-side regression coverage

Existing Apple snapshot tests for `ishikawa`, `treeView`, `eventModeling`
(SVG + image + ASCII) are unchanged by this work and continue to gate the
CoreText measurement path. If a refactor accidentally moves the CoreText
branch into the `#else` path, those snapshot tests fail.

## CI wiring

`Dockerfile.linux-check` already builds `DiagramKitLinuxTests` and runs
`swift test --filter LinuxPlatformGateTests` (Session 14, commit `6233040`).
No Dockerfile changes needed for Stage 2.5 — the existing test step picks
up the new tests automatically.

The header comment in `Dockerfile.linux-check` ("A portable text-measurement
shim is the Stage 2.5 follow-up") updates to point at this spec / the
landing commits once the work merges.

## Migration / breaking change risk

- **Internal-only break**: `LinuxPlatformGateTests` rewrites are internal to
  this repo.
- **Behavioral change for Linux consumers**: `DiagramEngine.renderSVG(source:)`
  no longer throws `unsupportedOnPlatform` for the three families on Linux.
  Consumers explicitly catching that case should still compile (the case
  still exists) but the catch is dead code for these families.
- **`DiagramEngine.linuxSupport(for:)` return value**: now reports
  `(true, nil)` for the three families. Callers using the introspection API
  to switch UI ("show family X as Linux-unsupported") will silently re-enable
  those families. Acceptable per "make Linux work" being the whole point of
  this work.
- **Snapshot risk on Apple**: zero. The CoreText branch is byte-identical;
  the changes are all `#else`-side additions plus gate restructuring.

## Out of scope

- The wider "split `DiagramFontResolver` into name + font halves" refactor.
- Bundling per-glyph advance tables for Linux fidelity. The char-count
  estimate is documented as the contract; future fidelity work is a separate
  spec.
- Re-running `Scripts/linux-check.sh` locally (no Docker daemon in this
  environment); CI will run it.
- Recording Linux-specific snapshot baselines.

## Implementation order (preview, full plan to follow)

The implementation plan is a separate document. Preview of the commit
sequence:

1. `TextMetrics.swift` inline-gate (fixes the latent Linux build break).
   New test: `TextMetrics` compiles and `shared` constructs on Linux.
2. TreeView layout file-gate lift + measurement re-route.
3. EventModeling layout file-gate lift + measurement re-route.
4. SVG renderer audits (one commit per family, possibly more if a renderer
   needs Apple-only block extraction).
5. Registry flips for the three families.
6. `LinuxPlatformGateTests` rewrite (delete / invert / add).
7. `CLAUDE.md` Linux Portability section + `Dockerfile.linux-check` header
   comment refresh.

Each step is independently revertable; each step is verified by the
targeted `swift test --filter` for the suites it touches plus, on Linux,
the `LinuxPlatformGateTests` suite.

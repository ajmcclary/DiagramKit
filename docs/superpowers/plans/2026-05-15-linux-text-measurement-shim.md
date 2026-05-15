# Linux Text-Measurement Shim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `ishikawa`, `treeView`, and `eventModeling` parse → layout → renderSVG / renderASCII succeed on Linux, with valid-geometry-only accuracy (no NaN, all widths/heights > 0).

**Architecture:** Inline-gate `TextMetrics.fontResolver` under `#if canImport(CoreText)`. Lift file-level Apple gates on TreeView + EventModeling layouts; route their measurement through `TextMetrics.shared.estimateTextWidth`. Lift the stale TreeView SVG-renderer gate. Flip three registry `linuxSupport` flags. Rewrite `LinuxPlatformGateTests` (delete 8 obsolete tests, add ~10 structural-validity tests).

**Tech Stack:** Swift 6, SwiftPM, swift-testing (`@Suite` / `@Test`), `Dockerfile.linux-check` (swift:6.3.1-noble).

**Spec:** [docs/superpowers/specs/2026-05-15-linux-text-measurement-shim-design.md](../specs/2026-05-15-linux-text-measurement-shim-design.md)

**Standing project defaults (from CLAUDE.md + auto-memory):**
- Commit-by-commit on `main` — no worktrees, no branches.
- Never use full `swift test`; always `--filter`.
- Don't re-run tests once you've seen the result — two confirmatory runs max, then commit or change strategy.
- Local `Scripts/linux-check.sh` records as environment-skipped (no Docker daemon) — that's not a source failure; the container verification happens in CI / a follow-up session.

## File Structure

**Modify:**
- `Sources/DiagramKitModel/TextMetrics.swift` — Task 1
- `Sources/DiagramKitModel/src_treeview_renderer.swift` — Task 2
- `Sources/DiagramKitModel/src_treeview_layout.swift` — Task 3
- `Sources/DiagramKitModel/src_eventmodeling_layout.swift` — Task 4
- `Sources/DiagramKit/DiagramRegistry+Ishikawa.swift` — Task 5
- `Sources/DiagramKit/DiagramRegistry+TreeView.swift` — Task 6
- `Sources/DiagramKit/DiagramRegistry+EventModeling.swift` — Task 7
- `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` — Tasks 5, 6, 7, 8
- `CLAUDE.md` — Task 9
- `Dockerfile.linux-check` — Task 9

**Create:** none.

---

## Task 1: Inline-gate `TextMetrics.fontResolver` under `#if canImport(CoreText)`

**Why:** `TextMetrics.swift` references `DiagramFontResolver` unconditionally (lines 13, 15) but `DiagramFontResolver` is whole-file gated to `#if canImport(UIKit) || canImport(AppKit)`. The file doesn't compile on Linux today. Session 14's container run was environment-skipped, so this bustage is latent. Fix in-band.

**Files:**
- Modify: `Sources/DiagramKitModel/TextMetrics.swift:12-21`

- [ ] **Step 1: Read the current state**

Run: `cat Sources/DiagramKitModel/TextMetrics.swift`

Expected: 72 lines, the resolver-using lines at 13–17, the CoreText / `#else` measurement branches at 26–36 and 42–52.

- [ ] **Step 2: Apply the inline gate**

In `Sources/DiagramKitModel/TextMetrics.swift`, replace:

```swift
public struct TextMetrics: Sendable {
    public let fontResolver: DiagramFontResolver

    public init(fontResolver: DiagramFontResolver = .shared) {
        self.fontResolver = fontResolver
    }

    /// Shared instance using the default font resolver.
    public static let shared = TextMetrics()
```

with:

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

    /// Shared instance.
    ///
    /// On Apple this uses `DiagramFontResolver.shared` for CoreText
    /// measurement. On Linux this is a no-state struct that drives the
    /// char-count fallback in `estimateTextWidth` / `estimateMonoTextWidth`.
    public static let shared = TextMetrics()
```

The CoreText / `#else` branches inside `estimateTextWidth` and `estimateMonoTextWidth` remain unchanged — they already keep the `fontResolver` references confined to the Apple branch.

- [ ] **Step 3: Verify the Apple build is still green**

Run: `swift build --target DiagramKitModel 2>&1 | tail -3`

Expected: `Build of target: 'DiagramKitModel' complete!`, exit 0.

- [ ] **Step 4: Verify Apple-side TextMetrics-touching tests still pass**

Run: `swift test --filter "TextMetrics|Ishikawa" 2>&1 | tail -10`

Expected: all green. The Ishikawa tests exercise `TextMetrics.shared` via `_measureIshikawaText`'s `#else` branch when CoreText is unavailable, but on Apple they go through the CT branch — either way the binary is built cleanly.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitModel/TextMetrics.swift
git commit -m "$(cat <<'EOF'
fix(model): gate TextMetrics.fontResolver under canImport(CoreText)

DiagramFontResolver is whole-file gated to canImport(UIKit) ||
canImport(AppKit); TextMetrics referenced it unconditionally and so
failed to compile on Linux. The #else measurement branches do not need
the resolver — they use pure char-count estimation. Gating the field
and init is honest about that. No Apple-side behavior change.

Stage 2.5 prerequisite — Linux text-measurement shim.
EOF
)"
```

---

## Task 2: Lift the stale `#if` gate on `src_treeview_renderer.swift`

**Why:** The file header claims "depends on gated symbols (ShapePath/BMFont/etc.)" but `grep` confirms no `BMFont` / `CTFont` / `NSAttributedString` / `NSString` / `DiagramFontResolver` references in the body. It's pure SVG-string emission. The gate is stale.

**Files:**
- Modify: `Sources/DiagramKitModel/src_treeview_renderer.swift` (header + outer `#if` / `#endif`)

- [ ] **Step 1: Verify the file body has no Apple-only references**

Run: `grep -n "BMFont\|CTFont\|NSAttributed\|NSString\|DiagramFontResolver" Sources/DiagramKitModel/src_treeview_renderer.swift`

Expected: empty output.

- [ ] **Step 2: Remove the file-level gate and stale header comment**

In `Sources/DiagramKitModel/src_treeview_renderer.swift`, replace:

```swift
// Apple-only — depends on gated symbols (ShapePath/BMFont/etc.). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import DiagramKitCommon

public func renderTreeViewSvg(_ positioned: PositionedTreeViewDiagram, diagramId: String, font: String) -> String {
```

with:

```swift
import Foundation
import DiagramKitCommon

public func renderTreeViewSvg(_ positioned: PositionedTreeViewDiagram, diagramId: String, font: String) -> String {
```

Delete the trailing `#endif` at the end of the file.

- [ ] **Step 3: Verify the Apple build is still green**

Run: `swift build --target DiagramKitModel 2>&1 | tail -3`

Expected: `Build of target: 'DiagramKitModel' complete!`, exit 0.

- [ ] **Step 4: Verify TreeView tests still pass**

Run: `swift test --filter "TreeView" 2>&1 | tail -10`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitModel/src_treeview_renderer.swift
git commit -m "$(cat <<'EOF'
fix(model): drop stale Apple-only gate on renderTreeViewSvg

The header comment claimed BMFont/ShapePath dependencies but the body
is pure SVG-string emission — no Apple-only references in the file.
Lifting the gate so renderTreeViewSvg is callable on Linux.

Stage 2.5 — Linux text-measurement shim.
EOF
)"
```

---

## Task 3: Lift TreeView layout file gate; route `measureText` through `TextMetrics`

**Why:** `src_treeview_layout.swift` is whole-file gated to `#if canImport(UIKit) || canImport(AppKit)`. Its `measureText` uses `NSString.size(withAttributes:)` and `_treeViewFont` returns `BMFont`. The measurement needs a `#if canImport(CoreText) / #else` split; the `_treeViewFont` helper stays Apple-only.

**Files:**
- Modify: `Sources/DiagramKitModel/src_treeview_layout.swift:1-13` (file header + imports)
- Modify: `Sources/DiagramKitModel/src_treeview_layout.swift:29-34` (inner `measureText`)
- Modify: `Sources/DiagramKitModel/src_treeview_layout.swift:184-193` (`_treeViewFont` + trailing `#endif`)

- [ ] **Step 1: Replace the file header and imports**

In `Sources/DiagramKitModel/src_treeview_layout.swift`, replace lines 1–13:

```swift
// Apple-only — depends on BMColor/BMFont (UIKit/AppKit). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import CoreGraphics
import CoreText
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
```

with:

```swift
import Foundation
import DiagramKitCommon
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(CoreText)
import CoreText
#endif
#if canImport(UIKit) || canImport(AppKit)
#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#endif
```

- [ ] **Step 2: Re-route the inner `measureText` to use `TextMetrics` on Linux**

In `Sources/DiagramKitModel/src_treeview_layout.swift`, replace the `measureText` closure body (currently around lines 29–34):

```swift
    func measureText(_ text: String, fontSize: Double) -> (width: Double, height: Double) {
        let font = _treeViewFont(size: CGFloat(fontSize))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return (Double(size.width), Double(size.height))
    }
```

with:

```swift
    func measureText(_ text: String, fontSize: Double) -> (width: Double, height: Double) {
#if canImport(CoreText)
        let font = _treeViewFont(size: CGFloat(fontSize))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return (Double(size.width), Double(size.height))
#else
        let width = Double(TextMetrics.shared.estimateTextWidth(
            text, fontSize: CGFloat(fontSize), fontWeight: 400))
        let height = fontSize * 1.2
        return (width, height)
#endif
    }
```

- [ ] **Step 3: Gate `_treeViewFont` under the Apple-only `#if` and drop the trailing file-level `#endif`**

In `Sources/DiagramKitModel/src_treeview_layout.swift`, replace the tail (currently lines 184–193):

```swift
/// Resolve the label font through `DiagramFontResolver.shared` so layout
/// and the CG renderer (`DiagramRenderer+TreeView`) measure text with
/// the same font family. Previously this called `BMFont.systemFont(...)`
/// directly, which let the bundled-font determinism guarantee leak
/// out — labels could be measured in system Helvetica but rendered in
/// Inter, drifting layout widths from snapshot baselines.
private func _treeViewFont(size: CGFloat) -> BMFont {
    DiagramFontResolver.shared.proportionalFont(size: size, weight: .regular)
}
#endif
```

with:

```swift
#if canImport(UIKit) || canImport(AppKit)
/// Resolve the label font through `DiagramFontResolver.shared` so layout
/// and the CG renderer (`DiagramRenderer+TreeView`) measure text with
/// the same font family. Previously this called `BMFont.systemFont(...)`
/// directly, which let the bundled-font determinism guarantee leak
/// out — labels could be measured in system Helvetica but rendered in
/// Inter, drifting layout widths from snapshot baselines.
private func _treeViewFont(size: CGFloat) -> BMFont {
    DiagramFontResolver.shared.proportionalFont(size: size, weight: .regular)
}
#endif
```

Note: only one `#endif` total at the very end (the new one closing the Apple-only helper block); the file-level `#endif` from before is removed.

- [ ] **Step 4: Verify the Apple build is still green**

Run: `swift build --target DiagramKitModel 2>&1 | tail -3`

Expected: `Build of target: 'DiagramKitModel' complete!`, exit 0.

- [ ] **Step 5: Verify TreeView tests still pass on Apple**

Run: `swift test --filter "TreeView" 2>&1 | tail -10`

Expected: all green (CoreText branch is byte-identical).

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitModel/src_treeview_layout.swift
git commit -m "$(cat <<'EOF'
feat(treeview): Linux-portable layout via TextMetrics fallback

Lift the file-level canImport(UIKit) || canImport(AppKit) gate so the
TreeView layout compiles on Linux. measureText splits into a CoreText
branch (unchanged) and a Linux branch that routes through
TextMetrics.shared.estimateTextWidth with a 1.2x line-height ratio.
_treeViewFont stays Apple-only behind its own inner gate.

Stage 2.5 — Linux text-measurement shim.
EOF
)"
```

---

## Task 4: Lift EventModeling layout file gate; route `_measureTextDimensions` through `TextMetrics`

**Why:** `src_eventmodeling_layout.swift` is whole-file gated to `#if canImport(CoreText)`. `_measureTextDimensions` uses CoreText directly. Same shape as Task 3 — split the measurement, keep the CoreText helper Apple-only.

**Files:**
- Modify: `Sources/DiagramKitModel/src_eventmodeling_layout.swift:1-2` (header + outer `#if`)
- Modify: `Sources/DiagramKitModel/src_eventmodeling_layout.swift:389-…` (`_measureTextDimensions`)
- Modify: file end (`#endif` placement)

- [ ] **Step 1: Read the full file to confirm CoreText references stay inside `_measureTextDimensions` and the static `fontFamily` getter at line 25**

Run: `grep -n "DiagramFontResolver\|CTFont\|CTLine\|BMFont" Sources/DiagramKitModel/src_eventmodeling_layout.swift`

Expected: references at lines 25 (`fontFamily`) and 396 (`proportionalCTFont`), plus the CoreText measurement around line 389+. The body's `Double` / `CGRect` / structural math stays portable.

- [ ] **Step 2: Replace the file header**

In `Sources/DiagramKitModel/src_eventmodeling_layout.swift`, replace lines 1–6:

```swift
// Apple-only — depends on CoreText. Gated by `#if canImport(CoreText)`.
#if canImport(CoreText)
import Foundation
import CoreGraphics
import DiagramKitCommon
import CoreText
```

with:

```swift
import Foundation
import DiagramKitCommon
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(CoreText)
import CoreText
#endif
```

- [ ] **Step 3: Gate the `fontFamily` static computed property under `#if canImport(CoreText)` only if it references `DiagramFontResolver`**

Locate the static getter around line 25. If it reads:

```swift
static var fontFamily: String { DiagramFontResolver().svgProportionalFamilyChain }
```

replace with:

```swift
#if canImport(CoreText)
static var fontFamily: String { DiagramFontResolver().svgProportionalFamilyChain }
#else
static var fontFamily: String { "Inter, Verdana, sans-serif" }
#endif
```

The `"Inter, Verdana, sans-serif"` literal mirrors `DiagramFontResolver.svgProportionalFamilyChain`'s value (see `DiagramFontResolver.swift:65-67`). Family strings are SVG hints to the consumer; no font instance is created on Linux.

- [ ] **Step 4: Split `_measureTextDimensions` into a CoreText + char-count pair**

Replace the body of `_measureTextDimensions` (currently around line 389) with:

```swift
private func _measureTextDimensions(
    _ text: String,
    fontSize: Double,
    weight: Int = 400
) -> (width: Double, height: Double) {
#if canImport(CoreText)
    let font = DiagramFontResolver().proportionalCTFont(size: CGFloat(fontSize))
    let attr: [NSAttributedString.Key: Any] = [.font: font]
    let attrStr = NSAttributedString(string: text, attributes: attr)
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    return (Double(bounds.width), Double(bounds.height))
#else
    let width = Double(TextMetrics.shared.estimateTextWidth(
        text, fontSize: CGFloat(fontSize), fontWeight: weight))
    let height = fontSize * 1.2
    return (width, height)
#endif
}
```

If the existing CoreText body looks different (different attribute keys, different bounds option), preserve the Apple branch byte-for-byte — only the `#else` is new. Use `git diff` to verify the CoreText branch is unchanged.

- [ ] **Step 5: Drop the file-level `#endif`**

The trailing `#endif` that closes the file-level `#if canImport(CoreText)` is no longer needed — the file no longer has a file-level gate. Delete it from the end of the file.

- [ ] **Step 6: Verify the Apple build is still green**

Run: `swift build --target DiagramKitModel 2>&1 | tail -3`

Expected: `Build of target: 'DiagramKitModel' complete!`, exit 0.

- [ ] **Step 7: Verify EventModeling tests still pass on Apple**

Run: `swift test --filter "EventModeling" 2>&1 | tail -10`

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitModel/src_eventmodeling_layout.swift
git commit -m "$(cat <<'EOF'
feat(eventmodeling): Linux-portable layout via TextMetrics fallback

Lift the file-level canImport(CoreText) gate so the EventModeling
layout compiles on Linux. _measureTextDimensions splits into a CoreText
branch (unchanged) and a Linux branch that routes through
TextMetrics.shared.estimateTextWidth. The static fontFamily getter
returns the literal "Inter, Verdana, sans-serif" chain on Linux,
matching DiagramFontResolver.svgProportionalFamilyChain.

Stage 2.5 — Linux text-measurement shim.
EOF
)"
```

---

## Task 5: Flip `ishikawa` registry to `linuxSupport: true` (TDD)

**Why:** Ishikawa's layout already routes through `TextMetrics.shared.measureMonospaceMultiline` on Linux. Its SVG renderer (`src_ishikawa_renderer.swift`) is already un-gated. Only the registry flag blocks Linux execution. This is the smallest flip in the set — do it first to validate the approach.

**Files:**
- Modify: `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (add new tests)
- Modify: `Sources/DiagramKit/DiagramRegistry+Ishikawa.swift:37-38` (flip flag)

- [ ] **Step 1: Write the failing tests**

Add to `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (inside the existing `LinuxPlatformGateTests` suite, anywhere after the existing tests):

```swift
    // MARK: - Stage 2.5: Linux-supported families

    @Test func ishikawaIsLinuxSupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .ishikawa }
        #expect(descriptor?.linuxSupport == true)
        #expect(descriptor?.linuxUnsupportedReason == nil)
    }

    @Test func ishikawaRenderSVGSucceedsOnLinux() async throws {
        let source = """
        ishikawa
        Problem
            Cause A
                Sub A1
            Cause B
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(svg.hasPrefix("<svg") || svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
        // Structural validity — no NaN serialized into coordinates.
        #expect(!svg.lowercased().contains("nan"))
    }

    @Test func ishikawaRenderASCIISucceedsOnLinux() async throws {
        let source = """
        ishikawa
        Problem
            Cause A
            Cause B
        """
        let output = try await DiagramEngine.renderASCII(source: source)
        #expect(!output.text.isEmpty)
    }
```

- [ ] **Step 2: Run the new tests on Apple — first two should pass, `ishikawaIsLinuxSupported` should fail**

Run: `swift test --filter "ishikawaIsLinuxSupported|ishikawaRenderSVGSucceedsOnLinux|ishikawaRenderASCIISucceedsOnLinux" 2>&1 | tail -20`

Expected on Apple:
- `ishikawaIsLinuxSupported` — FAIL (`linuxSupport == true` not yet); message references the current `false`.
- `ishikawaRenderSVGSucceedsOnLinux` — PASS (Apple goes through CoreText branch).
- `ishikawaRenderASCIISucceedsOnLinux` — PASS.

If `ishikawaRenderSVGSucceedsOnLinux` fails on Apple, debug the test (the source might need adjustment) before flipping the flag.

- [ ] **Step 3: Flip the registry flag**

In `Sources/DiagramKit/DiagramRegistry+Ishikawa.swift:37-38`, replace:

```swift
        linuxSupport: false,
        linuxUnsupportedReason: "requires CoreText text-measurement"
```

with:

```swift
        linuxSupport: true
```

(Drop the `linuxUnsupportedReason` field entirely; default is `nil`.)

- [ ] **Step 4: Re-run the three new tests — all should pass**

Run: `swift test --filter "ishikawaIsLinuxSupported|ishikawaRenderSVGSucceedsOnLinux|ishikawaRenderASCIISucceedsOnLinux" 2>&1 | tail -20`

Expected: 3/3 PASS.

- [ ] **Step 5: Verify no broader Apple regression**

Run: `swift test --filter "Ishikawa" 2>&1 | tail -10`

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKit/DiagramRegistry+Ishikawa.swift Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift
git commit -m "$(cat <<'EOF'
feat(ishikawa): linuxSupport = true

The Ishikawa layout has always routed measurement through TextMetrics
on Linux via _measureIshikawaText's #else branch; the SVG renderer is
un-gated. Only the registry flag was blocking. Flip and pin with
three new tests in LinuxPlatformGateTests: descriptor flag, renderSVG
success + NaN scan, renderASCII success.

Stage 2.5 — Linux text-measurement shim.
EOF
)"
```

---

## Task 6: Flip `treeView` registry to `linuxSupport: true` (TDD)

**Why:** After Tasks 2 + 3 lifted the renderer and layout gates, TreeView is mechanically ready for Linux. Flip the flag and pin.

**Files:**
- Modify: `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (add new tests)
- Modify: `Sources/DiagramKit/DiagramRegistry+TreeView.swift:42-43` (flip flag)

- [ ] **Step 1: Write the failing tests**

Append to `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift`:

```swift
    @Test func treeViewIsLinuxSupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .treeView }
        #expect(descriptor?.linuxSupport == true)
        #expect(descriptor?.linuxUnsupportedReason == nil)
    }

    @Test func treeViewRenderSVGSucceedsOnLinux() async throws {
        let source = """
        treeView
        root
            child1
            child2
                grandchild
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
        #expect(!svg.lowercased().contains("nan"))
    }

    @Test func treeViewRenderASCIISucceedsOnLinux() async throws {
        let source = """
        treeView
        root
            child1
            child2
        """
        let output = try await DiagramEngine.renderASCII(source: source)
        #expect(!output.text.isEmpty)
    }
```

- [ ] **Step 2: Run the new tests — first should fail, last two should pass on Apple**

Run: `swift test --filter "treeViewIsLinuxSupported|treeViewRenderSVGSucceedsOnLinux|treeViewRenderASCIISucceedsOnLinux" 2>&1 | tail -20`

Expected:
- `treeViewIsLinuxSupported` — FAIL.
- `treeViewRenderSVGSucceedsOnLinux` — PASS on Apple.
- `treeViewRenderASCIISucceedsOnLinux` — PASS on Apple.

If a TreeView source-string test fails on Apple, adjust the fixture source until the parser is happy.

- [ ] **Step 3: Flip the registry flag**

In `Sources/DiagramKit/DiagramRegistry+TreeView.swift:42-43`, replace:

```swift
        linuxSupport: false,
        linuxUnsupportedReason: "requires CoreText text-measurement"
```

with:

```swift
        linuxSupport: true
```

- [ ] **Step 4: Re-run the three tests — all should pass**

Run: `swift test --filter "treeViewIsLinuxSupported|treeViewRenderSVGSucceedsOnLinux|treeViewRenderASCIISucceedsOnLinux" 2>&1 | tail -20`

Expected: 3/3 PASS.

- [ ] **Step 5: Verify no broader Apple regression**

Run: `swift test --filter "TreeView" 2>&1 | tail -10`

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKit/DiagramRegistry+TreeView.swift Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift
git commit -m "$(cat <<'EOF'
feat(treeview): linuxSupport = true

Tasks 2 + 3 made the renderer un-gated and routed measureText through
TextMetrics on Linux. Flip the registry flag and pin with three new
tests: descriptor flag, renderSVG success + NaN scan, renderASCII
success.

Stage 2.5 — Linux text-measurement shim.
EOF
)"
```

---

## Task 7: Flip `eventModeling` registry to `linuxSupport: true` (TDD)

**Why:** After Task 4 lifted the layout gate, EventModeling is mechanically ready. (Its SVG renderer is already un-gated — confirmed in the file structure audit.) Flip the flag and pin.

**Files:**
- Modify: `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (add new tests)
- Modify: `Sources/DiagramKit/DiagramRegistry+EventModeling.swift:43-44` (flip flag)

- [ ] **Step 1: Write the failing tests**

Append to `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift`:

```swift
    @Test func eventModelingIsLinuxSupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .eventModeling }
        #expect(descriptor?.linuxSupport == true)
        #expect(descriptor?.linuxUnsupportedReason == nil)
    }

    @Test func eventModelingRenderSVGSucceedsOnLinux() async throws {
        let source = """
        eventModeling
            event "Order Placed"
            command "Place Order"
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
        #expect(!svg.lowercased().contains("nan"))
    }

    @Test func eventModelingRenderASCIISucceedsOnLinux() async throws {
        let source = """
        eventModeling
            event "Order Placed"
            command "Place Order"
        """
        let output = try await DiagramEngine.renderASCII(source: source)
        #expect(!output.text.isEmpty)
    }
```

If the EventModeling source syntax above isn't accepted by the current parser, copy a minimal fixture from any `eventmodeling-*` entry in `Examples/DiagramPlayground/Resources/test-diagrams.json`.

- [ ] **Step 2: Run the new tests — first should fail, last two should pass on Apple**

Run: `swift test --filter "eventModelingIsLinuxSupported|eventModelingRenderSVGSucceedsOnLinux|eventModelingRenderASCIISucceedsOnLinux" 2>&1 | tail -20`

Expected:
- `eventModelingIsLinuxSupported` — FAIL.
- `eventModelingRenderSVGSucceedsOnLinux` — PASS on Apple.
- `eventModelingRenderASCIISucceedsOnLinux` — PASS on Apple.

If a renderSVG test fails on Apple with parse error, swap the literal source for one of the corpus fixtures.

- [ ] **Step 3: Flip the registry flag**

In `Sources/DiagramKit/DiagramRegistry+EventModeling.swift:43-44`, replace:

```swift
        linuxSupport: false,
        linuxUnsupportedReason: "requires CoreText text-measurement"
```

with:

```swift
        linuxSupport: true
```

- [ ] **Step 4: Re-run the three tests — all should pass**

Run: `swift test --filter "eventModelingIsLinuxSupported|eventModelingRenderSVGSucceedsOnLinux|eventModelingRenderASCIISucceedsOnLinux" 2>&1 | tail -20`

Expected: 3/3 PASS.

- [ ] **Step 5: Verify no broader Apple regression**

Run: `swift test --filter "EventModeling" 2>&1 | tail -10`

Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKit/DiagramRegistry+EventModeling.swift Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift
git commit -m "$(cat <<'EOF'
feat(eventmodeling): linuxSupport = true

Task 4 routed _measureTextDimensions through TextMetrics on Linux.
The SVG renderer was already un-gated. Flip the registry flag and
pin with three new tests: descriptor flag, renderSVG success + NaN
scan, renderASCII success.

Stage 2.5 — Linux text-measurement shim. All three formerly-CoreText-
bound families now supported on Linux.
EOF
)"
```

---

## Task 8: Rewrite `LinuxPlatformGateTests` — delete obsolete cases, add lock-down

**Why:** With all three families flipped, eight tests in `LinuxPlatformGateTests` pin a contract that no longer holds (the three families' `linuxSupport == false` and their throw paths). They need to be deleted. The cohort `exactlyThreeFamiliesAreLinuxUnsupported` is replaced with `exactlyZeroFamiliesAreLinuxUnsupported` to lock down the new shape.

**Files:**
- Modify: `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift`

- [ ] **Step 1: Read the current file and identify tests to delete**

Run: `grep -n "@Test func" Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift`

Identify lines for these eight tests:
- `ishikawaIsLinuxUnsupported`
- `treeViewIsLinuxUnsupported`
- `eventModelingIsLinuxUnsupported`
- `exactlyThreeFamiliesAreLinuxUnsupported`
- `linuxSupportReturnsFalseForIshikawa`
- `linuxSupportReportsAllThreeUnsupported`
- `pipelineRenderSVGGatesIshikawaOnLinux`
- `engineRenderSVGGatesIshikawaOnLinux`

- [ ] **Step 2: Delete the eight obsolete tests**

In `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift`, delete each `@Test func <name>(...) { ... }` block listed above. Preserve every other test in the file.

- [ ] **Step 3: Add the new lock-down test**

In `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (near the top, around where `exactlyThreeFamiliesAreLinuxUnsupported` used to live), add:

```swift
    @Test func exactlyZeroFamiliesAreLinuxUnsupported() {
        let unsupported = DiagramRegistry.all.filter { !$0.linuxSupport }.map(\.type)
        #expect(unsupported.isEmpty, "Expected zero linuxSupport==false families, got: \(unsupported)")
    }
```

This catches any regression where someone re-introduces a CoreText-bound family without also providing a Linux fallback path.

- [ ] **Step 4: Run the full LinuxPlatformGateTests suite — verify clean**

Run: `swift test --filter "LinuxPlatformGate" 2>&1 | tail -20`

Expected: all remaining tests pass. The original 12-test suite shrinks to (12 − 8 + 1 + 9 new tests from tasks 5/6/7) = 14 tests.

- [ ] **Step 5: Commit**

```bash
git add Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift
git commit -m "$(cat <<'EOF'
test(linux): delete obsolete gate tests; add zero-unsupported lockdown

Stage 2.5 made the three formerly-CoreText-bound families Linux-
supported. The eight tests pinning their unsupported state and throw
contract (ishikawa/treeView/eventModeling Unsupported, exactlyThree*,
linuxSupportReturnsFalseForIshikawa, the parameterized
reportsAllThreeUnsupported, the two pipeline/engine RenderSVGGates*)
are deleted. New exactlyZeroFamiliesAreLinuxUnsupported locks down
the post-Stage-2.5 invariant.

Stage 2.5 — Linux text-measurement shim.
EOF
)"
```

---

## Task 9: Doc sync — `CLAUDE.md` + `Dockerfile.linux-check` header

**Why:** `CLAUDE.md`'s "Linux Portability" section says ishikawa/treeView/eventModeling throw on Linux; the portable text-measurement shim is "a deferred follow-up." `Dockerfile.linux-check`'s header comment names this as Stage 2.5. Both need updating. Test source count also bumps (no new test files; only tests added inside an existing file — count stays).

**Files:**
- Modify: `CLAUDE.md` ("Linux Portability" section, ~line 295–310)
- Modify: `Dockerfile.linux-check` (header comment block, ~lines 18–24)
- Modify: `REVIEW.md` (add Session 15 entry)

- [ ] **Step 1: Update `CLAUDE.md` Linux Portability section**

In `CLAUDE.md`, locate the "Linux Portability" section. Replace the paragraph that says:

```
Families that depend on CoreText measurement (`ishikawa`, `treeView`,
`eventModeling`) throw `DiagramError.unsupportedOnPlatform(family:reason:platform:)`
on Linux; `DiagramDescriptor.linuxSupport: Bool` is the per-family flag
and `DiagramEngine.linuxSupport(for:)` is the public introspection API.

The portable text-measurement shim for `ishikawa`, `treeView`, and
`eventModeling` remains a deferred follow-up.
```

with:

```
All 28 diagram families are Linux-supported as of Stage 2.5.
`DiagramDescriptor.linuxSupport: Bool` is the per-family flag and
`DiagramEngine.linuxSupport(for:)` is the public introspection API —
both currently return `true` / `(true, nil)` for every family in the
default registry. The throw case `DiagramError.unsupportedOnPlatform`
remains as the protocol contract for third-party importers that
declare unsupported families in custom registries.

On Linux, text measurement for `ishikawa`, `treeView`, and
`eventModeling` falls back to `TextMetrics.shared.estimateTextWidth`'s
char-count estimation (0.55× / 0.6× fontSize per character). Output is
geometrically valid (no NaN, positive widths/heights) but not
pixel-equivalent to Apple's CoreText measurement. No Linux-specific
snapshot baselines are recorded.
```

- [ ] **Step 2: Update `Dockerfile.linux-check` header comment**

In `Dockerfile.linux-check`, locate the header comment block that says:

```dockerfile
# Functional Linux layout/rendering for layouts that depend on text
# measurement (CTLineGetBoundsWithOptions) is deferred — the call sites
# throw DiagramError.unsupportedOnPlatform on Linux for ishikawa,
# treeView, and eventModeling. A portable text-measurement shim is the
# Stage 2.5 follow-up.
```

Replace with:

```dockerfile
# All 28 diagram families are Linux-supported as of Stage 2.5 (see
# docs/superpowers/specs/2026-05-15-linux-text-measurement-shim-design.md).
# Text-measurement on Linux falls back to TextMetrics.shared's
# char-count estimation for ishikawa, treeView, and eventModeling —
# geometrically valid but not pixel-equivalent to Apple's CoreText.
```

- [ ] **Step 3: Add a Session 15 entry to `REVIEW.md`**

In `REVIEW.md`, after the "Resolution Status — Session 14" section, append a new section. Use the same table-driven format as prior sessions. Suggested content:

```markdown
## Resolution Status — Session 15 (2026-05-15)

Closes the CLAUDE.md deferred follow-up: portable text-measurement shim
for `ishikawa`, `treeView`, and `eventModeling`. Spec at
`docs/superpowers/specs/2026-05-15-linux-text-measurement-shim-design.md`;
plan at `docs/superpowers/plans/2026-05-15-linux-text-measurement-shim.md`.
N commits on `main`.

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | TextMetrics inline-gate | <hash> | DiagramFontResolver field gated under canImport(CoreText); Linux build no longer broken by unconditional reference. |
| 2 | TreeView renderer gate lift | <hash> | Stale file-level Apple gate removed; body was pure SVG-string emission. |
| 3 | TreeView layout gate lift | <hash> | File-level UIKit/AppKit gate replaced with inner measureText branch; _treeViewFont stays Apple-gated. |
| 4 | EventModeling layout gate lift | <hash> | File-level CoreText gate replaced with _measureTextDimensions branch; fontFamily literal "Inter, Verdana, sans-serif" on Linux. |
| 5 | Ishikawa linuxSupport=true | <hash> | Three new tests (descriptor flag, renderSVG, renderASCII). |
| 6 | TreeView linuxSupport=true | <hash> | Three new tests. |
| 7 | EventModeling linuxSupport=true | <hash> | Three new tests. |
| 8 | Gate test cleanup | <hash> | Eight obsolete tests deleted; exactlyZeroFamiliesAreLinuxUnsupported added. |
| 9 | Docs sync | _this commit_ | CLAUDE.md Linux Portability rewritten; Dockerfile.linux-check header updated; REVIEW.md Session 15 entry. |

Session-end verification: targeted `swift test --filter` across LinuxPlatformGate, Ishikawa, TreeView, EventModeling, TextMetrics suites all green on Apple. `Scripts/linux-check.sh` recorded as environment-skipped (no Docker daemon locally) — container verification deferred to CI or a follow-up session.

---
```

Fill the `<hash>` placeholders by reading the commit hashes after each task lands (`git log --oneline -10`).

- [ ] **Step 4: Verify nothing accidentally broke**

Run: `swift test --filter "LinuxPlatformGate|Ishikawa|TreeView|EventModeling" 2>&1 | tail -10`

Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md Dockerfile.linux-check REVIEW.md
git commit -m "$(cat <<'EOF'
docs: sync CLAUDE.md + Dockerfile + REVIEW.md for Stage 2.5

All 28 families Linux-supported. CLAUDE.md "Linux Portability" no
longer mentions the deferred shim; Dockerfile.linux-check header
references the design doc instead of the deferral; REVIEW.md gains
the Session 15 entry mapping commits to tasks.

Stage 2.5 — Linux text-measurement shim.
EOF
)"
```

---

## Self-Review Notes

**Spec coverage:**
- "Inline-gate `TextMetrics.fontResolver`" → Task 1 ✓
- "Lift file gates on TreeView + EventModeling layouts" → Tasks 3, 4 ✓
- "Route measurement through `TextMetrics`" → Tasks 3, 4 ✓
- "Audit SVG renderers" → Task 2 (TreeView only — Ishikawa + EventModeling renderers already un-gated, verified in spec-writing phase) ✓
- "Flip three `linuxSupport` flags" → Tasks 5, 6, 7 ✓
- "Update `LinuxPlatformGateTests`" → Tasks 5, 6, 7 (add) + Task 8 (delete + lockdown) ✓
- "Doc sync" → Task 9 ✓

**Placeholder scan:** none — every step ships concrete code or a concrete file edit.

**Type consistency:** `linuxSupport` / `linuxUnsupportedReason` / `DiagramRegistry.all` / `DiagramDescriptor` / `DiagramError.unsupportedOnPlatform` / `DiagramEngine.linuxSupport(for:)` / `TextMetrics.shared.estimateTextWidth` — names match Session 14's landings (verified against repo).

**Out-of-band risks accepted:**
- The container run is environment-skipped locally. Tasks 5–7's renderSVG / renderASCII tests pass on Apple immediately — that's regression insurance for the CoreText branch but it doesn't *prove* the Linux branch works. CI / a follow-up container session will provide that proof.
- If the Apple-side test source string for TreeView or EventModeling doesn't parse cleanly, the plan says to swap in a corpus fixture from `test-diagrams.json`. This is a known-good fallback.

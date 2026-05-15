# Linux SVG / ASCII Parity for `DiagramEngine`

**Status:** Approved (brainstorming, 2026-05-15)
**Closes:** REVIEW.md → Cross-cutting Observation #5 + Critical "Public API contract holes" (`DiagramEngine.renderSVG` / `renderASCII` Linux gating).

---

## Problem

`DiagramEngine.renderSVG`, `renderASCII`, and `parseImportResult` are wrapped in `#if canImport(CoreGraphics)` at `Sources/DiagramKit/DiagramEngine.swift:118–162`, and the matching `String.renderDiagramSVG` / `String.renderDiagramASCII` extensions at lines 211–228 carry the same gate. The underlying `DiagramPipeline.renderSVG` and `DiagramPipeline.renderASCII` are NOT gated and depend only on `DiagramKitModel` + `DiagramKitCommon`, both Linux-portable per CLAUDE.md's "Target Layout" map. `_runOnWorker` already has a Linux fresh-`Thread` fallback (`DiagramEngine.swift:177–192`), so the gates are unnecessary for everything except `renderImage`.

The story today:
- ARCHITECTURE.md advertises SVG/ASCII on Linux.
- The async public facade can't reach them on Linux.
- Three families (`ishikawa`, `treeView`, `eventModeling`) depend on CoreText measurement and would lay out incorrectly on Linux if invoked.

## Goal

1. Expose `DiagramEngine.renderSVG`, `renderASCII`, `parseImportResult` and the matching `String` extensions on Linux.
2. Give callers a typed, predictable failure for the 3 families that can't lay out on Linux, with a public introspection API so hosts can pre-check.
3. Keep image rendering (`DiagramEngine.renderImage`, `String.renderDiagramImage`) Apple-only — genuinely CG-bound.

## Non-goals

- Closing the text-measurement shim itself (so `ishikawa`/`treeView`/`eventModeling` actually work on Linux). That is a separate follow-on spec (CLAUDE.md:293–294 deferred follow-up).
- Re-auditing the other 25 families to verify they really lay out cleanly on Linux. The current `linux-check.sh` build pass plus CLAUDE.md's portability claim is the working assumption; the `linuxSupport` flag is the escape hatch if any of them later turn out broken.
- Touching the image renderer.

## Design

### Per-family Linux declaration

Two additive, defaulted fields on `DiagramDescriptor` (`Sources/DiagramKit/DiagramDescriptor.swift:87`):

```swift
public let linuxSupport: Bool
public let linuxUnsupportedReason: String?

public init(
    type: DiagramType,
    matches: @escaping @Sendable (DiagramHeader) -> Bool,
    parse: @escaping @Sendable (String, DiagramFrontmatter?) throws -> (DiagramDocument, [DiagramDiagnostic]),
    layout: @escaping @Sendable (DiagramDocument, LayoutConfig) throws -> (PositionedGraph, [DiagramDiagnostic]),
    linuxSupport: Bool = true,
    linuxUnsupportedReason: String? = nil
) {
    self.type = type
    self.matches = matches
    self.parse = parse
    self.layout = layout
    self.linuxSupport = linuxSupport
    self.linuxUnsupportedReason = linuxUnsupportedReason
}
```

Defaulted to `true` / `nil`. Three descriptor files set them to `false`:

| Family | File | Reason |
|---|---|---|
| `ishikawa` | `DiagramRegistry+Ishikawa.swift` | "requires CoreText text-measurement" |
| `treeView` | `DiagramRegistry+TreeView.swift` | "requires CoreText text-measurement" |
| `eventModeling` | `DiagramRegistry+EventModeling.swift` | "requires CoreText text-measurement" |

### New error case

`DiagramError` in `Sources/DiagramKitModel/Types.swift:763` gains:

```swift
case unsupportedOnPlatform(family: DiagramType, reason: String, platform: String)
```

`errorDescription`:

```
"<family.rawValue> layout is not supported on <platform>: <reason>"
```

`platform` is the runtime platform name (e.g. `"Linux"`); passing it explicitly keeps the error self-describing for hosts that log/render the error without re-deriving the platform.

### Enforcement point

`DiagramPipeline.renderSVG` (`Sources/DiagramKit/DiagramPipeline.swift:142`) and `DiagramPipeline.renderASCII` (line 212) each call a new private helper after `loadDocument` returns the parsed document:

```swift
private static func _assertPlatformSupport(_ document: DiagramDocument) throws {
    #if os(Linux)
    let descriptor = try DiagramRegistry.descriptor(for: document.type)
    if !descriptor.linuxSupport {
        throw DiagramError.unsupportedOnPlatform(
            family: document.type,
            reason: descriptor.linuxUnsupportedReason ?? "no reason provided",
            platform: "Linux"
        )
    }
    #endif
}
```

`renderSVG(positioned:)` (the pre-positioned variant, line 179) ALSO calls `_assertPlatformSupport(positioned.diagram)` — same chokepoint discipline, even though the caller already did the work to produce `PositionedGraph`. Belt-and-braces; cheap.

`parseImportResult` does NOT gate. Parsing is portable; only layout/render measurement matters. Hosts that want the document for inspection can get it on Linux.

`DiagramPipeline.layout(_:)` direct callers are out of scope — they bypass the gate by design (this is the "Approach 1" trade-off; if a 4th family becomes Linux-broken it's the same migration path).

### Gate removal

Gates need to come off at TWO levels — `DiagramEngine` (the async facade) and `DiagramPipeline` (the sync implementation it dispatches to). Without the `DiagramPipeline` fix, the `DiagramEngine` async fns reference funcs that don't exist on Linux.

**`Sources/DiagramKit/DiagramPipeline.swift`** — the `#if canImport(CoreGraphics)` block at lines 115–230 over-gates: it wraps `prepare` (which legitimately needs `PreparedDiagram` from `DiagramKitRenderingCG`) AND `renderSVG` / `renderSVG(positioned:)` / `renderASCII` (which don't). Split the block:
- Keep a tight `#if canImport(CoreGraphics)` / `#endif` around `prepare` (lines 118–133) only.
- Pull `renderSVG` (142–175), `renderSVG(positioned:)` (179–208), and `renderASCII` (212–229) out of the gate. Their bodies use only `DiagramKitModel` / `DiagramKitCommon` symbols (`loadDocument`, `GraphLayout`, `DiagramColors`, `DiagramFontResolver`, `SVGIDGenerator`, `SVGRenderRegistry`, `original_src_ascii_index.*`) — all Linux-portable.

**`Sources/DiagramKit/DiagramEngine.swift`** — two `#if canImport(CoreGraphics)` / `#endif` blocks get removed:
- Lines 118–162: wraps `DiagramEngine.renderSVG`, `renderASCII`, and `parseImportResult` (three funcs in one block).
- Lines 211–228: wraps `String.renderDiagramSVG` and `String.renderDiagramASCII` (two funcs in one block).

Everything else stays unchanged. In particular:
- The import gate at `DiagramEngine.swift:4` (`#if canImport(CoreGraphics) import DiagramKitRenderingCG #endif`) stays — `renderSVG`/`renderASCII` paths don't use `DiagramKitRenderingCG`.
- The `prepare` / `parse` / `renderImage` gates and the Apple variant of `_runOnWorker` stay.
- `String.renderDiagramImage` (lines 201–209) stays gated — it's genuinely CG-bound.
- The `_DiagramPreparerBootstrap.didInstall` bootstrap call inside `parse` (line 42) and `layout` (line 55) stays gated — it's CG-bound; the un-gated `renderSVG`/`renderASCII`/`parseImportResult` bodies will only call it under `#if canImport(CoreGraphics)`.

### Introspection API

New public static fn on `DiagramEngine`:

```swift
/// Returns whether `family` is supported on Linux, and if not, the human-readable reason.
/// On non-Linux platforms always returns `(true, nil)`.
public static func linuxSupport(for family: DiagramType) -> (supported: Bool, reason: String?) {
    guard let descriptor = DiagramRegistry.all.first(where: { $0.type == family }) else {
        return (true, nil)
    }
    return (descriptor.linuxSupport, descriptor.linuxUnsupportedReason)
}
```

Implementation note: returns `(true, nil)` for unknown families rather than throwing — callers asking "is this Linux-safe?" should get a yes for anything the engine doesn't recognize, since no rendering would happen anyway.

## Data flow

```
async DiagramEngine.renderSVG(source:)
  └─ _runOnWorker { try DiagramPipeline.renderSVG(source:) }
                                  │
                                  ▼
                          loadDocument(source) → DiagramDocument
                                  │
                                  ▼
                          _assertPlatformSupport(document)
                            ├─ #if os(Linux):
                            │     descriptor.linuxSupport == false
                            │       → throw DiagramError.unsupportedOnPlatform(...)
                            │     descriptor.linuxSupport == true → continue
                            └─ #else: no-op
                                  │
                                  ▼
                          GraphLayout(...).layout(graph)
                                  │
                                  ▼
                          SVGRenderRegistry.render(...)
                                  │
                                  ▼
                          _resolveSvgCssVariables / _flattenKnownSvgTokens
```

`renderASCII` is the same shape with the ASCII registry as the final step.

## Testing

### New Linux-portable test target

The existing `DiagramKitTests` target depends on `DiagramKitInteractive` and `DiagramPlayground` unconditionally (`Package.swift:212, 214`); both are Apple-bound in practice. `Dockerfile.linux-check` never builds or runs the test target today, so its Linux-buildability is currently unverified. Auditing every test file for Linux-portability is out of scope.

This spec adds a new `.testTarget(name: "DiagramKitLinuxTests", ...)` with only Linux-portable deps:

```swift
.testTarget(
    name: "DiagramKitLinuxTests",
    dependencies: [
        "DiagramKit",
        "DiagramKitCommon",
        "DiagramKitModel",
        "DiagramKitTestSupport",
    ],
    swiftSettings: strictConcurrencySettings
)
```

The target compiles on every platform the package targets, but the tests it carries are scoped to the platform-gate contract.

### Coverage

New file `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (Linux-portable, uses swift-testing). Coverage:

1. **Introspection — supported family.** `DiagramEngine.linuxSupport(for: .flowchart)` returns `(true, nil)` on every platform.
2. **Introspection — unsupported family.** `DiagramEngine.linuxSupport(for: .ishikawa)` returns `(false, .some)` on every platform; the reason string is non-empty.
3. **Introspection — all three families.** Sweep `[.ishikawa, .treeView, .eventModeling]` — each is `(false, .some)`.
4. **Introspection — registry coverage.** Walk `DiagramRegistry.all`; assert that exactly the 3 known families have `linuxSupport == false`. Locks the policy from silently drifting.
5. **Throw path (Linux only, gated by `#if os(Linux)`).** `try await DiagramEngine.renderSVG(source: "ishikawa\n...minimal valid body")` throws; switch on the error and assert it's `.unsupportedOnPlatform(family: .ishikawa, reason: _, platform: "Linux")`.
6. **No-throw path (non-Linux, gated by `#if !os(Linux)`).** Same call on macOS does NOT throw `.unsupportedOnPlatform` (it may throw for other reasons — bad fixture — but specifically not the platform error).
7. **`parseImportResult` does not gate.** `try await DiagramEngine.parseImportResult(source: "ishikawa\n...")` succeeds on every platform, including Linux. The returned document has `type == .ishikawa`.

### CI wiring

`Dockerfile.linux-check` build matrix gains `DiagramKitLinuxTests` to its target sweep. A second `RUN` step adds `swift test --filter LinuxPlatformGateTests` — the first time a Linux test fires from CI on this repo. `Scripts/linux-check.sh` itself stays unchanged; it already invokes the Dockerfile.

CLAUDE.md test source count syncs by +1; CLAUDE.md "Target Layout" gains the new test target in the right column.

## Migration / breaking change risk

- `DiagramDescriptor.init` gains two defaulted params — non-breaking for any in-tree call site (none use positional init for the new fields).
- `DiagramError.unsupportedOnPlatform` is an additive case. Any third-party `switch self` on `DiagramError` without a `@unknown default` will get a compile warning; that's the existing precedent the enum already follows (it has no `@unknown default` reqs).
- `DiagramEngine.renderSVG`/`renderASCII`/`parseImportResult` becoming available on Linux is a strictly-additive surface change for Linux callers; Apple callers see no diff.
- `String.renderDiagramSVG`/`String.renderDiagramASCII` likewise additive on Linux.

No deprecations needed.

## Implementation order (preview)

The implementation plan will land in commit-by-commit-on-main order per the project's standing default. Sketch:

1. `DiagramError.unsupportedOnPlatform(family:reason:platform:)` case + LocalizedError text.
2. `DiagramDescriptor` two new fields + default init; thread defaults through all four `_typed` overloads in `DiagramRegistry+TypedDescriptor.swift`.
3. Three family descriptors flipped (`+Ishikawa`, `+TreeView`, `+EventModeling`).
4. Split the `#if canImport(CoreGraphics)` block in `DiagramPipeline.swift` so `renderSVG` (both overloads) and `renderASCII` are no longer gated; `prepare` stays gated.
5. `_assertPlatformSupport` helper in `DiagramPipeline`, called from `renderSVG` (both overloads) and `renderASCII`.
6. `DiagramEngine.linuxSupport(for:)` public API.
7. Drop the 2 `#if canImport(CoreGraphics)` blocks on `DiagramEngine`'s async facades and the `String` extensions.
8. Add `.testTarget(name: "DiagramKitLinuxTests")` to `Package.swift`.
9. New `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (7 tests).
10. Extend `Dockerfile.linux-check` to build `DiagramKitLinuxTests` and run `swift test --filter LinuxPlatformGateTests`.
11. CLAUDE.md test count + "Target Layout" sync; REVIEW.md Session entry.

Per-step diagnostic/verification details come in the writing-plans pass.

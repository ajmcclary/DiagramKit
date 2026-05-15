# Linux SVG / ASCII Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose `DiagramEngine.renderSVG` / `renderASCII` / `parseImportResult` and the matching `String` extensions on Linux, with a typed-error contract for the three families that need CoreText measurement (`ishikawa`, `treeView`, `eventModeling`), and a public introspection API.

**Architecture:** Drop the `#if canImport(CoreGraphics)` gates at both `DiagramEngine` and `DiagramPipeline` levels (splitting the over-gated pipeline block so `prepare` stays Apple-only and `renderSVG`/`renderASCII` become portable). Add `linuxSupport: Bool` + `linuxUnsupportedReason: String?` to `DiagramDescriptor`, threaded through all four `_typed` factory overloads. Enforce via a private `_assertPlatformSupport(_:)` helper called from `DiagramPipeline.renderSVG` (both overloads) and `renderASCII` after parse. Land a new small `DiagramKitLinuxTests` test target so CI proves the Linux contract end-to-end via `Dockerfile.linux-check`.

**Tech Stack:** Swift 6 (strict concurrency), swift-testing, SwiftPM test targets, Docker/Podman + `swift:6.3.1-noble` for Linux CI.

---

## File Structure

**Create:**
- `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` — new portable test suite carrying the introspection + throw-path + parse-doesn't-gate tests.

**Modify:**
- `Sources/DiagramKitModel/Types.swift` — add `DiagramError.unsupportedOnPlatform(family:reason:platform:)` case + `errorDescription`.
- `Sources/DiagramKit/DiagramDescriptor.swift` — add `linuxSupport: Bool` and `linuxUnsupportedReason: String?` stored properties + default-valued init params.
- `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift` — thread `linuxSupport` / `linuxUnsupportedReason` defaults through all four `_typed` overloads.
- `Sources/DiagramKit/DiagramRegistry+Ishikawa.swift` — pass `linuxSupport: false, linuxUnsupportedReason: "requires CoreText text-measurement"` to `_typed(...)`.
- `Sources/DiagramKit/DiagramRegistry+TreeView.swift` — same flip.
- `Sources/DiagramKit/DiagramRegistry+EventModeling.swift` — same flip.
- `Sources/DiagramKit/DiagramPipeline.swift` — split the `#if canImport(CoreGraphics)` block at lines 115–230 so `prepare` stays gated and `renderSVG` (both overloads) + `renderASCII` are pulled out; add `_assertPlatformSupport(_:)` helper and call it from those three funcs after `loadDocument`.
- `Sources/DiagramKit/DiagramEngine.swift` — drop the two `#if canImport(CoreGraphics)` blocks at lines 118–162 (renderSVG / renderASCII / parseImportResult) and 211–228 (String.renderDiagramSVG / renderDiagramASCII); add `linuxSupport(for:)` static fn.
- `Package.swift` — add `.testTarget(name: "DiagramKitLinuxTests")` with Linux-portable deps.
- `Dockerfile.linux-check` — extend build matrix to include the new test target; add a second `RUN` step that runs `swift test --filter LinuxPlatformGateTests`.
- `CLAUDE.md` — sync test source count (+1) and add the new test target to the "Target Layout" right column.

**Test:**
- `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` carries every test in this plan. The existing `Tests/DiagramKitTests/` directory is not touched.

---

## Task 1: Scaffold the new test target

**Files:**
- Modify: `Package.swift:204-225` (add a sibling `.testTarget` after `DiagramKitTests`)
- Create: `Tests/DiagramKitLinuxTests/Placeholder.swift`

This task lands the empty target so later tasks can add tests to it without churning `Package.swift` multiple times.

- [ ] **Step 1: Add the test target to Package.swift**

Open `Package.swift`. After the closing `)` of the existing `.testTarget(name: "DiagramKitTests", ...)` block (currently ends at line 225 with `)`), insert a new sibling test target. The trailing `]` of `targets:` at line 226 must move down. Result:

```swift
        .testTarget(
            name: "DiagramKitTests",
            dependencies: [
                "DiagramKit",
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitExport",
                "DiagramKitMermaid",
                "DiagramKitInteractive",
                "DiagramKitTestSupport",
                "DiagramPlayground",
                "DiagramKitD2",
                "DiagramKitGraphviz",
                "DiagramKitStructurizr",
                "DiagramKitPlantUML",
                .target(name: "DiagramKitRenderingCG", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"],
            swiftSettings: strictConcurrencySettings
        ),
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
    ],
    swiftLanguageModes: [.v6]
)
```

Note: the existing `DiagramKitTests` block's closing paren now needs a trailing comma (was `)` at line 225, becomes `),`). Don't forget.

- [ ] **Step 2: Create the placeholder test file**

Write `Tests/DiagramKitLinuxTests/Placeholder.swift`:

```swift
import Testing

@Suite("DiagramKitLinuxTests placeholder")
struct DiagramKitLinuxTestsPlaceholder {
    @Test func targetCompiles() {
        #expect(true)
    }
}
```

- [ ] **Step 3: Verify the new target builds**

Run: `swift package resolve && swift build --target DiagramKitLinuxTests`
Expected: `Build complete!` with no errors.

- [ ] **Step 4: Verify the placeholder test passes**

Run: `swift test --filter DiagramKitLinuxTestsPlaceholder`
Expected: `Test Suite "DiagramKitLinuxTests placeholder" passed` (1/1 passing).

- [ ] **Step 5: Commit**

```bash
git add Package.swift Tests/DiagramKitLinuxTests/Placeholder.swift
git commit -m "$(cat <<'EOF'
test(linux): scaffold DiagramKitLinuxTests target

New small SPM test target with only Linux-portable deps (DiagramKit,
DiagramKitCommon, DiagramKitModel, DiagramKitTestSupport). Will carry
the Linux platform-gate tests landed in subsequent commits. Placeholder
test ensures the target compiles and the test discovery sees it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `DiagramError.unsupportedOnPlatform` case

**Files:**
- Modify: `Sources/DiagramKitModel/Types.swift:763-783`
- Test: `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (create)

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift`:

```swift
import Testing
import DiagramKit
import DiagramKitCommon
import DiagramKitModel

@Suite("Linux platform gate")
struct LinuxPlatformGateTests {

    // MARK: - DiagramError.unsupportedOnPlatform

    @Test func unsupportedOnPlatformErrorDescription() {
        let error = DiagramError.unsupportedOnPlatform(
            family: .ishikawa,
            reason: "requires CoreText text-measurement",
            platform: "Linux"
        )
        #expect(error.errorDescription == "ishikawa layout is not supported on Linux: requires CoreText text-measurement")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LinuxPlatformGateTests/unsupportedOnPlatformErrorDescription`
Expected: build failure with `type 'DiagramError' has no member 'unsupportedOnPlatform'`.

- [ ] **Step 3: Add the case**

In `Sources/DiagramKitModel/Types.swift`, change the `DiagramError` enum body. The current text is at lines 763–783:

```swift
public enum DiagramError: Error, LocalizedError {
    case notYetImplemented(String)
    /// No importer claimed the source. Distinct from `notYetImplemented`
    /// (which signals an implementation gap) — `unrecognizedFormat` means
    /// the input did not match any registered format probe.
    case unrecognizedFormat(String)
    /// The source matched a format probe but the body could not be parsed.
    /// Carries a human-readable description of the parse failure.
    case malformedSource(message: String)
    /// The diagram family is not supported on the current runtime platform.
    /// `platform` is the human-readable platform name (e.g. `"Linux"`).
    /// `reason` is a short explanation suitable for surfacing to end users
    /// (e.g. `"requires CoreText text-measurement"`).
    case unsupportedOnPlatform(family: DiagramType, reason: String, platform: String)

    public var errorDescription: String? {
        switch self {
        case .notYetImplemented(let feature):
            return "\(feature) is not yet implemented."
        case .unrecognizedFormat(let detail):
            return "Unrecognized diagram source format: \(detail)"
        case .malformedSource(let message):
            return "Malformed diagram source: \(message)"
        case .unsupportedOnPlatform(let family, let reason, let platform):
            return "\(family.rawValue) layout is not supported on \(platform): \(reason)"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter LinuxPlatformGateTests/unsupportedOnPlatformErrorDescription`
Expected: 1/1 passing.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitModel/Types.swift Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift
git commit -m "$(cat <<'EOF'
feat(model): DiagramError.unsupportedOnPlatform case

Typed error for diagram families that can't lay out on the current
runtime platform. Carries the family enum case, a human reason, and
the platform name so hosts can render the error without re-deriving
context.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add `linuxSupport` / `linuxUnsupportedReason` to `DiagramDescriptor`

**Files:**
- Modify: `Sources/DiagramKit/DiagramDescriptor.swift:87-116`
- Modify: `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift` (all four `_typed` overloads)
- Test: `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (add)

- [ ] **Step 1: Write the failing test**

Append to `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (inside the existing `LinuxPlatformGateTests` struct):

```swift
    // MARK: - DiagramDescriptor fields

    @Test func descriptorDefaultsLinuxSupportToTrue() {
        let descriptor = DiagramRegistry.all.first { $0.type == .flowchart }
        #expect(descriptor != nil)
        #expect(descriptor?.linuxSupport == true)
        #expect(descriptor?.linuxUnsupportedReason == nil)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LinuxPlatformGateTests/descriptorDefaultsLinuxSupportToTrue`
Expected: build failure with `value of type 'DiagramDescriptor' has no member 'linuxSupport'`.

- [ ] **Step 3: Add fields + init params to DiagramDescriptor**

In `Sources/DiagramKit/DiagramDescriptor.swift`, change the `DiagramDescriptor` struct body (lines 87–116). Result:

```swift
public struct DiagramDescriptor: Sendable {
    public let type: DiagramType

    /// Returns `true` when `header` matches this diagram family.
    /// Order matters: `DiagramRegistry.all` is evaluated in array order;
    /// the first match wins.
    public let matches: @Sendable (DiagramHeader) -> Bool

    /// Parse the preprocessed source into a `DiagramDocument` plus any
    /// non-fatal diagnostics emitted during parsing.
    /// `frontmatter` is the parsed and bound frontmatter (optional).
    public let parse: @Sendable (String, DiagramFrontmatter?) throws -> (DiagramDocument, [DiagramDiagnostic])

    /// Layout a parsed graph into a `PositionedGraph` plus any non-fatal
    /// diagnostics emitted during layout (subgraph recursion truncations,
    /// Ishikawa overflow, gitgraph fallbacks, etc.).
    public let layout: @Sendable (DiagramDocument, LayoutConfig) throws -> (PositionedGraph, [DiagramDiagnostic])

    /// Whether this family can be laid out and rendered on Linux. Defaults
    /// to `true`. Set to `false` for families that depend on CoreText (or
    /// other Apple-only) measurement until a portable shim lands.
    public let linuxSupport: Bool

    /// Human-readable reason surfaced in `DiagramError.unsupportedOnPlatform`
    /// when `linuxSupport` is `false`. Nil for supported families.
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
}
```

- [ ] **Step 4: Thread the new params through all four `_typed` overloads**

In `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift`, each of the four `_typed` static funcs needs the two new defaulted params, and each call to `DiagramDescriptor(...)` needs to pass them through. Apply this diff pattern to ALL FOUR overloads (lines 23–46, 51–74, 80–104, 110–134):

For each overload, change the function signature to add the two new params at the end (after `positioned:`):

```swift
        positioned: @escaping @Sendable (DiagramDocument, Positioned) -> PositionedGraph,
        linuxSupport: Bool = true,
        linuxUnsupportedReason: String? = nil
    ) -> DiagramDescriptor {
```

And change the `DiagramDescriptor(...)` call at the bottom of each overload's body to pass them through:

```swift
        DiagramDescriptor(
            type: type,
            matches: matches,
            parse: { source, fm in
                // ... existing body unchanged ...
            },
            layout: { graph, config in
                // ... existing body unchanged ...
            },
            linuxSupport: linuxSupport,
            linuxUnsupportedReason: linuxUnsupportedReason
        )
```

Do this for all four overloads. Each overload's `parse:` and `layout:` closure bodies stay unchanged; only the surrounding signature and the trailing `DiagramDescriptor(...)` call gain the new params.

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter LinuxPlatformGateTests/descriptorDefaultsLinuxSupportToTrue`
Expected: 1/1 passing.

- [ ] **Step 6: Confirm no other build breaks**

Run: `swift build --target DiagramKit`
Expected: `Build complete!` with no errors. The 28 family descriptor files all call `_typed(...)` without specifying the new params, so they pick up the `true` / `nil` defaults.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKit/DiagramDescriptor.swift Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift
git commit -m "$(cat <<'EOF'
feat(descriptor): linuxSupport + linuxUnsupportedReason fields

Additive, defaulted (true / nil) so all existing call sites pick up
"supported" without source changes. Threaded through all four `_typed`
factory overloads in DiagramRegistry+TypedDescriptor so per-family
descriptor files can flip the flag without dropping to the underlying
DiagramDescriptor(...) initializer.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Flip the three CoreText-bound families

**Files:**
- Modify: `Sources/DiagramKit/DiagramRegistry+Ishikawa.swift`
- Modify: `Sources/DiagramKit/DiagramRegistry+TreeView.swift`
- Modify: `Sources/DiagramKit/DiagramRegistry+EventModeling.swift`
- Test: `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (add)

- [ ] **Step 1: Write the failing test (drift-lock + per-family checks)**

Append to `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (inside the existing `LinuxPlatformGateTests` struct):

```swift
    // MARK: - Per-family linuxSupport

    @Test func ishikawaIsLinuxUnsupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .ishikawa }
        #expect(descriptor?.linuxSupport == false)
        #expect(descriptor?.linuxUnsupportedReason?.isEmpty == false)
    }

    @Test func treeViewIsLinuxUnsupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .treeView }
        #expect(descriptor?.linuxSupport == false)
        #expect(descriptor?.linuxUnsupportedReason?.isEmpty == false)
    }

    @Test func eventModelingIsLinuxUnsupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .eventModeling }
        #expect(descriptor?.linuxSupport == false)
        #expect(descriptor?.linuxUnsupportedReason?.isEmpty == false)
    }

    @Test func exactlyThreeFamiliesAreLinuxUnsupported() {
        let unsupported = DiagramRegistry.all.filter { !$0.linuxSupport }.map(\.type)
        #expect(Set(unsupported) == Set<DiagramType>([.ishikawa, .treeView, .eventModeling]))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter LinuxPlatformGateTests`
Expected: the 4 new tests fail (all three descriptors return `linuxSupport == true` from the default).

- [ ] **Step 3: Flip Ishikawa**

In `Sources/DiagramKit/DiagramRegistry+Ishikawa.swift`, the `_ishikawa` descriptor currently ends with `)` after the `positioned:` closure (line 37). Add the two new params before that closing paren. Final state:

```swift
extension DiagramRegistry {
    static let _ishikawa = _typed(
        type: .ishikawa,
        matches: { header in _isIshikawaDiagramHeader(header.raw) },
        parseWithDiagnostics: { source, frontmatter in
            try parseIshikawaDiagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
        },
        wrap: DiagramPayload.ishikawa,
        unwrap: { payload in
            guard case let .ishikawa(value) = payload else { return nil }
            return value
        },
        layoutWithDiagnostics: { diagram, _ in
            #if canImport(CoreText)
            return layoutIshikawaDiagram(diagram)
            #else
            // Linux: layoutIshikawaDiagram requires CoreText for text-bounds
            // measurement. Unreachable until the portable text-measurement
            // shim lands (Stage 2.5 follow-up).
            _ = diagram
            throw DiagramStructuralError.payloadMismatch(.ishikawa)
            #endif
        },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .ishikawa(positioned))
        },
        linuxSupport: false,
        linuxUnsupportedReason: "requires CoreText text-measurement"
    )
}
```

- [ ] **Step 4: Flip TreeView**

In `Sources/DiagramKit/DiagramRegistry+TreeView.swift`, add the same two params at the end of the `_typed(...)` call (before the final `)`). Use the same `linuxSupport: false, linuxUnsupportedReason: "requires CoreText text-measurement"`.

- [ ] **Step 5: Flip EventModeling**

In `Sources/DiagramKit/DiagramRegistry+EventModeling.swift`, add the same two params at the end of the `_typed(...)` call. Use the same flag + reason.

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter LinuxPlatformGateTests`
Expected: all 5 tests (1 existing + 4 new) passing.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKit/DiagramRegistry+Ishikawa.swift Sources/DiagramKit/DiagramRegistry+TreeView.swift Sources/DiagramKit/DiagramRegistry+EventModeling.swift Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift
git commit -m "$(cat <<'EOF'
feat(linux): flip 3 CoreText-bound families to linuxSupport=false

Ishikawa, TreeView, and EventModeling each require CTLineGetBoundsWithOptions
for text-bounds measurement. Pre-existing #if canImport(CoreText) gates
in their layout funcs threw DiagramStructuralError.payloadMismatch on
Linux; the new flag is the public-introspection signal that this is
expected, with a typed-error reason callers can render.

Drift-lock test asserts exactly these three families are flagged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Split the `DiagramPipeline` over-gated block

**Files:**
- Modify: `Sources/DiagramKit/DiagramPipeline.swift:115-230`

This task is a structural refactor — no behavior change on Apple (the funcs were already visible), but it makes `renderSVG` / `renderSVG(positioned:)` / `renderASCII` visible on Linux. Verified via build, not unit test.

- [ ] **Step 1: Move `prepare` into its own narrow `#if` block; pull the render funcs out**

In `Sources/DiagramKit/DiagramPipeline.swift`, the current block structure is:

```
line 115:   #if canImport(CoreGraphics)
line 116:   // MARK: - Prepare
line 118:   public static func prepare(...) throws -> PreparedDiagram { ... }
line 134:
line 135:   // MARK: - Render SVG
line 142:   public static func renderSVG(source:...) throws -> String { ... }
line 179:   public static func renderSVG(positioned:...) throws -> String { ... }
line 210:   // MARK: - Render ASCII
line 212:   public static func renderASCII(...) throws -> AsciiRenderOutput { ... }
line 230:   #endif
```

Replace with:

```
    #if canImport(CoreGraphics)
    // MARK: - Prepare

    public static func prepare(...) throws -> PreparedDiagram { ... }
    #endif

    // MARK: - Render SVG

    public static func renderSVG(source:...) throws -> String { ... }

    public static func renderSVG(positioned:...) throws -> String { ... }

    // MARK: - Render ASCII

    public static func renderASCII(...) throws -> AsciiRenderOutput { ... }
```

Concretely: move the `#endif` from line 230 to immediately after `prepare`'s closing `}` (currently line 133). The render funcs at lines 135–229 stay where they are textually, but are no longer inside the `#if` block. Don't change their bodies — `loadDocument`, `GraphLayout`, `DiagramColors`, `DiagramFontResolver`, `SVGIDGenerator`, `SVGRenderRegistry`, `_resolveSvgCssVariables`, `_flattenKnownSvgTokens`, and `original_src_ascii_index.*` are all Linux-portable.

- [ ] **Step 2: Verify the Apple build still works**

Run: `swift build`
Expected: `Build complete!` with no errors.

- [ ] **Step 3: Verify existing Apple tests still pass**

Run: `swift test --filter "DiagramPipeline|DiagramEngine" 2>&1 | tail -20`
Expected: all targeted tests still pass; no regression from the gate split.

- [ ] **Step 4: Verify Linux build now includes the render funcs**

Run: `Scripts/linux-check.sh`

Expected: container build succeeds; `DiagramKit` target builds clean. If Docker/Podman isn't available locally, record the run as environment-skipped (per CLAUDE.md "Discipline Gates" policy). If the container runs, the now-portable `renderSVG` / `renderASCII` symbols are part of the `DiagramKit` Linux build.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKit/DiagramPipeline.swift
git commit -m "$(cat <<'EOF'
fix(pipeline): split overgated #if to expose renderSVG/renderASCII on Linux

The #if canImport(CoreGraphics) block at lines 115-230 wrapped `prepare`
(legitimately CG-bound via PreparedDiagram) AND `renderSVG` /
renderSVG(positioned:) / renderASCII (which depend only on Linux-portable
Model/Common symbols). Split the block: keep `prepare` gated, pull the
three render funcs out.

Apple-side behavior unchanged; Linux now compiles DiagramPipeline.renderSVG
and DiagramPipeline.renderASCII.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Add `_assertPlatformSupport` + call from render entry points

**Files:**
- Modify: `Sources/DiagramKit/DiagramPipeline.swift` (add helper + 3 call sites)
- Test: `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (add pipeline-level throw test)

- [ ] **Step 1: Write the failing pipeline-level throw test**

Append to `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (inside the existing `LinuxPlatformGateTests` struct):

```swift
    // MARK: - DiagramPipeline.renderSVG enforcement

    @Test func pipelineRenderSVGGatesIshikawaOnLinux() throws {
        let source = "ishikawa\nProblem\nCause A\nCause B"
        #if os(Linux)
        do {
            _ = try DiagramPipeline.renderSVG(source: source)
            Issue.record("expected DiagramPipeline.renderSVG(source:) to throw on Linux for ishikawa")
        } catch let error as DiagramError {
            if case let .unsupportedOnPlatform(family, reason, platform) = error {
                #expect(family == .ishikawa)
                #expect(reason.isEmpty == false)
                #expect(platform == "Linux")
            } else {
                Issue.record("expected .unsupportedOnPlatform, got \(error)")
            }
        }
        #else
        // On Apple platforms the helper is a no-op; just confirm we don't
        // see DiagramError.unsupportedOnPlatform when running this source.
        do {
            _ = try DiagramPipeline.renderSVG(source: source)
        } catch let error as DiagramError {
            if case .unsupportedOnPlatform = error {
                Issue.record("did not expect .unsupportedOnPlatform on non-Linux platform")
            }
            // Other DiagramError cases are fine — the test isn't asserting success here.
        } catch {
            // Non-DiagramError throws are fine (the fixture might be incomplete).
        }
        #endif
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LinuxPlatformGateTests/pipelineRenderSVGGatesIshikawaOnLinux`
Expected on Apple: passes (no `unsupportedOnPlatform` thrown). But this test is meaningful only when it runs on Linux; on Apple it's a no-op. Mark a TODO to verify the Linux behavior in Step 5.

Note: Since the Linux harness isn't wired into this swift-test invocation yet (Task 9), we'll get the Linux-side red→green proof in Task 9 when `Dockerfile.linux-check` runs the suite. For this task, the verification is that the helper exists, compiles on Linux, and is called from the right sites.

- [ ] **Step 3: Add the helper**

In `Sources/DiagramKit/DiagramPipeline.swift`, immediately after the `loadImportResult` helper (currently lines 71–76), add the new helper:

```swift
    /// Throw `DiagramError.unsupportedOnPlatform` if `document.type`'s
    /// descriptor declares `linuxSupport == false` and the current
    /// runtime platform is Linux. No-op on every other platform.
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

- [ ] **Step 4: Call from `renderSVG(source:)` (line 142)**

Find the `renderSVG(source:)` body. Currently:

```swift
        try runPipeline(operation: "DiagramPipeline.renderSVG") {
            let graph = try loadDocument(source, registry: registry)
            let positioned = try GraphLayout(config: layoutConfig).layout(graph)
            ...
```

Change to insert the helper call between `loadDocument` and `GraphLayout`:

```swift
        try runPipeline(operation: "DiagramPipeline.renderSVG") {
            let graph = try loadDocument(source, registry: registry)
            try _assertPlatformSupport(graph)
            let positioned = try GraphLayout(config: layoutConfig).layout(graph)
            ...
```

- [ ] **Step 5: Call from `renderSVG(positioned:)` (line 179)**

The pre-positioned variant has no `loadDocument` call — the caller already has a `PositionedGraph`. Insert at the top of the `runPipeline` block:

```swift
        try runPipeline(operation: "DiagramPipeline.renderSVG(positioned:)") {
            try _assertPlatformSupport(positioned.diagram)
            let colors = DiagramColors(
            ...
```

- [ ] **Step 6: Call from `renderASCII` (line 212)**

The ASCII path goes through `renderMermaidASCIIWithDiagnostics` which internally parses. To get the document type up-front, do a lightweight pre-parse. Change:

```swift
        try runPipeline(operation: "DiagramPipeline.renderASCII") {
            let colors: [String: String] = [
            ...
```

To:

```swift
        try runPipeline(operation: "DiagramPipeline.renderASCII") {
            let graph = try loadDocument(source, registry: defaultRegistry)
            try _assertPlatformSupport(graph)
            let colors: [String: String] = [
            ...
```

The double-parse is acceptable — `renderMermaidASCIIWithDiagnostics(source, options:)` re-parses internally; we accept the cost to get a clean throw-before-do path. The function takes a `source: String`, not the pre-parsed document, so this is structural.

- [ ] **Step 7: Build & confirm no regressions**

Run: `swift build`
Expected: `Build complete!`.

Run: `swift test --filter "DiagramPipeline|LinuxPlatformGateTests" 2>&1 | tail -20`
Expected: all targeted tests pass; the new `pipelineRenderSVGGatesIshikawaOnLinux` test passes on Apple as a no-op verification (it doesn't expect `.unsupportedOnPlatform` on Apple).

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKit/DiagramPipeline.swift Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift
git commit -m "$(cat <<'EOF'
feat(pipeline): _assertPlatformSupport gate in renderSVG/renderASCII

Private helper looks up the family descriptor and, on Linux, throws
DiagramError.unsupportedOnPlatform when linuxSupport == false. Called
from DiagramPipeline.renderSVG (source: variant), renderSVG(positioned:),
and renderASCII immediately after parse. No-op on Apple platforms.

DiagramPipeline.layout(_:) callers bypass the gate by design (Approach 1
in the spec).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `DiagramEngine.linuxSupport(for:)` public introspection API

**Files:**
- Modify: `Sources/DiagramKit/DiagramEngine.swift` (add static fn)
- Test: `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (add)

- [ ] **Step 1: Write the failing test**

Append to `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (inside the existing `LinuxPlatformGateTests` struct):

```swift
    // MARK: - DiagramEngine.linuxSupport public API

    @Test func linuxSupportReturnsTrueForSupportedFamily() {
        let result = DiagramEngine.linuxSupport(for: .flowchart)
        #expect(result.supported == true)
        #expect(result.reason == nil)
    }

    @Test func linuxSupportReturnsFalseForIshikawa() {
        let result = DiagramEngine.linuxSupport(for: .ishikawa)
        #expect(result.supported == false)
        #expect(result.reason?.isEmpty == false)
    }

    @Test(arguments: [DiagramType.ishikawa, .treeView, .eventModeling])
    func linuxSupportReportsAllThreeUnsupported(family: DiagramType) {
        let result = DiagramEngine.linuxSupport(for: family)
        #expect(result.supported == false)
        #expect(result.reason?.isEmpty == false)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter LinuxPlatformGateTests/linuxSupport`
Expected: build failure with `type 'DiagramEngine' has no member 'linuxSupport'`.

- [ ] **Step 3: Add the public API**

In `Sources/DiagramKit/DiagramEngine.swift`, add the new static fn. Locate a spot inside the `public struct DiagramEngine { ... }` body but outside any `#if canImport(...)` block. A clean spot is immediately after the `supportedDiagramTypes` constant (currently line 23). Insert:

```swift
    /// Returns whether `family` is supported on Linux, and if not, the
    /// human-readable reason. On non-Linux platforms always returns
    /// `(true, nil)` — the contract is "would a renderSVG/renderASCII call
    /// for this family throw `DiagramError.unsupportedOnPlatform` on Linux?"
    public static func linuxSupport(for family: DiagramType) -> (supported: Bool, reason: String?) {
        guard let descriptor = DiagramRegistry.all.first(where: { $0.type == family }) else {
            return (true, nil)
        }
        return (descriptor.linuxSupport, descriptor.linuxUnsupportedReason)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter LinuxPlatformGateTests/linuxSupport`
Expected: 5 tests passing (2 single tests + 3 parameterized cases).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKit/DiagramEngine.swift Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift
git commit -m "$(cat <<'EOF'
feat(engine): DiagramEngine.linuxSupport(for:) introspection API

Public static fn that lets hosts pre-check whether a family will throw
DiagramError.unsupportedOnPlatform on Linux. Returns (true, nil) for
unknown family types — callers asking "is this Linux-safe?" get a yes
for anything we don't recognize, since no render would happen anyway.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Drop the `DiagramEngine` and `String` extension gates

**Files:**
- Modify: `Sources/DiagramKit/DiagramEngine.swift:118-162` (remove outer `#if`)
- Modify: `Sources/DiagramKit/DiagramEngine.swift:211-228` (remove outer `#if`)
- Modify: `Sources/DiagramKit/DiagramEngine.swift:42-44, 55-57` (gate the `_DiagramPreparerBootstrap.didInstall` calls inside `parse` and `layout` — they were already gated, no change; verify they stay correct after the surrounding edits)
- Modify: `Sources/DiagramKit/DiagramEngine.swift` — add `_DiagramPreparerBootstrap.didInstall` gates inside the now-portable `renderSVG`, `renderASCII`, and `parseImportResult` bodies
- Test: `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (add the end-to-end engine-level tests)

- [ ] **Step 1: Write the failing end-to-end test**

Append to `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` (inside the existing `LinuxPlatformGateTests` struct):

```swift
    // MARK: - End-to-end via DiagramEngine

    @Test func engineRenderSVGGatesIshikawaOnLinux() async throws {
        let source = "ishikawa\nProblem\nCause A\nCause B"
        #if os(Linux)
        do {
            _ = try await DiagramEngine.renderSVG(source: source)
            Issue.record("expected DiagramEngine.renderSVG(source:) to throw on Linux for ishikawa")
        } catch let error as DiagramError {
            if case let .unsupportedOnPlatform(family, _, platform) = error {
                #expect(family == .ishikawa)
                #expect(platform == "Linux")
            } else {
                Issue.record("expected .unsupportedOnPlatform, got \(error)")
            }
        }
        #else
        do {
            _ = try await DiagramEngine.renderSVG(source: source)
        } catch let error as DiagramError {
            if case .unsupportedOnPlatform = error {
                Issue.record("did not expect .unsupportedOnPlatform on non-Linux")
            }
        } catch {
            // Other failures are fine.
        }
        #endif
    }

    @Test func parseImportResultDoesNotGateOnLinux() async throws {
        let source = "ishikawa\nProblem\nCause A\nCause B"
        // Parsing succeeds on every platform — only layout/render is gated.
        let result = try await DiagramEngine.parseImportResult(source: source)
        #expect(result.document.type == .ishikawa)
    }
```

- [ ] **Step 2: Run tests on Apple to confirm they compile and pass**

Run: `swift test --filter LinuxPlatformGateTests/engineRenderSVGGatesIshikawaOnLinux`
Expected: passes (no `.unsupportedOnPlatform` thrown; other DiagramError cases are tolerated).

Run: `swift test --filter LinuxPlatformGateTests/parseImportResultDoesNotGateOnLinux`
Expected: passes.

(These tests already pass on Apple — `DiagramEngine.renderSVG` and `parseImportResult` are visible on Apple today. The real proof point is that they ALSO pass on Linux after the gate drop, which Task 9 wires up.)

- [ ] **Step 3: Remove the DiagramEngine.renderSVG/renderASCII/parseImportResult gate**

In `Sources/DiagramKit/DiagramEngine.swift`, the block at lines 118–162 currently looks like:

```swift
    #if canImport(CoreGraphics)
    /// Render a Mermaid diagram to an SVG string.
    public static func renderSVG(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        idPolicy: SVGIDPolicy = .unique
    ) async throws -> String {
        _ = _DiagramPreparerBootstrap.didInstall
        return try await _runOnWorker {
            try DiagramPipeline.renderSVG(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig,
                idPolicy: idPolicy
            )
        }
    }

    /// Render a Mermaid diagram to an ASCII/Unicode string ...
    public static func renderASCII(...) async throws -> AsciiRenderOutput { ... }

    /// Parse `source` and return the full `DiagramImportResult` ...
    public static func parseImportResult(...) async throws -> DiagramImportResult { ... }
    #endif
```

Two edits:
1. Delete the `#if canImport(CoreGraphics)` line at line 118 and the matching `#endif` at line 162.
2. Inside each of the three func bodies, wrap the `_ = _DiagramPreparerBootstrap.didInstall` line in `#if canImport(CoreGraphics)` / `#endif`. This call references a CG-only symbol; the func body becomes:

```swift
    public static func renderSVG(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        idPolicy: SVGIDPolicy = .unique
    ) async throws -> String {
        #if canImport(CoreGraphics)
        _ = _DiagramPreparerBootstrap.didInstall
        #endif
        return try await _runOnWorker {
            try DiagramPipeline.renderSVG(
                source: source,
                theme: theme,
                layoutConfig: layoutConfig,
                idPolicy: idPolicy
            )
        }
    }
```

Apply the same `#if canImport(CoreGraphics) _ = _DiagramPreparerBootstrap.didInstall #endif` pattern to `renderASCII` and `parseImportResult` bodies.

- [ ] **Step 4: Remove the String extension gate**

The block at lines 211–228 currently looks like:

```swift
    #if canImport(CoreGraphics)
    public func renderDiagramSVG(
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) async throws -> String {
        try await DiagramEngine.renderSVG(
            source: self,
            theme: theme,
            layoutConfig: layoutConfig
        )
    }

    public func renderDiagramASCII(
        theme: DiagramTheme = .default
    ) async throws -> String {
        try await DiagramEngine.renderASCII(source: self, theme: theme).text
    }
    #endif
```

Delete the `#if canImport(CoreGraphics)` line at line 211 and the matching `#endif` at line 228. The bodies need no changes — they delegate to `DiagramEngine.*` which we just made portable. The remaining `String.renderDiagramImage` block at lines 201–209 stays gated unchanged.

- [ ] **Step 5: Verify Apple build and tests still work**

Run: `swift build`
Expected: `Build complete!`.

Run: `swift test --filter "DiagramEngine|LinuxPlatformGateTests" 2>&1 | tail -20`
Expected: all targeted tests pass; the two new e2e tests pass on Apple.

- [ ] **Step 6: Verify Linux now builds the full surface**

Run: `Scripts/linux-check.sh`
Expected: container build succeeds; `DiagramKit` Linux compile picks up `DiagramEngine.renderSVG`, `renderASCII`, `parseImportResult`, plus `String.renderDiagramSVG`, `renderDiagramASCII`.

(If Docker/Podman is unavailable, record environment-skipped per project policy.)

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKit/DiagramEngine.swift Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift
git commit -m "$(cat <<'EOF'
feat(engine): drop CG gates on renderSVG/renderASCII/parseImportResult

Two #if canImport(CoreGraphics) blocks on DiagramEngine (lines 118-162
and 211-228 pre-edit) come off. _DiagramPreparerBootstrap.didInstall
calls inside the three engine funcs and the String extensions are now
individually gated since the bootstrap symbol is CG-bound.

End-to-end test pins that DiagramEngine.renderSVG on Linux throws
.unsupportedOnPlatform for ishikawa, and parseImportResult does NOT
gate (parsing remains portable).

Closes Cross-cutting #5 + Critical "Public API contract holes" from
REVIEW.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Wire `DiagramKitLinuxTests` into `Dockerfile.linux-check`

**Files:**
- Modify: `Dockerfile.linux-check`

- [ ] **Step 1: Read the current Dockerfile**

Current state (use `Read` tool or `cat`): the matrix builds 4 library targets and then prints results. No test execution.

- [ ] **Step 2: Extend the build matrix to include the new test target**

In `Dockerfile.linux-check`, the build matrix `for tgt in DiagramKitCommon DiagramKitModel DiagramKitTestSupport DiagramKit;` should additionally cover `DiagramKitLinuxTests`. Append `DiagramKitLinuxTests` to the list. Final:

```dockerfile
RUN echo "=== Build matrix ===" >> /tmp/results.txt && \
    for tgt in DiagramKitCommon DiagramKitModel DiagramKitTestSupport DiagramKit DiagramKitLinuxTests; do \
        echo "--- swift build --target $tgt ---" >> /tmp/results.txt; \
        swift build --target "$tgt" >> /tmp/results.txt 2>&1 \
            && echo "RESULT: $tgt PASS" >> /tmp/results.txt \
            || echo "RESULT: $tgt FAIL" >> /tmp/results.txt; \
        echo "" >> /tmp/results.txt; \
    done
```

- [ ] **Step 3: Add a new `RUN` step that runs the test suite**

After the build-matrix `RUN` (and before the `CMD` line), insert:

```dockerfile
RUN echo "=== swift test --filter LinuxPlatformGateTests ===" >> /tmp/results.txt && \
    swift test --filter LinuxPlatformGateTests >> /tmp/results.txt 2>&1 \
        && echo "RESULT: LinuxPlatformGateTests PASS" >> /tmp/results.txt \
        || (echo "RESULT: LinuxPlatformGateTests FAIL" >> /tmp/results.txt && exit 1)
```

The `exit 1` ensures the container exit code is non-zero on test failure, so `linux-check.sh`'s `set -euo pipefail` surfaces the failure to the smoke-check.

- [ ] **Step 4: Update the `CMD` to include the test results in the printed summary**

Change the `CMD` line at the bottom from:

```dockerfile
CMD ["bash", "-c", "echo '=== Build matrix ==='; cat /tmp/results.txt | grep -E 'RESULT:|swift build'"]
```

To:

```dockerfile
CMD ["bash", "-c", "echo '=== Results ==='; cat /tmp/results.txt | grep -E 'RESULT:|swift build|=== '"]
```

- [ ] **Step 5: Update the obsolete header comment**

The header comment block at lines 21–24 says "the call sites throw MermaidStructuralError.payloadMismatch on Linux" — `MermaidStructuralError` is the deprecated alias name (Session 12). Update to reflect the typed-error contract:

```dockerfile
# Functional Linux layout/rendering for layouts that depend on text
# measurement (CTLineGetBoundsWithOptions) is deferred — the call sites
# throw DiagramError.unsupportedOnPlatform on Linux for ishikawa,
# treeView, and eventModeling. A portable text-measurement shim is the
# Stage 2.5 follow-up.
```

- [ ] **Step 6: Run the container locally to verify**

Run: `Scripts/linux-check.sh`
Expected: container build succeeds; `=== Results ===` summary shows `RESULT: DiagramKitLinuxTests PASS` AND `RESULT: LinuxPlatformGateTests PASS`. If Docker/Podman isn't available, record environment-skipped.

If the test suite fails, this is the first time the Linux throw path has actually fired in CI — debug from the `swift test` output in the container log.

- [ ] **Step 7: Commit**

```bash
git add Dockerfile.linux-check
git commit -m "$(cat <<'EOF'
ci(linux): run DiagramKitLinuxTests inside the linux-check container

Build matrix now compiles the new test target; second RUN step executes
`swift test --filter LinuxPlatformGateTests` and fails the container on
a non-zero exit. First Linux test execution on this repo — pins that
the platform gate actually throws on Linux for the 3 CoreText-bound
families.

Drive-by: header-comment update from the deprecated
MermaidStructuralError.payloadMismatch wording to the typed
DiagramError.unsupportedOnPlatform contract.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Documentation sync

**Files:**
- Modify: `CLAUDE.md` (test source count + Target Layout)
- Modify: `REVIEW.md` (new Resolution Status — Session N entry)

- [ ] **Step 1: Update the test source count in CLAUDE.md**

In `CLAUDE.md`, the "Testing And Snapshots" section currently says `Current test source count: 258 Swift files under Tests/DiagramKitTests`. After this work, there's also `Tests/DiagramKitLinuxTests/LinuxPlatformGateTests.swift` + `Tests/DiagramKitLinuxTests/Placeholder.swift`. Verify the count with:

```bash
find Tests -name "*.swift" -type f | wc -l
```

Then update the CLAUDE.md sentence to the new total. The sentence shape becomes:

```
- Current test source count: 260 Swift files (258 under `Tests/DiagramKitTests`, 2 under `Tests/DiagramKitLinuxTests`).
```

(Adjust the numbers to match what `find` returns.)

- [ ] **Step 2: Add `DiagramKitLinuxTests` to the "Target Layout" diagram**

In `CLAUDE.md`'s "Target Layout" ASCII art (around line 60–70), the right-column list currently includes `DiagramKitTestSupport`. Add `DiagramKitLinuxTests` next to it. The exact wording follows the surrounding style — keep the column alignment.

- [ ] **Step 3: Add a Session entry to REVIEW.md**

In `REVIEW.md`, after the existing "Resolution Status — Session 13" header (around line 255), insert a new section:

```markdown
## Resolution Status — Session 14 (2026-05-15)

Closes Cross-cutting Observation #5 + Critical "Public API contract holes" (`DiagramEngine.renderSVG` / `renderASCII` Linux gating). Spec at `docs/superpowers/specs/2026-05-15-linux-svg-ascii-parity-design.md`; plan at `docs/superpowers/plans/2026-05-15-linux-svg-ascii-parity.md`. Ten commits on `main`.

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | Test target scaffold | `<hash>` | New `.testTarget(name: "DiagramKitLinuxTests")` in `Package.swift` with Linux-portable deps; placeholder test. |
| 2 | `DiagramError.unsupportedOnPlatform` | `<hash>` | New case carrying `(family, reason, platform)`; LocalizedError surfaces them. |
| 3 | `DiagramDescriptor` linuxSupport fields | `<hash>` | `linuxSupport: Bool = true` + `linuxUnsupportedReason: String? = nil`; threaded through all four `_typed` factory overloads. |
| 4 | Three families flipped | `<hash>` | Ishikawa, TreeView, EventModeling each declare `linuxSupport: false` with "requires CoreText text-measurement" reason. Drift-lock test pins exactly these three. |
| 5 | `DiagramPipeline` gate split | `<hash>` | `#if canImport(CoreGraphics)` block at lines 115-230 split: `prepare` stays gated, `renderSVG` (both overloads) + `renderASCII` are pulled out. |
| 6 | `_assertPlatformSupport` helper | `<hash>` | Private helper looks up the descriptor and throws `DiagramError.unsupportedOnPlatform` on Linux when `linuxSupport == false`. Called from the 3 pipeline render entry points after parse. |
| 7 | `DiagramEngine.linuxSupport(for:)` | `<hash>` | Public introspection API; returns `(true, nil)` for unknown families. |
| 8 | `DiagramEngine` gate drops | `<hash>` | Two `#if canImport(CoreGraphics)` blocks on `DiagramEngine` (renderSVG/renderASCII/parseImportResult + String extensions) removed; `_DiagramPreparerBootstrap.didInstall` calls individually gated. |
| 9 | Dockerfile.linux-check wires tests | `<hash>` | Container build matrix gains `DiagramKitLinuxTests`; second `RUN` step runs `swift test --filter LinuxPlatformGateTests`. First Linux test execution from CI on this repo. |
| 10 | Docs sync | _this commit_ | CLAUDE.md test count + Target Layout; this REVIEW.md Session entry. |

Session-end verification: `swift test --filter LinuxPlatformGateTests` green on Apple (12 tests); `Scripts/linux-check.sh` green (DiagramKitLinuxTests builds and all tests pass under Linux). `Scripts/check-sendable-annotations.sh` ✓ green. `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings.
```

Fill in the `<hash>` values from the actual commits after they land. The plan executor should `git log --oneline -11` after Task 9 to gather the hashes.

- [ ] **Step 4: Verify the docs render and the test count is correct**

Run: `find Tests -name "*.swift" -type f | wc -l`
Confirm the number matches the value in CLAUDE.md.

Run: `grep -c "^| " REVIEW.md | head -1` to spot-check the table.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md REVIEW.md
git commit -m "$(cat <<'EOF'
docs: sync CLAUDE.md test count + REVIEW.md Session 14 entry

Test source count updated to reflect the new DiagramKitLinuxTests target.
Target Layout diagram lists the new test target. REVIEW.md Session 14
table captures the ten commits that close Cross-cutting #5 +
Critical Public API contract holes (Linux SVG/ASCII parity).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Verification (end-of-plan)

After the last commit lands:

- [ ] **Apple-side smoke check**

```bash
swift test --filter LinuxPlatformGateTests
```

Expected: 12 tests / 1 suite passing (errorDescription + 4 descriptor checks + 5 introspection cases + 2 e2e tests).

- [ ] **Linux-side smoke check**

```bash
Scripts/linux-check.sh
```

Expected: container build green, `=== Results ===` summary shows `RESULT: LinuxPlatformGateTests PASS`. If Docker/Podman is unavailable, record environment-skipped per project policy.

- [ ] **Discipline gates**

```bash
Scripts/check-sendable-annotations.sh
Scripts/check-file-sizes.sh
Scripts/strict-concurrency-check.sh
```

Expected: all three green; only pre-existing yellow file-size warnings allowed.

- [ ] **Session sanity**

```bash
git log --oneline -12
```

Expected: 10 commits from this plan plus the spec + plan commits, all on `main`. No `--no-verify` flags, no force-pushes.

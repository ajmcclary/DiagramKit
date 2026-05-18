# Sample App Relocation + Platform Floor Bump — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Relocate `Examples/DiagramPlayground/` to `Sources/DiagramKitSample/` and raise the package-wide platform floor to macOS 26 + iOS 26 only (drop macCatalyst, tvOS, visionOS).

**Architecture:** Five independent commits on `main`, each independently buildable and verified by a targeted `swift test --filter <SuiteName>` run. No worktrees, no branches — this matches the repo's standing "commit-by-commit on main" convention. Refactor only; no behavior changes.

**Tech Stack:** Swift 6.3, SwiftPM, swift-testing, xcodebuild for the multiplatform sweep.

**Reference spec:** `docs/superpowers/specs/2026-05-18-sample-app-relocation-and-platform-floor-design.md`

---

## File Structure (deltas)

### Created
- `Sources/DiagramKitSample/**` (via `git mv` from `Examples/DiagramPlayground/`)

### Modified
- `Package.swift` — platforms list, target conditions, executable target
- `Scripts/bootstrap-smoke-check.sh` — strip `run_build "tvOS"` / `run_build "visionOS"` rows
- `Scripts/rebaseline-snapshots.sh:47` — corpus JSON path
- `CLAUDE.md`, `ARCHITECTURE.md`, `BASELINES.md`, `README.md`, `AGENTS.md`, `CONTRIBUTING.md` — paths, commands, gates table, platform invariants
- ~20 library/test source files — collapse `#if !targetEnvironment(macCatalyst)` blocks
- ~30 test files — `@testable import DiagramPlayground` → `@testable import DiagramKitSample`
- ~10 test files — corpus path `Examples/DiagramPlayground/...` → `Sources/DiagramKitSample/...`
- `Tests/DiagramKitTests/WardleyMapEndToEndTests.swift:20` — drive-by absolute-path fix
- `Sources/DiagramKitSample/DiagramKitSampleApp.swift` (renamed) — strip `@available(... 26.0, *)` guards
- ~68 other files in `Sources/DiagramKitSample/**` — strip `@available(... 26.0, *)` / `if #available(... 26.0, *)` guards

### Deleted
- `Examples/DiagramPlayground/DiagramPlayground.xcodeproj/`
- `Examples/DiagramPlayground/DiagramPlayground.xcworkspace/`
- `Examples/DiagramPlayground/project.yml`
- `Examples/DiagramPlayground/Info.plist`
- `Examples/DiagramPlayground/UITests/`
- `Examples/DiagramPlayground/Scripts/`
- `Scripts/playground-a11y-check.sh`
- `Examples/` (top-level, once empty)

### Explicitly NOT touched
- `docs/archive/**` — historical record, frozen per CLAUDE.md
- `docs/superpowers/plans/**` and `docs/superpowers/specs/**` (other than this spec/plan pair) — historical records of past work
- The 14 library targets' internal source files (other than `#if !targetEnvironment(macCatalyst)` collapses)
- `Tests/DiagramKitLinuxTests/` — unaffected by macCatalyst/sample changes
- The corpus JSON content itself — only its filesystem location moves

---

## Task 1: Platform floor + Catalyst/tvOS/visionOS strip

**Files:**
- Modify: `Package.swift` lines 15–20 (platforms), 122–126, 169–178, 190, 225 (conditional clauses)
- Modify: `Scripts/bootstrap-smoke-check.sh:91–92` (drop tvOS + visionOS rows)
- Modify: ~20 source files matching `grep -rl "targetEnvironment(macCatalyst)"` in `Sources/` and `Tests/` and `Examples/`

### Steps

- [ ] **Step 1: Inventory all `.condition(.when(platforms:` clauses to confirm scope**

Run: `grep -n "\.when(platforms" Package.swift`

Expected output (7 hits, lines may shift):
```
67:                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
123:                    condition: .when(platforms: [
170:                    condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])
176:                .target(name: "DiagramKitRenderingCG", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])),
177:                .target(name: "DiagramKitViews", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst]))
190:                .target(name: "DiagramKitInteractive", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])),
225:                .target(name: "DiagramKitRenderingCG", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])),
```

The single `.linux` Crypto condition (line 67) stays — it gates the Linux-only `swift-crypto` fallback. The other 6 Apple-only clauses (line 123, which spans lines 123–126 as a multi-line clause; and lines 170, 176, 177, 190, 225) are all redundant once the package platforms list restricts to macOS+iOS only.

- [ ] **Step 2: Inventory `#if targetEnvironment(macCatalyst)` and `#if !targetEnvironment(macCatalyst)` sites**

Run: `grep -rn "targetEnvironment(macCatalyst)" Sources Tests Examples | grep -v ".xcodeproj"`

Expected: ~20 files. Note for each: is it `#if targetEnvironment(macCatalyst)` (delete the block contents) or `#if !targetEnvironment(macCatalyst)` (keep the block contents unconditionally)?

- [ ] **Step 3: Update `Package.swift` `platforms:` array**

Edit `Package.swift` lines 15–20:

```swift
// OLD:
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
```

```swift
// NEW:
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
```

- [ ] **Step 4: Strip the six Apple-only `.condition(.when(platforms:` clauses from `Package.swift`**

There are six Apple-only clauses, all matching `.condition(.when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst]))`. Delete each clause (and the surrounding `.target(name: "X", condition: ...)` wrappers can become bare `"X"` strings since SwiftPM allows that form).

Example transformation around line 121–129 (DiagramKitInteractive target's RenderingCG dep):

```swift
// OLD:
                .target(
                    name: "DiagramKitRenderingCG",
                    condition: .when(platforms: [
                        .macOS, .iOS, .tvOS, .visionOS, .macCatalyst
                    ])
                )

// NEW:
                "DiagramKitRenderingCG"
```

Example transformation around lines 168–177 (umbrella DiagramKit target):

```swift
// OLD:
                .target(
                    name: "DiagramKitInteractive",
                    condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])
                ),
                .target(name: "DiagramKitD2"),
                .target(name: "DiagramKitGraphviz"),
                .target(name: "DiagramKitStructurizr"),
                .target(name: "DiagramKitPlantUML"),
                .target(name: "DiagramKitRenderingCG", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])),
                .target(name: "DiagramKitViews", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst]))

// NEW:
                "DiagramKitInteractive",
                "DiagramKitD2",
                "DiagramKitGraphviz",
                "DiagramKitStructurizr",
                "DiagramKitPlantUML",
                "DiagramKitRenderingCG",
                "DiagramKitViews"
```

Same pattern for executable target lines 190 and testTarget line 225.

- [ ] **Step 5: Update the comment at `Package.swift:38–40` that mentions macCatalyst**

The comment block before the executable's `.executable` product entry currently says:

```swift
        // SwiftPM has a package-wide platform floor, while the Playground app
        // intentionally targets the latest Apple UI APIs. The library products
        // support the platforms declared above; the Playground executable is
        // additionally guarded by `@available(iOS/macOS/macCatalyst 26.0, *)`
        // and the Xcode project sets its deployment target to 26.0.
```

Replace with:

```swift
        // Library products and the sample share the same macOS 26 / iOS 26 floor
        // declared above. The Xcode project that previously bundled the sample
        // (along with its UI test bundle and xcodegen project.yml) has been
        // removed in favor of pure SwiftPM (see commit history 2026-05-18).
```

- [ ] **Step 6: Strip tvOS + visionOS rows from `Scripts/bootstrap-smoke-check.sh`**

Edit lines 90–92:

```bash
# OLD:
run_build "iOS" 'generic/platform=iOS'
run_build "visionOS" 'generic/platform=visionOS'
run_build "tvOS" 'generic/platform=tvOS'

# NEW:
run_build "iOS" 'generic/platform=iOS'
```

- [ ] **Step 7: Collapse `#if targetEnvironment(macCatalyst)` blocks in source**

For each file from Step 2, apply the collapse rule:

- `#if targetEnvironment(macCatalyst)` … `#else` … `#endif` → keep the `#else` branch unconditionally; delete the rest.
- `#if targetEnvironment(macCatalyst)` … `#endif` (no `#else`) → delete the whole block.
- `#if !targetEnvironment(macCatalyst)` … `#else` … `#endif` → keep the `#if !` branch unconditionally; delete the rest.
- `#if !targetEnvironment(macCatalyst)` … `#endif` (no `#else`) → keep the contents; delete only the directives.

Do all ~20 files in one pass. Use Edit per file (sed is error-prone for nested directives).

Note: Some sites combine `targetEnvironment(macCatalyst)` with other conditions, e.g. `#if canImport(UIKit) && !targetEnvironment(macCatalyst)`. In those cases, just remove the `&& !targetEnvironment(macCatalyst)` clause (or `&& targetEnvironment(macCatalyst)`, inverted) — don't collapse the whole `#if`.

- [ ] **Step 8: Verify Package.swift parses**

Run: `swift package dump-package > /dev/null`

Expected: exit code 0, no output.

- [ ] **Step 9: Verify clean build of the umbrella**

Run: `swift package clean && swift build --target DiagramKitMermaid 2>&1 | tail -20`

Expected: ends with "Build complete!" — no errors, no `targetEnvironment(macCatalyst)` warnings.

- [ ] **Step 10: Verify a fast representative test suite**

Run: `swift test --filter MermaidPipelineConcurrencyTests 2>&1 | tail -20`

Expected: all tests pass.

- [ ] **Step 11: Verify a Linux-portable suite (optional but cheap)**

Run: `swift test --filter DiagramKitLinuxTests 2>&1 | tail -10`

Expected: all tests pass. Skip if it's flaky in your environment.

- [ ] **Step 12: Commit**

```bash
git add -u Package.swift Scripts/bootstrap-smoke-check.sh Sources Tests Examples
git commit -m "$(cat <<'EOF'
chore: raise platform floor to macOS 26 / iOS 26, drop macCatalyst + tvOS + visionOS

Replaces the package-wide platforms list (iOS 17 / macOS 14 / macCatalyst 17 /
visionOS 1) with a macOS 26 + iOS 26 floor. Strips the five Apple-only
.condition(.when(platforms:)) clauses that are now redundant. Collapses every
#if targetEnvironment(macCatalyst) site in Sources/ and Tests/ to its
non-Catalyst branch. Removes the visionOS and tvOS xcodebuild rows from the
bootstrap-smoke-check sweep.

Refactor only — no behavior changes. Per
docs/superpowers/specs/2026-05-18-sample-app-relocation-and-platform-floor-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Drop Xcode artifacts

**Files:**
- Delete: `Examples/DiagramPlayground/DiagramPlayground.xcodeproj/`
- Delete: `Examples/DiagramPlayground/DiagramPlayground.xcworkspace/`
- Delete: `Examples/DiagramPlayground/project.yml`
- Delete: `Examples/DiagramPlayground/Info.plist`
- Delete: `Examples/DiagramPlayground/UITests/` (15 Swift files)
- Delete: `Examples/DiagramPlayground/Scripts/` (`GenerateAppIcon.swift`)
- Delete: `Scripts/playground-a11y-check.sh`
- Modify: `Package.swift` — trim the `exclude:` list inside the executable target (lines 194–199)

### Steps

- [ ] **Step 1: Confirm what will be deleted**

Run: `ls Examples/DiagramPlayground/ && ls Examples/DiagramPlayground/UITests/ | wc -l && ls -la Scripts/playground-a11y-check.sh`

Expected:
- Top-level lists `DiagramPlayground.xcodeproj`, `DiagramPlayground.xcworkspace`, `DiagramPlaygroundApp.swift`, `Info.plist`, `Models`, `Resources`, `Scripts`, `UITests`, `Views`, `project.yml`
- UITests count: 15 files
- `Scripts/playground-a11y-check.sh` exists

- [ ] **Step 2: Delete the Xcode-side artifacts**

Run:
```bash
git rm -r Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
          Examples/DiagramPlayground/DiagramPlayground.xcworkspace \
          Examples/DiagramPlayground/project.yml \
          Examples/DiagramPlayground/Info.plist \
          Examples/DiagramPlayground/UITests \
          Examples/DiagramPlayground/Scripts \
          Scripts/playground-a11y-check.sh
```

Expected: deletions reported, no errors.

- [ ] **Step 3: Trim the `exclude:` list in `Package.swift`**

Find the executable target's `exclude:` block (lines 194–199 before Task 1, may have shifted slightly):

```swift
// OLD:
            path: "Examples/DiagramPlayground",
            exclude: [
                "Info.plist",
                "project.yml",
                "Scripts",
                "UITests"
            ],
            resources: [
```

```swift
// NEW:
            path: "Examples/DiagramPlayground",
            resources: [
```

(Leave the `path:` argument as-is for now — Task 3 changes it.)

- [ ] **Step 4: Verify build still works**

Run: `swift build 2>&1 | tail -10`

Expected: "Build complete!" — no missing-resource errors.

- [ ] **Step 5: Verify the sample regression suite still passes**

Run: `swift test --filter DiagramPlaygroundRegressionTests 2>&1 | tail -10`

Expected: all tests pass.

- [ ] **Step 6: Smoke-test the binary launches**

Run: `swift build --product DiagramPlayground 2>&1 | tail -5 && ls .build/debug/DiagramPlayground`

Expected: build succeeds; executable exists. (Not running it — SwiftUI app requires a windowing environment.)

- [ ] **Step 7: Commit**

```bash
git add -u Package.swift
git commit -m "$(cat <<'EOF'
chore: drop bundled Xcode project + UITests bundle from sample app

Deletes DiagramPlayground.xcodeproj, the xcodegen project.yml, Info.plist,
the 15-file UITests bundle, the sample's internal Scripts directory, and the
top-level Scripts/playground-a11y-check.sh gate. The sample app is now a pure
SwiftPM executable target, matching CodeEditorSample.

Lost coverage (acknowledged in the spec): AccessibilityAuditTests +
IdentifierPresenceTests + SmokeTests + the performAccessibilityAudit() sweep
across five screen states. Re-add later as a SwiftPM test target if needed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Move + rename (the load-bearing commit)

**Files:**
- Move: `Examples/DiagramPlayground/` → `Sources/DiagramKitSample/` (via `git mv`)
- Rename: `Sources/DiagramKitSample/DiagramPlaygroundApp.swift` → `Sources/DiagramKitSample/DiagramKitSampleApp.swift`
- Modify the renamed file: `struct DiagramPlaygroundApp` → `struct DiagramKitSampleApp`
- Modify: `Package.swift` — target name, path, product, test-target dependency entry
- Modify: ~30 files in `Tests/DiagramKitTests/` — `@testable import DiagramPlayground` → `@testable import DiagramKitSample`
- Modify: ~10 files in `Tests/DiagramKitTests/` — corpus path string
- Modify: `Tests/DiagramKitTests/WardleyMapEndToEndTests.swift:20` — replace absolute path with relative walk
- Delete: `Examples/` (top-level, will be empty)

### Steps

- [ ] **Step 1: Move the tree**

Run:
```bash
git mv Examples/DiagramPlayground Sources/DiagramKitSample
```

Expected: rename reported.

- [ ] **Step 2: Rename the App file**

Run:
```bash
git mv Sources/DiagramKitSample/DiagramPlaygroundApp.swift \
       Sources/DiagramKitSample/DiagramKitSampleApp.swift
```

Expected: rename reported.

- [ ] **Step 3: Rename the `@main` struct inside the App file**

Edit `Sources/DiagramKitSample/DiagramKitSampleApp.swift` to replace the struct identifier:

```swift
// OLD (around line 18):
struct DiagramPlaygroundApp: App {

// NEW:
struct DiagramKitSampleApp: App {
```

Update the file-header comment block too:

```swift
// OLD (lines 1–7):
//
//  DiagramPlaygroundApp.swift
//  DiagramPlayground
//
//  SwiftUI app entry point for iOS and macOS.
//  Instantiates the LiveEditorStore and passes it to LiveEditorView.
//

// NEW:
//
//  DiagramKitSampleApp.swift
//  DiagramKitSample
//
//  SwiftUI app entry point for iOS and macOS.
//  Instantiates the LiveEditorStore and passes it to LiveEditorView.
//
```

- [ ] **Step 4: Update `Package.swift` — rename target, drop `path:`, rename product**

Find the executable target (was lines 182–209, slightly shifted by prior commits):

```swift
// OLD:
        .executableTarget(
            name: "DiagramPlayground",
            dependencies: [
                "DiagramKit",
                "DiagramKitD2",
                "DiagramKitGraphviz",
                "DiagramKitStructurizr",
                "DiagramKitPlantUML",
                "DiagramKitInteractive",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            path: "Examples/DiagramPlayground",
            resources: [
                .process("Resources")
            ],
            swiftSettings: strictConcurrencySettings + [
                .define("DIAGRAMKIT_SWIFTPM")
            ]
        ),

// NEW:
        .executableTarget(
            name: "DiagramKitSample",
            dependencies: [
                "DiagramKit",
                "DiagramKitD2",
                "DiagramKitGraphviz",
                "DiagramKitStructurizr",
                "DiagramKitPlantUML",
                "DiagramKitInteractive",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            // No `path:` — SwiftPM's default Sources/<TargetName>/ convention now applies.
            resources: [
                .process("Resources")
            ],
            swiftSettings: strictConcurrencySettings + [
                .define("DIAGRAMKIT_SWIFTPM")
            ]
        ),
```

Find the `.executable` product entry near line 41:

```swift
// OLD:
        .executable(name: "DiagramPlayground", targets: ["DiagramPlayground"])

// NEW:
        .executable(name: "DiagramKitSample", targets: ["DiagramKitSample"])
```

Find the `DiagramKitTests` target's dependency list (around line 220, the entry that says `"DiagramPlayground",`):

```swift
// OLD:
                "DiagramPlayground",

// NEW:
                "DiagramKitSample",
```

- [ ] **Step 5: Bulk-rewrite `@testable import DiagramPlayground` across `Tests/`**

Run:
```bash
find Tests/DiagramKitTests -name "*.swift" -exec \
  sed -i '' 's/@testable import DiagramPlayground/@testable import DiagramKitSample/g' {} +
```

Verify the rewrite:
```bash
grep -rln "@testable import DiagramPlayground" Tests/ ; echo "exit=$?"
grep -rln "@testable import DiagramKitSample" Tests/ | wc -l
```

Expected: first grep prints nothing (exit=1, "no match"); second grep prints ~30.

- [ ] **Step 6: Bulk-rewrite corpus path strings across `Tests/`**

Run:
```bash
find Tests/DiagramKitTests -name "*.swift" -exec \
  sed -i '' 's|Examples/DiagramPlayground/Resources/test-diagrams\.json|Sources/DiagramKitSample/Resources/test-diagrams.json|g' {} +
```

Verify:
```bash
grep -rn "Examples/DiagramPlayground" Tests/ ; echo "exit=$?"
grep -rn "Sources/DiagramKitSample/Resources/test-diagrams.json" Tests/ | wc -l
```

Expected: first grep prints nothing (exit=1); second grep prints ~10.

- [ ] **Step 7: Drive-by fix — replace absolute path in WardleyMapEndToEndTests**

Edit `Tests/DiagramKitTests/WardleyMapEndToEndTests.swift` lines 19–22:

```swift
// OLD:
    func testPlaygroundWardleyExamplesParseLayoutAndRenderSvg() throws {
        let path = "/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift/Examples/DiagramPlayground/Resources/test-diagrams.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: path))

// NEW:
    func testPlaygroundWardleyExamplesParseLayoutAndRenderSvg() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests/DiagramKitTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Sources/DiagramKitSample/Resources/test-diagrams.json")
        let data = try Data(contentsOf: url)
```

(This is the same `#filePath`-relative walk used by `CorpusSnapshotTests.swift:49`, `PlaygroundExampleCatalogTests.swift:46`, etc.)

- [ ] **Step 8: Delete the now-empty `Examples/` directory**

Run:
```bash
ls Examples/ ; rmdir Examples
```

Expected: `ls` shows empty, `rmdir` succeeds silently.

- [ ] **Step 9: Re-resolve the package**

Run: `swift package resolve 2>&1 | tail -5`

Expected: no output or "Resolved version: …" — no errors.

- [ ] **Step 10: Verify Package.swift parses**

Run: `swift package dump-package > /dev/null`

Expected: exit code 0.

- [ ] **Step 11: Verify build**

Run: `swift build 2>&1 | tail -10`

Expected: "Build complete!" — no errors. Pay attention to any unresolved-import errors that would mean a `@testable import` rewrite was missed.

- [ ] **Step 12: Verify the playground regression suites pass**

Run: `swift test --filter DiagramPlaygroundRegressionTests 2>&1 | tail -20`

Expected: all tests pass.

Then run the broader Playground subdirectory:

```bash
swift test --filter "Playground" 2>&1 | tail -20
```

Expected: all tests pass. Caveat from memory `feedback_swift_test_filter.md`: be aware that broad substrings can hang. `Playground` is safe here because no corpus parameterized test name contains that substring — but if it does hang, fall back to running each `Tests/DiagramKitTests/Playground/<Suite>.swift` filter individually.

- [ ] **Step 13: Verify the Wardley test specifically (drive-by fix)**

Run: `swift test --filter WardleyMapEndToEndTests 2>&1 | tail -10`

Expected: all tests pass — proves the relative-path replacement is correct.

- [ ] **Step 14: Smoke-test the renamed executable builds**

Run: `swift build --product DiagramKitSample 2>&1 | tail -5 && ls .build/debug/DiagramKitSample`

Expected: build succeeds; executable exists at the new name.

- [ ] **Step 15: Commit**

```bash
git add -u
git commit -m "$(cat <<'EOF'
refactor: relocate sample to Sources/DiagramKitSample (renamed from DiagramPlayground)

Moves Examples/DiagramPlayground/ → Sources/DiagramKitSample/ via git mv
(preserves blame). Renames the @main struct DiagramPlaygroundApp →
DiagramKitSampleApp and the SwiftPM target / executable product accordingly.
Rewrites ~30 @testable imports and ~10 corpus path strings in tests. Drops
the now-redundant path: argument from the executable target (Sources/<Name>/
default applies). Deletes the now-empty Examples/ directory.

Drive-by: replaces a hardcoded absolute path in WardleyMapEndToEndTests:20
with the #filePath-relative walk used by sibling tests.

Refactor only — no behavior changes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Doc + script sweep

**Files:**
- Modify: `CLAUDE.md`
- Modify: `ARCHITECTURE.md`
- Modify: `BASELINES.md`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `CONTRIBUTING.md`
- Modify: `Scripts/rebaseline-snapshots.sh:47`
- (Do NOT modify) `docs/archive/**` — frozen
- (Do NOT modify) `docs/superpowers/plans/**` or `docs/superpowers/specs/**` other than this plan/spec pair — also historical

### Steps

- [ ] **Step 1: Update `Scripts/rebaseline-snapshots.sh`**

Edit line 47:

```bash
# OLD:
JSON="Examples/DiagramPlayground/Resources/test-diagrams.json"

# NEW:
JSON="Sources/DiagramKitSample/Resources/test-diagrams.json"
```

- [ ] **Step 2: Sweep `CLAUDE.md` (highest signal — source of truth)**

Apply these replacements to `CLAUDE.md`:

- `Examples/DiagramPlayground` → `Sources/DiagramKitSample` (every occurrence)
- `Examples/DiagramPlayground/` → `Sources/DiagramKitSample/` (every occurrence; substring of above so order matters — do the longer one first)
- `swift run DiagramPlayground` → `swift run DiagramKitSample`
- In the Commands section: keep the comment about chunked rebaselining; ensure it references the new path
- In the Target Layout section: remove the `Examples/DiagramPlayground/` description from the bulleted list and replace with `Sources/DiagramKitSample/` containing the sample app and the `test-diagrams.json` corpus
- In the Critical Invariants section: in the macCatalyst-mentioning bullet (the one that bans thread pools), remove `.macCatalyst` from the platform enumeration in any parenthetical
- In the Discipline Gates section: delete the row for `Scripts/playground-a11y-check.sh` and its surrounding paragraph
- In the Testing And Snapshots section: change `Examples/DiagramPlayground/Resources/test-diagrams.json` references to the new path
- In the Target Layout pipeline ASCII art: if it depicts the package's platforms list, update; if it depicts the sample as `Examples/DiagramPlayground` in any text, update
- In the `DiagramKitInteractive` Apple-only mention: remove `.macCatalyst` from the enumerated platforms list
- In the "Examples/DiagramPlayground/UITests/" subsection: delete the entire subsection (XCUI bundle is gone)

Use Edit with `replace_all: true` for the pure string swaps; use targeted Edits for the structural removals (the gates table row, the UI test subsection).

Verify after editing:
```bash
grep -n "Examples/DiagramPlayground\|playground-a11y-check\|macCatalyst" CLAUDE.md ; echo "exit=$?"
```

Expected: prints nothing; exit code 1.

- [ ] **Step 3: Sweep `ARCHITECTURE.md`**

Apply the same string replacements:

- `Examples/DiagramPlayground` → `Sources/DiagramKitSample`
- `swift run DiagramPlayground` → `swift run DiagramKitSample`
- Any platform invariants listing `.macCatalyst` → remove

Verify:
```bash
grep -n "Examples/DiagramPlayground\|playground-a11y-check\|macCatalyst" ARCHITECTURE.md ; echo "exit=$?"
```

Expected: prints nothing; exit code 1.

- [ ] **Step 4: Sweep `BASELINES.md`**

Same replacements. Also remove any baseline metric for `playground-a11y-check.sh` if present.

Verify:
```bash
grep -n "Examples/DiagramPlayground\|playground-a11y-check\|macCatalyst" BASELINES.md ; echo "exit=$?"
```

Expected: prints nothing; exit code 1.

- [ ] **Step 5: Sweep `README.md`**

Same replacements. The README is user-facing — be especially careful about command examples.

Verify:
```bash
grep -n "Examples/DiagramPlayground\|playground-a11y-check\|macCatalyst" README.md ; echo "exit=$?"
```

Expected: prints nothing; exit code 1.

- [ ] **Step 6: Sweep `AGENTS.md` and `CONTRIBUTING.md`**

Same replacements.

Verify:
```bash
grep -n "Examples/DiagramPlayground\|playground-a11y-check\|macCatalyst" AGENTS.md CONTRIBUTING.md ; echo "exit=$?"
```

Expected: prints nothing; exit code 1.

- [ ] **Step 7: Full repo verification (excluding frozen archives + the spec/plan pair)**

Run:
```bash
grep -rn "Examples/DiagramPlayground\|playground-a11y-check\|macCatalyst" \
  --include="*.md" --include="*.sh" --include="*.swift" \
  Sources Tests Scripts docs CLAUDE.md ARCHITECTURE.md BASELINES.md README.md AGENTS.md CONTRIBUTING.md \
  2>/dev/null \
  | grep -v "docs/archive/" \
  | grep -v "docs/superpowers/plans/" \
  | grep -v "docs/superpowers/specs/" \
  ; echo "exit=$?"
```

Expected: prints nothing; exit code 1. (`docs/archive/`, `docs/superpowers/plans/`, and `docs/superpowers/specs/` are all historical-record directories — they intentionally narrate the prior `Examples/DiagramPlayground` state. Non-archive `docs/*.md` files like `docs/diagnostic-severity-discipline.md` ARE scanned here.)

- [ ] **Step 8: Verify the test suite still passes (no path-string assertions broken)**

Some tests assert on path substrings (e.g. `PlaygroundExampleCatalogTests.swift:103` asserts `modelSource.contains("Resources/test-diagrams.json")`). Confirm those still pass:

```bash
swift test --filter PlaygroundExampleCatalogTests 2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add -u
git commit -m "$(cat <<'EOF'
docs: update CLAUDE.md / ARCHITECTURE.md / README.md / friends for sample relocation

Sweep the root docs (CLAUDE.md, ARCHITECTURE.md, BASELINES.md, README.md,
AGENTS.md, CONTRIBUTING.md) plus Scripts/rebaseline-snapshots.sh:

- Examples/DiagramPlayground/      -> Sources/DiagramKitSample/
- swift run DiagramPlayground       -> swift run DiagramKitSample
- Drop macCatalyst from platform invariants
- Remove the playground-a11y-check.sh row from the gates table
- Drop the UI-test bundle subsection from CLAUDE.md's target-layout section

docs/archive/ and the docs/superpowers/{plans,specs}/ historical artifacts
are left untouched (they narrate prior-state by design).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Dead availability-guard cleanup

**Files:**
- Modify: ~69 files under `Sources/DiagramKitSample/` containing `@available(... 26.0, *)` or `if #available(... 26.0, *)` guards (97 total guard sites)

### Steps

- [ ] **Step 1: Inventory the guards to be removed**

Run:
```bash
grep -rEn "@available\([^)]*26\.0[^)]*\*\)|if #available\([^)]*26\.0[^)]*\*\)" \
  Sources/DiagramKitSample/ | wc -l
```

Expected: ~97 hits.

Also list the unique guard patterns:
```bash
grep -rEoh "@available\([^)]*26\.0[^)]*\*\)" Sources/DiagramKitSample/ | sort -u
grep -rEoh "if #available\([^)]*26\.0[^)]*\*\)" Sources/DiagramKitSample/ | sort -u
```

Expected patterns include `@available(macOS 26.0, *)`, `@available(iOS 26.0, macOS 26.0, *)`, `@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)` (the macCatalyst variants survived Task 1 only because they're guards, not directives — Task 5 deletes them).

- [ ] **Step 2: Remove `@available(... 26.0, *)` attribute lines**

For each file with a standalone `@available(... 26.0, *)` attribute line preceding a declaration, delete the attribute line entirely.

Example transformation in `Sources/DiagramKitSample/DiagramKitSampleApp.swift`:

```swift
// OLD (lines 16–18 of the renamed file):
@main
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct DiagramKitSampleApp: App {

// NEW:
@main
struct DiagramKitSampleApp: App {
```

And:

```swift
// OLD:
@available(macOS 26.0, *)
@MainActor
private func focusedTextViewUndoManager() -> UndoManager? {

// NEW:
@MainActor
private func focusedTextViewUndoManager() -> UndoManager? {
```

Do this for all standalone-attribute occurrences across the ~69 files.

- [ ] **Step 3: Collapse `if #available(... 26.0, *)` runtime checks**

For each `if #available(macOS 26.0, *) { … } else { … }` block, keep the `if` branch unconditionally and delete the `else` branch (and the directives).

```swift
// OLD:
if #available(macOS 26.0, *) {
    doNewAPI()
} else {
    doFallback()
}

// NEW:
doNewAPI()
```

For `guard #available(macOS 26.0, *) else { … }` patterns, delete the entire guard since it now never triggers.

- [ ] **Step 4: Handle inline attribute fragments (rare)**

Some `@available(...)` attributes are inline with a declaration (e.g. `public @available(macOS 26.0, *) func foo()`). For those, delete just the attribute fragment without disturbing the declaration.

- [ ] **Step 5: Verify build with no new warnings**

Run:
```bash
swift build 2>&1 | grep -iE "availability|deprecation|warning" ; echo "exit=$?"
```

Expected: no availability/deprecation warnings introduced; exit code 1 (no matches). Pre-existing warnings unrelated to this change may still appear — eyeball that the diff is "nothing new", not zero output.

- [ ] **Step 6: Verify the playground regression suites still pass**

Run: `swift test --filter "Playground" 2>&1 | tail -20`

Expected: all tests pass.

- [ ] **Step 7: Verify the sample executable still builds**

Run: `swift build --product DiagramKitSample 2>&1 | tail -5`

Expected: "Build complete!"

- [ ] **Step 8: Final grep for residual `... 26.0, *` guards in the sample**

```bash
grep -rEn "@available\([^)]*26\.0[^)]*\*\)|if #available\([^)]*26\.0[^)]*\*\)" \
  Sources/DiagramKitSample/ ; echo "exit=$?"
```

Expected: zero hits (exit=1). If any survive, they may be sites you intentionally kept (e.g. a `@available(macOS 26.5, *)` guard for an API even newer than the floor — leave those alone). The scope is specifically `26.0`.

- [ ] **Step 9: Commit**

```bash
git add -u Sources/DiagramKitSample
git commit -m "$(cat <<'EOF'
chore: strip dead @available(... 26.0, *) guards from sample now that floor is 26

The package-wide platform floor moved to macOS 26 / iOS 26 in commit 1 of
this series, making every @available(macOS 26.0, *) / @available(iOS 26.0, *)
guard in Sources/DiagramKitSample/ a tautology. ~97 guard sites collapse to
their non-guarded branch. Strips trailing macCatalyst alternatives within
those guards in the same pass.

Library-target guards with a lower floor (@available(macOS 14, *) etc.) are
intentionally left alone — those reflect older library design decisions
unrelated to the sample.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Manual verification after the chain lands

These are NOT automated and need a human:

- [ ] **Sample launches** — `swift run DiagramKitSample`, sanity-check that the editor + canvas + sidebar render correctly and a sample diagram appears.
- [ ] **Xcode previews still work** — Open `Package.swift` in Xcode, select the `DiagramKitSample` scheme, verify SwiftUI `#Preview` macros expand. (The `DIAGRAMKIT_SWIFTPM` define is preserved precisely for this.)
- [ ] **Full smoke check** — Run `Scripts/bootstrap-smoke-check.sh`. The tvOS + visionOS rows are gone; the remaining gates should all pass (modulo the pre-existing `CorpusSnapshotTests` signal-10 caveat noted in memory `corpus_signal_10.md`).

---

## Rollback plan

- **Commits 1, 2, 5** are independent and revertable via `git revert <sha>`.
- **Commits 3 and 4** are the load-bearing pair. If Task 3 fails partway, fix forward (a missed `@testable import` rewrite is almost always the culprit). If Task 4 fails, fix forward; do not revert Task 3.
- Do not use `git push --force` or `--no-verify`. If a pre-commit hook fails, fix and create a new commit per `CLAUDE.md`.

---

## What this plan does NOT do (deferred follow-ups)

- Extract `test-diagrams.json` into a dedicated `DiagramKitTestCorpus` target (MusicToolkit pattern).
- Sweep dead `A11yID` constants in the sample now that the UI test bundle is gone.
- Re-introduce accessibility audit coverage as a SwiftPM test target.

These are intentionally out of scope.

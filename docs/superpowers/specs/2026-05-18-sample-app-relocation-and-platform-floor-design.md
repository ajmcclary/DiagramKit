# Sample App Relocation + Platform Floor Bump — Design

**Date:** 2026-05-18
**Status:** Approved (brainstorming); awaiting implementation plan
**Scope:** Refactor only — no new features, no behavior changes

## Summary

Two coupled changes:

1. Move the sample app from `Examples/DiagramPlayground/` into `Sources/DiagramKitSample/` so it lives alongside the library targets and is treated as a first-class part of the codebase, mirroring `CodeEditorPlugin/Sources/CodeEditorSample/`.
2. Raise the package-wide platform floor to **macOS 26 + iOS 26 only**, dropping `macCatalyst`, `tvOS`, and `visionOS` from the matrix. This deletes ~155 `macCatalyst` conditional clauses and unlocks ~103 now-redundant `@available(... 26.0, *)` guards in the sample.

The two changes are sequenced as a chain of five independent commits on `main`, each independently buildable and testable.

## Goals

- **Match the rest of the workspace.** `CodeEditorPlugin` ships its sample as `Sources/CodeEditorSample/` with package platforms `[.macOS("26.3"), .iOS("26.3")]`. DiagramKit should join that pattern.
- **Simplify the surface.** No more bundled `.xcodeproj`, no xcodegen, no XCUI bundle, no `playground-a11y-check.sh` gate. The sample becomes a pure SwiftPM `.executableTarget` run via `swift run DiagramKitSample`.
- **Strip dead conditionals.** Every `.condition(.when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst]))` clause becomes unnecessary once the package only ships macOS+iOS.
- **Preserve test coverage** for everything that survives. The 30+ `@testable import DiagramPlayground` test sites get rewritten to `@testable import DiagramKitSample`; the ~10 hardcoded corpus paths get rewritten to point at the new location.

## Non-goals

- No decomposition of the corpus into a dedicated `DiagramKitTestCorpus` target. (Considered; chosen against. Can be a follow-up.)
- No restructuring of the existing 14 library targets, their dependency graph, or public API. (Pruning redundant `.condition(.when(platforms:))` clauses from existing target declarations is in scope and is not "restructuring".)
- No new features in the sample app. No behavior changes anywhere.
- No history rewriting in `docs/archive/*` — that directory stays frozen.
- No removal of the `XCUI` accessibility audit infrastructure beyond what is dictated by deleting the host project. `A11yID` constants in the sample become candidates for dead-code cleanup *only if* grep shows zero remaining consumers, and only as a follow-up.

## Decisions (confirmed)

| Decision | Choice | Why |
|---|---|---|
| Platform floor | `[.macOS(.v26), .iOS(.v26)]` only | Matches `CodeEditorPlugin`. Smallest matrix. User explicitly stated "macOS 26 or higher." |
| Drop `macCatalyst` | Yes | User-requested. ~155 conditional clauses removed mechanically. |
| Drop `tvOS` | Yes | Not in current `platforms:` list anyway; only appears in `bootstrap-smoke-check.sh` and conditional clauses. |
| Drop `visionOS` | Yes | Was at `.v1`. Removing it shrinks the matrix; user did not request keeping it. |
| Xcode artifacts | Delete `.xcodeproj`, `.xcworkspace`, `project.yml`, `Info.plist`, `UITests/`, `Scripts/playground-a11y-check.sh` | Match `CodeEditorSample` (pure SwiftPM, no Xcode-side artifacts). |
| Target name | `DiagramPlayground` → `DiagramKitSample` | Mirror `CodeEditorSample` naming convention. |
| Target path | `Examples/DiagramPlayground/` → `Sources/DiagramKitSample/` | User requested move into `Sources/`. |
| Corpus location | Stays co-located with sample: `Sources/DiagramKitSample/Resources/test-diagrams.json` | Smallest scope; existing test-target dependency on the sample is preserved. |

## Target layout after the refactor

### Package.swift skeleton

```swift
let package = Package(
    name: "DiagramKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        // 14 existing library products, unchanged
        .executable(name: "DiagramKitSample", targets: ["DiagramKitSample"]),
    ],
    dependencies: [/* unchanged */],
    targets: [
        // Every library target keeps its dependencies, but each
        // `.condition(.when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst]))`
        // clause is deleted outright (the package-level floor now makes it redundant).

        .executableTarget(
            name: "DiagramKitSample",
            dependencies: [
                "DiagramKit",
                "DiagramKitD2", "DiagramKitGraphviz", "DiagramKitStructurizr", "DiagramKitPlantUML",
                "DiagramKitInteractive",  // no longer conditional
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ],
            // No `path:` — SwiftPM's default Sources/<TargetName>/ convention now applies.
            // No `exclude:` — Info.plist / project.yml / Scripts / UITests were deleted in commit 2.
            resources: [.process("Resources")],
            swiftSettings: strictConcurrencySettings + [.define("DIAGRAMKIT_SWIFTPM")]
        ),
        .testTarget(
            name: "DiagramKitTests",
            dependencies: [
                /* unchanged, EXCEPT */ "DiagramKitSample",  // was: "DiagramPlayground"
                /* … */
            ],
            exclude: ["__Snapshots__", "RoundTrip/Resources"],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(name: "DiagramKitLinuxTests", /* unchanged */)
    ],
    swiftLanguageModes: [.v6]
)
```

### Filesystem after the refactor

```
mermaid-swift/
├── Sources/
│   ├── DiagramKit/                   (unchanged)
│   ├── DiagramKitCommon/             (unchanged)
│   ├── … 12 other library targets, unchanged …
│   └── DiagramKitSample/             ← moved from Examples/DiagramPlayground/
│       ├── DiagramKitSampleApp.swift    (renamed from DiagramPlaygroundApp.swift)
│       ├── Models/                      (unchanged)
│       ├── Views/                       (unchanged)
│       └── Resources/                   (unchanged — incl. test-diagrams.json)
├── Examples/                         ← deleted (was only DiagramPlayground)
├── Scripts/
│   ├── bootstrap-smoke-check.sh         (tvOS + visionOS rows removed)
│   └── playground-a11y-check.sh         ← deleted
└── (everything else unchanged)
```

### Things that are explicitly NOT changing

- The 14 library products and their internal dependency graph.
- `DiagramKitTests`' `@testable` access to the sample (rename is purely the module identifier).
- Linux portability — the sample is already Apple-only; SwiftPM skips Apple-only executable targets on Linux automatically; `linux-check.sh` continues to build only the Linux-portable targets.
- The `DIAGRAMKIT_SWIFTPM` define — still needed because `#Preview` macros only expand under the Xcode app-preview build path.
- The corpus signal-10 caveat — pre-existing on main; not in scope.

## Per-commit slice details

Five commits on `main`, each independently buildable and testable. Verification command listed under each.

### Commit 1 — Platform floor + Catalyst/tvOS/visionOS strip

- `Package.swift`: `platforms:` → `[.macOS(.v26), .iOS(.v26)]`. Delete every `.condition(.when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst]))` clause outright — the package-level floor now makes them redundant rather than just narrowing them.
- `Scripts/bootstrap-smoke-check.sh`: remove the `run_build "visionOS"` and `run_build "tvOS"` rows.
- Source code: collapse any `#if targetEnvironment(macCatalyst)` blocks to their non-Catalyst branch (delete the Catalyst-only path).
- **Out of scope for this commit:** the 103 `@available(... 26.0, *)` / `if #available(... 26.0, *)` guards in the sample. Those are mechanical cleanup once the floor is in (commit 5).
- **Verify:** `swift build && swift test --filter MermaidPipelineConcurrencyTests`. Then `Scripts/bootstrap-smoke-check.sh` runs macOS + iOS rows only.

### Commit 2 — Drop Xcode artifacts

- Delete: `Examples/DiagramPlayground/DiagramPlayground.xcodeproj`, `…xcworkspace`, `project.yml`, `Info.plist`, the entire `UITests/` directory, `Examples/DiagramPlayground/Scripts/`, and top-level `Scripts/playground-a11y-check.sh`.
- `Package.swift`: trim the executable's `exclude:` list (was guarding `Info.plist`, `project.yml`, `Scripts`, `UITests` — all now gone).
- **Verify:** `swift build && swift run DiagramPlayground` (binary launches). `swift test --filter DiagramPlaygroundRegressionTests`.

### Commit 3 — Move + rename (the load-bearing one)

- `git mv Examples/DiagramPlayground Sources/DiagramKitSample` (preserves blame).
- Rename `DiagramPlaygroundApp.swift` → `DiagramKitSampleApp.swift`; rename the `@main` struct `DiagramPlaygroundApp` → `DiagramKitSampleApp`.
- `Package.swift`: rename target `DiagramPlayground` → `DiagramKitSample`, drop the `path:` argument entirely (SwiftPM default `Sources/<TargetName>/` now applies), rename the product, and update the `Tests/DiagramKitTests` dependency entry.
- Rewrite ~30 `@testable import DiagramPlayground` → `@testable import DiagramKitSample`.
- Rewrite ~10 corpus paths `Examples/DiagramPlayground/Resources/test-diagrams.json` → `Sources/DiagramKitSample/Resources/test-diagrams.json`.
- Drive-by fix: `Tests/DiagramKitTests/WardleyMapEndToEndTests.swift:20` hard-codes an *absolute* user-specific path. Update to the relative-walk pattern used by its siblings.
- Delete the now-empty `Examples/` directory.
- Run `swift package resolve`.
- **Verify:** `swift build && swift test --filter Playground` (covers `Tests/DiagramKitTests/Playground/*` + `DiagramPlaygroundRegressionTests`). Then `swift run DiagramKitSample`.

### Commit 4 — Doc + script sweep

- Text replace across `CLAUDE.md`, `ARCHITECTURE.md`, `BASELINES.md`, `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `docs/*.md` (excluding `docs/archive/`):
  - `Examples/DiagramPlayground/` → `Sources/DiagramKitSample/`
  - `DiagramPlayground` target/command refs → `DiagramKitSample`
  - `swift run DiagramPlayground` → `swift run DiagramKitSample`
- `CLAUDE.md` specifically: remove the `playground-a11y-check.sh` row from the discipline-gates table; remove its mention from the "DiagramPlayground UI tests" target-layout paragraph; remove the `macCatalyst` entry from the platforms invariant; update `DiagramKitInteractive`'s Apple-only platform list (drop Catalyst/tvOS/visionOS).
- `Scripts/check-file-sizes-allowlist.txt`, `Scripts/rebaseline-snapshots.sh`, and any other Scripts: grep for `Examples/DiagramPlayground` and update.
- `docs/archive/*` is historical — leave frozen; do not rewrite history.
- **Verify:** `grep -r "Examples/DiagramPlayground\|playground-a11y-check\|macCatalyst" Sources Tests Scripts CLAUDE.md ARCHITECTURE.md BASELINES.md README.md AGENTS.md CONTRIBUTING.md docs --exclude-dir=archive` returns zero hits.

### Commit 5 — Dead availability-guard cleanup

- In `Sources/DiagramKitSample/`: strip the 103 `@available(macOS 26.0, *)` / `@available(iOS 26.0, *)` / `if #available(macOS 26.0, *)` / `targetEnvironment(macCatalyst)` guards. Each is now a tautology.
- **Scope discipline:** only delete guards where the bound is ≤ the new floor. Leave alone any `@available(macOS 14, *)` shims elsewhere — those were intentional design choices unrelated to the sample.
- **Verify:** `swift build 2>&1 | grep -i "availability\|deprecation"` returns zero new warnings; `swift test --filter Playground` still passes.

### Ordering rationale

- **Commit 1 before 2** because dropping the Xcode artifacts is independent and small; doing it second keeps commit 1 focused on the package-level platform change.
- **Commit 2 before 3** so the `git mv` in 3 moves only the SwiftPM-relevant tree (no `.xcodeproj` blob noise in the rename diff).
- **Commit 4 before 5** so the doc sweep is grepable for the pre-cleanup state of source.
- **Commit 5 last** because it's optional polish — if anything breaks, stopping after 4 leaves the refactor complete.

## Verification + risk strategy

### Discipline gates after the chain lands

Per `CLAUDE.md`, `Scripts/bootstrap-smoke-check.sh` is the merge gate. After commit 4 it runs:

- `swift package dump-package` — catches Package.swift parse regressions
- `swift test` (subject to the corpus signal-10 caveat — use `--filter`)
- `Scripts/check-file-sizes.sh` — should pass; no Swift file is being grown
- `Scripts/check-sendable-annotations.sh` — should pass; no `@unchecked Sendable` is being touched
- `Scripts/strict-concurrency-check.sh` — should pass; no concurrency code is changing
- `Scripts/linux-check.sh` — should pass; the Linux-portable target matrix doesn't include the sample
- `Scripts/check-diagnostic-discipline.sh` — should pass; no diagnostic emission sites are being touched
- `xcodebuild` multiplatform sweep — **changes shape**: tvOS and visionOS rows are gone (commit 1); macOS + iOS slices are what remain

### Transitional-state risks across the chain

- **After commit 1, before commit 2:** the executable still has its `exclude: ["Info.plist", "project.yml", "Scripts", "UITests"]` and the Xcode artifacts are still on disk. SwiftPM unaffected; risk is zero.
- **After commit 2, before commit 3:** the sample is now pure SwiftPM but still under `Examples/DiagramPlayground/`. The 30 `@testable import DiagramPlayground` sites in tests still resolve because the target name hasn't changed yet. Risk is zero.
- **After commit 3, before commit 4:** docs and the secondary scripts still refer to old paths/names. The package itself builds and tests pass. The risk is that someone copy-pastes from CLAUDE.md and hits a stale path — short window if commit 4 lands promptly.
- **After commit 4, before commit 5:** 103 dead availability guards remain. Code works; it just looks transitional. Safe stopping point if commit 5 surfaces something unexpected.

### Things that need manual verification (no automated gate)

- **The sample app actually launches and renders a diagram.** `swift run DiagramKitSample` after commit 3 — sanity-check the editor + canvas + sidebar render correctly.
- **`#Preview` macros still expand in Xcode** for the sample. Open `Package.swift` in Xcode, pick the `DiagramKitSample` scheme, and verify SwiftUI previews work. The `DIAGRAMKIT_SWIFTPM` define is preserved precisely for this reason.

### What we are losing in exchange (acknowledged)

- The `AccessibilityAuditTests`, `IdentifierPresenceTests`, `SmokeTests`, and ~12 other XCUI suites driven by `Scripts/playground-a11y-check.sh` are gone. The `performAccessibilityAudit()` coverage across five screen states is no longer enforced. If this regresses, it will be a human-reported bug, not a CI signal.
- The `A11yID` constants in the sample become dead code unless something else depends on them. **Out of scope** for this refactor — clean up only if grep shows zero remaining consumers, and only as a follow-up.

### Recovery plan if something breaks mid-chain

- **Commits 1, 2, 5** are independent and revertable; if commit 5 turns up an availability surprise, `git revert` it and ship through commit 4.
- **Commit 3 is the load-bearing one.** If `swift test --filter Playground` fails after commit 3, the fix is almost certainly a missed `@testable import` rewrite or a missed corpus-path rewrite. Fix forward in a 3a follow-up commit; don't revert (the rename is the whole point).
- **No `--no-verify` or `git push --force` is contemplated.** If a pre-commit hook fails, fix the underlying issue and create a new commit per `CLAUDE.md`.

### Known caveat we are leaving alone

- The full `CorpusSnapshotTests` signal-10 crash is pre-existing on `main`. This refactor does not touch the snapshot infrastructure, so the caveat carries forward unchanged. Verification uses `swift test --filter` against named suites, not the full suite.

## Open questions / follow-ups

None blocking. Two natural follow-ups, both explicitly out of scope here:

1. Extract `test-diagrams.json` into a dedicated `DiagramKitTestCorpus` target (MusicToolkit pattern). Would let `DiagramKitTests` stop depending on the sample.
2. Sweep the sample for `A11yID` constants that became dead code after the XCUI bundle was deleted.

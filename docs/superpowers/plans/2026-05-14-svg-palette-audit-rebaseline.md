# SVG Palette Audit + Baseline Regeneration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pin SVG palette math + pipeline integrity with two new tests, then regenerate 435 SVG + 435 image baselines so `CorpusSnapshotTests` is green against the post-`1c2f18f` resolver output.

**Architecture:** Audit-gated, five-commit sequence (C1 tests → C2 conditional fix → C3 record driver → C4 SVG rebaseline → C5 image rebaseline). Audit tests assert the rendered SVG palette equals `_hex(theme.effective<Token>())` and reject malformed leftovers (`var(--`, `))` after hex, `NaN`, empty `stroke=""`/`fill=""`). Recording is chunked through a new shell script that resumes from a `missing-*.txt` ledger.

**Tech Stack:** Swift 6, XCTest (matching `PieParserTests.swift` pattern), `swift-snapshot-testing`, bash 5 (rebaseline driver). All new tests Apple-only — gated `#if canImport(UIKit) || canImport(AppKit)` because the SVG render path itself is gated that way in `SVGHelpers.swift:1` and `DiagramEngine.swift:120`.

**Spec:** `docs/superpowers/specs/2026-05-14-svg-palette-audit-rebaseline-design.md`

---

## File Structure

| File | Action | Lines | Lands in |
|---|---|---|---|
| `Tests/DiagramKitTests/PalettePinTests.swift` | Create | ~100 | C1 |
| `Tests/DiagramKitTests/SVGStructuralSweepTests.swift` | Create | ~130 | C1 |
| `CLAUDE.md` | Modify (test count 216→218) | 1 line | C1 |
| Renderer source *(if audit fails)* | Modify | varies | C2 |
| `Scripts/rebaseline-snapshots.sh` | Create | ~100 | C3 |
| `CLAUDE.md` | Modify (Commands block) | ~3 lines | C3 |
| `.gitignore` | Modify (ignore `.rebaseline-logs/`) | 1 line | C3 |
| `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-*.txt` | Modify | 422 files | C4 |
| `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/multiFormatSvgSnapshot-*.txt` | Modify | 13 files | C4 |
| `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/imageSnapshot-*.png` | Modify | 422 files | C5 |
| `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/multiFormatImageSnapshot-*.png` | Modify | 13 files | C5 |
| `REVIEW.md` | Modify (Session-4 row) | ~10 lines | C5 |
| `BASELINES.md` | Modify (rebaseline-event row) | ~3 lines | C5 |

---

## Task 1: Create PalettePinTests.swift (test stub + first failing case)

**Files:**
- Create: `Tests/DiagramKitTests/PalettePinTests.swift`

- [ ] **Step 1: Write a failing test for one theme's palette**

```swift
// Tests/DiagramKitTests/PalettePinTests.swift
#if canImport(UIKit) || canImport(AppKit)
import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// REVIEW.md §1. Pins `Theme.effective<Token>()` math as canonical:
/// for each built-in theme, the rendered SVG must contain the hex
/// `_hex(theme.effective<Token>())` returns. This prevents the
/// "all tokens collapsed to fg" regression mode the review flagged
/// and runs in <1 s so iteration on Phase 2 fixes is fast.
final class PalettePinTests: XCTestCase {

    /// Canary diagram exercising every color role:
    ///  - node body fill (surface) and outline (border) on A and B
    ///  - edge stroke (line) and arrow head (accent)
    ///  - edge label fill (muted) and node text fill (fg)
    private static let canarySource = """
    flowchart TD
        A[Start] -->|step| B[End]
    """

    func testZincLightPalette() async throws {
        let theme = DiagramTheme.zincLight
        let svg = try await DiagramEngine.renderSVG(
            source: Self.canarySource,
            theme: theme
        )

        let line    = try XCTUnwrap(_hex(theme.effectiveLine()),    "no line hex")
        let muted   = try XCTUnwrap(_hex(theme.effectiveMuted()),   "no muted hex")
        let accent  = try XCTUnwrap(_hex(theme.effectiveAccent()),  "no accent hex")
        let surface = try XCTUnwrap(_hex(theme.effectiveSurface()), "no surface hex")
        let border  = try XCTUnwrap(_hex(theme.effectiveBorder()),  "no border hex")

        XCTAssertTrue(svg.contains(line),    "expected line=\(line) in SVG")
        XCTAssertTrue(svg.contains(muted),   "expected muted=\(muted) in SVG")
        XCTAssertTrue(svg.contains(accent),  "expected accent=\(accent) in SVG")
        XCTAssertTrue(svg.contains(surface), "expected surface=\(surface) in SVG")
        XCTAssertTrue(svg.contains(border),  "expected border=\(border) in SVG")
    }
}
#endif
```

- [ ] **Step 2: Run the test, observe pass-or-fail**

Run: `swift test --filter PalettePinTests/testZincLightPalette`
Expected: either PASS (renderer was already correct — C2 will be skipped) or FAIL on a specific assertion (audit succeeded — record which token failed, drives Task 4).

Do NOT proceed to Step 3 until you've recorded the outcome. Save the test log to `.audit-zinc-light.log` for reference in Task 4.

```bash
swift test --filter PalettePinTests/testZincLightPalette 2>&1 | tee .audit-zinc-light.log
```

- [ ] **Step 3: Do NOT commit yet — proceed to Task 2 first**

Both audit suites land together as C1.

---

## Task 2: Extend PalettePinTests to cover all built-in themes + malformed-string rejection

**Files:**
- Modify: `Tests/DiagramKitTests/PalettePinTests.swift`

- [ ] **Step 1: Add all-themes loop and malformed-pattern assertions**

Replace the single `testZincLightPalette` method body with the loop below, and add the malformed-string check method:

```swift
    func testPalettePinAcrossThemes() async throws {
        var failures: [String] = []
        for (name, theme) in DiagramTheme.allThemes {
            let svg: String
            do {
                svg = try await DiagramEngine.renderSVG(
                    source: Self.canarySource,
                    theme: theme
                )
            } catch {
                failures.append("[\(name)] render threw: \(error)")
                continue
            }

            if let fail = palettePinFailure(svg: svg, themeName: name, theme: theme) {
                failures.append(fail)
            }
            if let fail = structuralFailure(svg: svg, themeName: name) {
                failures.append(fail)
            }
        }
        if !failures.isEmpty {
            XCTFail("palette pin failures:\n  " + failures.joined(separator: "\n  "))
        }
    }

    /// Returns nil on pass, a one-line description on first failure.
    private func palettePinFailure(svg: String, themeName: String, theme: DiagramTheme) -> String? {
        guard let line    = _hex(theme.effectiveLine())    else { return "[\(themeName)] no line hex" }
        guard let muted   = _hex(theme.effectiveMuted())   else { return "[\(themeName)] no muted hex" }
        guard let accent  = _hex(theme.effectiveAccent())  else { return "[\(themeName)] no accent hex" }
        guard let surface = _hex(theme.effectiveSurface()) else { return "[\(themeName)] no surface hex" }
        guard let border  = _hex(theme.effectiveBorder())  else { return "[\(themeName)] no border hex" }

        if !svg.contains(line)    { return "[\(themeName)] expected line=\(line) in SVG" }
        if !svg.contains(muted)   { return "[\(themeName)] expected muted=\(muted) in SVG" }
        if !svg.contains(accent)  { return "[\(themeName)] expected accent=\(accent) in SVG" }
        if !svg.contains(surface) { return "[\(themeName)] expected surface=\(surface) in SVG" }
        if !svg.contains(border)  { return "[\(themeName)] expected border=\(border) in SVG" }
        return nil
    }

    /// Returns nil on pass, a one-line description on first malformed-pattern hit.
    private func structuralFailure(svg: String, themeName: String) -> String? {
        if svg.contains("var(--") {
            return "[\(themeName)] unresolved var(--…) in SVG"
        }
        if svg.range(of: #"#[0-9A-Fa-f]{6}[^\"]*\)\)"#, options: .regularExpression) != nil {
            return "[\(themeName)] color-mix \\\"))\\\" tail after hex"
        }
        if svg.range(of: #"\bNaN\b|\bnan\b"#, options: .regularExpression) != nil {
            return "[\(themeName)] NaN substring in SVG"
        }
        if svg.contains("stroke=\"\"") || svg.contains("fill=\"\"") {
            return "[\(themeName)] empty stroke=\"\" or fill=\"\""
        }
        return nil
    }
```

Then delete the now-replaced `testZincLightPalette` method.

- [ ] **Step 2: Run the full PalettePinTests suite**

Run: `swift test --filter PalettePinTests`
Expected (Path A): PASS — renderer is already correct, Task 4 will be a no-op.
Expected (Path B): FAIL with a list of `[<theme>] expected <token>=<hex> in SVG` lines. Save the log for Task 4.

```bash
swift test --filter PalettePinTests 2>&1 | tee .audit-all-themes.log
```

- [ ] **Step 3: Do NOT commit yet — proceed to Task 3 (structural sweep) first**

---

## Task 3: Create SVGStructuralSweepTests.swift

**Files:**
- Create: `Tests/DiagramKitTests/SVGStructuralSweepTests.swift`

- [ ] **Step 1: Write the live-render sweep test**

```swift
// Tests/DiagramKitTests/SVGStructuralSweepTests.swift
#if canImport(UIKit) || canImport(AppKit)
import XCTest
import Foundation
import DiagramKitTestSupport
@testable import DiagramKit

/// REVIEW.md §1. Walks the full corpus through the SVG render path and
/// fails on any pipeline-integrity violation (unresolved var(), `))`
/// after hex, NaN, empty stroke/fill). Independent of `__Snapshots__/`
/// baselines so it stays green across the C4/C5 rebaseline.
final class SVGStructuralSweepTests: XCTestCase {

    // MARK: - Loaders (independent copy of CorpusSnapshotTests.loadDiagrams)

    private static func projectRoot() -> URL {
        var url = URL(fileURLWithPath: #file).deletingLastPathComponent()
        while url.path != "/" {
            let package = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private static func loadCorpus() throws -> [CorpusEntry] {
        // Pin gantt today-marker the same way CorpusSnapshotTests does.
        setenv("DIAGRAMKIT_GANTT_TODAY", "2024-06-15", 1)
        let jsonURL = projectRoot()
            .appendingPathComponent("Examples/DiagramPlayground/Resources/test-diagrams.json")
        let data = try Data(contentsOf: jsonURL)
        let file = try JSONDecoder().decode(CorpusFile.self, from: data)
        for entry in file.diagrams {
            try entry.validate()
        }
        return file.diagrams
    }

    // MARK: - Tests

    func testLiveRenderSweep() async throws {
        let entries = try Self.loadCorpus()
        var violations: [String] = []
        for entry in entries {
            let svg: String
            do {
                svg = try await DiagramEngine.renderSVG(source: entry.source)
            } catch {
                violations.append("\(entry.id): render threw \(error)")
                continue
            }
            if let v = Self.firstViolation(in: svg) {
                violations.append("\(entry.id): \(v)")
            }
        }
        if !violations.isEmpty {
            XCTFail("\(violations.count) structural violation(s):\n  " + violations.joined(separator: "\n  "))
        }
    }

    func testOnDiskSweep() throws {
        guard ProcessInfo.processInfo.environment["SVG_SWEEP_ON_DISK"] == "1" else {
            throw XCTSkip("on-disk mode requires SVG_SWEEP_ON_DISK=1")
        }
        let snapshotDir = Self.projectRoot()
            .appendingPathComponent("Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests")
            .path
        let files = try FileManager.default.contentsOfDirectory(atPath: snapshotDir).filter {
            ($0.hasPrefix("svgSnapshot-") || $0.hasPrefix("multiFormatSvgSnapshot-"))
                && $0.hasSuffix(".txt")
        }
        var violations: [String] = []
        for f in files {
            let contents = try String(contentsOfFile: "\(snapshotDir)/\(f)")
            if let v = Self.firstViolation(in: contents) {
                violations.append("\(f): \(v)")
            }
        }
        if !violations.isEmpty {
            XCTFail("\(violations.count) on-disk violation(s):\n  " + violations.joined(separator: "\n  "))
        }
    }

    // MARK: - Shared check

    /// Returns nil on clean SVG, or a one-line description of the first
    /// malformed-pattern hit. Order is: unresolved var() → )) tail →
    /// NaN → empty stroke/fill.
    private static func firstViolation(in svg: String) -> String? {
        if let r = svg.range(of: "var(--") {
            let offset = svg.distance(from: svg.startIndex, to: r.lowerBound)
            return "literal var(-- at offset \(offset)"
        }
        if svg.range(of: #"#[0-9A-Fa-f]{6}[^\"]*\)\)"#, options: .regularExpression) != nil {
            return "color-mix \"))\" tail after hex"
        }
        if svg.range(of: #"\bNaN\b|\bnan\b"#, options: .regularExpression) != nil {
            return "NaN substring"
        }
        if svg.contains("stroke=\"\"") || svg.contains("fill=\"\"") {
            return "empty stroke=\"\" or fill=\"\""
        }
        return nil
    }
}
#endif
```

- [ ] **Step 2: Run the structural sweep**

Run: `swift test --filter SVGStructuralSweepTests/testLiveRenderSweep`
Expected (Path A): PASS — pipeline clean. Save log.
Expected (Path B): FAIL with `<entry.id>: <reason>` lines. Each line points at one corpus entry to investigate.

```bash
swift test --filter SVGStructuralSweepTests/testLiveRenderSweep 2>&1 | tee .audit-sweep.log
```

- [ ] **Step 3: Skip on-disk mode for now**

`testOnDiskSweep` is currently expected to FAIL because old baselines still have `))` tails. That's verified post-C4. Do not run with `SVG_SWEEP_ON_DISK=1` yet.

---

## Task 4: Conditional renderer fix (C2) — only if Task 2 or Task 3 reported failures

**Files:**
- Modify: renderer source — sites determined by which assertion failed. Candidates: `Sources/DiagramKitModel/SVGHelpers.swift`, `Sources/DiagramKitModel/Theme.swift`, `Sources/DiagramKitCommon/src_theme.swift`.

**This task has two branches.**

### Branch A: Both audit tests PASS on `main` → skip Task 4

If `.audit-all-themes.log` ends with `Test Suite 'PalettePinTests' passed` AND `.audit-sweep.log` ends with `Test Suite 'SVGStructuralSweepTests/testLiveRenderSweep' passed`, the renderer is already correct. The OLD baselines just record pre-`1c2f18f` malformed output. Proceed to Task 5.

### Branch B: One or both audit tests FAIL → diagnose + fix

- [ ] **Step 1: Identify the failing cell(s)**

Re-read `.audit-all-themes.log`. Each failure line has the shape `[<theme-name>] expected <token>=<hex> in SVG`. Group failures by `<token>` first, then by `<theme>`. A pattern across many themes for one token (e.g. all themes fail on `line=`) points at a shared helper. A single theme failing on multiple tokens points at that theme's definition.

- [ ] **Step 2: Diagnose one failing cell**

Pick the lowest-effort failure cell — usually the one where token's expected hex is far from `#27272A` (fg). Add a temporary debug block locally:

```swift
// In PalettePinTests, ABOVE the existing testPalettePinAcrossThemes:
func testDebugSingleTheme() async throws {
    let theme = DiagramTheme.zincLight  // or whichever theme failed
    let svg = try await DiagramEngine.renderSVG(source: Self.canarySource, theme: theme)
    print("expected line:", _hex(theme.effectiveLine()) ?? "nil")
    print("expected muted:", _hex(theme.effectiveMuted()) ?? "nil")
    // grep all hex strings in the SVG
    let hexes = svg.matches(of: try Regex(#"#[0-9A-Fa-f]{6}"#))
    print("actual hexes in SVG:", hexes.map { String($0.0) })
}
```

Run `swift test --filter PalettePinTests/testDebugSingleTheme`. Compare expected vs actual hexes. The diagnosis points at one of:

| Symptom | Likely site |
|---|---|
| Expected hex never appears | `_hex()` color-space round-trip (`SVGHelpers.swift:13-35`) — try AppKit `usingColorSpace(.deviceRGB)` early |
| Expected hex appears but token attribute is still `var(--…)` | `_flattenKnownSvgTokens` token replacement ordering (`SVGHelpers.swift:37-69`) |
| Hex format is right but value off by 1 in a channel | `BMColor.mixed` channel math — check `r,g,b` vs `R,G,B` capitalization |
| All tokens collapse to fg | `_flattenKnownSvgTokens` line 40 fallback path — `effectiveLine() ?? fg` is taking the `fg` branch unintentionally |

- [ ] **Step 3: Apply the minimal fix**

One commit per failing cell. Subject example:
`fix(svg): _flattenKnownSvgTokens fallback collapsed line to fg in zinc-light`

Do not bundle unrelated cleanup. Do not rename the surrounding code.

- [ ] **Step 4: Remove the debug test and re-run the suite**

```bash
swift test --filter PalettePinTests 2>&1 | tee .audit-all-themes.log
swift test --filter SVGStructuralSweepTests/testLiveRenderSweep 2>&1 | tee .audit-sweep.log
```

Both must end with `passed`.

- [ ] **Step 5: Commit C2**

Example shape (substitute the actual cell, file, and function from your diagnosis):

```bash
git add Sources/DiagramKitModel/SVGHelpers.swift  # or wherever Step 3 patched
git commit -m "$(cat <<'EOF'
fix(svg): _flattenKnownSvgTokens collapses line token to fg under deviceRGB normalization

REVIEW.md §1 / spec C2. Audit (PalettePinTests) revealed zinc-light
expected line=#939394 but rendered SVG carried #27272A across every
edge. Root cause: <one-sentence description>. Fix scoped to one site.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Re-run audit until green. If a second cell fails after the first fix, repeat Steps 1–5 as a separate commit.

---

## Task 5: Wire CLAUDE.md test count update + commit C1

**Files:**
- Modify: `CLAUDE.md` (test count line)

- [ ] **Step 1: Bump the test source count**

Edit `CLAUDE.md`. Find the line `Current test source count: 216 Swift files under \`Tests/DiagramKitTests\`.` and change `216` to `218`.

- [ ] **Step 2: Stage C1 — both new tests + the CLAUDE.md bump**

```bash
git add Tests/DiagramKitTests/PalettePinTests.swift \
        Tests/DiagramKitTests/SVGStructuralSweepTests.swift \
        CLAUDE.md
git status
```

Expected `git status` output: exactly three files staged, no other modifications staged.

- [ ] **Step 3: Verify both tests still green**

```bash
swift test --filter PalettePinTests
swift test --filter SVGStructuralSweepTests/testLiveRenderSweep
```

Both must end with `passed`.

- [ ] **Step 4: Commit C1**

```bash
git commit -m "$(cat <<'EOF'
test(svg): pin palette math + structural sweep

REVIEW.md §1 / spec C1. PalettePinTests asserts the rendered SVG
contains the hex `_hex(theme.effective<Token>())` returns, for every
built-in theme. SVGStructuralSweepTests walks the 422-entry corpus
and fails on var(--…) leakage, color-mix `))` tails, NaN, or empty
stroke/fill attributes.

Both tests are independent of `__Snapshots__/` baselines so they
remain stable across the upcoming C4/C5 rebaseline. CorpusSnapshotTests
remains the per-byte snapshot enforcer and will be red on `main`
until C4/C5 land.

Spec: docs/superpowers/specs/2026-05-14-svg-palette-audit-rebaseline-design.md
Resolver fix: 1c2f18f

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Cleanup**

```bash
rm -f .audit-zinc-light.log .audit-all-themes.log .audit-sweep.log
```

---

## Task 6: Create Scripts/rebaseline-snapshots.sh (the chunked recording driver)

**Files:**
- Create: `Scripts/rebaseline-snapshots.sh`
- Modify: `.gitignore`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Scripts/rebaseline-snapshots.sh
#
# Re-records CorpusSnapshotTests baselines in chunks small enough to
# avoid the documented swift-testing × swift-snapshot-testing signal-10
# hang at full-corpus parameterized scale.
#
# Usage:
#   Scripts/rebaseline-snapshots.sh [--target svg|image|both] [--chunk N] [--dry-run]
#
# Defaults: --target both, --chunk 20.
# Idempotent: re-running picks up .rebaseline-logs/missing-<target>.txt
# and re-records only those IDs.
#
# Spec: docs/superpowers/specs/2026-05-14-svg-palette-audit-rebaseline-design.md

set -euo pipefail

TARGET="both"
CHUNK=20
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --chunk)  CHUNK="$2";  shift 2 ;;
        --dry-run) DRY_RUN=1;  shift ;;
        -h|--help)
            sed -n '1,/^set -euo/p' "$0" | sed -n 's/^# \{0,1\}//p'
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

case "$TARGET" in
    svg|image|both) ;;
    *) echo "--target must be svg|image|both" >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

mkdir -p .rebaseline-logs

JSON="Examples/DiagramPlayground/Resources/test-diagrams.json"
if [ ! -f "$JSON" ]; then
    echo "Corpus file missing: $JSON" >&2
    exit 1
fi

# Extract IDs (jq preferred, sed fallback).
if command -v jq >/dev/null 2>&1; then
    mapfile -t ALL_IDS < <(jq -r '.diagrams[].id' "$JSON")
else
    mapfile -t ALL_IDS < <(grep -oE '"id"\s*:\s*"[^"]+"' "$JSON" \
        | sed -E 's/.*"id"\s*:\s*"([^"]+)".*/\1/')
fi
echo "Found ${#ALL_IDS[@]} corpus entries."

record_target() {
    local name="$1"        # svg | image
    local filter="$2"      # CorpusSnapshotTests/svgSnapshot, etc.

    local missing_file=".rebaseline-logs/missing-${name}.txt"
    local ids=()
    if [ -s "$missing_file" ]; then
        echo "[$name] resuming from $missing_file"
        mapfile -t ids < "$missing_file"
    else
        ids=( "${ALL_IDS[@]}" )
    fi
    rm -f "$missing_file"

    local total=${#ids[@]}
    local chunks=$(( (total + CHUNK - 1) / CHUNK ))
    local failed_chunks=()

    local idx=0
    for ((i=0; i<total; i+=CHUNK)); do
        idx=$((idx+1))
        local slice=( "${ids[@]:i:CHUNK}" )
        local csv
        csv=$(IFS=,; echo "${slice[*]}")
        local log=".rebaseline-logs/${name}-chunk-${idx}.log"
        echo "[$name $idx/$chunks] recording ${#slice[@]} entries → $log"

        if [ "$DRY_RUN" = "1" ]; then
            echo "  DRY: SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=$csv swift test --filter $filter"
            continue
        fi

        if ! SNAPSHOT_TESTING_RECORD=all \
             SNAPSHOT_DIAGRAM_IDS="$csv" \
             swift test --filter "$filter" > "$log" 2>&1; then
            echo "  CHUNK $idx FAILED (see $log)"
            failed_chunks+=( "$idx" )
            # Add IDs to missing for resume.
            printf '%s\n' "${slice[@]}" >> "$missing_file"
        fi
    done

    if [ "${#failed_chunks[@]}" -gt 0 ]; then
        echo "[$name] failed chunks: ${failed_chunks[*]} — re-run to retry missing IDs"
    else
        echo "[$name] all ${total} entries recorded ✓"
    fi
}

case "$TARGET" in
    svg)
        record_target svg   "CorpusSnapshotTests/svgSnapshot"
        record_target svg-mf "CorpusMultiFormatSnapshotTests/multiFormatSvgSnapshot" || true
        ;;
    image)
        record_target image    "CorpusSnapshotTests/imageSnapshot"
        record_target image-mf "CorpusMultiFormatSnapshotTests/multiFormatImageSnapshot" || true
        ;;
    both)
        record_target svg      "CorpusSnapshotTests/svgSnapshot"
        record_target svg-mf   "CorpusMultiFormatSnapshotTests/multiFormatSvgSnapshot" || true
        record_target image    "CorpusSnapshotTests/imageSnapshot"
        record_target image-mf "CorpusMultiFormatSnapshotTests/multiFormatImageSnapshot" || true
        ;;
esac
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x Scripts/rebaseline-snapshots.sh
```

- [ ] **Step 3: Add log directory to .gitignore**

Find `.gitignore` and append:

```
.rebaseline-logs/
```

(If `.rebaseline-logs/` is already present, leave as-is.)

- [ ] **Step 4: Dry-run the script for sanity**

```bash
./Scripts/rebaseline-snapshots.sh --dry-run --chunk 50 --target svg 2>&1 | head -20
```

Expected: prints `Found 422 corpus entries.` (give or take depending on multi-format counting) and several `DRY: SNAPSHOT_TESTING_RECORD=all …` lines. No `swift test` actually runs. No files modified.

```bash
git status
```

Expected: shows the new script and modified `.gitignore`, nothing else.

- [ ] **Step 5: Update CLAUDE.md Commands block**

Edit `CLAUDE.md`. Find the `## Commands` block. After the `swift run DiagramPlayground` line, add a new block:

````markdown
# Rebaseline snapshots after a renderer change (chunked to avoid signal-10):
Scripts/rebaseline-snapshots.sh                     # all SVG + image
Scripts/rebaseline-snapshots.sh --target svg        # SVG only
Scripts/rebaseline-snapshots.sh --target image --chunk 10  # smaller chunks
````

- [ ] **Step 6: Commit C3**

```bash
git add Scripts/rebaseline-snapshots.sh .gitignore CLAUDE.md
git commit -m "$(cat <<'EOF'
chore(scripts): rebaseline-snapshots.sh

REVIEW.md §1 / spec C3. New chunked recording driver for
CorpusSnapshotTests baselines. Default --chunk 20 stays well below
the documented swift-testing signal-10 trigger threshold.

Idempotent: failures populate .rebaseline-logs/missing-<target>.txt,
which a re-run consumes to retry only the missing IDs.

Not invoked by Scripts/bootstrap-smoke-check.sh — explicit operator
action only.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Rebaseline SVG snapshots (C4)

**Files:**
- Modify: `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-*.txt` (422 files)
- Modify: `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/multiFormatSvgSnapshot-*.txt` (13 files)

- [ ] **Step 1: Spot-check the commit-window for surprise rendering drift**

```bash
git log 1c2f18f..HEAD -- Sources/DiagramKitModel/ Sources/DiagramKitCommon/ Sources/DiagramKitRenderingCG/ --oneline
```

Read each subject. If you spot a commit whose body suggests a rendering change UNRELATED to the resolver (e.g., a font registry tweak, a layout fix), capture a sample SVG diff for one canary entry before vs after — you'll cite it in the commit body if it produced visible change.

To capture a canary baseline before re-recording:

```bash
cp Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-flow-1-simple.txt /tmp/before-flow-1-simple.svg.txt
```

- [ ] **Step 2: Confirm working tree is clean**

```bash
git status --short
```

Expected: empty (no modifications, no untracked files outside `.rebaseline-logs/`).

- [ ] **Step 3: Run the recorder for SVG only**

```bash
./Scripts/rebaseline-snapshots.sh --target svg --chunk 20
```

Expected: ~22 chunks for the Mermaid path, ~1 chunk for multi-format. Final line: `[svg] all 422 entries recorded ✓` and `[svg-mf] all 13 entries recorded ✓` (or similar). Wall-clock: ~6–12 minutes depending on machine.

If any chunk fails: the script writes `.rebaseline-logs/missing-svg.txt`. Re-run the same command to retry just the missing IDs. If a single ID consistently fails alone, isolate it manually:

```bash
SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=<the-id> swift test --filter CorpusSnapshotTests/svgSnapshot 2>&1 | tail -40
```

- [ ] **Step 4: Verify the on-disk structural sweep passes**

```bash
SVG_SWEEP_ON_DISK=1 swift test --filter SVGStructuralSweepTests/testOnDiskSweep
```

Expected: PASS. If FAIL, the recorder produced corrupted output for the listed files — inspect those .txt files manually for truncation or unexpected content. Stop and diagnose before committing.

- [ ] **Step 5: Diff canary**

```bash
diff /tmp/before-flow-1-simple.svg.txt \
     Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-flow-1-simple.txt | head -30
```

Sanity-check: expected differences are color-attribute hex values, removal of `))` tails, removal of `var(--…)` strings. If you see geometry diffs (path d=, x/y coordinates shifted), that's non-resolver drift — capture for the commit body.

- [ ] **Step 6: Verify live snapshot tests now pass**

```bash
swift test --filter CorpusSnapshotTests/svgSnapshot 2>&1 | tail -5
swift test --filter CorpusMultiFormatSnapshotTests/multiFormatSvgSnapshot 2>&1 | tail -5
```

Expected: both end with `passed` and no `recorded snapshot` messages. (If you see `recorded`, the previous step missed some IDs — re-run Step 3.)

- [ ] **Step 7: Failure-to-launch check + stage C4**

If `git status --short` shows ZERO changed `__Snapshots__/CorpusSnapshotTests/svgSnapshot-*` or `multiFormatSvgSnapshot-*` files after Steps 3–6, the resolver fix may already have been baselined by a prior pass missed by the spec. STOP. Do not create an empty commit. Investigate `git log Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-flow-1-simple.txt` to see who last touched a representative baseline; if that commit post-dates `1c2f18f`, this work is already done and the plan can be closed without C4/C5.

Otherwise, stage:

```bash
git add Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/svgSnapshot-*.txt \
        Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/multiFormatSvgSnapshot-*.txt
git status --short | head -5  # spot-check that only .txt baselines are staged
git diff --cached --stat | tail -1  # expected: "435 files changed" (give or take)
```

If the staged count is < 100 or > 500, something is off — a chunk missed, or unrelated baselines got pulled in. Investigate before committing.

```bash
git commit -m "$(cat <<'EOF'
test(snapshots): rebaseline SVG after color-mix resolver fix

REVIEW.md §1 / spec C4. Re-records the 422 Mermaid svgSnapshot and
13 multiFormatSvgSnapshot baselines against the post-1c2f18f
resolver output.

The pre-fix baselines recorded malformed `))` tails after color-mix
hex values, e.g. `stroke="#A9A9AA 40%, #FFFFFF))"`. The current
baselines reflect the paren-counting walker's correct output, with
palette math pinned by Tests/DiagramKitTests/PalettePinTests.swift
(landed in C1).

Visual sanity canary set (re-used in C5):
  flow-1-simple, seq-1-basic, class-1-basic,
  er-1-basic,    state-1-basic, xychart-1-bar

Resolver fix: 1c2f18f
Audit gate:   <C1 sha>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If Task 7 Step 5 surfaced non-resolver drift in the canary diff, append a line listing the responsible commits before the `Co-Authored-By` line:

```
Non-resolver drift captured: <short-sha>, <short-sha>
```

(Replace `<C1 sha>` with the actual SHA from `git log --oneline -5`.)

---

## Task 8: Rebaseline image snapshots (C5)

**Files:**
- Modify: `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/imageSnapshot-*.png` (422 files)
- Modify: `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/multiFormatImageSnapshot-*.png` (13 files)
- Modify: `REVIEW.md`
- Modify: `BASELINES.md`

- [ ] **Step 1: Pick 6 canary entries for visual sanity check (one per major family)**

The spec pins these for re-runnability:

```
flow:    flow-1-simple
seq:     seq-1-basic
class:   class-1-basic
er:      er-1-basic
state:   state-1-basic
xychart: xychart-1-bar
```

These six IDs were verified to exist in `Examples/DiagramPlayground/Resources/test-diagrams.json` at plan-write time. Confirm again before relying on them:

```bash
for id in flow-1-simple seq-1-basic class-1-basic er-1-basic state-1-basic xychart-1-bar; do
    if ! jq -e --arg id "$id" '.diagrams | map(.id) | index($id)' \
         Examples/DiagramPlayground/Resources/test-diagrams.json >/dev/null; then
        echo "MISSING: $id"
    fi
done
```

If any prints `MISSING` (a corpus add/remove happened between plan and execution), substitute the first available ID from the same family:
```bash
jq -r --arg p "<missing-family>" '.diagrams[] | select(.id | startswith($p + "-")) | .id' \
  Examples/DiagramPlayground/Resources/test-diagrams.json | head -1
```

Stash the old canary images:

```bash
mkdir -p /tmp/canary-before
for id in flow-1-simple seq-1-basic class-1-basic er-1-basic state-1-basic xychart-1-bar; do
    cp Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/imageSnapshot-${id}.png \
       /tmp/canary-before/${id}.png
done
```

- [ ] **Step 2: Run the recorder for images only**

```bash
./Scripts/rebaseline-snapshots.sh --target image --chunk 20
```

Expected: ~22 chunks + 1 multi-format chunk. Final lines: `[image] all 422 entries recorded ✓` and `[image-mf] all 13 entries recorded ✓`. Wall-clock: ~10–18 minutes (images are slower than SVG).

If chunks fail, same recovery as C4: re-run the same command.

- [ ] **Step 3: Visual sanity-check the canaries**

```bash
# macOS: open before+after side by side for each canary
for id in flow-1-simple seq-1-basic class-1-basic er-1-basic state-1-basic xychart-1-bar; do
    open /tmp/canary-before/${id}.png \
         Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/imageSnapshot-${id}.png
done
```

Acceptance criteria: text legible, edges visible, no rendering catastrophe (huge bleed, totally wrong layout, missing labels). Color differences ARE expected — the whole point. Layout differences are NOT expected.

If a canary looks visibly worse than its before: stop. Open the canary's source from the corpus and render it manually via `DiagramPlayground` to diagnose. Do not commit.

- [ ] **Step 4: Verify live image snapshot tests now pass**

```bash
swift test --filter CorpusSnapshotTests/imageSnapshot 2>&1 | tail -5
swift test --filter CorpusMultiFormatSnapshotTests/multiFormatImageSnapshot 2>&1 | tail -5
```

Expected: both end with `passed` and no `recorded snapshot` messages.

- [ ] **Step 5: Update REVIEW.md with the Session 4 row**

Open `REVIEW.md`. After the "Resolution Status — Session 3 (2026-05-14)" table, add a new section. (Adjust commit hashes to the actual ones from your `git log`.)

```markdown
---

## Resolution Status — Session 4 (2026-05-14)

Closes Deferred Effort §1 (SVG color-mix variable resolver) — the rebaseline phase deferred from Session 2's `1c2f18f`. Five commits on `main`.

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §1 Audit gate | `<C1 sha>` | New `PalettePinTests.swift` pins `_hex(theme.effective<Token>())` for every built-in theme. New `SVGStructuralSweepTests.swift` rejects `var(--…)`, `))` tails, NaN, empty stroke/fill across the 422-entry corpus. Both Apple-only via the existing `#if canImport(UIKit) || canImport(AppKit)` gate. |
| 2 | §1 Renderer fix | `<C2 sha or "no-op">` | <one-line summary if C2 ran; otherwise "Audit passed on main — no fix required."> |
| 3 | §1 Recording driver | `<C3 sha>` | `Scripts/rebaseline-snapshots.sh` chunks `SNAPSHOT_TESTING_RECORD=all` runs through `SNAPSHOT_DIAGRAM_IDS=` to avoid the documented swift-testing signal-10 hang at full-corpus scale. Idempotent via `.rebaseline-logs/missing-<target>.txt`. |
| 4 | §1 SVG rebaseline | `<C4 sha>` | 422 svgSnapshot + 13 multiFormatSvgSnapshot baselines re-recorded. `SVG_SWEEP_ON_DISK=1` mode of the structural sweep verifies the on-disk files are clean. |
| 5 | §1 Image rebaseline | `<C5 sha>` | 422 imageSnapshot + 13 multiFormatImageSnapshot baselines re-recorded. 6-entry visual canary set spot-checked (flow/seq/class/er/state/xychart). |

Session-end verification: targeted `swift test --filter` across `PalettePinTests`, `SVGStructuralSweepTests`, `CorpusSnapshotTests/svgSnapshot`, `CorpusSnapshotTests/imageSnapshot`, `CorpusMultiFormatSnapshotTests` all green. `Scripts/check-sendable-annotations.sh` ✓ green. `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings.
```

- [ ] **Step 6: Update BASELINES.md with the rebaseline-event row**

Open `BASELINES.md`. Find the section that tracks baseline events (likely a "Baseline events" or "Rebaseline history" header — if no such section exists, add one after the snapshot counts table). Add:

```markdown
| 2026-05-14 | SVG color-mix resolver rebaseline | <C4 sha>, <C5 sha> | Re-records 435 SVG + 435 image baselines against the post-1c2f18f paren-counting resolver. See REVIEW.md §1 Session 4. |
```

If `BASELINES.md` has no such table, add this minimal section header just below the latest counts:

```markdown
## Rebaseline Events

| Date | Reason | Commits | Notes |
|---|---|---|---|
| 2026-05-14 | SVG color-mix resolver rebaseline | <C4 sha>, <C5 sha> | Re-records 435 SVG + 435 image baselines against the post-1c2f18f paren-counting resolver. See REVIEW.md §1 Session 4. |
```

- [ ] **Step 7: Stage and commit C5**

```bash
git add Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/imageSnapshot-*.png \
        Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/multiFormatImageSnapshot-*.png \
        REVIEW.md BASELINES.md
git status --short | head -5
git diff --cached --stat | tail -1  # expected: ~437 files changed
```

```bash
git commit -m "$(cat <<'EOF'
test(snapshots): rebaseline image after color-mix resolver fix

REVIEW.md §1 / spec C5. Re-records the 422 imageSnapshot and 13
multiFormatImageSnapshot baselines against the post-1c2f18f
resolver output. Six-entry visual canary set (flow/seq/class/er/
state/xychart) spot-checked before commit.

Closes Deferred Effort §1. REVIEW.md Session 4 row added; BASELINES.md
rebaseline-event row added.

Resolver fix: 1c2f18f
Audit gate:  <C1 sha>
SVG rebase:  <C4 sha>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Cleanup**

```bash
rm -rf /tmp/canary-before .rebaseline-logs
```

- [ ] **Step 9: Final verification across all touched suites**

```bash
swift test --filter PalettePinTests
swift test --filter SVGStructuralSweepTests
SVG_SWEEP_ON_DISK=1 swift test --filter SVGStructuralSweepTests/testOnDiskSweep
swift test --filter CorpusSnapshotTests/svgSnapshot
swift test --filter CorpusSnapshotTests/imageSnapshot
swift test --filter CorpusMultiFormatSnapshotTests
Scripts/check-sendable-annotations.sh
Scripts/check-file-sizes.sh
```

All must end green. If any flips red, do not push — investigate and fix before considering the work complete.

---

## Acceptance Checklist (from spec)

After Task 8 lands, all of the following must be true:

- [ ] `swift test --filter PalettePinTests` green
- [ ] `swift test --filter SVGStructuralSweepTests` green (live render)
- [ ] `SVG_SWEEP_ON_DISK=1 swift test --filter SVGStructuralSweepTests` green (on-disk)
- [ ] `swift test --filter CorpusSnapshotTests/svgSnapshot` green
- [ ] `swift test --filter CorpusSnapshotTests/imageSnapshot` green
- [ ] REVIEW.md §1 Session 4 row present
- [ ] BASELINES.md rebaseline-event row present
- [ ] CLAUDE.md test count updated (216 → 218)
- [ ] CLAUDE.md Commands block has the `Scripts/rebaseline-snapshots.sh` entries
- [ ] No `Scripts/check-sendable-annotations.sh` regressions
- [ ] No new entries in `Scripts/check-file-sizes-allowlist.txt`

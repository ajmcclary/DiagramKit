# Coverage Expansion — Wave 3: Structurizr Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Structurizr backlog item from the coverage-expansion
spec. Two enhancements, no new family rows:

1. **Comment-encoded recovery on export.** Replace the two existing
   diagnostic-emitting sites in
   `Sources/DiagramKitStructurizr/StructurizrExporter.swift`
   (element-scoped `tags` at `StructurizrExporter.swift:170-174`, and
   nested-boundary flattening at `StructurizrExporter.swift:69-83`) with
   `# diagramkit:tag=<tag>` and `# diagramkit:boundary-parent=<id>`
   comment markers placed adjacent to the element/group line.
2. **Multi-view import.** Refactor
   `Sources/DiagramKitStructurizr/StructurizrMapper.swift:42-59` (the
   "first view only" branch) into a loop that maps every view in the
   workspace. The first view stays the rendered/exported view so every
   existing snapshot and round-trip stays green.

Because the recovery comments mean **no loss occurs**, the two existing
emission sites are **deleted, not redirected**. The Structurizr × c4 cell
moves ⚠ → ✓ and the per-cell `boundaryFlatten` allow-list entries
shrink. The plan is structured as an inversion of the normal "emit a
typed diagnostic for every loss" pattern: emit recovery comments first,
prove the round-trip is structurally lossless, *then* delete the
diagnostic emission site.

**Architecture:** Single slice
(`Sources/DiagramKitStructurizr/`). The Structurizr lexer already strips
`#` line comments at `StructurizrLexer.swift:84-93` *during
preprocessing* — so the importer needs a **pre-lexer pass** that scans
the raw source for `# diagramkit:` markers and records them with a
1-based source line number before the lexer's preprocess pass eats them.
Comments on lines that are NOT recovery markers continue to be silently
stripped by the lexer (today's behavior, unchanged). Multi-view import
preserves the first-view-is-rendered contract by indexing into
`workspace.views[0]` exactly as today, after looping. If
`StructurizrImporter.swift`'s call site for the loop crosses the
500-line warn line during the refactor, a dedicated
`StructurizrViewParser.swift` split is sequenced into the plan as
Task 9.

**Tech Stack:** Swift 6, SwiftPM,
[swift-testing](https://github.com/swiftlang/swift-testing) for new
tests (XCTest for the existing `CorpusRoundTripTests`),
`DiagramKitTestSupport.RoundTripHarness`,
`Scripts/check-diagnostic-discipline.sh`,
`Scripts/check-file-sizes.sh`,
`Scripts/check-sendable-annotations.sh`,
`Scripts/strict-concurrency-check.sh`,
`Scripts/bootstrap-smoke-check.sh`.

**Source spec:**
[docs/superpowers/specs/2026-05-19-coverage-expansion-design.md](../specs/2026-05-19-coverage-expansion-design.md)
— sections **Wave 3 — Structurizr** (Architecture & File Layout
subsection), **Diagnostics & Round-Trip Pairing** ("Structurizr Wave 3
inverts the pattern" paragraph), **Testing Strategy** (Wave 3 row +
verification commands).

**Prior wave plans (structural template + lessons):**
- [Wave 1 — PlantUML expansion](2026-05-19-coverage-expansion-wave-1-plantuml.md)
  (when authored).
- [Wave 2 — D2 + DOT expansion](2026-05-19-coverage-expansion-wave-2-d2-dot.md)
  (when authored).

This plan is independent from Waves 1 and 2 (the spec calls out
"`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/` … disjoint
filenames"); execute it sequentially or in parallel.

---

## Lessons Folded In Up-Front

These are baked into every task below; do not relearn them.

1. **The pattern is inverted.** Wave 3 deletes two diagnostic emission
   sites because comment-encoded recovery means no loss happens. The
   correct order is: (a) failing round-trip test that exercises the
   tag/boundary path, (b) implement comment emission on export +
   recovery on import, (c) confirm round-trip is structurally lossless
   *with the old `.featureDropped` / `.lossyTransform` emission still
   present* — this means the `boundaryFlatten` allow-list entry still
   covers anything that slips through, (d) **then** delete the emission
   site, (e) shrink the per-cell allow-list, (f) confirm the cell is
   still green. Never reverse the order — deleting the emission first
   would convert a real loss into an unpaired-loss harness failure with
   no diagnostic to explain it.
2. **The Structurizr lexer eats `#` line comments at preprocess time.**
   `StructurizrLexer.swift:84-93` strips both `//` and `#` line comments
   before tokenization, inside the lexer's own `preprocess(_:)`
   function. By the time the parser sees tokens, comments are gone.
   Recovery markers must be harvested by a **pre-lexer scan of the raw
   source** that runs before `StructurizrImporter.swift:25`'s
   `lexer.tokenize(source)` call. Records are stored as
   `[StructurizrRecoveryMarker]` and attached to the matching shape /
   group during `StructurizrMapper.map(...)`.
3. **First view stays rendered.** The spec is explicit:
   "the first view remains the document's rendered/exported view for
   back-compat with current callers." Every existing Structurizr
   snapshot test and the `structurizrC4` same-format + Mermaid /
   PlantUML cross-format round-trip cells must continue to pass without
   any baseline edits. Multi-view import enriches `StructurizrWorkspace`
   with the additional views (already supported — `StructurizrParser`
   parses every view into `[StructurizrView]`), but `StructurizrMapper`
   still maps only the first view to the resulting `C4Diagram` for now.
   The currently-suppressed `"only the first view is imported in this
   release"` diagnostic at `StructurizrMapper.swift:53-56` is removed
   in Task 8 because the importer now visits every view (even though
   the rendered output remains the first).
4. **Test filter form.** Always use `swift test --filter
   <ExactSuiteName>` per the `feedback_swift_test_filter` standing
   default. The exact suite/test names this plan uses:
   `SameFormatRoundTripTests/structurizrC4`,
   `CrossFormatRoundTripTests/mermaidStructurizrC4`,
   `CrossFormatRoundTripTests/structurizrMermaidC4`,
   `CrossFormatRoundTripTests/plantumlStructurizrC4`,
   `CrossFormatRoundTripTests/structurizrPlantumlC4`,
   `StructurizrBoundaryRoundTripTests`,
   `StructurizrLexerTests`, plus the new
   `StructurizrRecoveryMarkerTests` (Task 1) and
   `StructurizrMultiViewTests` (Task 7).
5. **Commit-by-commit on `main`.** Per `feedback_branching`. No
   branches or worktrees. Each task ends with a commit.
6. **Diagnostic discipline.** Only typed factories
   (`.lossyTransform`, `.featureDropped`, `.informational`). Wave 3
   *removes* two emission sites; no new emission sites added.
   `Scripts/check-diagnostic-discipline.sh` enforces typed factories on
   the surviving sites.
7. **Choose a placement for recovery markers and document it.**
   The plan places `# diagramkit:tag=<tag>` and
   `# diagramkit:boundary-parent=<id>` on the line **immediately
   following** the element/group line they augment. Rationale: the
   exporter's existing emission walks elements top-to-bottom and
   appends to `lines`, so "append on the next line" requires only one
   extra `lines.append` per case. The importer's pre-lexer scan walks
   line-by-line and recognizes the previously-seen element/group by
   tracking the most recently emitted alias / group label on the
   previous non-blank, non-comment line. This is consistent with the
   convention adopted in [ARCHITECTURE.md](../../../ARCHITECTURE.md)
   "Drift hazards" (added in Task 10).
8. **Don't grow `RoundTripLoss` for Wave 3.** Today's allow-list for
   `structurizrC4` is
   `[.idSanitization, .boundaryFlatten, .c4SlotDrop]`. Wave 3 removes
   `.boundaryFlatten` once the tag + nested-boundary recovery lands;
   `.idSanitization` and `.c4SlotDrop` stay (alias rewriting at
   `StructurizrExporter.swift:226-246` is unchanged; `c4SlotDrop`
   covers per-shape `technology` / `description` slot drops that
   Wave 3 does not touch). The cross-format allow-lists in
   `RoundTripCrossRegistry.swift:19-24` shrink the same way:
   `.boundaryFlatten` drops from
   `mermaidStructurizrC4`, `structurizrMermaidC4`,
   `plantumlStructurizrC4`, `structurizrPlantumlC4`. The C4 ×
   {mermaid↔plantuml} pairs (lines 21-22) are *not* touched — they
   don't involve Structurizr.
9. **The `tags` field on `C4Shape` is `String?`, not `[String]`.**
   `Sources/DiagramKitModel/src_c4_types.swift:321`. Today the
   StructurizrExporter at line 169-174 only emits a `.featureDropped`
   when `tags` is non-empty. Wave 3 emits one `# diagramkit:tag=<tag>`
   line per **comma-separated component** of that string, trimmed of
   whitespace, after splitting on `,`. Empty components after trim are
   skipped. The importer reverses the process and re-joins recovered
   markers with `,` separators back into the single `tags: String?`
   field.
10. **No corpus growth, no snapshot growth.** Per the spec's Out of
    Scope: "Sources/DiagramKitSample/Resources/test-diagrams.json stays
    at 424 entries; SVG/image/ASCII snapshot baselines stay at
    437/437/424." All Wave 3 fixtures live exclusively under
    `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.
11. **Linux portability.** `DiagramKitStructurizr` is already
    Linux-portable (no `BMColor` / `BMFont` / CoreText reach). All Wave 3
    code stays in `DiagramKitStructurizr` and stays Linux-portable.
12. **File-size policy** (500-line warn / 1000-line error per
    `Scripts/check-file-sizes.sh`). Today's files are well clear of
    both thresholds:

    | File | Lines today |
    |------|-------------|
    | `StructurizrAST.swift` | 155 |
    | `StructurizrExporter.swift` | 247 |
    | `StructurizrImporter.swift` | 40 |
    | `StructurizrLexer.swift` | 248 |
    | `StructurizrMapper.swift` | 334 |
    | `StructurizrModelRegistry.swift` | 178 |
    | `StructurizrParser.swift` | 377 |
    | `StructurizrParserState.swift` | 130 |
    | `StructurizrProbe.swift` | (small) |

    The Wave 3 changes add roughly: importer +30 (pre-lexer scan call,
    marker plumbing), exporter +25 (recovery-marker emission), mapper
    +60 (multi-view loop + tag/boundary re-attach), plus a new
    `StructurizrRecoveryMarker.swift` (~80 lines, holds the marker
    struct + scan function). `StructurizrParser.swift` is the closest
    to the warn line (377 → ~410 after multi-view refactor); still well
    clear of 500. Task 9 (the optional split into
    `StructurizrViewParser.swift`) is **conditional**: only execute it
    if the file actually crosses 500 lines.

---

## Wave 3 Recovery-Marker Grammar Cheat Sheet

The two new line forms below are the **entire** Wave 3 grammar
addition. They live on their own line (no other content), use ASCII
only, and are case-sensitive.

| Marker | Where emitted | Captures | Pre-lexer scan regex |
|--------|---------------|----------|----------------------|
| `# diagramkit:tag=<tag>` | One line per comma-separated component of `C4Shape.tags`, emitted *immediately after* the `<alias> = <kind> "<label>" [...]` line that defines the shape. | `tag` is the literal text of one tag, trimmed of leading/trailing ASCII whitespace, `\n` / `\r` / `"` replaced with U+0020 (defense-in-depth — the source-of-truth `C4Shape.tags` is already escape-clean). | `^[ \t]*#[ \t]*diagramkit:tag=(?<value>.*)$` (anchored on a single line). |
| `# diagramkit:boundary-parent=<id>` | One line per **flattened** authored boundary whose `parentBoundary` is non-empty and not `"global"`; emitted *immediately after* the `group "<label>" {` line of the flattened (now-sibling) boundary. | `id` is the literal `boundary.parentBoundary` value as it appears in the source model (no sanitization — the importer looks it up by the same key the exporter wrote). | `^[ \t]*#[ \t]*diagramkit:boundary-parent=(?<value>.*)$` (anchored on a single line). |

Both regexes are implemented in Swift via `String.range(of: …,
options: .regularExpression)` and a manual capture — anchored per line
by splitting the source on `\n` first. The pre-lexer scan returns
`[StructurizrRecoveryMarker]` where each marker carries `lineNumber:
Int` (1-based) so the mapper can match it against the
immediately-preceding shape/group definition.

> **Decision: marker placement.** Markers go on the line **immediately
> following** the element/group declaration. The exporter loop in
> `StructurizrC4Export.emit(_:)` already appends a single line per
> shape; appending the recovery marker on the very next iteration is a
> one-line insertion at the call site. The importer side tracks the
> "most recently emitted shape alias" and "most recently emitted group
> label" via line-position state during the pre-lexer scan; markers
> attach to the most recent of the two by token-class on the previous
> non-blank, non-marker line.

---

## File Structure

**Files created (Wave 3):**

```
Sources/DiagramKitStructurizr/
  StructurizrRecoveryMarker.swift     # Task 1 — marker struct + pre-lexer scan
  (Task 9 optional, conditional on Task 7 file-size crossing 500 lines:)
  StructurizrViewParser.swift         # Task 9 — extracted multi-view parsing

Tests/DiagramKitTests/
  StructurizrRecoveryMarkerTests.swift  # Task 1
  StructurizrMultiViewTests.swift       # Task 7

Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/
  structurizr-c4/04-tags.dsl                          # Task 1 — same-format tag recovery
  structurizr-c4/05-nested-boundary.dsl               # Task 5 — same-format boundary recovery
  structurizr-c4/06-multi-view.dsl                    # Task 7 — multi-view fixture
  cross-mermaid-structurizr-c4/02-boundary.md         # Task 5 — Mermaid round-trips boundary
  cross-structurizr-mermaid-c4/02-boundary.dsl        # Task 5 — Structurizr→Mermaid carries marker
```

**Files modified (Wave 3):**

```
Sources/DiagramKitStructurizr/
  StructurizrExporter.swift           # Task 3, Task 5 — emit recovery markers; Task 4, Task 6 — DELETE the two diagnostic emissions
  StructurizrImporter.swift           # Task 2 — wire pre-lexer scan and pass markers to mapper
  StructurizrMapper.swift             # Task 2 — re-attach markers; Task 8 — visit every view in the loop; Task 8 — delete first-view-only diagnostic
  StructurizrParser.swift             # Task 7 — (potentially) view-loop minor adjustment
  StructurizrAST.swift                # Task 2 — may grow with a `recoveredTags`/`recoveredParentBoundary` shadow field on `StructurizrModelElement` (alternative: pass markers directly to mapper — see Task 2 design note)

Tests/DiagramKitTests/RoundTrip/
  RoundTripCellRegistry.swift         # Task 4, Task 6 — shrink structurizrC4.allowedLosses (remove .boundaryFlatten)
  RoundTripCrossRegistry.swift        # Task 4, Task 6 — shrink the four Structurizr-touching cross-cells

COVERAGE.md                            # Task 10 — Structurizr × c4 Export column ⚠ → ✓; remove the "Structurizr × c4" entry in "Partial-support detail"; update §3 "Structurizr scope" and "Backlog summary" item 3; bump "Last audited" date
BASELINES.md                           # Task 10 — Wave 3 closing entry; round-trip fixture count grows from 16 to 18 same-format and 16 to 18 cross-format directed (4 unordered → 5 unordered) per the spec's Testing Strategy table (Wave 3 row: "structurizr-c4-multiview" + tag/boundary regression cases + cross-format Mermaid/PlantUML updates)
ARCHITECTURE.md                        # Task 10 — new "Drift hazards" bullet: do not strip `# diagramkit:` recovery comments
```

> **About `StructurizrAST.swift`.** The current AST surface
> (`StructurizrModelElement` at `StructurizrAST.swift:42-75`) already
> carries a `tags: [String]` field at line 50 that is populated as `[]`
> by `parseElementDef(...)` at `StructurizrParser.swift:255`. Wave 3
> populates that existing field from recovered `# diagramkit:tag=<tag>`
> markers — no AST change needed for tags. For boundary parent recovery,
> the AST has no equivalent field — Wave 3 routes the recovered
> parentage through a side-channel `[String: String]`
> (`groupLabel → parentGroupLabel`) carried alongside the workspace,
> which the mapper consumes in Task 2. Both choices keep
> `StructurizrAST.swift` unmodified.

---

## Task Ordering Rationale

The plan order enforces the inversion. **Recovery comments emit first,
diagnostics delete last.**

- **Tasks 1–2** introduce the recovery-marker mechanism: a typed
  `StructurizrRecoveryMarker`, a pre-lexer scan, and the wiring into
  `StructurizrImporter` → `StructurizrMapper`. The emission and removal
  of the two diagnostic sites happens in the four subsequent tag /
  boundary tasks.
- **Tasks 3–4** handle tags: emit `# diagramkit:tag=<tag>` markers on
  export, prove via a fresh same-format round-trip fixture that the data
  recovers, **then** delete the `StructurizrExporter.swift:170-174`
  `.featureDropped(.diagramFamilyUnsupported, …)` site and shrink the
  cell allow-list (no `.boundaryFlatten` to remove from tags — the tag
  site uses `.diagramFamilyUnsupported`/`.unsupported`, but no
  Structurizr loss kind currently maps to that category anyway, so the
  allow-list effect is null for tags; the boundary task removes
  `.boundaryFlatten`).
- **Tasks 5–6** handle nested boundaries: emit
  `# diagramkit:boundary-parent=<id>` markers on export, prove via a
  fresh same-format and **two** cross-format fixtures that the data
  recovers, **then** delete the
  `StructurizrExporter.swift:69-83`
  `.lossyTransform(.boundaryFlatten, …)` sites (two sites: nested
  parent flattening and empty-group elision) and shrink the cell +
  cross-cell allow-lists by removing `.boundaryFlatten`.
- **Tasks 7–8** handle multi-view import: failing test that asserts
  multi-view workspace surfaces every view in the AST, then a mapper
  refactor that visits every view but still emits the first view as
  the rendered output, then delete the
  `"only the first view is imported in this release"` diagnostic at
  `StructurizrMapper.swift:53-56`.
- **Task 9** (conditional) splits
  `StructurizrParser.swift` if it crosses the 500-line warn line. Skip
  if the file stays under 500 lines after Task 7.
- **Task 10** is the spec-level closing task: update COVERAGE.md
  (Structurizr × c4 ⚠ → ✓, remove the partial-support detail entry,
  bump audit date), BASELINES.md (Wave 3 closing entry), ARCHITECTURE.md
  (new Drift Hazards bullet), and run all discipline gates.

---

## Task 1: Recovery-Marker Scaffolding

**Files:**
- Create: `Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift`
- Create: `Tests/DiagramKitTests/StructurizrRecoveryMarkerTests.swift`

This task introduces the typed `StructurizrRecoveryMarker` and the
pre-lexer scan that harvests `# diagramkit:` lines from raw source. It
does **not** yet wire the markers through the importer; that happens in
Task 2.

- [ ] **Step 1.1: Stub the marker file**

Create `Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift`:

```swift
import Foundation

/// One `# diagramkit:` recovery marker harvested from raw Structurizr
/// source before lexing.
///
/// Wave 3 of the coverage-expansion spec
/// (docs/superpowers/specs/2026-05-19-coverage-expansion-design.md)
/// encodes element-scoped tags and flattened nested-boundary parentage
/// as line-comment markers. The Structurizr lexer strips `#` line
/// comments at preprocess time
/// (StructurizrLexer.swift:84-93), so recovery markers must be
/// harvested by a pre-lexer scan over the raw source before
/// `StructurizrLexer.tokenize(_:)` is called.
public struct StructurizrRecoveryMarker: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// `# diagramkit:tag=<value>` — restores a tag for the most
        /// recently declared element on the previous non-blank,
        /// non-marker line.
        case elementTag(value: String)
        /// `# diagramkit:boundary-parent=<id>` — restores the parent
        /// boundary alias for the most recently declared group on the
        /// previous non-blank, non-marker line.
        case boundaryParent(id: String)
    }

    /// 1-based line number in the raw source where the marker appeared.
    public let lineNumber: Int
    public let kind: Kind

    public init(lineNumber: Int, kind: Kind) {
        self.lineNumber = lineNumber
        self.kind = kind
    }
}

/// Scans raw Structurizr source for `# diagramkit:` recovery markers
/// before the lexer's preprocess pass eats line comments.
///
/// - Parameter source: Raw Structurizr DSL source (frontmatter
///   already stripped; importer-side comments still present).
/// - Returns: Markers in source order. Lines that are not recovery
///   markers are ignored — they continue to be silently stripped by the
///   lexer.
public func scanStructurizrRecoveryMarkers(_ source: String) -> [StructurizrRecoveryMarker] {
    return []
}
```

- [ ] **Step 1.2: Stub the test**

Create `Tests/DiagramKitTests/StructurizrRecoveryMarkerTests.swift`:

```swift
import Testing
@testable import DiagramKitStructurizr

@Suite("StructurizrRecoveryMarkerTests")
struct StructurizrRecoveryMarkerTests {

    @Test("tag marker is harvested with 1-based line number")
    func tagMarker() {
        let source = """
        workspace {
          model {
            customer = person "Customer"
            # diagramkit:tag=external
          }
        }
        """
        let markers = scanStructurizrRecoveryMarkers(source)
        #expect(markers.count == 1)
        guard case .elementTag(let value) = markers.first?.kind else {
            Issue.record("expected elementTag, got \(String(describing: markers.first?.kind))")
            return
        }
        #expect(value == "external")
        #expect(markers.first?.lineNumber == 4)
    }

    @Test("boundary-parent marker is harvested")
    func boundaryParentMarker() {
        let source = """
        workspace {
          model {
            group "inner" {
        # diagramkit:boundary-parent=outer
            }
          }
        }
        """
        let markers = scanStructurizrRecoveryMarkers(source)
        #expect(markers.count == 1)
        guard case .boundaryParent(let id) = markers.first?.kind else {
            Issue.record("expected boundaryParent, got \(String(describing: markers.first?.kind))")
            return
        }
        #expect(id == "outer")
        #expect(markers.first?.lineNumber == 4)
    }

    @Test("non-diagramkit comments are ignored")
    func nonDiagramkitCommentsIgnored() {
        let source = """
        workspace {
          # plain comment
          // also a comment
          model {
            customer = person "Customer"
          }
        }
        """
        let markers = scanStructurizrRecoveryMarkers(source)
        #expect(markers.isEmpty)
    }

    @Test("multiple markers preserve source order")
    func multipleMarkers() {
        let source = """
        workspace {
          model {
            a = person "A"
            # diagramkit:tag=alpha
            b = person "B"
            # diagramkit:tag=beta
            # diagramkit:tag=gamma
          }
        }
        """
        let markers = scanStructurizrRecoveryMarkers(source)
        #expect(markers.count == 3)
        let values: [String] = markers.compactMap { marker in
            if case .elementTag(let v) = marker.kind { return v }
            return nil
        }
        #expect(values == ["alpha", "beta", "gamma"])
    }
}
```

- [ ] **Step 1.3: Run tests to confirm RED**

Run:
```bash
swift test --filter StructurizrRecoveryMarkerTests
```
Expected: all four tests FAIL — `scanStructurizrRecoveryMarkers(_:)`
returns `[]` unconditionally.

- [ ] **Step 1.4: Implement the scan**

Replace the stub `scanStructurizrRecoveryMarkers(_:)` in
`StructurizrRecoveryMarker.swift` with:

```swift
public func scanStructurizrRecoveryMarkers(_ source: String) -> [StructurizrRecoveryMarker] {
    var markers: [StructurizrRecoveryMarker] = []
    let tagPrefix = "diagramkit:tag="
    let boundaryParentPrefix = "diagramkit:boundary-parent="
    var lineNumber = 0
    for rawLine in source.components(separatedBy: "\n") {
        lineNumber += 1
        // Trim leading whitespace.
        var trimmed = rawLine
        while let first = trimmed.first, first == " " || first == "\t" {
            trimmed.removeFirst()
        }
        guard trimmed.first == "#" else { continue }
        // Skip the '#' and any whitespace between '#' and 'diagramkit:'.
        trimmed.removeFirst()
        while let first = trimmed.first, first == " " || first == "\t" {
            trimmed.removeFirst()
        }
        if trimmed.hasPrefix(tagPrefix) {
            var value = String(trimmed.dropFirst(tagPrefix.count))
            // Trim trailing whitespace and CRs.
            while let last = value.last, last == " " || last == "\t" || last == "\r" {
                value.removeLast()
            }
            markers.append(StructurizrRecoveryMarker(
                lineNumber: lineNumber,
                kind: .elementTag(value: value)
            ))
        } else if trimmed.hasPrefix(boundaryParentPrefix) {
            var value = String(trimmed.dropFirst(boundaryParentPrefix.count))
            while let last = value.last, last == " " || last == "\t" || last == "\r" {
                value.removeLast()
            }
            markers.append(StructurizrRecoveryMarker(
                lineNumber: lineNumber,
                kind: .boundaryParent(id: value)
            ))
        }
    }
    return markers
}
```

- [ ] **Step 1.5: Run tests to confirm GREEN**

Run:
```bash
swift test --filter StructurizrRecoveryMarkerTests
```
Expected: all four tests PASS.

- [ ] **Step 1.6: Run discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
```
Expected: both exit 0. The new file is well under the 500-line warn
line (~80 lines).

- [ ] **Step 1.7: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift \
        Tests/DiagramKitTests/StructurizrRecoveryMarkerTests.swift

git commit -m "$(cat <<'EOF'
Add Structurizr recovery-marker scaffolding

Wave 3 of the coverage-expansion spec introduces typed
`# diagramkit:` line-comment markers so the Structurizr exporter can
encode element-scoped tags and flattened nested-boundary parentage
losslessly. This commit adds the `StructurizrRecoveryMarker` type and
the pre-lexer scan that harvests markers from raw source before the
lexer's preprocess pass strips `#` comments (StructurizrLexer.swift:
84-93).

The scan is plumbed through the importer / mapper in the next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Wire Recovery-Marker Scan Through Importer → Mapper

**Files:**
- Modify: `Sources/DiagramKitStructurizr/StructurizrImporter.swift`
- Modify: `Sources/DiagramKitStructurizr/StructurizrMapper.swift`

This task wires the scan output through the importer into the mapper.
**The mapper does nothing with the markers yet** — that comes in Tasks 3
and 5 once we have failing round-trip tests to drive the behavior. This
task just gets the data to the right place without changing observable
output.

> **Design note: marker delivery channel.** Two options:
> (1) extend `StructurizrWorkspace` with a `recoveryMarkers:
> [StructurizrRecoveryMarker]` field, or (2) thread the markers as an
> extra argument to `StructurizrMapper.map(_:markers:)`. Option 2 is
> chosen because it keeps `StructurizrAST.swift` unmodified (the AST is
> a pure tokenization output of the lexer; markers are an importer-side
> recovery channel that lives outside lex/parse). The mapper applies
> markers as a post-processing pass against the parsed workspace.

- [ ] **Step 2.1: Extend the mapper signature**

In `Sources/DiagramKitStructurizr/StructurizrMapper.swift`, change the
`map(_:)` signature to accept markers:

```swift
public func map(
    _ workspace: StructurizrWorkspace,
    markers: [StructurizrRecoveryMarker] = []
) -> (diagram: C4Diagram, diagnostics: [DiagramDiagnostic]) {
    // ... existing body unchanged for now; markers ignored ...
}
```

The default value `= []` preserves source compatibility for any
external caller. Internally the importer always passes the harvested
markers.

- [ ] **Step 2.2: Wire the scan in the importer**

In `Sources/DiagramKitStructurizr/StructurizrImporter.swift`, edit
`parse(_:)` to scan the source *before* tokenizing and pass the
markers to the mapper:

```swift
public func parse(_ source: String) throws -> DiagramImportResult {
    let recoveryMarkers = scanStructurizrRecoveryMarkers(source)

    let lexer = StructurizrLexer()
    let tokens = lexer.tokenize(source)

    let parser = StructurizrParser()
    let (workspace, parseDiagnostics) = try parser.parse(tokens)

    let mapper = StructurizrMapper()
    let (c4Diagram, mapDiagnostics) = mapper.map(workspace, markers: recoveryMarkers)

    let allDiagnostics = parseDiagnostics + mapDiagnostics
    let payload = DiagramPayload.c4(c4Diagram)
    let document = DiagramDocument(payload: payload)

    return DiagramImportResult(document: document, diagnostics: allDiagnostics)
}
```

- [ ] **Step 2.3: Run the existing Structurizr suite to confirm no regression**

Run each of the following — none should fail (the mapper still ignores
markers in this task):
```bash
swift test --filter StructurizrRecoveryMarkerTests
swift test --filter StructurizrBoundaryRoundTripTests
swift test --filter StructurizrLexerTests
swift test --filter SameFormatRoundTripTests/structurizrC4
swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4
swift test --filter CrossFormatRoundTripTests/plantumlStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrPlantumlC4
```
Expected: all PASS.

- [ ] **Step 2.4: Run discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
```
Expected: both exit 0.

- [ ] **Step 2.5: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrImporter.swift \
        Sources/DiagramKitStructurizr/StructurizrMapper.swift

git commit -m "$(cat <<'EOF'
Wire Structurizr recovery-marker scan into importer + mapper

Plumb the pre-lexer scan output from `StructurizrImporter.parse` into
`StructurizrMapper.map`. The mapper accepts but does not yet act on
markers; that lands in the tag and boundary tasks once a failing
round-trip test exercises the recovery path.

`StructurizrMapper.map`'s `markers:` parameter defaults to `[]` so
external callers keep compiling.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Tag Recovery — Failing Round-Trip Fixture, Emit, Re-Attach

**Files:**
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/04-tags.dsl`
- Modify: `Sources/DiagramKitStructurizr/StructurizrExporter.swift`
- Modify: `Sources/DiagramKitStructurizr/StructurizrMapper.swift`

This task lands the tag-recovery round-trip. The
`.featureDropped(.diagramFamilyUnsupported, …)` emission at
`StructurizrExporter.swift:170-174` is **still present** at the end of
this task — its deletion is sequenced in Task 4 once the round-trip is
proven structurally lossless.

- [ ] **Step 3.1: Add a failing fixture `04-tags.dsl`**

Create
`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/04-tags.dsl`:

```
workspace {
    model {
        customer = person "Customer"
        # diagramkit:tag=external
        banking = softwareSystem "Banking System"
        # diagramkit:tag=core
        customer -> banking "Uses"
    }

    views {
        systemContext banking "SystemContext" {
            include *
        }
    }
}
```

This fixture exercises the tag-recovery path on both a person and a
softwareSystem, with single-tag values. The fixture itself uses the
recovery comments (rather than relying on cross-format reach) so the
round-trip's `parse → export → parse` cycle proves the importer side
end-to-end.

- [ ] **Step 3.2: Run the structurizr-c4 suite to confirm RED**

Run:
```bash
swift test --filter SameFormatRoundTripTests/structurizrC4
```
Expected: the `04-tags.dsl` arm FAILS. The first parse populates
`C4Shape.tags = "external"` on customer (via Task 2's pre-lexer scan
that Task 2 wired but the mapper still ignores), but the export does
not yet emit a `# diagramkit:tag=external` marker, so the second parse
gets `C4Shape.tags = nil` and the diff arm reports
`shapes[customer].tags` mismatch.

> If `C4Shape.tags` is *not* yet populated by the first parse (mapper
> still ignores markers), the test fails differently — the export still
> emits the `.featureDropped` diagnostic and the round-trip carries no
> tag at all. Either failure proves the test is RED; proceed.

- [ ] **Step 3.3: Apply tag markers in the mapper**

In `Sources/DiagramKitStructurizr/StructurizrMapper.swift`, add a
helper that re-attaches tag markers to elements, and call it from
`map(_:markers:)` after the model registry is built but before
`c4Shapes` is constructed:

```swift
private func applyTagMarkers(
    to elements: inout [String: StructurizrModelElement],
    elementOrder: [String],
    markers: [StructurizrRecoveryMarker]
) {
    // Walk markers in source order; each tag marker attaches to the
    // most recently declared element. The `elementOrder` array carries
    // alias-by-line-of-first-token mapping; for simplicity (and because
    // the Structurizr DSL puts each element def on its own line), we
    // pair markers to elements positionally: the Nth tag marker after
    // alias X re-attaches to X.
    //
    // Implementation: for each tag marker, find the element whose
    // declaration line is the largest line number strictly less than
    // the marker's line number.
    // ...
}
```

Then in `map(_:markers:)`, before populating `c4Shapes`, walk
`registry.elementsByAlias` and apply markers: append each
`elementTag(value:)` marker's value to the element's `tags: [String]`
array (the existing field on `StructurizrModelElement`,
`StructurizrAST.swift:50`).

Concretely, replace the body of `map(_:markers:)` to insert this block
immediately after the `registry` is constructed
(`StructurizrMapper.swift:28-31` today):

```swift
let registry = StructurizrModelRegistry(
    elements: model.elements,
    relationships: model.relationships
)

// Apply tag markers.
//
// The registry indexes elements by alias; we need an ordering by
// source position to bind markers to the immediately-preceding
// element. Since `StructurizrAST` does not currently carry source
// positions, the simplest robust mapping is: harvest both the
// markers and the *declaration order* of elements (preserved by
// `model.elements` flattening), then attach each tag marker to the
// most recently declared element. Multi-tag elements emit multiple
// adjacent markers per the exporter rule (Task 3.4).
//
// Concretely: build a stable order of aliases from `model.elements`
// (depth-first), pair markers to aliases by counting markers between
// each element's line and the next element's line in the raw source.
//
// For the v1 implementation, we use a simpler positional pairing:
// each marker attaches to the alias that appears immediately above
// it in the source, identified by re-tokenizing each marker's
// preceding line. This is implemented in `recoveredTagsByAlias` below.
var recoveredTagsByAlias: [String: [String]] = [:]
for marker in markers {
    guard case .elementTag(let value) = marker.kind else { continue }
    // Find the element whose declaration line is the largest line
    // number strictly less than `marker.lineNumber`. The pre-lexer
    // scan does not know declaration line numbers; we re-derive them
    // by line-scanning the raw workspace text. To keep the mapper
    // pure, the scan now returns (alias, declarationLine) tuples for
    // every `<alias> = <kind>` form; we cache those in the importer
    // and pass them through alongside `markers`.
    //
    // Implementation detail deferred to Step 3.3.a below.
    _ = value
}
```

> **Implementation detail (Step 3.3.a — declaration-line scan).** The
> simplest concrete implementation pairs markers to aliases via a
> shared raw-source scan rather than re-walking the AST. Extend
> `scanStructurizrRecoveryMarkers(_:)` (or add a sibling function
> `scanStructurizrDeclarations(_:)`) that returns both the markers and
> the per-alias declaration line numbers from the same raw source:
>
> ```swift
> public struct StructurizrPreLexerScanResult: Sendable, Equatable {
>     public let markers: [StructurizrRecoveryMarker]
>     /// Maps each `<alias> = <kind>` declaration to its 1-based line.
>     public let elementDeclarations: [(alias: String, line: Int)]
>     /// Maps each `group "<label>" {` declaration to its 1-based line.
>     public let groupDeclarations: [(label: String, line: Int)]
> }
>
> public func scanStructurizrPreLexer(_ source: String) -> StructurizrPreLexerScanResult
> ```
>
> The pairing rule for tag markers: for each `elementTag(value:)`
> marker at `line N`, find the largest `elementDeclarations[i].line < N`
> and assign the value to `elementDeclarations[i].alias`. If no such
> declaration exists, drop the marker silently (it's a stray comment).
>
> Update `StructurizrImporter.parse(_:)` to call
> `scanStructurizrPreLexer(_:)` and pass the result to
> `StructurizrMapper.map(_:scan:)` (rename `markers:` → `scan:` so the
> mapper has both the markers and the declaration index in one
> argument).

Implement the helper, update the importer to call it, and update the
mapper to use `scan.elementDeclarations` to pair markers to aliases.

After pairing, populate `C4Shape.tags` in the existing `c4ShapeType`
loop (`StructurizrMapper.swift:135-181`): when constructing the
`C4Shape`, set `tags:` to `recoveredTagsByAlias[element.alias]?.joined(separator: ",")`.

> **About the existing `tags: String?` field on `C4Shape`.** Today
> `StructurizrMapper.swift` never populates `C4Shape.tags`; the
> field stays `nil`. After this change, recovered tags concatenate
> with `,` separator before assignment, matching the format the
> StructurizrExporter at line 169-174 already uses for the
> `.featureDropped` message body.

- [ ] **Step 3.4: Emit `# diagramkit:tag=<tag>` markers on export**

In `Sources/DiagramKitStructurizr/StructurizrExporter.swift`, modify
`emitShape(_:indent:aliasMap:into:diagnostics:)` to append one
recovery marker line per tag *after* the element line. Keep the
existing `.featureDropped(.diagramFamilyUnsupported, …)` emission for
now (it is removed in Task 4 only after the round-trip is proven):

```swift
private static func emitShape(
    _ shape: C4Shape,
    indent: String,
    aliasMap: [String: String],
    into lines: inout [String],
    diagnostics: inout [DiagramDiagnostic]
) {
    let safeAlias = aliasMap[shape.alias] ?? shape.alias
    let stype = structurizrType(shape.typeC4Shape)
    let escapedLabel = escape(shape.label)
    let escapedDesc = shape.description.map { escape($0) } ?? ""

    if !escapedDesc.isEmpty {
        lines.append("\(indent)\(safeAlias) = \(stype) \"\(escapedLabel)\" \"\(escapedDesc)\"")
    } else {
        lines.append("\(indent)\(safeAlias) = \(stype) \"\(escapedLabel)\"")
    }

    if let tags = shape.tags, !tags.isEmpty {
        // Wave 3: emit one `# diagramkit:tag=<tag>` line per comma-
        // separated tag component immediately after the element line so
        // the next import can re-attach via the pre-lexer scan.
        let components = tags.split(separator: ",").map { component -> String in
            var trimmed = String(component)
            while let first = trimmed.first, first == " " || first == "\t" {
                trimmed.removeFirst()
            }
            while let last = trimmed.last, last == " " || last == "\t" {
                trimmed.removeLast()
            }
            return trimmed
        }
        for component in components where !component.isEmpty {
            // Defense-in-depth: collapse newlines / CRs / quotes that
            // would corrupt the marker form.
            let sanitized = component
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\"", with: " ")
            lines.append("\(indent)# diagramkit:tag=\(sanitized)")
        }
        // Old `.featureDropped` site — removed in Task 4 once the
        // round-trip is proven structurally lossless.
        diagnostics.append(.featureDropped(
            .diagramFamilyUnsupported,
            message: "Structurizr parser does not currently support element-scoped tags; dropping `tags \"\(tags)\"` for alias '\(shape.alias)'"
        ))
    }
}
```

- [ ] **Step 3.5: Run the structurizr-c4 suite to confirm GREEN**

Run:
```bash
swift test --filter SameFormatRoundTripTests/structurizrC4
```
Expected: all four fixtures PASS (01-basic, 02-two-systems, 03-group,
**04-tags**). The round-trip on `04-tags.dsl` is now structurally
lossless: the export emits `# diagramkit:tag=external` after
`customer = person "Customer"`, the next import's pre-lexer scan
harvests it, the mapper re-attaches it to `customer`, and the diff arm
sees `lhs.tags == rhs.tags`.

If the test still fails on a `shapes[<alias>].tags` mismatch, verify
the pre-lexer scan's declaration-line pairing is matching the right
alias — the smallest-larger-than-element rule must use a **strict**
`<` (the marker is on a later line than the element).

- [ ] **Step 3.6: Run all Structurizr tests to confirm no regression**

```bash
swift test --filter StructurizrRecoveryMarkerTests
swift test --filter StructurizrBoundaryRoundTripTests
swift test --filter SameFormatRoundTripTests/structurizrC4
swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4
swift test --filter CrossFormatRoundTripTests/plantumlStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrPlantumlC4
```
Expected: all PASS.

- [ ] **Step 3.7: Run discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
```
Expected: both exit 0.

- [ ] **Step 3.8: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrExporter.swift \
        Sources/DiagramKitStructurizr/StructurizrImporter.swift \
        Sources/DiagramKitStructurizr/StructurizrMapper.swift \
        Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/04-tags.dsl

git commit -m "$(cat <<'EOF'
Round-trip Structurizr element-scoped tags via recovery comments

Wave 3 of the coverage-expansion spec. The Structurizr exporter now
emits `# diagramkit:tag=<tag>` markers immediately after each element
that carries a non-empty `C4Shape.tags`, one marker per comma-separated
component. The importer's pre-lexer scan harvests those markers and
the mapper re-attaches them via a strict-less-than pairing against
the per-alias declaration line numbers indexed in the same scan.

The legacy `.featureDropped(.diagramFamilyUnsupported, ...)` emission
at StructurizrExporter.swift:170-174 is intentionally still present —
it is removed in the next commit once the round-trip is proven
structurally lossless across the broader suite. Same-format fixture
`04-tags.dsl` exercises the path end-to-end.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Tag Recovery — Delete the Diagnostic, Confirm No Allow-List Shrink Needed

**Files:**
- Modify: `Sources/DiagramKitStructurizr/StructurizrExporter.swift`

The tag emission site at `StructurizrExporter.swift:170-174` uses
`.featureDropped(.diagramFamilyUnsupported, …)`. There is no
`RoundTripLossKind` that pairs to `.diagramFamilyUnsupported` — that
category is used by the mapper for "unknown view scope alias", "no
model section", etc. So `structurizrC4`'s allow-list does **not**
contain anything that covers this emission today; it pairs to no
`RoundTripLoss`. **No allow-list shrink is needed for the tag site.**
This task is purely "delete the now-unnecessary diagnostic."

- [ ] **Step 4.1: Delete the `.featureDropped` emission**

In `Sources/DiagramKitStructurizr/StructurizrExporter.swift`, inside
`emitShape(_:indent:aliasMap:into:diagnostics:)`, delete the
**three-line `.featureDropped` block** added at the end of Task 3.5
(lines roughly 184-188 after Task 3's insertion):

```swift
        // DELETE these three lines:
        diagnostics.append(.featureDropped(
            .diagramFamilyUnsupported,
            message: "Structurizr parser does not currently support element-scoped tags; dropping `tags \"\(tags)\"` for alias '\(shape.alias)'"
        ))
```

The recovery-marker `lines.append(...)` block above stays.

- [ ] **Step 4.2: Run the structurizr-c4 suite to confirm GREEN**

```bash
swift test --filter SameFormatRoundTripTests/structurizrC4
```
Expected: all four fixtures PASS. The diagnostic is gone but no loss
occurred; the harness sees zero diagnostics and zero deltas, which is
the green path.

- [ ] **Step 4.3: Run the Structurizr cross-format suites**

```bash
swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4
swift test --filter CrossFormatRoundTripTests/plantumlStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrPlantumlC4
```
Expected: all PASS. None of the existing cross-format fixtures populate
`C4Shape.tags` so the deletion has no effect on them.

- [ ] **Step 4.4: Run discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
```
Expected: both exit 0. The discipline gate enforces typed factories
on emission sites; deleting a site cannot create a discipline error.

- [ ] **Step 4.5: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrExporter.swift

git commit -m "$(cat <<'EOF'
Remove Structurizr tag drop diagnostic — data now round-trips

Tags now round-trip losslessly through `# diagramkit:tag=` recovery
markers (previous commit). The
`.featureDropped(.diagramFamilyUnsupported, ...)` emission inside
`emitShape(...)` for element-scoped tags is no longer accurate — the
data is not dropped, it is encoded — so the site is removed.

This is the diagnostic-emission inversion that Wave 3 calls out: the
diagnostic decision tree emits only for actual loss, and the recovery
comments mean no loss occurs. Per the spec's "Structurizr Wave 3
inverts the pattern" paragraph, the site is deleted rather than
redirected.

`structurizrC4` cell allow-list is unchanged for this commit:
`.diagramFamilyUnsupported` had no `RoundTripLossKind` paired to it,
so the cell was never gated on this diagnostic.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Boundary Recovery — Failing Round-Trip Fixtures, Emit, Re-Attach

**Files:**
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/05-nested-boundary.dsl`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-structurizr-c4/02-boundary.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-structurizr-mermaid-c4/02-boundary.dsl`
- Modify: `Sources/DiagramKitStructurizr/StructurizrExporter.swift`
- Modify: `Sources/DiagramKitStructurizr/StructurizrMapper.swift`

This task lands boundary-parent recovery. The two
`.lossyTransform(.boundaryFlatten, …)` emissions at
`StructurizrExporter.swift:69-83` are **still present** at the end of
this task — their deletion is sequenced in Task 6.

- [ ] **Step 5.1: Add a failing same-format fixture `05-nested-boundary.dsl`**

Create
`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/05-nested-boundary.dsl`:

```
workspace {
    model {
        group "outer" {
            outerSystem = softwareSystem "Outer System"
        }
        group "inner" {
            # diagramkit:boundary-parent=outer
            innerSystem = softwareSystem "Inner System"
        }
        outerSystem -> innerSystem "Talks to"
    }

    views {
        systemContext outerSystem "SystemContext" {
            include *
        }
    }
}
```

Two authored groups (`outer` and `inner`), where `inner`'s authored
parent is `outer`. The Structurizr DSL itself can't nest groups
(parser at `StructurizrParser.swift:130-135` rejects nested groups
with a `.featureDropped` diagnostic), so the recovery marker
encodes the parentage flatly. The mapper recovers `inner`'s
`parentBoundary` from the marker; the next export emits the marker
again; the round-trip is structurally lossless.

- [ ] **Step 5.2: Add a failing cross-format fixture `cross-mermaid-structurizr-c4/02-boundary.md`**

Create
`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-structurizr-c4/02-boundary.md`:

```
C4Context
    Person(customer, "Customer")
    Boundary(outer, "Outer Boundary") {
      Boundary(inner, "Inner Boundary") {
        System(banking, "Banking System")
      }
    }
    Rel(customer, banking, "Uses")
```

The Mermaid C4 parser supports nested `Boundary(...)` macros natively.
The Mermaid → Structurizr leg flattens the nested boundary and emits a
`# diagramkit:boundary-parent=outer` marker on the inner group; the
Structurizr → Mermaid leg recovers `inner`'s parent and re-emits the
nested `Boundary(...)` form. The cross-format round-trip
(`parse(mermaid) → export(structurizr) → parse(structurizr) → export(mermaid) → parse(mermaid)`)
asserts structural equality of doc₁ vs doc₃.

- [ ] **Step 5.3: Add a failing reverse cross-format fixture `cross-structurizr-mermaid-c4/02-boundary.dsl`**

Create
`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-structurizr-mermaid-c4/02-boundary.dsl`:

```
workspace {
    model {
        group "outer" {
            outerSystem = softwareSystem "Outer System"
        }
        group "inner" {
            # diagramkit:boundary-parent=outer
            innerSystem = softwareSystem "Inner System"
        }
        outerSystem -> innerSystem "Talks to"
    }

    views {
        systemContext outerSystem "SystemContext" {
            include *
        }
    }
}
```

Mirror of Step 5.1 but exercised through the Structurizr → Mermaid →
Structurizr cross-format harness. The first parse imports recovered
parentage from the inline marker; the Mermaid export re-emits as
nested `Boundary(...)`; the Mermaid → Structurizr leg flattens again
and re-emits the marker; doc₁ vs doc₃ are structurally equal.

- [ ] **Step 5.4: Run the same-format + cross-format suites to confirm RED**

```bash
swift test --filter SameFormatRoundTripTests/structurizrC4
swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4
```
Expected: the three new fixtures FAIL. The same-format `05-nested-boundary.dsl`
fails because:
- Either the importer doesn't yet recover the marker (Task 2 wired
  delivery only; Task 3 added tag pairing but not boundary-parent
  pairing), so the first parse drops `inner`'s parentage entirely.
- Or, if the first parse recovers parentage, the export does not yet
  emit the marker, so the second parse sees a flat workspace and
  doc₁/doc₂ diverge on `boundaries[inner].parentBoundary`.

The cross-format fixtures fail symmetrically. Proceed.

- [ ] **Step 5.5: Apply boundary-parent markers in the mapper**

In `Sources/DiagramKitStructurizr/StructurizrMapper.swift`, after the
existing `groupAliasMap` is built
(`StructurizrMapper.swift:33-40`), add a recovery pass that pairs each
`boundaryParent(id:)` marker to the most-recently-declared group label
using the `scan.groupDeclarations` index from Task 3's pre-lexer scan
extension:

```swift
// Wave 3: recover flattened nested-boundary parentage from
// `# diagramkit:boundary-parent=<id>` markers. The pairing rule
// mirrors the tag rule: for each `boundaryParent(id:)` marker at
// `line N`, find the largest `scan.groupDeclarations[i].line < N` and
// assign the id to that group's recovered parent.
var recoveredParentByGroupLabel: [String: String] = [:]
for marker in scan.markers {
    guard case .boundaryParent(let parentId) = marker.kind else { continue }
    var bestGroup: (label: String, line: Int)? = nil
    for decl in scan.groupDeclarations where decl.line < marker.lineNumber {
        if bestGroup == nil || decl.line > bestGroup!.line {
            bestGroup = decl
        }
    }
    if let group = bestGroup {
        recoveredParentByGroupLabel[group.label] = parentId
    }
}
```

Then, when constructing `C4Boundary` entries in the existing groupAliasMap
loop (`StructurizrMapper.swift:201-209`), set `parentBoundary:` to the
sanitized alias of the recovered parent (looking it up via
`groupAliasMap[recoveredParent] ?? "global"`):

```swift
for (label, alias) in groupAliasMap {
    let parentBoundary: String
    if let recoveredParentLabel = recoveredParentByGroupLabel[label],
       let parentAlias = groupAliasMap[recoveredParentLabel] {
        parentBoundary = parentAlias
    } else {
        parentBoundary = "global"
    }
    c4Boundaries.append(C4Boundary(
        alias: alias,
        label: label,
        type: "group",
        parentBoundary: parentBoundary,
        origin: .authored
    ))
}
```

> **About the pairing semantics.** The marker is emitted on the *first
> line inside* the group block (per Task 5.6 below). The group's
> declaration line is the `group "<label>" {` line. The strict-less-than
> rule pairs the marker to that group. Markers outside any group block
> have no matching `groupDeclarations` entry before them (only the
> `workspace {` and `model {` lines exist, and those are not group
> declarations) — drop silently.

- [ ] **Step 5.6: Emit `# diagramkit:boundary-parent=<id>` markers on export**

In `Sources/DiagramKitStructurizr/StructurizrExporter.swift`, inside
the authored-boundary loop
(`StructurizrExporter.swift:68-90`), emit the recovery marker as the
**first line inside** the `group "..." {` block when the boundary has
a non-global authored parent. Keep the existing
`.lossyTransform(.boundaryFlatten, …)` emissions for now (deleted in
Task 6):

```swift
for boundary in authoredBoundaries {
    if !boundary.parentBoundary.isEmpty && boundary.parentBoundary != "global" {
        // Old emission — removed in Task 6 once round-trip is green:
        diagnostics.append(.lossyTransform(
            .boundaryFlatten,
            message: "Structurizr `group` is non-nestable; flattening boundary '\(boundary.alias)' (parent: '\(boundary.parentBoundary)') to top-level"
        ))
    }

    let members = shapesByBoundary[boundary.alias] ?? []
    if members.isEmpty {
        // Old emission — removed in Task 6:
        diagnostics.append(.lossyTransform(
            .boundaryFlatten,
            message: "Empty group '\(boundary.label)' (alias '\(boundary.alias)') has no direct shapes after Structurizr flattening; dropping"
        ))
        continue
    }

    lines.append("    group \"\(escape(boundary.label))\" {")
    // Wave 3: emit the boundary-parent recovery marker as the first
    // line inside the group block when this group has a non-global
    // authored parent.
    if !boundary.parentBoundary.isEmpty && boundary.parentBoundary != "global" {
        lines.append("      # diagramkit:boundary-parent=\(boundary.parentBoundary)")
    }
    for shape in members {
        emitShape(shape, indent: "      ", aliasMap: aliasMap, into: &lines, diagnostics: &diagnostics)
    }
    lines.append("    }")
}
```

> **About empty-group elision recovery.** The empty-group case
> (`StructurizrExporter.swift:77-82`) currently drops the group
> entirely. Recovering an empty group requires emitting the `group
> "<label>" {}` block even when it has no members, plus the
> `# diagramkit:boundary-parent=<id>` marker inside. This task does
> that: in the empty-group branch, **also emit the `group "..." { ...
> }` block** (with just the marker line if non-global parent, or empty
> body otherwise). The `continue` after the (about-to-be-removed)
> diagnostic stays; rewrite to:
>
> ```swift
>     if members.isEmpty {
>         diagnostics.append(.lossyTransform(.boundaryFlatten, message: ...))   // removed in Task 6
>         lines.append("    group \"\(escape(boundary.label))\" {")
>         if !boundary.parentBoundary.isEmpty && boundary.parentBoundary != "global" {
>             lines.append("      # diagramkit:boundary-parent=\(boundary.parentBoundary)")
>         }
>         lines.append("    }")
>         continue
>     }
> ```
>
> The Structurizr parser at `StructurizrParser.swift:114-167` accepts
> empty `group "..." { }` blocks (the inner while loop simply finds the
> `}` and exits with `groupElements == []`), so empty-group emission is
> safe to round-trip. Verify with the same-format harness on Step 5.7.

- [ ] **Step 5.7: Run same-format + cross-format suites to confirm GREEN**

```bash
swift test --filter SameFormatRoundTripTests/structurizrC4
swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4
```
Expected: all PASS (including 04-tags from Task 3, 05-nested-boundary
new, both 02-boundary cross-format fixtures new).

If the cross-format `02-boundary` arms still fail, inspect the diff
arm's report:
- If `boundaries.count(authored)` differs, verify the
  `recoveredParentByGroupLabel` lookup is happening before the
  `c4Boundaries.append(...)` call in the groupAliasMap loop.
- If `shapes[<alias>].parentBoundary` differs, verify the existing
  `effectiveBoundary` logic at `StructurizrMapper.swift:166-170`
  still wins over the recovered parent (it should — the recovered
  parent sets `C4Boundary.parentBoundary`, not `C4Shape.parentBoundary`).

- [ ] **Step 5.8: Run discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
```
Expected: both exit 0.

- [ ] **Step 5.9: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrExporter.swift \
        Sources/DiagramKitStructurizr/StructurizrMapper.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/05-nested-boundary.dsl \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-structurizr-c4/02-boundary.md \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-structurizr-mermaid-c4/02-boundary.dsl

git commit -m "$(cat <<'EOF'
Round-trip Structurizr nested-boundary parentage via recovery comments

Wave 3 of the coverage-expansion spec. The Structurizr exporter now
emits `# diagramkit:boundary-parent=<id>` markers as the first line
inside each `group "..." {` block whose authored parent is neither
empty nor "global". The empty-group case now also emits the
`group "..." { ... }` block (with just the marker line) so empty
groups round-trip too — the Structurizr parser accepts empty group
blocks. The importer's pre-lexer scan pairs markers to the
immediately-preceding group declaration via strict-less-than line
matching.

Same-format fixture `structurizr-c4/05-nested-boundary.dsl` and
bidirectional cross-format fixtures
`cross-{mermaid-structurizr,structurizr-mermaid}-c4/02-boundary.*`
exercise the path end-to-end.

The legacy `.lossyTransform(.boundaryFlatten, ...)` emissions at
StructurizrExporter.swift:69-83 are intentionally still present; they
are removed in the next commit once the round-trip is proven green
across the full Structurizr suite.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Boundary Recovery — Delete Diagnostics, Shrink Allow-Lists

**Files:**
- Modify: `Sources/DiagramKitStructurizr/StructurizrExporter.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift`

The two `.lossyTransform(.boundaryFlatten, …)` emissions at
`StructurizrExporter.swift:69-83` (nested-parent flattening and
empty-group elision) are no longer accurate — the data is encoded in
`# diagramkit:boundary-parent=` markers. This task deletes them and
shrinks every cell allow-list that contained `.boundaryFlatten` for
Structurizr-touching cells.

- [ ] **Step 6.1: Delete the two `.lossyTransform(.boundaryFlatten, …)` emissions**

In `Sources/DiagramKitStructurizr/StructurizrExporter.swift`, delete
both `.lossyTransform(.boundaryFlatten, …)` blocks added in Task 5.6.
After deletion, the authored-boundary loop reads:

```swift
for boundary in authoredBoundaries {
    let members = shapesByBoundary[boundary.alias] ?? []

    lines.append("    group \"\(escape(boundary.label))\" {")
    if !boundary.parentBoundary.isEmpty && boundary.parentBoundary != "global" {
        lines.append("      # diagramkit:boundary-parent=\(boundary.parentBoundary)")
    }
    for shape in members {
        emitShape(shape, indent: "      ", aliasMap: aliasMap, into: &lines, diagnostics: &diagnostics)
    }
    lines.append("    }")
}
```

Empty groups now emit a valid `group "<label>" { ... }` block with just
the (optional) marker; no `continue` is needed. The conditional
non-global-parent line preserves the marker behavior from Task 5.

- [ ] **Step 6.2: Shrink `RoundTripCellRegistry.structurizrC4.allowedLosses`**

In `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift` at
**line 233**, change:

```swift
    static let structurizrC4 = RoundTripCell(
        importer: StructurizrImporter(),
        exporter: StructurizrExporter(),
        family: DiagramType.c4,
        allowedLosses: [.idSanitization, .boundaryFlatten, .c4SlotDrop]
    )
```

To:

```swift
    static let structurizrC4 = RoundTripCell(
        importer: StructurizrImporter(),
        exporter: StructurizrExporter(),
        family: DiagramType.c4,
        allowedLosses: [.idSanitization, .c4SlotDrop]
    )
```

The other two Structurizr-touching cells in this file
(`mermaidC4`, line 51, and `plantumlC4`, line 275) **also contain
`.boundaryFlatten`** but they are independent cells — the
`.boundaryFlatten` there pairs to losses introduced by the Mermaid /
PlantUML side, not by Structurizr. Wave 3 does not touch them; leave
those two cells unchanged.

- [ ] **Step 6.3: Shrink the four cross-format cell allow-lists**

In `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift` at
**lines 19-24**:

```swift
    static let mermaidStructurizrC4: Set<RoundTripLossKind> = [.idSanitization, .boundaryFlatten, .c4SlotDrop, .configDrop]
    static let structurizrMermaidC4: Set<RoundTripLossKind> = [.idSanitization, .boundaryFlatten, .c4SlotDrop, .configDrop]
    static let mermaidPlantumlC4: Set<RoundTripLossKind> = [.idSanitization, .c4SlotDrop, .configDrop]
    static let plantumlMermaidC4: Set<RoundTripLossKind> = [.idSanitization, .c4SlotDrop, .configDrop]
    static let plantumlStructurizrC4: Set<RoundTripLossKind> = [.idSanitization, .boundaryFlatten, .c4SlotDrop]
    static let structurizrPlantumlC4: Set<RoundTripLossKind> = [.idSanitization, .boundaryFlatten, .c4SlotDrop]
```

Change to:

```swift
    static let mermaidStructurizrC4: Set<RoundTripLossKind> = [.idSanitization, .c4SlotDrop, .configDrop]
    static let structurizrMermaidC4: Set<RoundTripLossKind> = [.idSanitization, .c4SlotDrop, .configDrop]
    static let mermaidPlantumlC4: Set<RoundTripLossKind> = [.idSanitization, .c4SlotDrop, .configDrop]
    static let plantumlMermaidC4: Set<RoundTripLossKind> = [.idSanitization, .c4SlotDrop, .configDrop]
    static let plantumlStructurizrC4: Set<RoundTripLossKind> = [.idSanitization, .c4SlotDrop]
    static let structurizrPlantumlC4: Set<RoundTripLossKind> = [.idSanitization, .c4SlotDrop]
```

`.boundaryFlatten` removed from `mermaidStructurizrC4`,
`structurizrMermaidC4`, `plantumlStructurizrC4`, and
`structurizrPlantumlC4`. The two pure Mermaid↔PlantUML cells
(`mermaidPlantumlC4`, `plantumlMermaidC4`) are unchanged — they did
not contain `.boundaryFlatten` to begin with.

- [ ] **Step 6.4: Run the full Structurizr round-trip surface to confirm GREEN**

```bash
swift test --filter SameFormatRoundTripTests/structurizrC4
swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4
swift test --filter CrossFormatRoundTripTests/plantumlStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrPlantumlC4
swift test --filter StructurizrBoundaryRoundTripTests
```
Expected: all PASS. With the diagnostics deleted, the harness's
unpaired-loss check would fail if any `.boundaryFlatten` loss surfaced
without a paired diagnostic — but no loss surfaces, because the data is
recovered. The shrunken allow-list now refuses to accept any stray
`.boundaryFlatten` loss, providing a regression bar.

If any cross-format fixture fails on `boundary.count(authored)` mismatch,
inspect whether the cross-format fixture exercises the boundary path
(it should; 02-boundary was added in Task 5). The pre-existing
01-context cross-format fixtures don't use boundaries, so they should
remain green.

- [ ] **Step 6.5: Run discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
```
Expected: all exit 0.

- [ ] **Step 6.6: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrExporter.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift

git commit -m "$(cat <<'EOF'
Remove Structurizr boundary-flatten diagnostics; shrink allow-lists

Boundaries now round-trip losslessly through `# diagramkit:boundary-
parent=` recovery markers (previous commit). Both
`.lossyTransform(.boundaryFlatten, ...)` emissions inside
`StructurizrC4Export.emit(...)` — for nested-parent flattening and
empty-group elision — are no longer accurate and are deleted.

Per-cell allow-lists shrink accordingly:
- `RoundTripCellRegistry.structurizrC4`: removes `.boundaryFlatten`.
- `RoundTripCrossRegistry.mermaidStructurizrC4`,
  `structurizrMermaidC4`, `plantumlStructurizrC4`,
  `structurizrPlantumlC4`: each removes `.boundaryFlatten`.

The two pure Mermaid↔PlantUML cells in `RoundTripCellRegistry`
(`mermaidC4`, `plantumlC4`) and the two pure Mermaid↔PlantUML
cross-cells in `RoundTripCrossRegistry` (`mermaidPlantumlC4`,
`plantumlMermaidC4`) are unchanged — their `.boundaryFlatten` (where
present) covers losses introduced by the Mermaid/PlantUML side, not
the Structurizr side that Wave 3 fixes.

The shrunken allow-lists now act as a regression bar: any stray
`.boundaryFlatten` loss from a Structurizr leg will fail the harness's
disallowed-loss check.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Multi-View Import — Failing Test, Refactor

**Files:**
- Create: `Tests/DiagramKitTests/StructurizrMultiViewTests.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/06-multi-view.dsl`
- Modify: `Sources/DiagramKitStructurizr/StructurizrMapper.swift`

The current importer parses every view into `workspace.views`
(`StructurizrParser.swift:278-376` already does this) but the mapper
hard-codes `workspace.views[0]` at `StructurizrMapper.swift:59`. The
spec calls this a "first view only" branch and asks for a loop that
visits every view while preserving the first view as the rendered
output.

> **What "multi-view" enriches.** Multi-view import does not change the
> rendered `C4Diagram` output (still the first view). It does:
> (a) visit every view so per-view diagnostics surface for *all* views,
> not just the first; (b) silently dropping the
> `"workspace contains N views; only the first view is imported in
> this release"` diagnostic at `StructurizrMapper.swift:53-56` because
> every view is now processed; (c) make Structurizr workspaces with
> N views round-trip cleanly because the export side already emits one
> view (the first) and the next import again visits every view in the
> re-emitted workspace (which is just the first view, so this is
> idempotent — the multi-view enrichment is a no-op on the round-trip,
> but the test in Step 7.1 asserts the mapper *visits* the additional
> views without throwing).

- [ ] **Step 7.1: Add a failing multi-view test**

Create `Tests/DiagramKitTests/StructurizrMultiViewTests.swift`:

```swift
import Testing
import DiagramKitImport
import DiagramKitModel
@testable import DiagramKitStructurizr

@Suite("StructurizrMultiViewTests")
struct StructurizrMultiViewTests {

    @Test("multi-view workspace produces no `only the first view` diagnostic")
    func multiViewNoFirstViewOnlyDiagnostic() throws {
        let source = """
        workspace {
            model {
                customer = person "Customer"
                banking = softwareSystem "Banking System"
                customer -> banking "Uses"
            }

            views {
                systemContext banking "ContextView" {
                    include *
                }
                container banking "ContainerView" {
                    include *
                }
            }
        }
        """
        let importer = StructurizrImporter()
        let result = try importer.parse(source)
        let firstViewOnlyDiag = result.diagnostics.first { diag in
            diag.message.contains("only the first view is imported")
        }
        #expect(firstViewOnlyDiag == nil)
    }

    @Test("multi-view workspace still renders the first view")
    func multiViewFirstViewRendered() throws {
        let source = """
        workspace {
            model {
                customer = person "Customer"
                banking = softwareSystem "Banking System"
            }

            views {
                systemContext banking "ContextView" {
                    include *
                }
                container banking "ContainerView" {
                    include *
                }
            }
        }
        """
        let importer = StructurizrImporter()
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else {
            Issue.record("expected c4 payload, got \(result.document.payload)")
            return
        }
        #expect(diagram.kind == .context)  // first view is systemContext
    }
}
```

- [ ] **Step 7.2: Add a same-format fixture `06-multi-view.dsl`**

Create
`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/06-multi-view.dsl`:

```
workspace {
    model {
        customer = person "Customer"
        banking = softwareSystem "Banking System"
        customer -> banking "Uses"
    }

    views {
        systemContext banking "ContextView" {
            include *
        }
        container banking "ContainerView" {
            include *
        }
    }
}
```

Two views in the source. The Structurizr exporter currently only emits
one view per export (the first; `StructurizrExporter.swift:118-143`).
After Wave 3, the round-trip behavior is:
- doc₁ has `kind=.context` (first view).
- export emits only the first view.
- doc₂ has `kind=.context` (still the first view, now the only view
  in the re-emitted source).
- diff arm sees doc₁ vs doc₂ equal on `kind`, `shapes`, `relationships`
  — the second view in the source is structurally invisible to the
  C4Diagram payload, so it cannot diverge.

This fixture is a regression bar — it asserts that the multi-view loop
in Task 7.4 does not introduce a spurious diagnostic that breaks the
no-diagnostic round-trip path.

- [ ] **Step 7.3: Run tests to confirm RED**

```bash
swift test --filter StructurizrMultiViewTests
swift test --filter SameFormatRoundTripTests/structurizrC4
```
Expected:
- `multiViewNoFirstViewOnlyDiagnostic` FAILS because the importer
  currently emits the `"only the first view is imported"` diagnostic
  at `StructurizrMapper.swift:53-56`.
- `multiViewFirstViewRendered` PASSES (the first view is already
  rendered today).
- `06-multi-view.dsl` round-trip likely PASSES (the diagnostic at
  StructurizrMapper.swift:53-56 has no paired `RoundTripLoss`, so the
  harness ignores it).

If `06-multi-view.dsl` fails for some other reason (e.g.
`relationships.count` mismatch from per-view scope filtering), inspect
the diff arm; the failure is the bar Task 7.4 must clear.

- [ ] **Step 7.4: Refactor the mapper into a view loop**

In `Sources/DiagramKitStructurizr/StructurizrMapper.swift`, replace
the `workspace.views[0]` hard-coding at line 59 with a loop. The loop
visits every view and **runs the per-view classification and
diagnostic emission** for each, but only the **first view's**
`C4Diagram` is returned as the rendered output.

Concretely, restructure `map(_:scan:)` (renamed in Task 3) so the
existing view-processing logic at `StructurizrMapper.swift:59-269`
runs inside a `for (viewIndex, view) in workspace.views.enumerated()`
loop. Collect:
- `firstViewDiagram: C4Diagram?` — set on the first iteration only.
- `allViewDiagnostics: [DiagramDiagnostic]` — accumulated across every
  view (the per-view "unknown view scope alias", "dynamic views not
  yet supported", etc. diagnostics now surface for every view, not
  just the first).

Return `(firstViewDiagram ?? .empty, recoveredParentByGroupLabel
diagnostics + allViewDiagnostics)`.

**Delete** the diagnostic at `StructurizrMapper.swift:53-56`:

```swift
        // DELETE:
        if workspace.views.count > 1 {
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "workspace contains \(workspace.views.count) views; only the first view is imported in this release"
            ))
        }
```

The diagnostic was a placeholder for "we're going to ignore views
2..N." After Wave 3, views 2..N are processed (their own diagnostics
surface), even though only view 1 contributes to the rendered output.

> **About "processed but not rendered."** The loop runs the same
> classification / visibility / relationship-resolution per view, but
> only the first view's outputs (shapes, boundaries, relationships,
> kind, title) populate the returned C4Diagram. The per-view
> diagnostics from views 2..N help users debug malformed view
> definitions even when they're not the rendered view.

- [ ] **Step 7.5: Run tests to confirm GREEN**

```bash
swift test --filter StructurizrMultiViewTests
swift test --filter SameFormatRoundTripTests/structurizrC4
swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4
swift test --filter CrossFormatRoundTripTests/plantumlStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrPlantumlC4
swift test --filter StructurizrBoundaryRoundTripTests
```
Expected: all PASS. The new `multiViewNoFirstViewOnlyDiagnostic` test
passes because the diagnostic is deleted. The `06-multi-view.dsl`
fixture stays green. The `multiViewFirstViewRendered` test confirms
back-compat.

- [ ] **Step 7.6: Check `StructurizrMapper.swift` file size**

```bash
wc -l Sources/DiagramKitStructurizr/StructurizrMapper.swift
Scripts/check-file-sizes.sh
```

If `StructurizrMapper.swift` is under 500 lines, **skip Task 9** —
no split needed. The file started at 334 lines; Wave 3 adds roughly
+60 lines for marker plumbing + multi-view loop + recovery passes,
putting it at ~395. The split is the contingency for if Tasks 3, 5,
and 7 together push it over 500.

If over 500 lines, execute Task 9 next.

- [ ] **Step 7.7: Run discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
```
Expected: both exit 0.

- [ ] **Step 7.8: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrMapper.swift \
        Tests/DiagramKitTests/StructurizrMultiViewTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/06-multi-view.dsl

git commit -m "$(cat <<'EOF'
Loop Structurizr view import over every view; drop first-view-only diagnostic

Wave 3 of the coverage-expansion spec. `StructurizrMapper.map(...)`
now loops over every view in the workspace, running classification and
diagnostic emission per view. The first view remains the rendered
output (its shapes, boundaries, relationships, kind, and title
populate the returned C4Diagram) so every existing Structurizr
snapshot and round-trip test passes without baseline edits. Views
2..N contribute their own diagnostics for debugging malformed view
definitions.

The `.featureDropped(.diagramFamilyUnsupported, message: "only the
first view is imported")` placeholder at StructurizrMapper.swift:53-56
is no longer accurate and is deleted.

Fixture `structurizr-c4/06-multi-view.dsl` exercises a two-view
workspace; tests in `StructurizrMultiViewTests` assert the first view
is still rendered and the placeholder diagnostic is gone.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Allow-List Hygiene Pass

**Files:**
- (verify only; no code modifications expected)

This task is a verification checkpoint: run the full Structurizr
round-trip surface plus the diagnostic discipline gate to confirm the
shrunken allow-lists hold, no unpaired losses surface, and no raw
`DiagramDiagnostic(severity:message:)` constructors were introduced.

> **Why a separate task.** The two diagnostic deletions (Tasks 4 and 6)
> and the multi-view refactor (Task 7) together touch the mapper,
> exporter, and two registries. The verification fence catches any
> drift before COVERAGE.md / BASELINES.md / ARCHITECTURE.md updates
> land in Task 10.

- [ ] **Step 8.1: Run the full Structurizr surface**

```bash
swift test --filter StructurizrRecoveryMarkerTests
swift test --filter StructurizrMultiViewTests
swift test --filter StructurizrBoundaryRoundTripTests
swift test --filter StructurizrLexerTests
swift test --filter SameFormatRoundTripTests/structurizrC4
swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4
swift test --filter CrossFormatRoundTripTests/plantumlStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrPlantumlC4
swift test --filter RoundTripHarnessTests
swift test --filter LossPairingTests
swift test --filter DiagramDocumentDiffTests
```
Expected: all PASS.

- [ ] **Step 8.2: Run all discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
```
Expected: all exit 0.

- [ ] **Step 8.3: Verify the silent-drop markers in `StructurizrExporter.swift` are still pinned**

The exporter at `StructurizrExporter.swift:53-60` carries a
`SILENT-DROP(viewScopeSynthesized boundaries are re-derived from
parent relationships on the next import; round-trip-stable). Pinned
by: viewScopeBoundariesRoundTrip` block. This is **unchanged** by
Wave 3 — `viewScopeSynthesized` boundaries are a separate concern
from authored `group { ... }` boundaries. Verify the marker is still
present and the referenced test
(`StructurizrBoundaryRoundTripTests.viewScopeBoundariesRoundTrip`)
still passes (covered by Step 8.1).

```bash
grep -A 3 "SILENT-DROP" Sources/DiagramKitStructurizr/StructurizrExporter.swift
```
Expected: the marker block prints at line 57; "Pinned by:
viewScopeBoundariesRoundTrip" is present.

- [ ] **Step 8.4: No commit**

This task is verification only; no source changes. If anything
fails, fix the failure inline and re-run, but do not introduce a new
commit just for the verification.

---

## Task 9: Conditional — Split `StructurizrViewParser.swift`

> **Conditional execution rule.** Execute this task only if Step 7.6
> reported `StructurizrParser.swift` (or `StructurizrMapper.swift`,
> the more likely candidate) over 500 lines. Otherwise skip to Task 10.

**Files:**
- Create: `Sources/DiagramKitStructurizr/StructurizrViewParser.swift`
- Modify: `Sources/DiagramKitStructurizr/StructurizrParser.swift` (or
  `StructurizrMapper.swift` depending on which crossed the warn line)

- [ ] **Step 9.1: Confirm the file is over 500 lines**

```bash
wc -l Sources/DiagramKitStructurizr/StructurizrParser.swift \
      Sources/DiagramKitStructurizr/StructurizrMapper.swift
```

If neither is over 500 lines, abort this task and proceed to Task 10.

- [ ] **Step 9.2: Extract view parsing into `StructurizrViewParser.swift`**

If `StructurizrParser.swift` is the over-warn file (most likely), move
the `parseViews(_:)` method (`StructurizrParser.swift:278-376`) and any
private helpers it owns into a new file
`Sources/DiagramKitStructurizr/StructurizrViewParser.swift`:

```swift
import Foundation
import DiagramKitImport
import DiagramKitModel

/// View-parsing extension for `StructurizrParser`. Extracted from
/// `StructurizrParser.swift` to keep the host file under the 500-line
/// `Scripts/check-file-sizes.sh` warn line.
extension StructurizrParser {

    func parseViews(_ s: inout StructurizrParserState) throws -> [StructurizrView] {
        // ... body moved verbatim from StructurizrParser.swift:278-376 ...
    }
}
```

Change `private func parseViews(_:)` in `StructurizrParser.swift` to
`internal func parseViews(_:)` (or leave `private` and use a
file-private dispatch — the chosen scheme follows whichever the rest of
the slice uses; the rest of the slice uses `private` so prefer
`internal` in the extension because Swift's `private` does not extend
across files).

If `StructurizrMapper.swift` is the over-warn file, extract the per-view
loop body (the inner block of the view loop introduced in Task 7.4) into
a private helper `mapSingleView(_:scan:registry:groupAliasMap:)` and
move that helper into a new file
`Sources/DiagramKitStructurizr/StructurizrSingleViewMapper.swift` via
an extension.

- [ ] **Step 9.3: Run the full Structurizr surface to confirm GREEN**

```bash
swift test --filter StructurizrRecoveryMarkerTests
swift test --filter StructurizrMultiViewTests
swift test --filter StructurizrBoundaryRoundTripTests
swift test --filter StructurizrLexerTests
swift test --filter SameFormatRoundTripTests/structurizrC4
swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4
swift test --filter CrossFormatRoundTripTests/plantumlStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrPlantumlC4
```
Expected: all PASS. The extraction is pure code motion; semantics are
unchanged.

- [ ] **Step 9.4: Run discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
```
Expected: both exit 0. The host file is now back under the 500-line
warn line.

- [ ] **Step 9.5: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrViewParser.swift \
        Sources/DiagramKitStructurizr/StructurizrParser.swift

git commit -m "$(cat <<'EOF'
Split Structurizr view parsing into StructurizrViewParser.swift

Pure code motion: `StructurizrParser.parseViews(_:)` and its helpers
move to a `StructurizrParser` extension in a new file. Wave 3's
multi-view refactor pushed StructurizrParser.swift over the 500-line
warn line in `Scripts/check-file-sizes.sh`; this commit restores the
file-size invariant per the spec's File-Size Policy section.

No semantic changes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Wave 3 Closing — COVERAGE.md + BASELINES.md + ARCHITECTURE.md

**Files:**
- Modify: `COVERAGE.md`
- Modify: `BASELINES.md`
- Modify: `ARCHITECTURE.md`

This is the spec-level closing task. The Structurizr × c4 export cell
moves ⚠ → ✓; the Partial-support detail entry for Structurizr is
removed; the backlog summary item #3 is removed; the Structurizr scope
section is updated; BASELINES.md gains a Wave 3 entry; ARCHITECTURE.md
"Drift hazards" gains a new bullet for the `# diagramkit:` recovery
comment convention.

- [ ] **Step 10.1: Update `COVERAGE.md` — Export coverage table**

In `COVERAGE.md` at the **Export coverage** table (line 84 today),
change the `c4` row's Structurizr cell from `⚠` to `✓`:

```
| c4                |   ✓    | — | —  |     ✓      |    ✓    |
```

And update the **Totals** row at line 86 — the Structurizr Export
totals stays `1/28` (no new family rows; the existing cell just moves
glyph), so this row needs no change.

- [ ] **Step 10.2: Update `COVERAGE.md` — Partial-support detail**

In `COVERAGE.md` at the **Partial-support detail** section (lines
102-114 today), the Structurizr entry reads:

```
- **Structurizr × c4 (export)** — `StructurizrExporter` emits
  `.featureDropped(.styling, ...)` for element-scoped tags
  (`Sources/DiagramKitStructurizr/StructurizrExporter.swift:170`) and
  `.lossyTransform(.structure, ...)` for nested-boundary flattening and
  empty-group elision (lines 70–82). Alias rewriting at lines 226–246 is silent
  but does not change semantics.
```

**Delete this entire bullet.** The remaining paragraph at line 104
("The two `⚠` cells are real:") becomes:

```
The remaining `⚠` cell is real:

- **PlantUML × sequenceDiagram (export)** — `PlantUMLSequenceExporter` emits
  an informational diagnostic for dropped link/properties/detail features
  (`Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift:126`).
```

(Singularize "cells" → "cell" and "two" → "one".)

- [ ] **Step 10.3: Update `COVERAGE.md` — §3 Structurizr scope**

In `COVERAGE.md` at the **§3 Structurizr scope** section
(lines 171-183 today), the first bullet reads:

```
- Resolve the two `⚠` diagnostics on the export side by negotiating the
  upstream Structurizr parser's tag/boundary semantics, or by encoding the
  dropped data into comments (currently structurally lost).
- Add support for additional Structurizr view types beyond the first view
  (`StructurizrImporter.swift` currently parses workspace model + first view
  only; lines 24-39).
```

Replace with a note that the work landed:

```
Wave 3 of the coverage-expansion spec (closed 2026-05-19) landed
comment-encoded recovery for tags and nested boundaries plus a
multi-view import loop. The `⚠` cell moved to `✓`; the
`first-view-only` diagnostic is gone. No further work is currently
scoped for the Structurizr slice; new family rows require a concrete
user need (per the spec's Out of Scope).
```

- [ ] **Step 10.4: Update `COVERAGE.md` — Backlog summary**

In `COVERAGE.md` at the **Backlog summary** section (lines 185-199
today), delete the third bullet:

```
3. **Structurizr: tag/boundary lossy export + multi-view import.** Lifts the
   existing `⚠` to `✓` and extends single-view fidelity.
```

The remaining bullets keep their original numbers (PlantUML stays #1,
D2/DOT stays #2; only #3 is removed).

- [ ] **Step 10.5: Update `COVERAGE.md` — Round-trip discipline counts**

In `COVERAGE.md` at the **Round-trip discipline** section (lines
88-100), update the count line and the cross-format pairs:

```
`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/` currently holds **19
same-format fixtures** and **18 cross-format directed pairs** (9 unordered).
```

Wave 3 adds 3 same-format fixtures (`04-tags.dsl`, `05-nested-boundary.dsl`,
`06-multi-view.dsl` — count grows 16 → 19) and 2 cross-format directed
fixtures (`cross-mermaid-structurizr-c4/02-boundary.md`,
`cross-structurizr-mermaid-c4/02-boundary.dsl` — count grows 16 → 18).

Update the **Cross-format pairs** description if needed; the
`c4 × {mermaid↔structurizr}` pair already exists, so the description
shape stays the same — only the count moves.

- [ ] **Step 10.6: Update `COVERAGE.md` — Last audited date**

In `COVERAGE.md` at line 8, change `Last audited: 2026-05-19.` to the
current commit date. If the closing commit lands on a later date, use
that date instead; the rule is "match the date in the closing commit's
`git log -1 --format=%ad --date=short` output". Today is **2026-05-19**.

- [ ] **Step 10.7: Update `BASELINES.md`**

Append a Wave 3 entry to `BASELINES.md`. Read the existing Wave 3
entry for Mermaid exporter (line 70-87 today) as the template; the new
Structurizr Wave 3 entry follows the same shape:

```
- **2026-05-19 — Coverage expansion Wave 3 (Structurizr):**
  Structurizr × c4 export column moves from `⚠` to `✓`. Comment-encoded
  recovery via `# diagramkit:tag=<tag>` and
  `# diagramkit:boundary-parent=<id>` markers round-trips element-scoped
  tags and flattened nested-boundary parentage losslessly. Two
  `.lossyTransform(.boundaryFlatten, ...)` emissions at
  `Sources/DiagramKitStructurizr/StructurizrExporter.swift:69-83` and
  one `.featureDropped(.diagramFamilyUnsupported, ...)` emission at
  `StructurizrExporter.swift:170-174` are removed (recovery comments
  eliminate the loss). `StructurizrMapper.map(...)` now loops over every
  view in the workspace; first view stays the rendered output for
  back-compat. The `"only the first view is imported in this release"`
  diagnostic is removed. 3 new same-format fixtures (`04-tags.dsl`,
  `05-nested-boundary.dsl`, `06-multi-view.dsl`) + 2 new cross-format
  directed fixtures (`cross-{mermaid-structurizr,structurizr-mermaid}-c4/02-boundary.*`).
  Same-format round-trip fixture count grows from 16 to 19; cross-format
  directed fixture count grows from 16 to 18 (8 unordered → 9 unordered).
  `structurizrC4` cell allow-list shrinks from
  `{.idSanitization, .boundaryFlatten, .c4SlotDrop}` to
  `{.idSanitization, .c4SlotDrop}`. The four cross-cells
  `mermaidStructurizrC4`, `structurizrMermaidC4`, `plantumlStructurizrC4`,
  `structurizrPlantumlC4` each remove `.boundaryFlatten`. Spec
  [docs/superpowers/specs/2026-05-19-coverage-expansion-design.md](docs/superpowers/specs/2026-05-19-coverage-expansion-design.md)
  Wave 3 row is closed.
```

If Task 9 ran (conditional split), append a sentence noting which file
was split.

- [ ] **Step 10.8: Update `ARCHITECTURE.md` — Drift hazards**

In `ARCHITECTURE.md`, add a new bullet to the **Drift hazards** list
(the spec calls this out explicitly):

```
- **Do not strip `# diagramkit:` recovery comments from Structurizr
  source.** The Structurizr exporter encodes element-scoped tags and
  flattened nested-boundary parentage in `# diagramkit:tag=<tag>` and
  `# diagramkit:boundary-parent=<id>` line-comment markers placed
  adjacent to the element/group they augment. A pre-lexer scan in the
  importer harvests those markers before
  `StructurizrLexer.swift:84-93` strips them; stripping the markers
  upstream of the importer (e.g., a generic comment-cleanup step)
  silently re-introduces a structural round-trip loss that the harness
  cannot pair to a diagnostic. The shrunken `structurizrC4` round-trip
  allow-list acts as a regression bar.
```

- [ ] **Step 10.9: Run the bootstrap smoke check**

```bash
Scripts/bootstrap-smoke-check.sh
```
Expected: exit 0. If Docker/Podman is not running locally, the
`Scripts/linux-check.sh` step records as skipped — that is acceptable
per CLAUDE.md.

- [ ] **Step 10.10: Run the full Structurizr surface one more time**

```bash
swift test --filter StructurizrRecoveryMarkerTests
swift test --filter StructurizrMultiViewTests
swift test --filter StructurizrBoundaryRoundTripTests
swift test --filter StructurizrLexerTests
swift test --filter SameFormatRoundTripTests/structurizrC4
swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4
swift test --filter CrossFormatRoundTripTests/plantumlStructurizrC4
swift test --filter CrossFormatRoundTripTests/structurizrPlantumlC4
swift test --filter RoundTripHarnessTests
swift test --filter LossPairingTests
```
Expected: all PASS.

- [ ] **Step 10.11: Commit the closing change**

```bash
git add COVERAGE.md \
        BASELINES.md \
        ARCHITECTURE.md

git commit -m "$(cat <<'EOF'
Close coverage-expansion Wave 3 (Structurizr): lift ⚠ to ✓

Wave 3 of the coverage-expansion spec closes the Structurizr backlog
item. Documentation updates:

COVERAGE.md:
- Export coverage: Structurizr × c4 cell moves from ⚠ to ✓.
- Partial-support detail: Structurizr × c4 bullet removed
  (singularize "two cells" → "one cell").
- §3 Structurizr scope: replaced with a closure note pointing at the
  Wave 3 spec.
- Backlog summary: item #3 (Structurizr) removed; remaining items
  keep their numbers.
- Round-trip discipline: same-format fixture count 16 → 19;
  cross-format directed count 16 → 18; unordered cross-format pairs
  8 → 9.
- Last audited date moved to today.

BASELINES.md:
- New Wave 3 entry documenting the cell lift, the two-emission
  deletion, the multi-view loop, the per-cell + cross-cell allow-list
  shrink, and the 5 new round-trip fixtures.

ARCHITECTURE.md:
- New "Drift hazards" bullet documenting the `# diagramkit:` recovery
  comment convention so future contributors don't strip the markers.

The Wave 3 row of the coverage-expansion spec is closed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist (executor uses on completion)

- [ ] `Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift`
      exists with `StructurizrRecoveryMarker` struct +
      `scanStructurizrRecoveryMarkers(_:)` / `scanStructurizrPreLexer(_:)`
      functions.
- [ ] `StructurizrImporter.parse(_:)` calls
      `scanStructurizrPreLexer(_:)` before `lexer.tokenize(source)`
      and passes the result to `mapper.map(_:scan:)`.
- [ ] `StructurizrMapper.map(_:scan:)` (1) re-attaches tag markers to
      element `tags` via strict-less-than line pairing against
      `scan.elementDeclarations`, (2) re-attaches boundary-parent
      markers to authored boundaries via the same rule against
      `scan.groupDeclarations`, (3) loops over every view (not just
      the first), (4) does NOT emit the
      `"only the first view is imported"` placeholder.
- [ ] `StructurizrExporter.emitShape(_:...)` emits
      `# diagramkit:tag=<tag>` markers for non-empty
      `C4Shape.tags`, one per comma-separated component.
- [ ] `StructurizrC4Export.emit(_:)` emits
      `# diagramkit:boundary-parent=<id>` markers as the first line
      inside each `group "..." {` block whose `parentBoundary` is
      neither empty nor `"global"`.
- [ ] Empty `group "..." {}` blocks are now emitted (with just the
      marker line if applicable) — no longer elided.
- [ ] Three emission sites have been **removed** from
      `StructurizrExporter.swift`:
      - `.featureDropped(.diagramFamilyUnsupported, message: "...tags...")` at line 170-174.
      - `.lossyTransform(.boundaryFlatten, message: "...flattening...")` at line 70-73.
      - `.lossyTransform(.boundaryFlatten, message: "Empty group ...")` at line 78-81.
- [ ] One emission site has been **removed** from
      `StructurizrMapper.swift`:
      - `.featureDropped(.diagramFamilyUnsupported, message: "only the first view is imported in this release")` at line 53-56.
- [ ] `RoundTripCellRegistry.structurizrC4.allowedLosses` is exactly
      `[.idSanitization, .c4SlotDrop]` (down from
      `[.idSanitization, .boundaryFlatten, .c4SlotDrop]`).
- [ ] `RoundTripCrossRegistry.mermaidStructurizrC4`,
      `structurizrMermaidC4`, `plantumlStructurizrC4`, and
      `structurizrPlantumlC4` each no longer contain
      `.boundaryFlatten`.
- [ ] `RoundTripCellRegistry.mermaidC4` and `plantumlC4` are unchanged
      (their `.boundaryFlatten` pairs to non-Structurizr losses).
- [ ] `RoundTripCrossRegistry.mermaidPlantumlC4` and `plantumlMermaidC4`
      are unchanged (they never contained `.boundaryFlatten`).
- [ ] 5 new round-trip fixture files exist:
      - `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/04-tags.dsl`
      - `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/05-nested-boundary.dsl`
      - `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/structurizr-c4/06-multi-view.dsl`
      - `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-structurizr-c4/02-boundary.md`
      - `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-structurizr-mermaid-c4/02-boundary.dsl`
- [ ] 2 new test files exist:
      - `Tests/DiagramKitTests/StructurizrRecoveryMarkerTests.swift`
        (4 tests).
      - `Tests/DiagramKitTests/StructurizrMultiViewTests.swift`
        (2 tests).
- [ ] No raw `DiagramDiagnostic(severity:message:)` constructors
      introduced anywhere; `Scripts/check-diagnostic-discipline.sh`
      passes.
- [ ] No new `SILENT-DROP(...)` markers introduced;
      `Scripts/check-diagnostic-discipline.sh` confirms no orphaned
      silent drops.
- [ ] `Scripts/check-file-sizes.sh` passes. If Task 9 ran,
      `StructurizrParser.swift` (or `StructurizrMapper.swift`,
      whichever was split) is back under the 500-line warn line.
- [ ] `Scripts/check-sendable-annotations.sh` passes.
- [ ] `Scripts/strict-concurrency-check.sh` passes.
- [ ] `Scripts/bootstrap-smoke-check.sh` exits 0 (Linux step may
      record as skipped if Docker/Podman is unavailable).
- [ ] `COVERAGE.md` updated:
      - Export coverage row for `c4` Structurizr column is `✓`, not `⚠`.
      - Partial-support detail removes the Structurizr × c4 bullet
        and singularizes the heading.
      - §3 Structurizr scope updated with closure note.
      - Backlog summary item #3 deleted.
      - Round-trip discipline counts updated (same-format 16 → 19,
        cross-format directed 16 → 18, unordered 8 → 9).
      - Last audited date updated.
- [ ] `BASELINES.md` carries a Wave 3 closing entry that mentions:
      the cell lift, three emission deletions, multi-view loop, per-cell
      + four cross-cell allow-list shrinks, 5 new fixtures.
- [ ] `ARCHITECTURE.md` "Drift hazards" gains a bullet for the
      `# diagramkit:` recovery comment convention.
- [ ] All exact-suite filters pass:
      - `swift test --filter StructurizrRecoveryMarkerTests`
      - `swift test --filter StructurizrMultiViewTests`
      - `swift test --filter StructurizrBoundaryRoundTripTests`
      - `swift test --filter StructurizrLexerTests`
      - `swift test --filter SameFormatRoundTripTests/structurizrC4`
      - `swift test --filter CrossFormatRoundTripTests/mermaidStructurizrC4`
      - `swift test --filter CrossFormatRoundTripTests/structurizrMermaidC4`
      - `swift test --filter CrossFormatRoundTripTests/plantumlStructurizrC4`
      - `swift test --filter CrossFormatRoundTripTests/structurizrPlantumlC4`
      - `swift test --filter RoundTripHarnessTests`
      - `swift test --filter LossPairingTests`
- [ ] First-view-is-rendered back-compat: every pre-Wave-3
      Structurizr fixture (01-basic.dsl, 02-two-systems.dsl,
      03-group.dsl, cross-{mermaid,plantuml}-structurizr-c4/01-context.*,
      cross-structurizr-{mermaid,plantuml}-c4/01-context.dsl) still
      passes without baseline edits.

---

## References

- Spec:
  [docs/superpowers/specs/2026-05-19-coverage-expansion-design.md](../specs/2026-05-19-coverage-expansion-design.md)
- Sibling wave plans (when authored):
  - Wave 1 — PlantUML:
    [2026-05-19-coverage-expansion-wave-1-plantuml.md](2026-05-19-coverage-expansion-wave-1-plantuml.md)
  - Wave 2 — D2 + DOT:
    [2026-05-19-coverage-expansion-wave-2-d2-dot.md](2026-05-19-coverage-expansion-wave-2-d2-dot.md)
- Diagnostic discipline:
  [docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md)
- Round-trip harness:
  - `Sources/DiagramKitTestSupport/RoundTripHarness.swift`
  - `Sources/DiagramKitTestSupport/RoundTripCell.swift`
  - `Sources/DiagramKitTestSupport/RoundTripLoss.swift`
  - `Sources/DiagramKitTestSupport/RoundTripLoss+Category.swift`
  - `Sources/DiagramKitTestSupport/DiagramDocumentDiff+C4.swift`
- Structurizr slice (Wave 3 touches):
  - `Sources/DiagramKitStructurizr/StructurizrExporter.swift:69-83, 170-174, 226-246`
  - `Sources/DiagramKitStructurizr/StructurizrImporter.swift:24-39`
  - `Sources/DiagramKitStructurizr/StructurizrMapper.swift:42-59, 53-56, 196-229`
  - `Sources/DiagramKitStructurizr/StructurizrParser.swift:278-376`
  - `Sources/DiagramKitStructurizr/StructurizrLexer.swift:84-93`
  - `Sources/DiagramKitStructurizr/StructurizrParserState.swift:8-129`
  - `Sources/DiagramKitStructurizr/StructurizrAST.swift:42-75` (C4Shape.tags field)
  - `Sources/DiagramKitStructurizr/StructurizrModelRegistry.swift`
- Model types referenced:
  - `Sources/DiagramKitModel/src_c4_types.swift:314-373` — `C4Shape`
    (`tags: String?` at line 321).
  - `Sources/DiagramKitModel/src_c4_types.swift:375-384` —
    `C4BoundaryOrigin` (`authored` vs `viewScopeSynthesized`).
  - `Sources/DiagramKitModel/src_c4_types.swift:386-429` — `C4Boundary`.
- Round-trip registry call sites (Wave 3 modifies):
  - `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift:233`
    — `structurizrC4` cell allow-list.
  - `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift:19-24`
    — cross-format Structurizr-touching cells.
- Discipline gates:
  - `Scripts/check-diagnostic-discipline.sh`
  - `Scripts/check-file-sizes.sh`
  - `Scripts/check-sendable-annotations.sh`
  - `Scripts/strict-concurrency-check.sh`
  - `Scripts/bootstrap-smoke-check.sh`
  - `Scripts/linux-check.sh`

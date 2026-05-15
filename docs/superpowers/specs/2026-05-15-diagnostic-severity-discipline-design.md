# Diagnostic severity discipline

**Status:** Design approved, awaiting plan
**Date:** 2026-05-15
**Origin:** REVIEW.md Cross-cutting Observation #2 — "`.unsupported` vs throw vs `.warning` vs `.info` is inconsistent across slices. PlantUML throws for unrecognized family; Structurizr returns `.warning` diagnostics for identifier rewrites; Mermaid returns `.info` for the same operation; D2 silently drops second-occurrence properties. A single discipline doc + linter would help."

## Goal

Pin the contributor-facing rule for which of `throw` / `.unsupported` / `.warning` / `.info` is the correct emission, and lock that rule in with typed factories on `DiagramDiagnostic`, a typed category enum that doubles as the round-trip harness's pairing key, and a script gate that catches new raw constructions and silent-drop discipline violations.

The spec's load-bearing artifact is a single yes/no decision tree any contributor can run in their head. Everything else — the category enum, the factories, the script gate, the harness rewire — exists to make wrong-severity choices either fail to compile, fire a precondition immediately, or trip a CI gate before merge.

## Scope

### In

- A `DiagnosticCategory` public enum in `DiagramKitCommon`, each case statically tagged with its `severity`.
- A `category: DiagnosticCategory?` field on `DiagramDiagnostic`; populated by new factories, `nil` for legacy raw construction during migration.
- Three static factories — `DiagramDiagnostic.lossyTransform(_:message:location:)`, `.featureDropped(...)`, `.informational(...)` — each preconditioned on the category's severity matching the factory's intent.
- `@available(*, deprecated, ...)` on the raw `init(severity:message:location:)`; preserved as the public escape hatch for third-party importers.
- A `Scripts/check-diagnostic-discipline.sh` gate matching the style of `check-sendable-annotations.sh`, wired into `bootstrap-smoke-check.sh`.
- Round-trip harness rewire: `RoundTripLossKind → DiagnosticCategory` exhaustive map replaces today's `diagnosticsCover(loss:in:)` message-keyword matching. Two-phase migration: typed-first/keyword-fallback during sweep, fallback deleted after sweep completes.
- A standalone reference doc at `docs/diagnostic-severity-discipline.md` carrying the decision tree, category table, silent-drop policy, and throw boundary.
- A silent-drop policy: dropping input without any diagnostic is permissible only when the drop is provably reversible by the round-trip pair. Every such site carries a `// SILENT-DROP(reason): ...` marker with a `Pinned by: <Test>` line referencing the test that pins reversibility.
- Recategorization of three currently-mis-emitted sites: `labelNewlineEscape` `.info` → `.warning`; `c4SlotDrop` `.info` → `.warning` (or `.unsupported` per Test 1 in §1); `d2InlineCommentStripped` silent → `.warning`.

### Out

- Diagnostic *message* wording standardization. Only category matters for typed pairing; message remains free text.
- Surfacing `.info` diagnostics through `DiagramImportResult.diagnostics` in any new way — Session 10 already wired the surfacing infrastructure; this spec doesn't change which severities flow through `PreparedDiagram.diagnostics`.
- Source-location accuracy. Most current emissions pass `location: nil`; that's its own backlog.
- Migration sweep correctness. The existing 254-file test corpus continuing to pass commit-by-commit is the regression net; no new tests are added per-callsite for "we moved one expression."
- Visual / snapshot equality, layout-tier diagnostics outside `PositionedGraph.diagnostics`, or any change to `DiagramError` cases.

## §1 — The decision tree

```text
Did the operation fail outright (cannot produce any meaningful output)?
├── YES → THROW
│   ├── Source is structurally invalid for the format
│   │   → throw DiagramError.malformedSource(message:)
│   └── Family/feature exists in the format but is not implemented in this build
│       → throw DiagramError.notYetImplemented(_)
└── NO — operation produced output
    └── Was anything from the input dropped or transformed?
        ├── NO → emit nothing (clean operation)
        └── YES — pick by the two tests below
            │
            ├── Test 1: could a future export-side change restore the original?
            │   (the loss is a current limitation, not a format limitation)
            │   ├── NO  → .featureDropped (severity: .unsupported)
            │   │         "the target format has no syntax for this — no fix will help"
            │   └── YES → Test 2 below
            │
            └── Test 2: does re-parsing the output produce input-equivalent semantics?
                ├── YES → .informational    (severity: .info)
                │         "encoding-only transformation; round-trip is stable"
                └── NO  → .lossyTransform   (severity: .warning)
                          "structure was rewritten; round-trip is bounded but not stable"
```

**The two tests are the spec's contribution.** Today contributors guess. The tests give them a deterministic answer.

### Worked examples

| Operation | Test 1 (target supports?) | Test 2 (round-trip stable?) | Severity |
|---|---|---|---|
| `id with spaces` → `id_with_spaces` | yes (Mermaid quoting could carry it later) | no (sanitized name sticks) | `.warning` `idSanitization` |
| C4 tech slot dropped on shape with no tech slot | no (target shape has no slot at all) | n/a | `.unsupported` `slotUnsupported` (or `.warning c4SlotDrop` if loss can be restored later) |
| Newline in node label → space | yes (Mermaid has `<br/>`) | no (newline → space → newline ≠ original) | **`.warning`** — currently `.info`; spec recategorizes |
| `/' block comment '/` skipped | n/a (comments are cosmetic) | yes (re-emit preserves intent) | `.info` `commentPreserved` |
| Structurizr nested boundary flattened | yes (Structurizr `group` could nest someday) | no (depth lost) | `.warning` `boundaryFlatten` |
| PlantUML enterprise-boundary on Mermaid export | no (Mermaid has no enterprise-boundary type) | n/a | `.unsupported` `boundaryTypeUnsupported` |

### Migration findings (concrete recategorizations)

Walking the existing emission sites through the decision tree surfaces three recategorizations:

1. **`labelNewlineEscape`** — `MermaidExportHelpers.escapeBracketLabel`/`escapeEdgeLabel`/`quote` currently emit `.info` for newline-in-label. Fails Test 2 (a label with a newline does not round-trip stably to a label with a space). Spec promotes to `.warning`.
2. **`c4SlotDrop`** — `MermaidC4Export.swift:87` currently emits `.info` for tech-slot drops. `RoundTripLoss.c4SlotDrop` exists in the harness as a `.warning`-tier loss; the harness's `diagnosticsCover` filters to `.warning`/`.unsupported` and never matches the `.info` emission. Spec promotes to `.warning`. If the shape has no tech slot at all (Test 1 fails), promote further to `.unsupported`.
3. **`d2InlineCommentStripped`** — D2 `// note` trailing-value stripping (added in Session 2's `5ef689f`) currently produces no diagnostic. Fails Test 2 (the comment value is lost; re-parsing the output doesn't reconstruct it). Spec adds a `.warning`-tier `d2InlineCommentStripped` category and emits.

## §2 — `DiagnosticCategory` enum + severity mapping

```swift
// Sources/DiagramKitCommon/DiagnosticCategory.swift
public enum DiagnosticCategory: String, Sendable, Hashable, CaseIterable {
  // .warning — lossy structural transforms (paired with RoundTripLossKind cases)
  case idSanitization, shapeDowngrade, subgraphFlatten, boundaryFlatten
  case c4SlotDrop, titleDrop, configDrop, styleDrop, accessibilityDrop
  case anonymousSubgraphRename, d2DuplicateOverride
  case labelNewlineEscape          // NEW — promoted from .info per §1 migration finding
  case d2InlineCommentStripped     // NEW — `// note` trailing-value strip

  // .unsupported — feature not available in target format
  case diagramFamilyUnsupported, slotUnsupported, boundaryTypeUnsupported
  case c4ShapeUnsupported          // NEW — covers PlantUML→Mermaid stereotypes

  // .info — encoding-level transforms; round-trip stable
  case identifierEscape            // quoting/escaping that re-parses to identity
  case commentPreserved            // /' block comment '/ skipped non-destructively

  public var severity: DiagramDiagnostic.Severity {
    switch self {
    case .idSanitization, .shapeDowngrade, .subgraphFlatten, .boundaryFlatten,
         .c4SlotDrop, .titleDrop, .configDrop, .styleDrop, .accessibilityDrop,
         .anonymousSubgraphRename, .d2DuplicateOverride,
         .labelNewlineEscape, .d2InlineCommentStripped:
      return .warning
    case .diagramFamilyUnsupported, .slotUnsupported,
         .boundaryTypeUnsupported, .c4ShapeUnsupported:
      return .unsupported
    case .identifierEscape, .commentPreserved:
      return .info
    }
  }
}
```

`DiagramDiagnostic` gains an optional `category` field. Optional because the existing raw `init(severity:message:)` (deprecated by this spec) constructs without one — needed for the migration window and for third-party diagnostic emitters who can't know about our category enum.

```swift
public struct DiagramDiagnostic: Sendable, Hashable, CustomStringConvertible {
  public let severity: Severity
  public let category: DiagnosticCategory?   // NEW, default nil
  public let message: String
  public let location: SourceLocation?
}
```

**`RoundTripLossKind` becomes a strict subset of `DiagnosticCategory`** — a static `expectedCategory` extension lives next to the loss enum (§6). The harness's pairing flips from message-keyword matching to `diagnostic.category == loss.kind.expectedCategory`.

**Factory parameter type — single enum vs three nested.** The spec picks **single enum + runtime precondition** in each factory. Reasoning: factory body is two lines (`precondition` + `init`); unit tests pin `precondition` for every case from `allCases`; compile-time guarantee not worth the duplicated enum surface.

## §3 — Static factory API + raw-init deprecation

```swift
// Sources/DiagramKitCommon/DiagramDiagnostic+Factories.swift

extension DiagramDiagnostic {
  public static func lossyTransform(
    _ category: DiagnosticCategory,
    message: String,
    location: SourceLocation? = nil
  ) -> DiagramDiagnostic {
    precondition(
      category.severity == .warning,
      "lossyTransform requires a .warning category; \(category) is \(category.severity)"
    )
    return DiagramDiagnostic(
      severity: .warning, category: category, message: message, location: location
    )
  }

  public static func featureDropped(
    _ category: DiagnosticCategory,
    message: String,
    location: SourceLocation? = nil
  ) -> DiagramDiagnostic {
    precondition(
      category.severity == .unsupported,
      "featureDropped requires an .unsupported category; \(category) is \(category.severity)"
    )
    return DiagramDiagnostic(
      severity: .unsupported, category: category, message: message, location: location
    )
  }

  public static func informational(
    _ category: DiagnosticCategory,
    message: String,
    location: SourceLocation? = nil
  ) -> DiagramDiagnostic {
    precondition(
      category.severity == .info,
      "informational requires an .info category; \(category) is \(category.severity)"
    )
    return DiagramDiagnostic(
      severity: .info, category: category, message: message, location: location
    )
  }
}

extension DiagramDiagnostic {
  @available(*, deprecated,
    message: "Use .lossyTransform/.featureDropped/.informational with a DiagnosticCategory. See docs/diagnostic-severity-discipline.md.")
  public init(severity: Severity, message: String, location: SourceLocation? = nil) {
    self.init(severity: severity, category: nil, message: message, location: location)
  }

  // Internal designated init — populates category. Factories route here.
  internal init(
    severity: Severity,
    category: DiagnosticCategory?,
    message: String,
    location: SourceLocation? = nil
  ) {
    self.severity = severity
    self.category = category
    self.message = message
    self.location = location
  }
}
```

### Callsite before / after

```swift
// Before
diagnostics.append(DiagramDiagnostic(
  severity: .warning,
  message: "Identifier '\(id)' sanitized to '\(sanitized)'"))

// After
diagnostics.append(.lossyTransform(
  .idSanitization,
  message: "Identifier '\(id)' sanitized to '\(sanitized)'"))
```

Same `.append(...)` shape; same `[DiagramDiagnostic]` bag; one expression swapped. No callsite restructure.

### Why the raw init stays public-but-deprecated

1. Third-party importers conforming to `DiagramSourceImporter` may construct diagnostics from contexts the umbrella enum can't anticipate (custom format → custom loss). Deleting forces them onto our enum or onto reflection hacks.
2. Test-utility paths in the harness echo synthetic diagnostics with no real category. Escape hatch is cheap to keep.

The deprecation annotation surfaces the migration intent to downstream consumers; the script gate (§5) treats *new* in-tree uses outside `Sources/DiagramKitCommon/` as failures.

## §4 — Silent-drop policy

The spec pins exactly one condition under which dropping input without any diagnostic is correct: **the drop is provably reversible by the round-trip pair.** Anything else emits.

### Marker format

```swift
// SILENT-DROP(reason): viewScopeSynthesized boundaries are re-derived from
// parent relationships on the next import; round-trip-stable.
// Pinned by: StructurizrBoundaryRoundTripTests.viewScopeBoundariesRoundTrip
//
// Allowed under §4 of docs/diagnostic-severity-discipline.md.
continue  // (or: skip without appending to the diagnostic bag)
```

- `// SILENT-DROP(<one-line reason>):` is the load-bearing marker grep finds.
- The `Pinned by: <TestName>` line is required and must reference a test the script gate can locate by name.
- Free text in the reason; structured `Pinned by:` line rots loudly when the test moves or deletes.

### Gate scope (honest)

- **Can:** verify every `// SILENT-DROP(` marker carries a `Pinned by:` line within 3 lines and the test exists.
- **Cannot:** detect *undeclared* silent drops. Catching those is the round-trip harness's job — if a drop isn't round-trip-stable, the harness fails because the delta isn't covered by an allowed `RoundTripLoss`.

### Known silent-drop sites — audit checklist

| Site | Current state | Spec disposition |
|---|---|---|
| `StructurizrExporter.swift:62-63` — `.viewScopeSynthesized` boundary drop | comment-only justification | Keep silent; add formal marker with `Pinned by:` line |
| `StructurizrLexer.swift:237` — unknown-character skip "for lenience" | no rationale | **Audit**: emit `.lossyTransform(.identifierEscape)` or similar if any char class carries semantic weight; otherwise add marker |
| Unrecognized parser blocks/statements (scattered, ~3 sites) | implementation-defined | **Audit**: each site picks `.featureDropped(.diagramFamilyUnsupported)` for whole-block skips, or remains silent with marker if the round-trip provably restores |

The migration sweep walks every existing silent-drop or zero-diagnostic skip site, categorizes it, and either adds a marker or emits a diagnostic. Out-of-policy silence is a review-time failure; the gate is belt + suspenders.

## §5 — `Scripts/check-diagnostic-discipline.sh`

```bash
#!/usr/bin/env bash
# Scripts/check-diagnostic-discipline.sh
#
# Enforces docs/diagnostic-severity-discipline.md. Style matches
# Scripts/check-sendable-annotations.sh.

set -euo pipefail
cd "$(dirname "$0")/.."
allowlist=".diagnostic-discipline-allowlist.txt"
violations=0

# Rule 1 — raw DiagramDiagnostic(severity:) outside Common is forbidden.
while IFS= read -r hit; do
  loc=$(echo "$hit" | cut -d: -f1-2)
  grep -qxF "$loc" "$allowlist" 2>/dev/null || {
    echo "  $loc: raw DiagramDiagnostic(severity:) — use .lossyTransform/.featureDropped/.informational" >&2
    violations=$((violations + 1))
  }
done < <(grep -RIn 'DiagramDiagnostic(severity:' Sources --include='*.swift' \
           --exclude-dir=DiagramKitCommon || true)

# Rule 2 — every // SILENT-DROP( marker must be followed within 3 lines
# by a `Pinned by: <TestName>` line, and that test must exist under Tests/.
while IFS= read -r hit; do
  file=$(echo "$hit" | cut -d: -f1)
  line=$(echo "$hit" | cut -d: -f2)
  ctx=$(sed -n "${line},$((line + 3))p" "$file")
  test_ref=$(echo "$ctx" | grep -oE 'Pinned by: \S+' | head -1 | awk '{print $3}')
  if [ -z "$test_ref" ]; then
    echo "  $file:$line: SILENT-DROP marker missing 'Pinned by: <Test>' line within 3 lines" >&2
    violations=$((violations + 1))
  elif ! grep -RIlq "func ${test_ref##*.}\|@Test.*${test_ref}" Tests/ 2>/dev/null; then
    echo "  $file:$line: SILENT-DROP references missing test '$test_ref'" >&2
    violations=$((violations + 1))
  fi
done < <(grep -RIn '// SILENT-DROP(' Sources --include='*.swift' || true)

# Rule 3 — Exporters MUST NOT throw DiagramError.malformedSource; emit diagnostic.
while IFS= read -r hit; do
  echo "  $hit: exporter throws malformedSource — emit a .featureDropped diagnostic instead" >&2
  violations=$((violations + 1))
done < <(grep -RIn 'throw DiagramError.malformedSource' \
           Sources --include='*Exporter*.swift' || true)

if [ "$violations" -gt 0 ]; then
  echo "diagnostic-discipline: $violations violation(s)" >&2
  exit 1
fi
echo "diagnostic-discipline: ✓ clean"
```

**Wiring** — one new line in `Scripts/bootstrap-smoke-check.sh`, placed after `check-sendable-annotations.sh`:

```bash
run_gate "diagnostic-discipline" Scripts/check-diagnostic-discipline.sh
```

**Allowlist** — `.diagnostic-discipline-allowlist.txt`. Same `path:line` format as the Sendable allowlist. Migration commits add entries only for legitimate escape-hatch uses (e.g., test-utility echoing); production code targets zero entries after the migration sweep.

**Explicit non-goals for the gate:**
- Wrong category for situation — semantic, can't grep. Caught by code review + harness.
- Undeclared silent drops — grep can't see "input was dropped." Caught by harness deltas.
- Diagnostic message wording — out of scope (only category matters for typed pairing now).

## §6 — Round-trip harness integration

Today: `RoundTripHarness.diagnosticsCover(loss:in:)` filters to `.warning`/`.unsupported` then matches via keyword lists like `["sanitiz", "alias", "renamed", originalID]`. Any slice rewording its diagnostic message silently breaks the pairing.

### Typed-category replacement

```swift
// Sources/DiagramKitTestSupport/RoundTripLoss+Category.swift
extension RoundTripLossKind {
  /// The DiagnosticCategory an exporter MUST emit when producing this loss.
  /// Exhaustive switch — adding a new loss kind forces a category choice.
  internal var expectedCategory: DiagnosticCategory {
    switch self {
    case .idSanitization:          return .idSanitization
    case .shapeDowngrade:          return .shapeDowngrade
    case .subgraphFlatten:         return .subgraphFlatten
    case .boundaryFlatten:         return .boundaryFlatten
    case .c4SlotDrop:              return .c4SlotDrop
    case .titleDrop:               return .titleDrop
    case .configDrop:              return .configDrop
    case .styleDrop:               return .styleDrop
    case .accessibilityDrop:       return .accessibilityDrop
    case .anonymousSubgraphRename: return .anonymousSubgraphRename
    case .d2DuplicateOverride:     return .d2DuplicateOverride
    }
  }
}
```

```swift
private func diagnosticsCover(loss: RoundTripLoss, in diagnostics: [DiagramDiagnostic]) -> Bool {
  let expected = loss.kind.expectedCategory
  return diagnostics.contains { diag in
    if let cat = diag.category { return cat == expected }
    // Migration fallback — legacy keyword matcher for un-categorized diagnostics.
    return _legacyKeywordCover(loss: loss, diagnostic: diag)
  }
}
```

### Two-phase migration discipline

1. **Additive phase** (this spec's implementation plan): typed factory rolls out, harness gains typed-first/keyword-fallback pairing, migration sweep walks every emission site slice-by-slice. Harness stays green throughout because both paths coexist.
2. **Strict phase** (one commit, after sweep completes): delete `_legacyKeywordCover` entirely. From that point, an un-categorized diagnostic can no longer pair to a loss.

### Known migration probe

§1 promoted `c4SlotDrop` from `.info` to `.warning`. If any current harness cell allows `.c4SlotDrop` AND exercises a tech-slot drop, that pairing is passing today only because the keyword matcher happens to include `"slot"` or `"tech"`. The implementation plan's first probe instruments the harness to fail when a loss is matched by the legacy fallback alone, runs the corpus, and surfaces any un-paired latent sites. Each becomes a discrete recategorization commit.

### Why the map is on the harness side

The category enum is a public API in `DiagramKitCommon`. Putting `expectedCategory` on `RoundTripLossKind` in `DiagramKitTestSupport` lets the test-support module own the contract direction. If a third-party loss enum ever ships, it can adopt the same shape without modifying common.

## §7 — Doc location + migration sweep scoping

### Doc location

`docs/diagnostic-severity-discipline.md` — new standalone file. `CONTRIBUTING.md` gains a one-line link from its "Adding a new format slice" section; `ARCHITECTURE.md`'s "Diagnostics" paragraph (added in Session 10) gains a link too. Standalone because the content is technical reference; `CONTRIBUTING.md` is workflow.

**Doc structure** (~3–5 kb):

1. The decision tree (§1 of this spec, verbatim)
2. Severity table — every `DiagnosticCategory` case → severity, one-line use case
3. Silent-drop policy — marker format + `Pinned by:` discipline
4. Throw boundary — `DiagramError.malformedSource` vs `notYetImplemented` vs emit
5. Cross-references — script gate path, harness pairing rule

### Migration sweep — commit order

| # | Commit shape | Touch surface |
|---|---|---|
| 1 | `DiagnosticCategory` enum + `DiagramDiagnostic.category` field + factories | `DiagramKitCommon` only; additive, zero callsite changes |
| 2 | Harness `expectedCategory` map + typed-first/keyword-fallback `diagnosticsCover` | `DiagramKitTestSupport`; harness stays green |
| 3 | Mermaid emission migration (export + import paths) | ~10 sites across `DiagramKitMermaid` + `MermaidImporter` |
| 4 | Structurizr emission migration | ~12 sites across parser/mapper/exporter |
| 5 | D2 + Graphviz/DOT emission migration | ~8 sites |
| 6 | PlantUML emission migration | ~10 sites across the 6 family slices |
| 7 | Model-tier emission migration (layout, parsers, ishikawa, etc.) | ~10 sites in `DiagramKitModel` |
| 8 | Recategorizations — `labelNewlineEscape` `.info`→`.warning`, `c4SlotDrop` `.info`→`.warning`/`.unsupported`, `d2InlineCommentStripped` silent→`.warning` | Targeted; may require round-trip cell `allowedLosses` updates |
| 9 | Silent-drop audit + marker pass | `StructurizrExporter` viewScope drop, `StructurizrLexer` unknown-char (decision + emit-or-marker), parser block skips |
| 10 | `Scripts/check-diagnostic-discipline.sh` + bootstrap wiring + empty allowlist | New script, smoke-check updated |
| 11 | Delete `_legacyKeywordCover` fallback (Phase 2 strict) | `RoundTripHarness`; landing gate is "every emission site has a category" |
| 12 | `CLAUDE.md` + `ARCHITECTURE.md` + `CONTRIBUTING.md` doc sync | Counts + links |

Commits 1–2 ship before any callsite migration so callsites can adopt incrementally. Commits 3–7 are independent and could parallelize, but project standing default is "commit-by-commit on main," so sequential. Commit 11 lands only once 3–9 finish.

## §8 — Testing strategy

Six test surfaces, in commit order:

### T1. `DiagnosticCategory` severity table

`Tests/DiagramKitTests/DiagnosticCategoryTests.swift`. One @Test enumerates `DiagnosticCategory.allCases` and asserts each case's `severity` against an explicit literal map — duplicates the switch in the enum body, but on purpose: any future case must be updated in both places, and any silent enum-default would surface immediately. ~20 single-case assertions.

### T2. Factory happy-path coverage

```swift
@Test func everyWarningCategoryConstructsViaLossyTransform() {
  for cat in DiagnosticCategory.allCases where cat.severity == .warning {
    let d = DiagramDiagnostic.lossyTransform(cat, message: "msg")
    #expect(d.severity == .warning)
    #expect(d.category == cat)
  }
}
```

Plus the two parallel sweeps for `featureDropped` / `informational`. The negative path (wrong-category-for-factory) hits a `precondition` — not in-process testable; the precondition message is the production safety net. Three @Tests.

### T3. `RoundTripLossKind → DiagnosticCategory` map

`Tests/DiagramKitTests/RoundTripLossExpectedCategoryTests.swift` pins every `RoundTripLossKind.allCases` entry's `expectedCategory`. Exhaustive-switch in the production code is the compile-time gate; this test is the regression net if someone re-points a case. 11 single-case @expects.

### T4. Harness typed-first/keyword-fallback ordering

Two @Tests in `RoundTripHarnessDiagnosticPairingTests.swift`:

- Construct a `RoundTripLoss.idSanitization(...)` delta + an export diagnostic with `category == .idSanitization` but a message the keyword matcher would NOT match (e.g., `"x"`); assert the harness reports paired.
- Same delta + a legacy diagnostic with `category == nil` and a keyword-matching message; assert paired via fallback.

After Commit 11 deletes the fallback, drop the second test.

### T5. Migration regression coverage

For each emission site that recategorizes (Commit 8 — `labelNewlineEscape`, `c4SlotDrop`, `d2InlineCommentStripped`), the slice's existing exporter test gains an assertion on the new severity + category. ~3 targeted tests.

### T6. Script gate self-test

`Scripts/check-diagnostic-discipline-tests/` directory:

```
Scripts/check-diagnostic-discipline-tests/
├── run.sh                    # driver, exits non-zero on any fixture surprise
├── fixtures/
│   ├── bad-raw-init/         # raw DiagramDiagnostic outside Common
│   ├── bad-missing-pinned/   # SILENT-DROP without Pinned-by
│   ├── bad-stale-pinned/     # SILENT-DROP referencing a deleted test
│   ├── bad-exporter-throws/  # exporter throws malformedSource
│   └── good-clean/           # clean tree
```

Driver `run.sh` runs the production script against each fixture and asserts the right exit code and the right error lines on stderr. Wires into `bootstrap-smoke-check.sh` as a sibling gate after the production gate runs against the real tree. ~5 fixture cases.

### Total new test surface

~6 new Swift test files, ~25 @Tests, plus the bash self-test harness.

## Risks and mitigations

1. **The keyword matcher silently passes some pairings today only by coincidence.** Specifically, `c4SlotDrop` is `.info` but `RoundTripLoss.c4SlotDrop` is `.warning`-tier. If any current cell exercises this, it's passing because the keyword matcher includes `"slot"` or `"tech"`. Mitigation: implementation plan's first probe (§6 "Known migration probe") makes this visible before any code moves.
2. **Third-party importers break when the raw init goes away.** Spec mitigates by keeping the raw init public-but-deprecated indefinitely. The script gate enforces in-tree discipline only.
3. **A misclassified recategorization (e.g., `labelNewlineEscape` should have stayed `.info`) causes harness churn in round-trip cells.** Each recategorization commit lands with its corresponding cell-level `allowedLosses` adjustment, so churn is bounded to one commit per recategorization.
4. **`StructurizrLexer.swift:237` audit may discover the unknown-character skip is correctness-critical** (e.g., quietly drops Unicode bidi marks that change meaning). Mitigation: the audit commit (Commit 9) is gated on the harness running over the existing fixture corpus before merge; if the audit changes behavior, the round-trip suite catches it.
5. **Migration commit count is larger than typical.** 12 commits is closer to Session 10's parser-diagnostics-surfacing scope than to a single-session fix. Operator should expect a multi-day land window. The two-phase structure (commits 1–2 ship the additive shape; the rest are independent slice migrations) keeps each commit small and reviewable.

## Acceptance

This spec is complete when:

- A reviewer reading `docs/diagnostic-severity-discipline.md` can answer "what severity should I emit?" for any new emission site in under 30 seconds.
- `grep -RIn 'DiagramDiagnostic(severity:' Sources --exclude-dir=DiagramKitCommon` returns zero results.
- `RoundTripHarness.diagnosticsCover` no longer contains `_legacyKeywordCover` references.
- `Scripts/check-diagnostic-discipline.sh` exits 0 on a clean tree and surfaces every violation kind on each fixture in the self-test corpus.
- The existing 254-file test corpus + the new ~25 @Tests stay green commit-by-commit through all 12 migration commits.

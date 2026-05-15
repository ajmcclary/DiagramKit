# Diagnostic Severity Discipline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land a typed `DiagnosticCategory` enum + static factories on `DiagramDiagnostic` so contributors emit consistent severities via clearly-named helpers, wire the category into the round-trip harness's pairing check to replace fragile keyword matching, and ship a script gate + reference doc that locks the discipline in.

**Architecture:** Two-phase migration. Phase 1 is additive — new types ship without removing any existing path; the harness's `diagnosticsCover` runs typed-first, falls back to the legacy keyword matcher. Slice migrations then walk every emission site to a factory call. Phase 2 deletes the legacy fallback and stamps the raw `init(severity:message:)` with `@available(*, deprecated, ...)`.

**Tech Stack:** Swift 6 + swift-testing (`@Test`, `#expect`). `DiagramKitCommon` (Linux-portable) holds the new types. `DiagramKitTestSupport` holds the harness changes. Bash for the script gate (matches `Scripts/check-sendable-annotations.sh` style).

**Spec:** `docs/superpowers/specs/2026-05-15-diagnostic-severity-discipline-design.md`.

**Standing defaults for this repo (apply to every task):**

- Work directly on `main` — no worktrees, no branches.
- One commit per task.
- Never run a bare `swift test` — always `--filter <Pattern>` (corpus crash is pre-existing per memory).
- After 2 confirmatory `swift test --filter` runs of the same thing, commit; do not re-confirm a third time.

---

## File Structure

### Files created

| Path | Responsibility |
|---|---|
| `Sources/DiagramKitCommon/DiagnosticCategory.swift` | The category enum + severity mapping |
| `Sources/DiagramKitCommon/DiagramDiagnostic+Factories.swift` | Three static factories + internal designated init |
| `Sources/DiagramKitTestSupport/RoundTripLoss+Category.swift` | `RoundTripLossKind.expectedCategory` extension |
| `Tests/DiagramKitTests/DiagnosticCategoryTests.swift` | T1 — category severity table |
| `Tests/DiagramKitTests/DiagramDiagnosticFactoryTests.swift` | T2 — factory happy paths |
| `Tests/DiagramKitTests/RoundTripLossExpectedCategoryTests.swift` | T3 — loss→category map |
| `Tests/DiagramKitTests/RoundTripHarnessDiagnosticPairingTests.swift` | T4 — typed-first / fallback ordering |
| `Scripts/check-diagnostic-discipline.sh` | The lint gate |
| `Scripts/check-diagnostic-discipline-tests/run.sh` | Gate self-test driver |
| `Scripts/check-diagnostic-discipline-tests/fixtures/...` | Self-test fixtures |
| `.diagnostic-discipline-allowlist.txt` | Empty allowlist after migration |
| `docs/diagnostic-severity-discipline.md` | Contributor reference doc |

### Files modified

| Path | What changes |
|---|---|
| `Sources/DiagramKitCommon/DiagramDiagnostic.swift` | Adds `category: DiagnosticCategory?` field; init gets a new designated form via factories file |
| `Sources/DiagramKitTestSupport/RoundTripHarness.swift` | `diagnosticsCover` rewritten typed-first, legacy fallback retained, then deleted in Phase 2 |
| `Sources/DiagramKitMermaid/Exporter/MermaidExport/*.swift` | ~10 emission sites switch to factories |
| `Sources/DiagramKitStructurizr/**/*.swift` | ~12 emission sites switch to factories |
| `Sources/DiagramKitD2/**/*.swift` + `Sources/DiagramKitGraphviz/**/*.swift` | ~8 sites |
| `Sources/DiagramKitPlantUML/**/*.swift` | ~10 sites |
| `Sources/DiagramKitModel/**/*.swift` | ~10 sites (layout, parser, ishikawa, kanban, etc.) |
| `Scripts/bootstrap-smoke-check.sh` | New `run_gate` line for diagnostic-discipline |
| `CLAUDE.md` | Test source count sync; cross-reference in "Pipeline" section |
| `ARCHITECTURE.md` | Diagnostics paragraph gains a link to the new doc |
| `CONTRIBUTING.md` | "Adding a new format slice" gains a link |

---

## Task 1: Add `DiagnosticCategory` enum (additive)

**Spec ref:** §2

**Files:**
- Create: `Sources/DiagramKitCommon/DiagnosticCategory.swift`
- Create: `Tests/DiagramKitTests/DiagnosticCategoryTests.swift`

**Rationale:** Land the type first with full test coverage of the severity mapping. Nothing else depends on the field yet.

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/DiagnosticCategoryTests.swift`:

```swift
import Testing
@testable import DiagramKitCommon

@Suite("DiagnosticCategory severity mapping")
struct DiagnosticCategoryTests {

    @Test("idSanitization is .warning")
    func idSanitization() { #expect(DiagnosticCategory.idSanitization.severity == .warning) }

    @Test("shapeDowngrade is .warning")
    func shapeDowngrade() { #expect(DiagnosticCategory.shapeDowngrade.severity == .warning) }

    @Test("subgraphFlatten is .warning")
    func subgraphFlatten() { #expect(DiagnosticCategory.subgraphFlatten.severity == .warning) }

    @Test("boundaryFlatten is .warning")
    func boundaryFlatten() { #expect(DiagnosticCategory.boundaryFlatten.severity == .warning) }

    @Test("c4SlotDrop is .warning")
    func c4SlotDrop() { #expect(DiagnosticCategory.c4SlotDrop.severity == .warning) }

    @Test("titleDrop is .warning")
    func titleDrop() { #expect(DiagnosticCategory.titleDrop.severity == .warning) }

    @Test("configDrop is .warning")
    func configDrop() { #expect(DiagnosticCategory.configDrop.severity == .warning) }

    @Test("styleDrop is .warning")
    func styleDrop() { #expect(DiagnosticCategory.styleDrop.severity == .warning) }

    @Test("accessibilityDrop is .warning")
    func accessibilityDrop() { #expect(DiagnosticCategory.accessibilityDrop.severity == .warning) }

    @Test("anonymousSubgraphRename is .warning")
    func anonymousSubgraphRename() { #expect(DiagnosticCategory.anonymousSubgraphRename.severity == .warning) }

    @Test("d2DuplicateOverride is .warning")
    func d2DuplicateOverride() { #expect(DiagnosticCategory.d2DuplicateOverride.severity == .warning) }

    @Test("labelNewlineEscape is .warning")
    func labelNewlineEscape() { #expect(DiagnosticCategory.labelNewlineEscape.severity == .warning) }

    @Test("d2InlineCommentStripped is .warning")
    func d2InlineCommentStripped() { #expect(DiagnosticCategory.d2InlineCommentStripped.severity == .warning) }

    @Test("diagramFamilyUnsupported is .unsupported")
    func diagramFamilyUnsupported() { #expect(DiagnosticCategory.diagramFamilyUnsupported.severity == .unsupported) }

    @Test("slotUnsupported is .unsupported")
    func slotUnsupported() { #expect(DiagnosticCategory.slotUnsupported.severity == .unsupported) }

    @Test("boundaryTypeUnsupported is .unsupported")
    func boundaryTypeUnsupported() { #expect(DiagnosticCategory.boundaryTypeUnsupported.severity == .unsupported) }

    @Test("c4ShapeUnsupported is .unsupported")
    func c4ShapeUnsupported() { #expect(DiagnosticCategory.c4ShapeUnsupported.severity == .unsupported) }

    @Test("identifierEscape is .info")
    func identifierEscape() { #expect(DiagnosticCategory.identifierEscape.severity == .info) }

    @Test("commentPreserved is .info")
    func commentPreserved() { #expect(DiagnosticCategory.commentPreserved.severity == .info) }

    @Test("allCases coverage — no case is missed by this suite")
    func allCasesCovered() {
        // This catches the case where someone adds a new DiagnosticCategory case
        // but forgets to write a @Test pinning its severity.
        let expectedCount = 19
        #expect(DiagnosticCategory.allCases.count == expectedCount,
                "Add a @Test for any new category and bump expectedCount.")
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
swift test --filter DiagnosticCategoryTests
```

Expected: build failure with `cannot find 'DiagnosticCategory' in scope`.

- [ ] **Step 3: Create the enum**

Create `Sources/DiagramKitCommon/DiagnosticCategory.swift`:

```swift
import Foundation

/// Typed category that pins which severity an emission site MUST use.
///
/// Use with `DiagramDiagnostic.lossyTransform(_:message:)`,
/// `.featureDropped(_:message:)`, or `.informational(_:message:)`. See
/// `docs/diagnostic-severity-discipline.md` for the decision tree.
///
/// Each case statically maps to one `DiagramDiagnostic.Severity`. Wrong
/// helper for category is caught by `precondition` in the factory.
public enum DiagnosticCategory: String, Sendable, Hashable, CaseIterable {
    // MARK: - .warning — lossy structural transforms
    case idSanitization
    case shapeDowngrade
    case subgraphFlatten
    case boundaryFlatten
    case c4SlotDrop
    case titleDrop
    case configDrop
    case styleDrop
    case accessibilityDrop
    case anonymousSubgraphRename
    case d2DuplicateOverride
    case labelNewlineEscape           // promoted from .info per spec §1
    case d2InlineCommentStripped      // was silent per spec §1

    // MARK: - .unsupported — feature not available in target format
    case diagramFamilyUnsupported
    case slotUnsupported
    case boundaryTypeUnsupported
    case c4ShapeUnsupported

    // MARK: - .info — encoding-level transforms; round-trip stable
    case identifierEscape
    case commentPreserved

    /// The severity this category implies. Factories `precondition` on this.
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

- [ ] **Step 4: Run the test, verify it passes**

```bash
swift test --filter DiagnosticCategoryTests
```

Expected: 20 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitCommon/DiagnosticCategory.swift \
        Tests/DiagramKitTests/DiagnosticCategoryTests.swift
git commit -m "$(cat <<'EOF'
feat(common): DiagnosticCategory enum + severity mapping

Typed category that pins which DiagramDiagnostic.Severity an emission
site uses. 19 cases across .warning (11 paired with RoundTripLossKind +
2 new — labelNewlineEscape, d2InlineCommentStripped), .unsupported (4),
.info (2). Severity mapping is a switch; allCases count test catches
new cases that forget their @Test pin.

Additive — no callsite changes; spec §2.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `DiagramDiagnostic.category` field + static factories

**Spec ref:** §2, §3

**Files:**
- Modify: `Sources/DiagramKitCommon/DiagramDiagnostic.swift` (add field, route to designated init)
- Create: `Sources/DiagramKitCommon/DiagramDiagnostic+Factories.swift`
- Create: `Tests/DiagramKitTests/DiagramDiagnosticFactoryTests.swift`

**Rationale:** The category field defaults to `nil` so every existing `init(severity:message:)` call still compiles unchanged. Factories are the new path; raw init is NOT yet deprecated (deprecation lands in Task 14 alongside fallback removal to avoid a sea of warnings during migration).

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/DiagramDiagnosticFactoryTests.swift`:

```swift
import Testing
@testable import DiagramKitCommon

@Suite("DiagramDiagnostic static factories")
struct DiagramDiagnosticFactoryTests {

    @Test("lossyTransform constructs every .warning category")
    func lossyTransformAllWarning() {
        for cat in DiagnosticCategory.allCases where cat.severity == .warning {
            let d = DiagramDiagnostic.lossyTransform(cat, message: "msg")
            #expect(d.severity == .warning)
            #expect(d.category == cat)
            #expect(d.message == "msg")
            #expect(d.location == nil)
        }
    }

    @Test("featureDropped constructs every .unsupported category")
    func featureDroppedAllUnsupported() {
        for cat in DiagnosticCategory.allCases where cat.severity == .unsupported {
            let d = DiagramDiagnostic.featureDropped(cat, message: "msg")
            #expect(d.severity == .unsupported)
            #expect(d.category == cat)
        }
    }

    @Test("informational constructs every .info category")
    func informationalAllInfo() {
        for cat in DiagnosticCategory.allCases where cat.severity == .info {
            let d = DiagramDiagnostic.informational(cat, message: "msg")
            #expect(d.severity == .info)
            #expect(d.category == cat)
        }
    }

    @Test("location is propagated when provided")
    func locationPropagation() {
        let loc = DiagramDiagnostic.SourceLocation(line: 42, column: 7)
        let d = DiagramDiagnostic.lossyTransform(.idSanitization,
                                                  message: "x",
                                                  location: loc)
        #expect(d.location?.line == 42)
        #expect(d.location?.column == 7)
    }

    @Test("raw init still constructs with nil category (back-compat)")
    func rawInitNilCategory() {
        let d = DiagramDiagnostic(severity: .warning, message: "legacy")
        #expect(d.category == nil)
        #expect(d.severity == .warning)
    }
}
```

- [ ] **Step 2: Run the test, verify it fails**

```bash
swift test --filter DiagramDiagnosticFactoryTests
```

Expected: build failure — `lossyTransform` / `featureDropped` / `informational` not declared; `category` not a member of `DiagramDiagnostic`.

- [ ] **Step 3: Update `DiagramDiagnostic` to carry the category field**

Replace the contents of `Sources/DiagramKitCommon/DiagramDiagnostic.swift`:

```swift
import Foundation

/// A non-fatal issue discovered during import or export.
/// Returned in `DiagramImportResult.diagnostics` and
/// `DiagramExportResult.diagnostics`.
public struct DiagramDiagnostic: Sendable, Hashable, CustomStringConvertible {
    /// Severity level.
    public enum Severity: Sendable, Hashable {
        case warning     // recoverable; import proceeds
        case info        // informational; nothing dropped
        case unsupported // feature dropped; import proceeds without it
    }

    public let severity: Severity
    /// Typed category — populated by the static factories on this type.
    /// `nil` when constructed via the public raw `init(severity:message:)`.
    public let category: DiagnosticCategory?
    public let message: String
    /// Optional source location hint (line number, span, etc.)
    public let location: SourceLocation?

    public struct SourceLocation: Sendable, Hashable {
        public let line: Int?
        public let column: Int?
        public init(line: Int? = nil, column: Int? = nil) {
            self.line = line
            self.column = column
        }
    }

    /// Back-compatible raw init. Use the `.lossyTransform` /
    /// `.featureDropped` / `.informational` factories for new code; see
    /// `docs/diagnostic-severity-discipline.md`. (Deprecation marker
    /// lands once the in-tree migration completes.)
    public init(severity: Severity,
                message: String,
                location: SourceLocation? = nil) {
        self.severity = severity
        self.category = nil
        self.message = message
        self.location = location
    }

    /// Internal designated init — factories route here.
    internal init(severity: Severity,
                  category: DiagnosticCategory?,
                  message: String,
                  location: SourceLocation? = nil) {
        self.severity = severity
        self.category = category
        self.message = message
        self.location = location
    }

    public var description: String {
        if let loc = location {
            let lineStr = loc.line.map { "line \($0)" } ?? "?"
            return "[\(severity)] \(message) (\(lineStr))"
        }
        return "[\(severity)] \(message)"
    }
}
```

- [ ] **Step 4: Create the factories**

Create `Sources/DiagramKitCommon/DiagramDiagnostic+Factories.swift`:

```swift
import Foundation

extension DiagramDiagnostic {
    /// Lossy structural transform — the operation produced output but
    /// rewrote structure in a way that doesn't round-trip cleanly.
    /// Emits `.warning` severity.
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
            severity: .warning,
            category: category,
            message: message,
            location: location
        )
    }

    /// Feature dropped — the target format has no syntax for this input.
    /// Emits `.unsupported` severity.
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
            severity: .unsupported,
            category: category,
            message: message,
            location: location
        )
    }

    /// Informational — encoding-only transform; round-trip is stable.
    /// Emits `.info` severity.
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
            severity: .info,
            category: category,
            message: message,
            location: location
        )
    }
}
```

- [ ] **Step 5: Run the new tests + a smoke pass on existing diagnostic-emitting tests**

```bash
swift test --filter "DiagramDiagnosticFactoryTests|DiagramDiagnostic"
```

Expected: factory tests pass, no existing test regresses (raw init still works).

```bash
swift test --filter "MermaidImporterDiagnosticsTests"
```

Expected: pre-existing diagnostic tests still pass — the `category == nil` back-compat path works.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitCommon/DiagramDiagnostic.swift \
        Sources/DiagramKitCommon/DiagramDiagnostic+Factories.swift \
        Tests/DiagramKitTests/DiagramDiagnosticFactoryTests.swift
git commit -m "$(cat <<'EOF'
feat(common): DiagramDiagnostic.category field + static factories

Adds optional category field (default nil for back-compat) and three
factories: .lossyTransform / .featureDropped / .informational. Each
preconditions the category's severity matches the factory intent.
Internal designated init takes the category; public raw init keeps
category=nil. Raw init NOT yet deprecated — that lands in the strict
phase alongside the harness fallback removal.

Spec §2 + §3. Additive; existing callsites still compile.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add `RoundTripLossKind.expectedCategory` + harness typed-pairing

**Spec ref:** §6

**Files:**
- Create: `Sources/DiagramKitTestSupport/RoundTripLoss+Category.swift`
- Modify: `Sources/DiagramKitTestSupport/RoundTripHarness.swift` (rewrite `diagnosticsCover`)
- Create: `Tests/DiagramKitTests/RoundTripLossExpectedCategoryTests.swift`
- Create: `Tests/DiagramKitTests/RoundTripHarnessDiagnosticPairingTests.swift`

**Rationale:** Now the harness can pair losses to diagnostics by category equality. The legacy keyword matcher is preserved as a fallback for `category == nil` diagnostics — both paths coexist throughout the migration.

**Important constraint:** `RoundTripLoss.anonymousSubgraphRename` is currently exempt from pairing (returns `true` directly in `diagnosticsCover` at `RoundTripHarness.swift:240-241`). The new typed path must preserve this exemption — the new `diagnosticsCover` short-circuits on `anonymousSubgraphRename` before consulting the map.

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/RoundTripLossExpectedCategoryTests.swift`:

```swift
import Testing
import DiagramKitCommon
@testable import DiagramKitTestSupport

@Suite("RoundTripLossKind.expectedCategory pin")
struct RoundTripLossExpectedCategoryTests {
    @Test func idSanitization() { #expect(RoundTripLossKind.idSanitization.expectedCategory == .idSanitization) }
    @Test func shapeDowngrade() { #expect(RoundTripLossKind.shapeDowngrade.expectedCategory == .shapeDowngrade) }
    @Test func subgraphFlatten() { #expect(RoundTripLossKind.subgraphFlatten.expectedCategory == .subgraphFlatten) }
    @Test func boundaryFlatten() { #expect(RoundTripLossKind.boundaryFlatten.expectedCategory == .boundaryFlatten) }
    @Test func c4SlotDrop() { #expect(RoundTripLossKind.c4SlotDrop.expectedCategory == .c4SlotDrop) }
    @Test func titleDrop() { #expect(RoundTripLossKind.titleDrop.expectedCategory == .titleDrop) }
    @Test func configDrop() { #expect(RoundTripLossKind.configDrop.expectedCategory == .configDrop) }
    @Test func styleDrop() { #expect(RoundTripLossKind.styleDrop.expectedCategory == .styleDrop) }
    @Test func accessibilityDrop() { #expect(RoundTripLossKind.accessibilityDrop.expectedCategory == .accessibilityDrop) }
    @Test func anonymousSubgraphRename() { #expect(RoundTripLossKind.anonymousSubgraphRename.expectedCategory == .anonymousSubgraphRename) }
    @Test func d2DuplicateOverride() { #expect(RoundTripLossKind.d2DuplicateOverride.expectedCategory == .d2DuplicateOverride) }

    @Test("RoundTripLossKind cases all map — exhaustive sweep")
    func allCasesCovered() {
        for kind in RoundTripLossKind.allCases {
            _ = kind.expectedCategory  // exhaustive switch in production catches new cases at compile time
        }
        #expect(RoundTripLossKind.allCases.count == 11)
    }
}
```

Create `Tests/DiagramKitTests/RoundTripHarnessDiagnosticPairingTests.swift`:

```swift
import Testing
import DiagramKitCommon
@testable import DiagramKitTestSupport

@Suite("RoundTripHarness diagnosticsCover — typed-first / keyword-fallback")
struct RoundTripHarnessDiagnosticPairingTests {

    @Test("typed-category path covers a loss without matching keywords")
    func typedCovers() {
        let loss = RoundTripLoss.idSanitization(original: "id with spaces", sanitized: "id_with_spaces")
        let diag = DiagramDiagnostic.lossyTransform(.idSanitization, message: "x")
        #expect(diagnosticsCover(loss: loss, in: [diag]))
    }

    @Test("typed-category mismatch does not cover")
    func typedRejectsMismatch() {
        let loss = RoundTripLoss.idSanitization(original: "a", sanitized: "a_")
        // Wrong category — explicitly using shapeDowngrade despite the loss being idSanitization.
        let diag = DiagramDiagnostic.lossyTransform(.shapeDowngrade, message: "sanitized id 'a'")
        // Note: the legacy keyword matcher would match (message contains "sanitiz"), but
        // because diag.category != nil, the typed path is the only path consulted.
        #expect(!diagnosticsCover(loss: loss, in: [diag]))
    }

    @Test("legacy keyword fallback covers a nil-category diagnostic")
    func keywordFallback() {
        let loss = RoundTripLoss.idSanitization(original: "x", sanitized: "x_")
        // Raw init → category == nil; fallback path runs.
        let diag = DiagramDiagnostic(severity: .warning, message: "Identifier 'x' sanitized to 'x_'")
        #expect(diagnosticsCover(loss: loss, in: [diag]))
    }

    @Test("anonymousSubgraphRename remains exempt (returns true with empty bag)")
    func anonymousExempt() {
        let loss = RoundTripLoss.anonymousSubgraphRename(old: "subgraph_0", new: "subgraph_1")
        #expect(diagnosticsCover(loss: loss, in: []))
    }
}
```

- [ ] **Step 2: Run the tests, verify they fail**

```bash
swift test --filter "RoundTripLossExpectedCategoryTests|RoundTripHarnessDiagnosticPairingTests"
```

Expected: build failure — `expectedCategory` not a member of `RoundTripLossKind`; typed-category path not implemented.

- [ ] **Step 3: Create the `expectedCategory` extension**

Create `Sources/DiagramKitTestSupport/RoundTripLoss+Category.swift`:

```swift
import DiagramKitCommon

extension RoundTripLossKind {
    /// The `DiagnosticCategory` an exporter MUST emit when producing this
    /// round-trip loss. Exhaustive switch — adding a new loss kind forces
    /// a category choice at compile time.
    ///
    /// `anonymousSubgraphRename` returns its own category for completeness,
    /// but `RoundTripHarness.diagnosticsCover` short-circuits on this kind
    /// (anonymous renames are positional parser artifacts, not exporter
    /// emissions).
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

- [ ] **Step 4: Rewrite `diagnosticsCover` in the harness**

Edit `Sources/DiagramKitTestSupport/RoundTripHarness.swift`. Replace the existing `public func diagnosticsCover(...)` (currently at lines 209-249) with:

```swift
/// Tests whether the diagnostic bag contains at least one entry that
/// "explains" this loss.
///
/// Two-phase pairing:
///   1. Typed-first: any diagnostic with `category == loss.kind.expectedCategory`
///      counts as paired.
///   2. Fallback: for nil-category diagnostics (raw `init(severity:message:)`),
///      consult the legacy keyword matcher. The fallback is deleted in
///      Phase 2 of the migration (see plan Task 14).
///
/// `.anonymousSubgraphRename` is exempt — anonymous renames are positional
/// parser artifacts, not exporter-driven, and never carry a paired diagnostic.
public func diagnosticsCover(loss: RoundTripLoss, in diagnostics: [DiagramDiagnostic]) -> Bool {
    // Exemption: anonymous subgraph rename is positional, not exporter-driven.
    if case .anonymousSubgraphRename = loss { return true }

    let expected = loss.kind.expectedCategory
    let relevant = diagnostics.filter {
        $0.severity == .warning || $0.severity == .unsupported
    }

    // Typed-first.
    if relevant.contains(where: { $0.category == expected }) {
        return true
    }

    // Legacy keyword fallback — only consulted for nil-category diagnostics.
    return relevant.contains { diag in
        guard diag.category == nil else { return false }
        return _legacyKeywordCover(loss: loss, message: diag.message)
    }
}

/// Legacy keyword matcher — preserved for the migration window so the
/// harness stays green while emission sites are converted slice-by-slice.
/// Deleted in Phase 2 (plan Task 14).
private func _legacyKeywordCover(loss: RoundTripLoss, message: String) -> Bool {
    let keywords: [String]
    switch loss {
    case .idSanitization(let original, _):
        keywords = ["sanitiz", "alias", "renamed", original]
    case .shapeDowngrade(let nodeID, _, _):
        keywords = ["shape", nodeID]
    case .subgraphFlatten(let id, _):
        keywords = ["subgraph", "cluster", id]
    case .boundaryFlatten(let id, _):
        keywords = ["boundary", id]
    case .c4SlotDrop(let id, let slot):
        keywords = [slot.rawValue, id]
    case .titleDrop:
        keywords = ["title"]
    case .configDrop(let key):
        keywords = [key, "config", "frontmatter"]
    case .styleDrop(let target, let attribute):
        keywords = [target, attribute, "style"]
    case .accessibilityDrop(let field):
        keywords = [field.rawValue, "accessib", "acctitle", "accdescr"]
    case .anonymousSubgraphRename:
        return true  // unreachable; exemption is handled in diagnosticsCover
    case .d2DuplicateOverride(let id, _):
        keywords = ["duplicate", id]
    }
    let m = message.lowercased()
    return keywords.contains { m.contains($0.lowercased()) }
}
```

- [ ] **Step 5: Run the new tests + the existing round-trip suite**

```bash
swift test --filter "RoundTripLossExpectedCategoryTests|RoundTripHarnessDiagnosticPairingTests"
```

Expected: 4 new pairing tests + 12 expectedCategory pins all pass.

```bash
swift test --filter "RoundTrip"
```

Expected: the full round-trip suite (same-format 14 cells + cross-format 16 ordered directions) stays green — all current pairings still route through the legacy keyword path because every emission site still uses raw init.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitTestSupport/RoundTripLoss+Category.swift \
        Sources/DiagramKitTestSupport/RoundTripHarness.swift \
        Tests/DiagramKitTests/RoundTripLossExpectedCategoryTests.swift \
        Tests/DiagramKitTests/RoundTripHarnessDiagnosticPairingTests.swift
git commit -m "$(cat <<'EOF'
feat(test-support): typed RoundTripLossKind→DiagnosticCategory pairing

`expectedCategory` extension lives next to RoundTripLoss; harness
`diagnosticsCover` rewritten to consult typed category first, fall back
to the legacy keyword matcher for nil-category diagnostics during the
migration window. `.anonymousSubgraphRename` remains exempt
(positional, not exporter-driven).

Spec §6. Round-trip suite stays green — all current pairings still
route through the legacy path because no slice has migrated yet.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Mermaid emission migration

**Spec ref:** §7 commit 3

**Files modified:**
- `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidExportHelpers.swift`
- `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidC4Export.swift`
- `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidSequenceExport.swift`
- `Sources/DiagramKitMermaid/Exporter/MermaidExportDiagnostics.swift`
- `Sources/DiagramKit/MermaidImporter.swift` (Kanban duplicate-node, C4 boundary warnings)

**Rationale:** Walk every `DiagramDiagnostic(severity:.X, message: ...)` construction in `DiagramKitMermaid` + the umbrella's `MermaidImporter` and replace it with the appropriate factory call. Category selection follows the spec's §1 decision tree.

**Pattern transformation** (apply per-site):

```swift
// Before
DiagramDiagnostic(severity: .warning, message: "Identifier '\(id)' sanitized to '\(sanitized)'")

// After
DiagramDiagnostic.lossyTransform(.idSanitization,
                                  message: "Identifier '\(id)' sanitized to '\(sanitized)'")
```

For `.append(DiagramDiagnostic(...))` patterns, replace inline:

```swift
diagnostics.append(.lossyTransform(.idSanitization, message: "..."))
```

- [ ] **Step 1: Inventory current emission sites in Mermaid surfaces**

```bash
grep -RIn 'DiagramDiagnostic(severity:' \
  Sources/DiagramKitMermaid Sources/DiagramKit/MermaidImporter.swift
```

Expected sites (verify against current code; line numbers may have shifted):
- `MermaidExportHelpers.swift:22-24` — newline-in-bracket-label → `.lossyTransform(.labelNewlineEscape)` (was `.info`, recategorized per spec §1 — handle in Task 9)
- `MermaidExportHelpers.swift:47-49` — newline-in-edge-label → same, handle in Task 9
- `MermaidExportHelpers.swift:98-99` — sanitize identifier rename → `.lossyTransform(.idSanitization)`
- `MermaidExportHelpers.swift:129-130` — sanitize identifier collision → `.lossyTransform(.idSanitization)`
- `MermaidExportHelpers.swift:148-150` — newline in quoted value → handle in Task 9
- `MermaidC4Export.swift:87` — C4 tech slot drop → handle in Task 10 (recategorization)
- `MermaidSequenceExport.swift:253` — participant activity tracking (verify; pick category from context)
- `MermaidExportDiagnostics.swift:9` — unsupported diagram type → `.featureDropped(.diagramFamilyUnsupported)`
- `MermaidExportDiagnostics.swift:19` — unsupported sub-feature → `.featureDropped(.diagramFamilyUnsupported)` or `.slotUnsupported` depending on context
- `MermaidImporter.swift` C4 boundary warning → `.lossyTransform(.boundaryFlatten)` (verify)
- `MermaidImporter.swift` Kanban duplicate-node → `.lossyTransform(.d2DuplicateOverride)` or `.idSanitization` (verify; pick by context — if the duplicate is the same node twice, it's a no-op silent; if the second replaces the first, it's `d2DuplicateOverride`-style even though the family is Kanban not D2 — choose `.idSanitization` if naming-driven, otherwise a new category is needed; for this task, use `.idSanitization` since Kanban duplicates collapse via identifier deduplication)

**Recategorization-deferred sites** (Tasks 9-11 own these — leave them as raw init for now):
- All `MermaidExportHelpers` newline-escape sites (Task 9 promotes `.info` → `.warning` via `labelNewlineEscape`)
- `MermaidC4Export.swift:87` C4 tech slot drop (Task 10 promotes `.info` → `.warning`/`.unsupported`)

- [ ] **Step 2: Apply the pattern at each non-deferred site**

Edit each site to use the appropriate factory. Example for `MermaidExportHelpers.sanitizeIdentifier`:

```swift
// MermaidExportHelpers.swift:~98 — before
diagnostics.append(DiagramDiagnostic(
    severity: .warning,
    message: "Identifier '\(original)' sanitized to '\(sanitized)'"))

// after
diagnostics.append(.lossyTransform(
    .idSanitization,
    message: "Identifier '\(original)' sanitized to '\(sanitized)'"))
```

For the collision case (`MermaidExportHelpers.swift:~129`):

```swift
diagnostics.append(.lossyTransform(
    .idSanitization,
    message: "Identifier '\(original)' sanitized to '\(initial)' collided with another alias; renamed to '\(final)'"))
```

For `MermaidExportDiagnostics.swift:9`:

```swift
return .featureDropped(.diagramFamilyUnsupported,
                       message: "Mermaid export does not yet support diagram type '\(type)'.")
```

For `MermaidExportDiagnostics.swift:19`:

```swift
return .featureDropped(.diagramFamilyUnsupported,
                       message: "Mermaid \(type) export does not yet support sub-feature '\(feature)'.")
```

For `MermaidImporter.swift` Kanban duplicate-node:

```swift
diagnostics.append(.lossyTransform(
    .idSanitization,
    message: "Kanban node id '\(id)' appeared more than once; later occurrence dropped."))
```

For `MermaidImporter.swift` C4 boundary diagnostic (if any) — pass the parser's diagnostics through unchanged (Task 8 owns model-tier parser emissions).

- [ ] **Step 3: Run Mermaid-touching tests**

```bash
swift test --filter "Mermaid|RoundTrip"
```

Expected: every Mermaid suite + the round-trip cells that exercise Mermaid stay green. Pairings now run through the typed path for sites that migrated; deferred sites (newline-escape, c4 slot) still run through the legacy fallback.

- [ ] **Step 4: Verify no behavioral regressions**

```bash
swift test --filter "MermaidImporterDiagnosticsTests"
```

Expected: pass. The diagnostic messages are unchanged; only the category field is now populated.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitMermaid/ Sources/DiagramKit/MermaidImporter.swift
git commit -m "$(cat <<'EOF'
refactor(mermaid): emission sites → typed DiagnosticCategory factories

Migrates ~7 sites across MermaidExportHelpers, MermaidExportDiagnostics,
MermaidImporter Kanban duplicate-node path. Three sites deferred to
recategorization tasks: newline-in-label (Task 9: .info→.warning
labelNewlineEscape), C4 tech-slot drop (Task 10), and any
MermaidSequenceExport site that needs context review.

Round-trip suite stays green; typed path is now exercised for the
migrated sites, legacy keyword fallback covers the deferred ones.

Spec §7 commit 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Structurizr emission migration

**Spec ref:** §7 commit 4

**Files modified:**
- `Sources/DiagramKitStructurizr/Exporter/StructurizrExporter.swift`
- `Sources/DiagramKitStructurizr/Mapper/StructurizrMapper.swift`
- `Sources/DiagramKitStructurizr/Parser/StructurizrParser.swift`
- `Sources/DiagramKitStructurizr/Parser/StructurizrParserState.swift`

**Rationale:** Same pattern as Task 4. Structurizr is the largest single slice — ~12 emission sites across parser, mapper, exporter. Throws stay as throws (parse-stoppers per spec §1).

- [ ] **Step 1: Inventory current emission sites in Structurizr**

```bash
grep -RIn 'DiagramDiagnostic(severity:' Sources/DiagramKitStructurizr
```

Expected category mapping:
- `StructurizrExporter.swift:~74-76` — nested boundary flatten → `.lossyTransform(.boundaryFlatten)`
- `StructurizrExporter.swift:~82-83` — empty group drop → `.lossyTransform(.boundaryFlatten)` (the group is the boundary representation; an empty one is a structural drop)
- `StructurizrExporter.swift:~174` — enterprise boundary → `.featureDropped(.boundaryTypeUnsupported)`
- `StructurizrExporter.swift:~244-245` — uniqueSanitizedAlias rename → `.lossyTransform(.idSanitization)`
- `StructurizrExporter.swift:~26` — C4 type unsupported → `.featureDropped(.diagramFamilyUnsupported)`
- `StructurizrParserState.swift:~15` — C4 type unsupported on import → `.featureDropped(.diagramFamilyUnsupported)`
- `StructurizrMapper.swift:~22, 45, 54, 65, 71, 81, 103` — DSL features (tags, view-scoped relationships, etc.) → `.featureDropped(.diagramFamilyUnsupported)` or `.slotUnsupported` per site context (read surrounding code; pick the one that better matches "this DSL feature isn't expressible in the in-memory model").

`StructurizrExporter.swift:~62-63` — `.viewScopeSynthesized` silent drop is NOT a diagnostic emission; Task 12 handles the marker.

- [ ] **Step 2: Apply the pattern at each site**

Representative transformations:

```swift
// StructurizrExporter.swift:~74 — nested boundary
diagnostics.append(.lossyTransform(
    .boundaryFlatten,
    message: "Structurizr `group` is non-nestable; flattening boundary '\(boundary.id)' to top-level"))

// StructurizrExporter.swift:~82 — empty group
diagnostics.append(.lossyTransform(
    .boundaryFlatten,
    message: "Empty group '\(boundary.label)' has no direct shapes after Structurizr flattening; dropping"))

// StructurizrExporter.swift:~174 — enterprise boundary
diagnostics.append(.featureDropped(
    .boundaryTypeUnsupported,
    message: "Enterprise boundary not supported by Structurizr DSL export."))

// StructurizrExporter.swift:~244 — uniqueSanitizedAlias
diagnostics.append(.lossyTransform(
    .idSanitization,
    message: "Renamed alias '\(original)' to '\(sanitized)' for Structurizr parser compatibility"))

// StructurizrMapper.swift:~22 — unsupported tags
diagnostics.append(.featureDropped(
    .diagramFamilyUnsupported,
    message: "Structurizr tags directive not represented in DiagramKit model."))
```

For each Mapper site, read the surrounding context. The rule of thumb:
- If the feature has its own DSL keyword (tags, technology, perspectives), use `.featureDropped(.diagramFamilyUnsupported)`.
- If the feature is structural (boundary, relationship scope), use `.featureDropped(.boundaryTypeUnsupported)` or `.lossyTransform(.boundaryFlatten)` depending on whether it's dropped or restructured.

- [ ] **Step 3: Run Structurizr-touching tests**

```bash
swift test --filter "Structurizr|RoundTrip"
```

Expected: full Structurizr suite + round-trip cells stay green.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitStructurizr/
git commit -m "$(cat <<'EOF'
refactor(structurizr): emission sites → typed DiagnosticCategory factories

Migrates ~12 sites across parser, parser-state, mapper, and exporter
to the new factory API. Category selection: boundary flatten/drop →
.boundaryFlatten; alias renames → .idSanitization; unsupported DSL
features → .diagramFamilyUnsupported; enterprise boundary →
.boundaryTypeUnsupported.

viewScopeSynthesized silent drop unchanged here; handled by Task 12's
silent-drop marker pass.

Spec §7 commit 4.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: D2 + Graphviz/DOT emission migration

**Spec ref:** §7 commit 5

**Files modified:**
- `Sources/DiagramKitD2/**/*.swift`
- `Sources/DiagramKitGraphviz/**/*.swift`
- `Sources/DiagramKitExport/FlowchartExportWalker.swift` (the subgraph-drop warning emitted by both D2 and DOT)

**Rationale:** D2 and DOT share the `FlowchartExportWalker` subgraph-drop diagnostic plus per-slice emissions. ~8 sites.

- [ ] **Step 1: Inventory**

```bash
grep -RIn 'DiagramDiagnostic(severity:' \
  Sources/DiagramKitD2 Sources/DiagramKitGraphviz Sources/DiagramKitExport
```

Expected category mapping:
- `FlowchartExportWalker.swift` subgraph-drop warning → `.lossyTransform(.subgraphFlatten)`
- `D2Mapper.swift:~74-101` upsertNode 4 duplicate-override sites → `.lossyTransform(.d2DuplicateOverride)`
- `D2Mapper.swift` (other emit sites if any) → review per-site
- D2 inline-comment stripping in `D2Parser.swift` → defer to Task 11 (recategorization to `.lossyTransform(.d2InlineCommentStripped)`)
- `DOTMapper.swift` `_isHTMLLabel` unsupported emission → `.featureDropped(.slotUnsupported)`
- `DOTFlowchartExport.swift` (any direct emissions) → review

- [ ] **Step 2: Apply the pattern at each non-deferred site**

```swift
// FlowchartExportWalker.swift — subgraph drop
diagnostics.append(.lossyTransform(
    .subgraphFlatten,
    message: "Subgraph '\(subgraphID)' dropped: depth \(depth) exceeds walker capability"))

// D2Mapper.swift — duplicate-override
diagnostics.append(.lossyTransform(
    .d2DuplicateOverride,
    message: "Node '\(id)' duplicate occurrence overrode \(attribute)."))

// DOTMapper.swift — HTML label unsupported
diagnostics.append(.featureDropped(
    .slotUnsupported,
    message: "HTML label on '\(nodeID)' not supported in DOT import; using node id as fallback."))
```

- [ ] **Step 3: Run D2/DOT-touching tests**

```bash
swift test --filter "D2|DOT|Graphviz|FlowchartExport|RoundTrip"
```

Expected: stays green; deferred `d2InlineCommentStripped` sites still use raw init and route through legacy fallback (no current loss kind covers them, so they don't pair against any loss).

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitD2/ Sources/DiagramKitGraphviz/ Sources/DiagramKitExport/
git commit -m "$(cat <<'EOF'
refactor(d2,graphviz): emission sites → typed DiagnosticCategory factories

Migrates ~7 sites across D2 mapper, DOT mapper, and FlowchartExportWalker
(which is shared by D2 and DOT exporters). Category selection: subgraph
drop → .subgraphFlatten; D2 duplicate-node override → .d2DuplicateOverride;
DOT HTML label → .slotUnsupported.

D2 inline-comment stripping deferred to Task 11 (recategorization
silent→.lossyTransform(.d2InlineCommentStripped)).

Spec §7 commit 5.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: PlantUML emission migration

**Spec ref:** §7 commit 6

**Files modified:**
- `Sources/DiagramKitPlantUML/Exporter/*.swift` (six family slices)
- `Sources/DiagramKitPlantUML/PlantUMLImporter.swift`
- `Sources/DiagramKitPlantUML/Sequence/*.swift`
- `Sources/DiagramKitPlantUML/Class/*.swift`
- `Sources/DiagramKitPlantUML/State/*.swift`

**Rationale:** PlantUML has six family slices (sequence/class/state/activity/mindmap/gantt/C4) plus a top-level importer and per-family probes. ~10 sites.

- [ ] **Step 1: Inventory**

```bash
grep -RIn 'DiagramDiagnostic(severity:' Sources/DiagramKitPlantUML
```

Expected category mapping:
- `PlantUMLImporter.swift` malformed-source path → stays as `throw DiagramError.malformedSource(message:)` (no change; importer parse-stopper per spec §1)
- `PlantUMLImporter.swift` unsupported family path → stays as throw (parse-stopper)
- Per-family parser unsupported-feature emissions → `.featureDropped(.diagramFamilyUnsupported)` (most) or `.slotUnsupported` for shape-level drops
- C4 shape-not-Mermaid-expressible → `.featureDropped(.c4ShapeUnsupported)` if any (Mermaid has no `Person` stereotype distinction past Person/Container etc.; PlantUML has finer-grained shapes — this is the NEW category from spec §2)
- Class parser block-comment skipping → `.informational(.commentPreserved)` (re-emit preserves; round-trip stable per spec §1 Test 2)

- [ ] **Step 2: Apply the pattern at each site**

Representative transformations:

```swift
// PlantUMLClassParser.swift — block comment skipped
diagnostics.append(.informational(
    .commentPreserved,
    message: "PlantUML block comment skipped at line \(lineNo)."))

// PlantUMLC4Export.swift — Mermaid-incompatible C4 stereotype
diagnostics.append(.featureDropped(
    .c4ShapeUnsupported,
    message: "PlantUML C4 stereotype '\(stereotype)' has no Mermaid equivalent; using base shape."))
```

- [ ] **Step 3: Run PlantUML-touching tests**

```bash
swift test --filter "PlantUML|RoundTrip"
```

Expected: stays green.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitPlantUML/
git commit -m "$(cat <<'EOF'
refactor(plantuml): emission sites → typed DiagnosticCategory factories

Migrates ~10 sites across the six family slices. Throws kept as throws
(parse-stoppers per spec §1). New .c4ShapeUnsupported category applied
where PlantUML C4 stereotypes lose fidelity on Mermaid export. Class
parser block-comment skip → .informational(.commentPreserved).

Spec §7 commit 6.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Model-tier emission migration

**Spec ref:** §7 commit 7

**Files modified:**
- `Sources/DiagramKitModel/src_layout.swift` — flowchart subgraph recursion truncation
- `Sources/DiagramKitModel/src_ishikawa_layout.swift` — depth-overflow
- `Sources/DiagramKitModel/src_c4_parser.swift` — boundary mismatch / unresolved-ref warnings
- `Sources/DiagramKitModel/src_kanban_parser.swift` — duplicate-node
- Other `src_*_parser.swift` / `src_*_layout.swift` files surfaced by grep

**Rationale:** Last slice migration commit. Layout-tier and parser-tier diagnostics that flow through `PositionedGraph.diagnostics` and `DiagramImportResult.diagnostics`. ~10 sites.

- [ ] **Step 1: Inventory**

```bash
grep -RIn 'DiagramDiagnostic(severity:' Sources/DiagramKitModel
```

Expected category mapping:
- Flowchart subgraph recursion truncation (3 sites in `src_layout.swift`) → `.lossyTransform(.subgraphFlatten)`
- Ishikawa depth-overflow → `.lossyTransform(.subgraphFlatten)` (closest semantic match; depth limit truncates the rendering)
- C4 boundary mismatch / unresolved-ref → `.lossyTransform(.boundaryFlatten)` for mismatch, `.featureDropped(.diagramFamilyUnsupported)` for genuinely missing refs (read context)
- Kanban duplicate-node → `.lossyTransform(.idSanitization)` (same as Task 4's importer-side analog)
- GitGraph parallelCommits missing-position → `.lossyTransform(.styleDrop)` if position is style-tier, else `.lossyTransform(.configDrop)` (read context)
- Any other site: pick by spec §1 decision tree using surrounding code as ground

- [ ] **Step 2: Apply the pattern at each site**

```swift
// src_layout.swift — subgraph recursion truncation
_LayoutDiagnostics.append(.lossyTransform(
    .subgraphFlatten,
    message: "Subgraph '\(subgraphID)' truncated at recursion depth \(depth)."))

// src_c4_parser.swift — boundary mismatch (named-arg vs lexical)
diagnostics.append(.lossyTransform(
    .boundaryFlatten,
    message: "Shape '\(shapeID)' carries $boundary=\(named) but lexical boundary is \(lexical); using $boundary."))
```

- [ ] **Step 3: Run model-tier and ASCII tests**

```bash
swift test --filter "ParserDiagnostic|C4BoundaryNamedArg|MermaidImporterDiagnostics|RoundTrip"
```

Expected: stays green.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitModel/
git commit -m "$(cat <<'EOF'
refactor(model): emission sites → typed DiagnosticCategory factories

Migrates ~10 sites across layout (flowchart subgraph truncation,
ishikawa depth), parser-tier C4 boundary mismatch / unresolved-ref,
Kanban duplicate-node, GitGraph parallelCommits. Diagnostics flow
through PositionedGraph.diagnostics / DiagramImportResult.diagnostics
unchanged.

Spec §7 commit 7. With this commit, every in-tree non-recategorization
emission site now uses a factory.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Recategorize `labelNewlineEscape` (.info → .warning)

**Spec ref:** §1, §7 commit 8

**Files modified:**
- `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidExportHelpers.swift` (3 sites: escapeBracketLabel, escapeEdgeLabel, quote)
- `Tests/DiagramKitTests/<existing Mermaid exporter test>.swift` (add severity assertion)
- Possibly `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/*/<cell>.json` (`allowedLosses` may need updating if any cell exercises a label-newline)

**Rationale:** Newline-in-label is not round-trip stable (newline → space → newline ≠ original). Per spec §1 Test 2, it's `.warning`, not `.info`.

- [ ] **Step 1: Identify the three sites**

```bash
grep -n 'Newline in.*replaced with space' Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidExportHelpers.swift
```

Expected: three matches around lines 22-24, 47-49, 148-150.

- [ ] **Step 2: Add a regression test pinning the new severity + category**

Add to `Tests/DiagramKitTests/MermaidExporterTests.swift` (or whichever existing exporter test suite covers helpers):

```swift
@Test("newline in bracket label emits .warning labelNewlineEscape")
func labelNewlineEscapeIsWarning() throws {
    // Construct a flowchart with a label containing a literal newline.
    let source = """
    flowchart TD
      A[Line1
    Line2]
    """
    let doc = try source.parseDiagram()
    let result = try MermaidExporter().export(doc, to: .mermaid)
    let cat = result.diagnostics.first?.category
    let sev = result.diagnostics.first?.severity
    #expect(cat == .labelNewlineEscape)
    #expect(sev == .warning)
}
```

Run, verify it fails (severity is currently `.info`).

- [ ] **Step 3: Promote the three helpers**

```swift
// MermaidExportHelpers.swift:~22 — escapeBracketLabel
diagnostics.append(.lossyTransform(
    .labelNewlineEscape,
    message: "Newline in bracket label replaced with space"))

// MermaidExportHelpers.swift:~47 — escapeEdgeLabel
diagnostics.append(.lossyTransform(
    .labelNewlineEscape,
    message: "Newline in edge label replaced with space"))

// MermaidExportHelpers.swift:~148 — quote
diagnostics.append(.lossyTransform(
    .labelNewlineEscape,
    message: "Newline in quoted value replaced with space"))
```

- [ ] **Step 4: Run the new test + the Mermaid suite**

```bash
swift test --filter "MermaidExporterTests"
```

Expected: pass. Verify no existing test asserted `.severity == .info` for these sites — if so, update those tests to assert `.warning`.

- [ ] **Step 5: Run round-trip — check for unpaired-loss errors**

```bash
swift test --filter "RoundTrip"
```

Expected: stays green. If a cell exercises a label-with-newline AND its `allowedLosses` doesn't include `labelNewlineEscape`-equivalent, the harness will surface an unpaired-loss failure. Currently `RoundTripLossKind` has no `labelNewlineEscape` case — meaning either no cell exercises this, or the loss currently slips through as "unexpected" rather than "loss." This is acceptable: the new diagnostic is now visible in the bag; whether the harness needs a corresponding `RoundTripLoss` case is a Task 9.5 (deferred) decision.

If round-trip fails: identify the failing cell, document the loss as "unexpected" (existing harness behavior), and either (a) accept and update the cell's expected-equality structure, or (b) add a new `RoundTripLossKind.labelNewlineEscape` case in a follow-up commit. Either path keeps Task 9 atomic.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidExportHelpers.swift \
        Tests/DiagramKitTests/MermaidExporterTests.swift
git commit -m "$(cat <<'EOF'
fix(mermaid): label newline escape is .warning, not .info

Newline-in-label → space is NOT round-trip stable (newline → space →
newline ≠ original). Spec §1 Test 2 says .warning. Three helper sites
(escapeBracketLabel, escapeEdgeLabel, quote) recategorized to
.lossyTransform(.labelNewlineEscape).

Spec §1 migration finding + §7 commit 8.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Recategorize `c4SlotDrop` (.info → .warning or .unsupported)

**Spec ref:** §1, §6 "Known migration probe", §7 commit 8

**Files modified:**
- `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidC4Export.swift:~87`
- New regression test in `Tests/DiagramKitTests/MermaidC4ExporterTests.swift` or similar

**Rationale:** Today `c4SlotDrop` is `.info`. `RoundTripLoss.c4SlotDrop` is `.warning`-tier in the harness's keyword filter. So the current pairing is either passing by coincidence (keyword `"slot"`/`"tech"` happens to match) or no harness cell exercises it. Spec §6 calls this out as a probe.

**Per spec §1**, the choice is:
- If the target shape HAS a tech slot but we're dropping it for any other reason → `.warning` `.c4SlotDrop`
- If the target shape has NO tech slot at all (e.g., `Person` in Mermaid C4 has no tech slot) → `.unsupported` `.slotUnsupported`

The exporter knows which it is via `C4ShapeType.hasTechnologySlot`. Branch on that.

- [ ] **Step 1: Probe the current pairing**

```bash
swift test --filter "C4SlotSemanticsTests|MermaidC4|RoundTrip" 2>&1 | head -40
```

Expected: green today. The probe is informational only.

- [ ] **Step 2: Add the regression test**

Add to a relevant test file (e.g., `Tests/DiagramKitTests/MermaidC4ExporterTests.swift` if it exists, else create):

```swift
@Test("C4 tech-slot drop on slot-bearing shape is .warning c4SlotDrop")
func techSlotDropWarning() throws {
    let source = """
    C4Context
      Container(c, "Cache", "Redis", "in-memory cache")
    """
    // Target a format where the shape DOES have a tech slot — assume Mermaid
    // C4 Container has tech slot. Use a hypothetical context where it doesn't.
    // (Implementation detail: pick a shape and target where the drop fires.)
    // Construct the actual test against MermaidC4Export.swift:~87's specific
    // dropping condition — read the surrounding code to identify which
    // shape/slot combination triggers it.
    let doc = try source.parseDiagram()
    let result = try MermaidExporter().export(doc, to: .mermaid)
    let dropDiag = result.diagnostics.first { $0.message.contains("technology slot") }
    #expect(dropDiag?.severity == .warning)
    #expect(dropDiag?.category == .c4SlotDrop)
}
```

If the test setup can't readily fire the drop condition, instead add a unit test directly against the diagnostic-emit helper (read `MermaidC4Export.swift:~87` and identify the function holding the emit).

- [ ] **Step 3: Apply the branching**

Read `MermaidC4Export.swift` around line 87. The current emit is roughly:

```swift
// Before
diagnostics.append(DiagramDiagnostic(
    severity: .info,
    message: "Mermaid C4 \(shapeType) has no positional technology slot; dropping technology '\(tech)'."))
```

Replace with:

```swift
// After — branch on C4ShapeType.hasTechnologySlot
if shapeType.hasTechnologySlot {
    diagnostics.append(.lossyTransform(
        .c4SlotDrop,
        message: "Mermaid C4 \(shapeType) technology slot present but dropped; value was '\(tech)'."))
} else {
    diagnostics.append(.featureDropped(
        .slotUnsupported,
        message: "Mermaid C4 \(shapeType) has no positional technology slot; dropping technology '\(tech)'."))
}
```

The pre-existing emit fires only when there's nothing to put the tech in (the `.unsupported` branch above per the current comment at `MermaidC4Export.swift:~78`); if the branching is awkward because the upstream caller has already determined "no slot," keep just the `.featureDropped(.slotUnsupported)` form. Read the surrounding ~20 lines and pick the natural shape.

- [ ] **Step 4: Run targeted tests**

```bash
swift test --filter "C4|MermaidC4|RoundTrip"
```

Expected: stays green. If a round-trip cell was passing by keyword-match coincidence, it now passes by typed-category match. If a previously-undetected unpaired loss surfaces, address per the same playbook as Task 9 step 5.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidC4Export.swift \
        Tests/DiagramKitTests/
git commit -m "$(cat <<'EOF'
fix(mermaid): C4 tech-slot drop branches on hasTechnologySlot

Spec §1 Test 1: if target shape has the slot, drop is .warning
.c4SlotDrop (lossy but expressible later); if target shape lacks
the slot, drop is .unsupported .slotUnsupported (no future fix).
Previous emission was a flat .info, which the harness's
keyword-only matcher accepted by coincidence.

Spec §6 "Known migration probe" + §7 commit 8.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Recategorize `d2InlineCommentStripped` (silent → .warning)

**Spec ref:** §1, §7 commit 8

**Files modified:**
- `Sources/DiagramKitD2/Parser/D2Parser.swift` — `_stripInlineComment` callsite(s)
- New regression test

**Rationale:** D2's `// note` trailing-value stripping (added in Session 2's `5ef689f`) silently drops the comment. Per spec §1 Test 2, this is not round-trip stable (the comment can carry information the user wrote on purpose), so it's `.warning` `.d2InlineCommentStripped`.

- [ ] **Step 1: Identify the strip callsite**

```bash
grep -n '_stripInlineComment\|stripInlineComment' Sources/DiagramKitD2/Parser/D2Parser.swift
```

Read the surrounding code to find where the strip happens AND where it could emit a diagnostic. If the strip is in a pure-function helper (no diagnostic bag in scope), the emission needs to move one level up to the caller that owns the bag.

- [ ] **Step 2: Add the regression test**

```swift
// Tests/DiagramKitTests/D2ParserTests.swift — add @Test
@Test("D2 inline comment stripped emits .warning d2InlineCommentStripped")
func inlineCommentEmitsWarning() throws {
    let source = """
    foo: bar // important note
    """
    let result = try D2Importer().parse(source)
    let diag = result.diagnostics.first { $0.message.contains("comment") }
    #expect(diag?.severity == .warning)
    #expect(diag?.category == .d2InlineCommentStripped)
}
```

- [ ] **Step 3: Modify the strip callsite**

If `_stripInlineComment` is pure, change its signature to return both the stripped string AND a boolean indicating "comment was present." The caller (e.g., `D2Parser.preprocess`) then emits when the bool is true:

```swift
// D2Parser.swift — caller
let (cleaned, hadComment) = _stripInlineComment(line, marker: "//")
if hadComment {
    diagnostics.append(.lossyTransform(
        .d2InlineCommentStripped,
        message: "D2 inline comment stripped from line \(lineNo); value preserved as '\(cleaned)'."))
}
```

If the bag isn't reachable from the strip site, surface the strip at the next-higher level with bag access.

- [ ] **Step 4: Run D2 + round-trip tests**

```bash
swift test --filter "D2|RoundTrip"
```

Expected: stays green. If round-trip surfaces an unpaired loss for cells that exercise inline comments, address as in Task 9 step 5 — likely no existing cells do, since this is a brand-new diagnostic.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitD2/Parser/D2Parser.swift \
        Tests/DiagramKitTests/D2ParserTests.swift
git commit -m "$(cat <<'EOF'
fix(d2): inline comment strip emits .warning, not silent

`// note` trailing-value strip was silent — per spec §1 Test 2, the
comment carries information the user wrote on purpose, so the strip
is NOT round-trip stable. Now emits .lossyTransform(.d2InlineCommentStripped)
on every stripped line.

Spec §1 migration finding + §7 commit 8.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Silent-drop audit + marker pass

**Spec ref:** §4, §7 commit 9

**Files modified:**
- `Sources/DiagramKitStructurizr/Exporter/StructurizrExporter.swift:~62-63` — add `// SILENT-DROP(...)` marker
- `Sources/DiagramKitStructurizr/Lexer/StructurizrLexer.swift:~237` — audit decision: emit or marker
- Other parser block-skip sites surfaced by review
- Possibly a new test pinning the `viewScopeSynthesized` round-trip stability (if not already pinned)

**Rationale:** Each known silent-drop site gets a decision: keep silent + add marker (only if round-trip-reversible), or emit a diagnostic.

- [ ] **Step 1: viewScopeSynthesized — add marker**

Edit `Sources/DiagramKitStructurizr/Exporter/StructurizrExporter.swift:~62-63`:

```swift
// SILENT-DROP(viewScopeSynthesized boundaries are re-derived from parent
// relationships on the next import; round-trip-stable).
// Pinned by: StructurizrBoundaryRoundTripTests.viewScopeBoundariesRoundTrip
// Allowed under §4 of docs/diagnostic-severity-discipline.md.
continue
```

If `StructurizrBoundaryRoundTripTests.viewScopeBoundariesRoundTrip` does not exist (the session-6 work added group-based tests; the viewScope path may be tested under a different name), either find the existing test that pins this round-trip and reference its name, or add a new test:

```swift
// Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift
@Test("viewScopeSynthesized boundaries re-derive on round-trip")
func viewScopeBoundariesRoundTrip() throws {
    // construct a Mermaid C4 source whose mapping produces .viewScopeSynthesized
    // boundaries; export to Structurizr; re-import; assert the boundaries are
    // present in the re-imported model.
    // ... concrete test body ...
}
```

- [ ] **Step 2: StructurizrLexer.swift:~237 — audit decision**

Read the surrounding code at `Sources/DiagramKitStructurizr/Lexer/StructurizrLexer.swift:~237` to understand what character class is being skipped.

If the skipped chars are purely whitespace-ish (no semantic carry possible) — add a marker pinned by a test that asserts no Structurizr fixture contains semantic content in those character classes.

If the skipped chars could carry semantic content (e.g., Unicode bidi marks, zero-width joiners) — emit `.informational(.identifierEscape)` since the input is at the character level and stripping is encoding-cosmetic-with-warning:

```swift
diagnostics.append(.informational(
    .identifierEscape,
    message: "Skipped unrecognized character '\(scalar.debugDescription)' at line \(line); may indicate encoding issue."))
```

If the bag isn't reachable from the lexer, surface at the parser entry point with an "encountered unknown chars" counter and emit once.

The choice depends on what the actual character class is. Read the code, decide, document the decision in the commit message.

- [ ] **Step 3: Parser block-skip sites**

Run:

```bash
grep -RIn 'unrecognized\|unknown\|skip' Sources/DiagramKitModel/src_*_parser.swift | head -20
```

Identify any silent block/statement skips. For each: either add a marker (with Pinned-by) or emit `.featureDropped(.diagramFamilyUnsupported)` for whole-block skips. Choose per the spec's silent-drop policy — silence only OK when re-emit on round-trip is provable.

- [ ] **Step 4: Run round-trip + Structurizr tests**

```bash
swift test --filter "Structurizr|RoundTrip"
```

Expected: stays green. Any audit decision that converts silent → emit MUST keep the round-trip cell green; if a cell breaks, the audit decision needs to revisit (either the silent was correct after all, or the cell's `allowedLosses` needs updating).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitStructurizr/Exporter/StructurizrExporter.swift \
        Sources/DiagramKitStructurizr/Lexer/StructurizrLexer.swift \
        Sources/DiagramKitModel/ \
        Tests/DiagramKitTests/
git commit -m "$(cat <<'EOF'
chore(silent-drops): audit + add // SILENT-DROP markers

viewScopeSynthesized boundary drop: kept silent + Pinned-by marker
(re-derived on import). Lexer unknown-char skip: audit decided <emit
or marker per actual char class>. Model parser block skips: <decisions>.

Each marker carries a `Pinned by: <Test>` line so a stale reference
rots loudly when the test moves.

Spec §4 + §7 commit 9.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Script gate + bootstrap wiring

**Spec ref:** §5, §7 commit 10

**Files created:**
- `Scripts/check-diagnostic-discipline.sh`
- `Scripts/check-diagnostic-discipline-tests/run.sh`
- `Scripts/check-diagnostic-discipline-tests/fixtures/bad-raw-init/Sample.swift`
- `Scripts/check-diagnostic-discipline-tests/fixtures/bad-missing-pinned/Sample.swift`
- `Scripts/check-diagnostic-discipline-tests/fixtures/bad-stale-pinned/Sample.swift`
- `Scripts/check-diagnostic-discipline-tests/fixtures/bad-exporter-throws/SampleExporter.swift`
- `Scripts/check-diagnostic-discipline-tests/fixtures/good-clean/Sample.swift`
- `.diagnostic-discipline-allowlist.txt` (empty)

**Files modified:**
- `Scripts/bootstrap-smoke-check.sh` — add `run_gate` line

**Rationale:** After Tasks 4-12, the in-tree raw-init use should be near-zero. The gate locks in zero (after allowlist). Self-test fixtures verify each violation kind is detected.

- [ ] **Step 1: Create the production script**

Create `Scripts/check-diagnostic-discipline.sh`:

```bash
#!/usr/bin/env bash
#
# check-diagnostic-discipline.sh
#
# Enforces docs/diagnostic-severity-discipline.md. Three rules:
#   1. Raw `DiagramDiagnostic(severity:` outside Sources/DiagramKitCommon/ is
#      forbidden; use .lossyTransform / .featureDropped / .informational.
#   2. Every `// SILENT-DROP(` marker must be followed within 3 lines by a
#      `Pinned by: <TestName>` line, and that test must exist under Tests/.
#   3. Exporters MUST NOT throw DiagramError.malformedSource; emit a
#      .featureDropped diagnostic instead.
#
# Allowlist: .diagnostic-discipline-allowlist.txt at repo root.
# Format: file:line  (one entry per line; comments with # OK)

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ALLOWLIST="$ROOT/.diagnostic-discipline-allowlist.txt"
VIOLATIONS=0

# Load allowlist into an associative array.
declare -A ALLOW
if [[ -f "$ALLOWLIST" ]]; then
  while IFS= read -r entry || [[ -n "$entry" ]]; do
    [[ -z "$entry" || "$entry" =~ ^[[:space:]]*# ]] && continue
    ALLOW["$entry"]=1
  done < "$ALLOWLIST"
fi

# Rule 1 — raw DiagramDiagnostic(severity:) outside Common.
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  loc=$(echo "$hit" | cut -d: -f1-2)
  if [[ -z "${ALLOW["$loc"]:-}" ]]; then
    echo "  $loc: raw DiagramDiagnostic(severity:) — use .lossyTransform/.featureDropped/.informational" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done < <(grep -RIn 'DiagramDiagnostic(severity:' Sources --include='*.swift' \
           --exclude-dir=DiagramKitCommon 2>/dev/null || true)

# Rule 2 — // SILENT-DROP( markers must carry a Pinned by: line within 3 lines
# and the referenced test must exist under Tests/.
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  file=$(echo "$hit" | cut -d: -f1)
  line=$(echo "$hit" | cut -d: -f2)
  end=$((line + 3))
  ctx=$(sed -n "${line},${end}p" "$file" 2>/dev/null || true)
  test_ref=$(echo "$ctx" | grep -oE 'Pinned by:[[:space:]]+\S+' | head -1 | awk '{print $3}')
  if [[ -z "$test_ref" ]]; then
    echo "  $file:$line: SILENT-DROP marker missing 'Pinned by: <Test>' line within 3 lines" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
    continue
  fi
  # Strip leading qualifier (e.g., "Suite.testName" → "testName").
  short="${test_ref##*.}"
  if ! grep -RIlq "func $short\b" Tests/ 2>/dev/null; then
    echo "  $file:$line: SILENT-DROP references missing test '$test_ref'" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done < <(grep -RIn '// SILENT-DROP(' Sources --include='*.swift' 2>/dev/null || true)

# Rule 3 — exporters MUST NOT throw DiagramError.malformedSource.
while IFS= read -r hit; do
  [[ -z "$hit" ]] && continue
  echo "  $hit: exporter throws malformedSource — emit a .featureDropped diagnostic instead" >&2
  VIOLATIONS=$((VIOLATIONS + 1))
done < <(grep -RIn 'throw DiagramError\.malformedSource' \
           Sources --include='*Exporter*.swift' 2>/dev/null || true)

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo "diagnostic-discipline: $VIOLATIONS violation(s)" >&2
  exit 1
fi
echo "diagnostic-discipline: ✓ clean"
exit 0
```

Make executable:

```bash
chmod +x Scripts/check-diagnostic-discipline.sh
```

- [ ] **Step 2: Create the empty allowlist**

```bash
cat > .diagnostic-discipline-allowlist.txt <<'EOF'
# Diagnostic discipline allowlist. Format: <file>:<line>
# Each entry permits a raw DiagramDiagnostic(severity:) construction at that
# exact location. Use only for documented escape-hatch cases (third-party
# test utility echoing, fixture builders, etc.). Production code targets zero
# entries.
EOF
```

- [ ] **Step 3: Run the gate against the real tree**

```bash
Scripts/check-diagnostic-discipline.sh
```

Expected: exit 0 with `diagnostic-discipline: ✓ clean`. If violations report, they identify any emission site missed by Tasks 4-8. Add those sites to the appropriate prior task's commit and re-run — but in this plan, since Tasks 4-8 are already committed, instead either (a) migrate the missed site here, or (b) add it to the allowlist with a comment explaining why. Prefer (a).

- [ ] **Step 4: Create the self-test fixtures**

`Scripts/check-diagnostic-discipline-tests/fixtures/bad-raw-init/Sample.swift`:

```swift
import DiagramKitCommon

func emit() -> DiagramDiagnostic {
    return DiagramDiagnostic(severity: .warning, message: "should fail gate")
}
```

`Scripts/check-diagnostic-discipline-tests/fixtures/bad-missing-pinned/Sample.swift`:

```swift
func process() {
    // SILENT-DROP(I forgot the Pinned-by line)
    return
}
```

`Scripts/check-diagnostic-discipline-tests/fixtures/bad-stale-pinned/Sample.swift`:

```swift
func process() {
    // SILENT-DROP(reasoning):
    // Pinned by: NonexistentTestName
    return
}
```

`Scripts/check-diagnostic-discipline-tests/fixtures/bad-exporter-throws/SampleExporter.swift`:

```swift
import DiagramKitCommon

func exportSomething() throws {
    throw DiagramError.malformedSource(message: "exporters should emit, not throw")
}
```

`Scripts/check-diagnostic-discipline-tests/fixtures/good-clean/Sample.swift`:

```swift
import DiagramKitCommon

func emit() -> DiagramDiagnostic {
    return .lossyTransform(.idSanitization, message: "clean")
}
```

- [ ] **Step 5: Create the self-test driver**

`Scripts/check-diagnostic-discipline-tests/run.sh`:

```bash
#!/usr/bin/env bash
#
# Self-test for check-diagnostic-discipline.sh. Each fixture under
# fixtures/ is a tiny tree containing a violation we expect the gate
# to surface. The driver runs the production script against each
# fixture and asserts the expected exit code.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$ROOT/Scripts/check-diagnostic-discipline.sh"

FAILED=0

run_fixture() {
  local name="$1"
  local expected_exit="$2"

  local sandbox
  sandbox=$(mktemp -d)
  trap "rm -rf '$sandbox'" RETURN

  mkdir -p "$sandbox/Sources" "$sandbox/Tests"
  cp -R "$HERE/fixtures/$name/." "$sandbox/Sources/"
  # Empty Tests/ tree so Rule 2's grep finds nothing (intentional for bad-stale-pinned).

  pushd "$sandbox" >/dev/null
  set +e
  "$GATE" >/dev/null 2>&1
  actual=$?
  set -e
  popd >/dev/null

  if [[ "$actual" -eq "$expected_exit" ]]; then
    echo "  ✓ $name (exit $actual)"
  else
    echo "  ✗ $name expected exit $expected_exit, got $actual" >&2
    FAILED=$((FAILED + 1))
  fi
}

echo "diagnostic-discipline self-test:"
run_fixture "bad-raw-init" 1
run_fixture "bad-missing-pinned" 1
run_fixture "bad-stale-pinned" 1
run_fixture "bad-exporter-throws" 1
run_fixture "good-clean" 0

if [[ "$FAILED" -gt 0 ]]; then
  echo "diagnostic-discipline self-test: $FAILED fixture(s) failed" >&2
  exit 1
fi
echo "diagnostic-discipline self-test: ✓ all fixtures passed"
exit 0
```

Make executable:

```bash
chmod +x Scripts/check-diagnostic-discipline-tests/run.sh
```

- [ ] **Step 6: Run the self-test**

```bash
Scripts/check-diagnostic-discipline-tests/run.sh
```

Expected: 5/5 fixtures pass.

- [ ] **Step 7: Wire into bootstrap-smoke-check.sh**

Edit `Scripts/bootstrap-smoke-check.sh`. Insert after the `run_gate "check-sendable-annotations.sh"` line:

```bash
run_gate "check-diagnostic-discipline.sh" "$ROOT/Scripts/check-diagnostic-discipline.sh"
run_gate "check-diagnostic-discipline-tests/run.sh" "$ROOT/Scripts/check-diagnostic-discipline-tests/run.sh"
```

- [ ] **Step 8: Commit**

```bash
git add Scripts/check-diagnostic-discipline.sh \
        Scripts/check-diagnostic-discipline-tests/ \
        Scripts/bootstrap-smoke-check.sh \
        .diagnostic-discipline-allowlist.txt
git commit -m "$(cat <<'EOF'
build(gate): diagnostic-discipline lint + self-test

Three-rule gate following check-sendable-annotations.sh style:
(1) raw DiagramDiagnostic(severity:) outside DiagramKitCommon
forbidden; (2) // SILENT-DROP( markers must carry a Pinned by: line
referencing an existing test; (3) exporters must not throw
malformedSource. Self-test driver covers all four violation kinds
and one happy-path fixture. Wired into bootstrap-smoke-check.sh
adjacent to the Sendable gate.

Spec §5 + §7 commit 10.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Phase 2 strict — deprecate raw init + delete legacy fallback

**Spec ref:** §3, §6 "Two-phase migration", §7 commit 11

**Files modified:**
- `Sources/DiagramKitCommon/DiagramDiagnostic.swift` — add `@available(*, deprecated, ...)` on the raw init
- `Sources/DiagramKitTestSupport/RoundTripHarness.swift` — delete `_legacyKeywordCover` and its caller branch
- `Tests/DiagramKitTests/RoundTripHarnessDiagnosticPairingTests.swift` — drop the keyword-fallback @Test

**Rationale:** By this point every in-tree emission site uses a factory. The deprecation marker now serves only third-party consumers, and the harness can rely on category equality exclusively.

- [ ] **Step 1: Verify the in-tree migration is complete**

```bash
Scripts/check-diagnostic-discipline.sh
```

Expected: ✓ clean, zero violations, empty allowlist. If non-zero, the migration isn't done — return to the appropriate prior task and finish.

- [ ] **Step 2: Add the deprecation marker**

Edit `Sources/DiagramKitCommon/DiagramDiagnostic.swift`. The raw init becomes:

```swift
/// Back-compatible raw init. **Deprecated** — use the
/// `.lossyTransform` / `.featureDropped` / `.informational`
/// factories with a `DiagnosticCategory`.
/// See `docs/diagnostic-severity-discipline.md`.
@available(*, deprecated,
  message: "Use .lossyTransform/.featureDropped/.informational with a DiagnosticCategory. See docs/diagnostic-severity-discipline.md.")
public init(severity: Severity,
            message: String,
            location: SourceLocation? = nil) {
    self.severity = severity
    self.category = nil
    self.message = message
    self.location = location
}
```

- [ ] **Step 3: Delete the legacy keyword fallback**

Edit `Sources/DiagramKitTestSupport/RoundTripHarness.swift`. Replace `diagnosticsCover` with the strict version:

```swift
/// Tests whether the diagnostic bag contains at least one entry that
/// "explains" this loss — typed-category equality, exclusively.
///
/// `.anonymousSubgraphRename` is exempt — anonymous renames are positional
/// parser artifacts, not exporter-driven, and never carry a paired diagnostic.
public func diagnosticsCover(loss: RoundTripLoss, in diagnostics: [DiagramDiagnostic]) -> Bool {
    if case .anonymousSubgraphRename = loss { return true }
    let expected = loss.kind.expectedCategory
    return diagnostics.contains { diag in
        (diag.severity == .warning || diag.severity == .unsupported)
            && diag.category == expected
    }
}
```

Delete `private func _legacyKeywordCover(loss:message:)` entirely.

- [ ] **Step 4: Drop the keyword-fallback test**

Edit `Tests/DiagramKitTests/RoundTripHarnessDiagnosticPairingTests.swift`. Delete the `keywordFallback` @Test method.

- [ ] **Step 5: Run the round-trip suite + smoke gates**

```bash
swift test --filter "RoundTrip|RoundTripHarnessDiagnosticPairing"
```

Expected: all green. If any cell fails with "unpaired loss," it means some site emitted via the raw init (category nil) and the typed-only matcher can't pair it. Trace and fix at the emission site (move to a factory).

```bash
Scripts/check-diagnostic-discipline.sh
```

Expected: ✓ clean.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitCommon/DiagramDiagnostic.swift \
        Sources/DiagramKitTestSupport/RoundTripHarness.swift \
        Tests/DiagramKitTests/RoundTripHarnessDiagnosticPairingTests.swift
git commit -m "$(cat <<'EOF'
chore(common,test-support): strict phase — deprecate raw init, delete fallback

Raw DiagramDiagnostic(severity:message:) carries
@available(*, deprecated, ...). RoundTripHarness.diagnosticsCover
keeps only the typed-category path; _legacyKeywordCover and its
caller branch deleted. Phase-2-strict per spec §6.

Spec §3 + §6 + §7 commit 11.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Reference doc + doc-sync

**Spec ref:** §7 commit 12

**Files created:**
- `docs/diagnostic-severity-discipline.md`

**Files modified:**
- `CLAUDE.md` — test source count + one cross-reference under "Pipeline" or "Testing And Snapshots"
- `ARCHITECTURE.md` — Diagnostics paragraph gains a link
- `CONTRIBUTING.md` — "Adding a new format slice" / equivalent section gains a link

**Rationale:** The discipline doc is the contributor-facing artifact this whole spec exists to produce.

- [ ] **Step 1: Write `docs/diagnostic-severity-discipline.md`**

Create the file:

```markdown
# Diagnostic Severity Discipline

This document tells you which severity to emit when reporting a non-fatal
issue from a parser, mapper, layout, exporter, or any other slice that
produces a `DiagramDiagnostic`. Follow the decision tree; use the named
factories; if you can't decide, ask in PR review.

## The decision tree

```text
Did the operation fail outright (cannot produce any meaningful output)?
├── YES → THROW
│   ├── Source is structurally invalid for the format
│   │   → throw DiagramError.malformedSource(message:)
│   └── Family/feature exists in the format but not implemented here
│       → throw DiagramError.notYetImplemented(_)
└── NO — operation produced output
    └── Was anything from the input dropped or transformed?
        ├── NO → emit nothing (clean operation)
        └── YES — pick by the two tests below
            │
            ├── Test 1: could a future export-side change restore the original?
            │   (the loss is a current limitation, not a format limitation)
            │   ├── NO  → .featureDropped (severity: .unsupported)
            │   └── YES → Test 2 below
            │
            └── Test 2: does re-parsing the output produce input-equivalent semantics?
                ├── YES → .informational    (severity: .info)
                └── NO  → .lossyTransform   (severity: .warning)
```

## Category → severity table

| Category | Severity | When to emit |
|---|---|---|
| `idSanitization` | `.warning` | Identifier rewritten (spaces/specials → underscores, or collision-suffix). |
| `shapeDowngrade` | `.warning` | Shape kind unavailable in target; nearest equivalent substituted. |
| `subgraphFlatten` | `.warning` | Nested subgraph/cluster collapsed to a sibling. |
| `boundaryFlatten` | `.warning` | Nested boundary collapsed to a sibling (e.g., Structurizr group flatten). |
| `c4SlotDrop` | `.warning` | A C4 positional slot present in input was dropped because target shape supports the slot but exporter chose not to emit it (e.g., Mermaid C4 family that prefers description over tech). |
| `titleDrop` | `.warning` | Diagram title dropped (target has no syntax for it AND the value was non-empty). |
| `configDrop` | `.warning` | Frontmatter / config key dropped. |
| `styleDrop` | `.warning` | Style attribute (class, color, etc.) dropped. |
| `accessibilityDrop` | `.warning` | accTitle / accDescr dropped. |
| `anonymousSubgraphRename` | `.warning` | Anonymous-subgraph id collision auto-renamed. |
| `d2DuplicateOverride` | `.warning` | Second occurrence of D2 node overrode a prior attribute (label/shape/width/height/etc.). |
| `labelNewlineEscape` | `.warning` | Newline in a label collapsed to a space (not round-trip stable). |
| `d2InlineCommentStripped` | `.warning` | D2 `// note` trailing-value strip (value lost). |
| `diagramFamilyUnsupported` | `.unsupported` | Entire diagram family not implemented in this exporter. |
| `slotUnsupported` | `.unsupported` | A specific slot/attribute not expressible in target format. |
| `boundaryTypeUnsupported` | `.unsupported` | A boundary type (e.g., enterprise) not supported by target. |
| `c4ShapeUnsupported` | `.unsupported` | PlantUML/C4 stereotype with no Mermaid equivalent. |
| `identifierEscape` | `.info` | Quoting/escaping at the character level; round-trip stable. |
| `commentPreserved` | `.info` | Block/inline comment skipped, but the structural intent survives. |

## How to emit

```swift
import DiagramKitCommon

// .warning — lossy structural transform
diagnostics.append(.lossyTransform(.idSanitization,
                                    message: "Identifier '\(id)' sanitized to '\(sanitized)'"))

// .unsupported — feature unavailable in target format
diagnostics.append(.featureDropped(.diagramFamilyUnsupported,
                                    message: "Mermaid export does not yet support 'kanban'."))

// .info — encoding-only, round-trip stable
diagnostics.append(.informational(.commentPreserved,
                                   message: "Block comment skipped at line \(n)."))
```

The factories' `precondition` catches wrong-category-for-factory at runtime; the script gate
(`Scripts/check-diagnostic-discipline.sh`) catches raw `DiagramDiagnostic(severity:...)`
constructions outside `Sources/DiagramKitCommon/`.

## Silent-drop policy

Dropping input without any diagnostic is permissible only when **the drop is provably reversible
by the round-trip pair**. Every such site carries a `// SILENT-DROP(...)` marker:

```swift
// SILENT-DROP(viewScopeSynthesized boundaries are re-derived from parent
// relationships on the next import; round-trip-stable).
// Pinned by: StructurizrBoundaryRoundTripTests.viewScopeBoundariesRoundTrip
continue
```

The script gate verifies every `// SILENT-DROP(` marker has a `Pinned by:` line within 3 lines
and that the referenced test exists under `Tests/`. Undeclared silent drops are caught by the
round-trip harness — if the drop isn't round-trip-stable, the harness fails because the resulting
delta isn't covered by an allowed `RoundTripLoss`.

## Throw boundary

| Situation | Throw | Emit |
|---|---|---|
| Parse cannot recover; no output possible | ✓ `DiagramError.malformedSource(message:)` | — |
| Feature exists in the format but not in this build (e.g., new family) | ✓ `DiagramError.notYetImplemented(_)` | — |
| Loss / transform / unsupported in target | — | `.lossyTransform` / `.featureDropped` / `.informational` |

Exporters specifically must NOT throw `DiagramError.malformedSource` — emit
`.featureDropped(...)`. The gate enforces this.

## Cross-references

- Script gate: `Scripts/check-diagnostic-discipline.sh`
- Allowlist: `.diagnostic-discipline-allowlist.txt`
- Round-trip pairing: `RoundTripHarness.diagnosticsCover` in `Sources/DiagramKitTestSupport/`
- Spec: `docs/superpowers/specs/2026-05-15-diagnostic-severity-discipline-design.md`
```

- [ ] **Step 2: Add CLAUDE.md cross-reference + test count sync**

Edit `CLAUDE.md`. In the "Testing And Snapshots" or appropriate nearby section, after the round-trip discipline paragraph, append:

```markdown
**Diagnostic discipline.** Emission sites use the typed
`DiagramDiagnostic.lossyTransform(.<category>, ...)` /
`.featureDropped(.<category>, ...)` / `.informational(.<category>, ...)`
factories; raw `DiagramDiagnostic(severity:message:)` is deprecated.
Decision tree, category table, silent-drop policy, and throw boundary
live in [docs/diagnostic-severity-discipline.md](docs/diagnostic-severity-discipline.md).
Enforced by `Scripts/check-diagnostic-discipline.sh`.
```

Bump the test source count: from current value (per memory, 254) to whatever `find Tests/DiagramKitTests -name '*.swift' | wc -l` reports at this point — likely +4 (the four new test files in Tasks 1-3).

- [ ] **Step 3: Add ARCHITECTURE.md link**

Edit `ARCHITECTURE.md`. In the "Diagnostics" paragraph (added in Session 10), append:

```markdown
See [docs/diagnostic-severity-discipline.md](docs/diagnostic-severity-discipline.md) for
the per-severity contract and category catalog.
```

- [ ] **Step 4: Add CONTRIBUTING.md link**

Edit `CONTRIBUTING.md`. In the format-slice contribution section (find by grepping for "format slice" / "exporter" / similar), append:

```markdown
When emitting diagnostics, use the typed factories
(`DiagramDiagnostic.lossyTransform` / `.featureDropped` / `.informational`) and pick a
`DiagnosticCategory` per the decision tree in
[docs/diagnostic-severity-discipline.md](docs/diagnostic-severity-discipline.md).
```

- [ ] **Step 5: Verify the new doc renders + links resolve**

```bash
ls -la docs/diagnostic-severity-discipline.md \
       Sources/DiagramKitCommon/DiagnosticCategory.swift \
       Sources/DiagramKitCommon/DiagramDiagnostic+Factories.swift \
       Scripts/check-diagnostic-discipline.sh
```

Expected: all four files exist.

- [ ] **Step 6: Commit**

```bash
git add docs/diagnostic-severity-discipline.md CLAUDE.md ARCHITECTURE.md CONTRIBUTING.md
git commit -m "$(cat <<'EOF'
docs: diagnostic severity discipline reference + sync

New docs/diagnostic-severity-discipline.md is the contributor-facing
artifact this work was for. CLAUDE.md picks up the discipline paragraph
and bumps the test source count. ARCHITECTURE.md's Diagnostics
paragraph and CONTRIBUTING.md's format-slice section link in.

Spec §7 commit 12; closes the cross-cutting #2 line of work.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review

### Spec coverage

| Spec section | Task(s) |
|---|---|
| §1 Decision tree | Task 9, 10, 11 (recategorizations) + Task 15 (doc) |
| §2 DiagnosticCategory enum | Task 1 |
| §2 DiagramDiagnostic.category field | Task 2 |
| §3 Static factories | Task 2 |
| §3 Raw-init deprecation | Task 14 |
| §4 Silent-drop policy + marker | Task 12 |
| §5 Script gate | Task 13 |
| §6 Round-trip harness typed pairing | Task 3 |
| §6 Two-phase migration (fallback delete) | Task 14 |
| §7 Doc location | Task 15 |
| §7 Migration sweep commits 3-7 | Tasks 4-8 |
| §7 Migration sweep commit 8 (recat) | Tasks 9, 10, 11 |
| §7 Migration sweep commits 9-12 | Tasks 12, 13, 14, 15 |
| §8 T1 category severity table | Task 1 |
| §8 T2 factory happy-path | Task 2 |
| §8 T3 expectedCategory map | Task 3 |
| §8 T4 typed-first/fallback | Task 3 |
| §8 T5 migration regression | Tasks 9, 10, 11 |
| §8 T6 script gate self-test | Task 13 |

Every spec section maps to at least one task; every test surface T1-T6 is owned.

### Type / signature consistency

- `DiagnosticCategory` is declared in Task 1, referenced in Tasks 2 (factory params), 3 (expectedCategory map), and every emission task. Same case spellings throughout (camelCase like `idSanitization`, `c4SlotDrop`, `labelNewlineEscape`, `d2InlineCommentStripped`).
- `DiagramDiagnostic.lossyTransform(_:message:location:)` signature matches across Task 2 (declaration), Task 4-8 (callsites), Task 9-11 (recategorization callsites), and Task 15 (doc examples).
- `RoundTripLossKind.expectedCategory` is `internal`, matching the access level chosen in spec §6 (test-support owns the contract direction).
- `diagnosticsCover(loss:in:)` keeps its `public` access level and signature across Tasks 3 and 14 — the implementation changes; the API doesn't.
- Script gate's `Pinned by:` token format is consistent across Task 12 (marker examples), Task 13 (script grep), and Task 13 fixtures.

### Risks captured by the plan

- Task 9 step 5, Task 10 step 4, Task 11 step 4 — each calls out the case where a round-trip cell may surface a previously-hidden unpaired loss after recategorization, and offers two resolution paths.
- Task 13 step 3 — calls out the case where the production gate run surfaces a missed emission site after the migration tasks committed, and instructs to either migrate the missed site or allowlist with comment.
- Task 14 step 5 — calls out the case where the strict-phase round-trip run surfaces an un-migrated site, and points back to the relevant prior task to fix.

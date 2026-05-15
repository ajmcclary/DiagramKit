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
| `subgraphFlatten` | `.warning` | Nested subgraph/cluster collapsed to a sibling, or recursion truncation. |
| `boundaryFlatten` | `.warning` | Nested boundary collapsed to a sibling (e.g., Structurizr group flatten), or undefined-boundary reference. |
| `c4SlotDrop` | `.warning` | A C4 positional slot present in input was dropped because target shape supports the slot but exporter chose not to emit it. For slotless target shapes (Person, System on Mermaid), use `.slotUnsupported` instead. |
| `titleDrop` | `.warning` | Diagram title dropped (target has no syntax for it AND the value was non-empty). |
| `configDrop` | `.warning` | Frontmatter / config key / unresolvable reference dropped. |
| `styleDrop` | `.warning` | Style attribute (class, color, etc.) dropped. |
| `accessibilityDrop` | `.warning` | accTitle / accDescr dropped. |
| `anonymousSubgraphRename` | `.warning` | Anonymous-subgraph id collision auto-renamed. Exempt from harness pairing. |
| `d2DuplicateOverride` | `.warning` | Second occurrence of D2 node overrode a prior attribute. |
| `labelNewlineEscape` | `.warning` | Newline in a label collapsed to a space (NOT round-trip stable). |
| `d2InlineCommentStripped` | `.warning` | D2 `// note` trailing-value strip (value lost). |
| `diagramFamilyUnsupported` | `.unsupported` | Entire diagram family not implemented, or an unsupported sub-feature/macro. |
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
// Pinned by: viewScopeBoundariesRoundTrip
// Allowed under §4 of docs/diagnostic-severity-discipline.md.
continue
```

The script gate verifies every `// SILENT-DROP(` marker has a `Pinned by:` line within 6 lines
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
- Self-test driver: `Scripts/check-diagnostic-discipline-tests/run.sh`
- Allowlist: `.diagnostic-discipline-allowlist.txt`
- Round-trip pairing: `RoundTripHarness.diagnosticsCover` in `Sources/DiagramKitTestSupport/`
- Spec: `docs/superpowers/specs/2026-05-15-diagnostic-severity-discipline-design.md`
- Plan: `docs/superpowers/plans/2026-05-15-diagnostic-severity-discipline.md`

# Mermaid C4 `$boundary` / `$parent` Named-Arg Round-Trip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Honor the `$boundary=<alias>` and `$parent=<alias>` named arguments emitted by `MermaidC4Export` so Mermaid → Mermaid C4 round-trip preserves boundary linkage for flat-emit shapes and boundaries.

**Architecture:** Add a public SPI variant `_parseC4DiagramWithDiagnostics(_:frontmatter:)` that returns `(C4Diagram, [DiagramDiagnostic])`. Two new private helpers — `_resolveParentBoundary` (resolution + mismatch `.warning`) and `_validateBoundaryReferences` (post-pass unresolved-ref `.warning`). 28 dispatch-site rewrites in `_parseC4Diagram`'s macro switch route the named-arg lookup through the resolver. The existing `parseC4Diagram` shrinks to a one-line wrapper. Two production registry sites switch to the SPI variant (diagnostics discarded for now — surfacing through the importer is a separate concern).

**Tech Stack:** Swift 6, swift-testing (`@Suite`/`@Test`), SwiftPM, `DiagramKitModel` (parser lives here), `DiagramKit` (umbrella + registries), `DiagramKitImport` (`DiagramDiagnostic` type).

**Spec:** `docs/superpowers/specs/2026-05-14-mermaid-c4-boundary-named-arg-design.md`.

---

## File Structure

**Modify:**
- `Sources/DiagramKitModel/src_c4_parser.swift` — add `_parseC4DiagramWithDiagnostics`, refactor `parseC4Diagram` to wrap it, add two private helpers, rewrite 28 dispatch sites.
- `Sources/DiagramKit/DiagramRegistry+C4.swift:16` — call SPI variant.
- `Sources/DiagramKit/AsciiRenderRegistry.swift:223` — call SPI variant.

**Create:**
- `Tests/DiagramKitTests/C4BoundaryNamedArgTests.swift` — parser unit tests for named-arg resolution + diagnostics.
- `Tests/DiagramKitTests/MermaidC4BoundaryRoundTripTests.swift` — Mermaid → Mermaid round-trip tests.

**Touch (existing test extension):**
- `Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift` — extend `structurizrToMermaidEmit` to re-parse the Mermaid output.

**Sync:**
- `REVIEW.md` — close §7 in the Deferred Effort section.
- `CLAUDE.md` — bump test source count.

---

## Task 1: Add the SPI variant + private helpers

**Files:**
- Modify: `Sources/DiagramKitModel/src_c4_parser.swift`

This task introduces the SPI variant and the two private helpers WITHOUT yet wiring the dispatch sites — that comes in Task 3. After Task 1, behavior is unchanged because the resolver and validator are not called.

- [ ] **Step 1: Read the current parser entry point** to confirm the function signature.

Run: `sed -n '10,12p' Sources/DiagramKitModel/src_c4_parser.swift`
Expected output: `public func parseC4Diagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> C4Diagram {`

- [ ] **Step 2: Refactor the existing function into a one-line wrapper.**

Replace lines 5–10 of `Sources/DiagramKitModel/src_c4_parser.swift`:

```swift
/// Parse a C4 diagram from source lines.
/// - Parameters:
///   - lines: Raw lines of the diagram source (after frontmatter stripping)
///   - frontmatter: Optional frontmatter with C4 config overrides
/// - Returns: A parsed `C4Diagram`
public func parseC4Diagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> C4Diagram {
```

With:

```swift
/// Parse a C4 diagram from source lines.
/// - Parameters:
///   - lines: Raw lines of the diagram source (after frontmatter stripping)
///   - frontmatter: Optional frontmatter with C4 config overrides
/// - Returns: A parsed `C4Diagram`
public func parseC4Diagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> C4Diagram {
    let (diagram, _) = try _parseC4DiagramWithDiagnostics(lines, frontmatter: frontmatter)
    return diagram
}

/// SPI variant of `parseC4Diagram` that also returns the diagnostics produced
/// during the parse pass. Used by registry call sites that route diagnostics
/// upward, and by tests that assert on the warning surface.
public func _parseC4DiagramWithDiagnostics(
    _ lines: [String],
    frontmatter: DiagramFrontmatter? = nil
) throws -> (C4Diagram, [DiagramDiagnostic]) {
```

Then close the original function body (the existing `}` at line 266) and BEFORE that closing brace, change `return diagram` to `return (diagram, diagnostics)` and add `var diagnostics: [DiagramDiagnostic] = []` near the top of the body (next to the `var shapes`/`var boundaries` lines around line 17).

The body of the original `parseC4Diagram` becomes the body of `_parseC4DiagramWithDiagnostics`. The new `parseC4Diagram` is just the wrapper above.

- [ ] **Step 3: Add the two private helpers near the existing `_findMatchingParen`** (around line 400).

Insert after `_findMatchingParen`'s closing brace:

```swift
// MARK: - Boundary resolution helpers

private func _resolveParentBoundary(
    named: [String: String],
    lexical: String,
    key: String,
    macroName: String,
    alias: String,
    diagnostics: inout [DiagramDiagnostic]
) -> String {
    guard let namedValue = named[key], !namedValue.isEmpty else {
        return lexical
    }
    if lexical != "global" && lexical != namedValue {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Mermaid C4 \(macroName)(\(alias)) named arg \(key)=\(namedValue) overrides enclosing \(lexical) — using named value"
        ))
    }
    return namedValue
}

private func _validateBoundaryReferences(
    shapes: [C4Shape],
    boundaries: [C4Boundary],
    diagnostics: inout [DiagramDiagnostic]
) {
    let known: Set<String> = Set(boundaries.map(\.alias)).union(["global", ""])
    for s in shapes where !known.contains(s.parentBoundary) {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Mermaid C4 shape '\(s.alias)' parentBoundary=\(s.parentBoundary) references undefined boundary"
        ))
    }
    for b in boundaries where !known.contains(b.parentBoundary) {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Mermaid C4 boundary '\(b.alias)' parentBoundary=\(b.parentBoundary) references undefined boundary"
        ))
    }
}
```

- [ ] **Step 4: Ensure the `DiagramDiagnostic` type is in scope.**

Run: `grep -n "^import" Sources/DiagramKitModel/src_c4_parser.swift`
Expected: `import Foundation` is the only import.

`DiagramDiagnostic` lives in `DiagramKitCommon`. The file currently has no `import DiagramKitCommon`. Add it under the `import Foundation` line:

```swift
import Foundation
import DiagramKitCommon
```

- [ ] **Step 5: Verify it compiles.**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 6: Verify no test regressions.**

Run: `swift test --filter C4ParserTests`
Expected: all C4 parser tests pass (the wrapper preserves the existing signature; behavior is unchanged because the new helpers aren't called yet).

- [ ] **Step 7: Commit.**

```bash
git add Sources/DiagramKitModel/src_c4_parser.swift
git commit -m "$(cat <<'EOF'
feat(c4): SPI variant `_parseC4DiagramWithDiagnostics` + boundary helpers

Adds a public underscore-prefixed parser entry point that returns
the parsed diagram plus a `[DiagramDiagnostic]` accumulator. The
existing public `parseC4Diagram` becomes a one-line wrapper. Two new
private helpers (`_resolveParentBoundary`, `_validateBoundaryReferences`)
land but are not yet wired — behavior unchanged. Sets up the dispatch
rewrite in the next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Author parser unit tests (TDD red)

**Files:**
- Create: `Tests/DiagramKitTests/C4BoundaryNamedArgTests.swift`

Write the failing tests BEFORE wiring the resolver. After this task the new file compiles and the new tests fail. Task 3 wires the resolver and turns them green.

- [ ] **Step 1: Create the test file with eleven `@Test` cases.**

Write `Tests/DiagramKitTests/C4BoundaryNamedArgTests.swift`:

```swift
import Testing
import Foundation
@testable import DiagramKitModel
@testable import DiagramKitCommon

@Suite struct C4BoundaryNamedArgTests {

    // MARK: - Shape side: $boundary on flat-emit

    @Test func personFlatEmitHonoursBoundary() throws {
        let (diagram, diagnostics) = try _parseC4DiagramWithDiagnostics([
            "C4Context",
            "Boundary(b, \"B\")",
            "Person(p, \"P\") $boundary=b"
        ])
        let p = try #require(diagram.shapes.first { $0.alias == "p" })
        #expect(p.parentBoundary == "b")
        #expect(diagnostics.allSatisfy { $0.severity != .warning })
    }

    @Test func systemFlatEmitHonoursBoundary() throws {
        let (diagram, _) = try _parseC4DiagramWithDiagnostics([
            "C4Context",
            "Boundary(b, \"B\")",
            "System(s, \"S\") $boundary=b"
        ])
        let s = try #require(diagram.shapes.first { $0.alias == "s" })
        #expect(s.parentBoundary == "b")
    }

    @Test func containerFlatEmitHonoursBoundary() throws {
        let (diagram, _) = try _parseC4DiagramWithDiagnostics([
            "C4Container",
            "Boundary(b, \"B\")",
            "Container(c, \"C\", \"Tech\") $boundary=b"
        ])
        let c = try #require(diagram.shapes.first { $0.alias == "c" })
        #expect(c.parentBoundary == "b")
    }

    @Test func componentFlatEmitHonoursBoundary() throws {
        let (diagram, _) = try _parseC4DiagramWithDiagnostics([
            "C4Component",
            "Boundary(b, \"B\")",
            "Component(c, \"C\", \"Tech\") $boundary=b"
        ])
        let c = try #require(diagram.shapes.first { $0.alias == "c" })
        #expect(c.parentBoundary == "b")
    }

    // MARK: - Boundary side: $parent on flat-emit

    @Test func boundaryFlatEmitHonoursParent() throws {
        let (diagram, _) = try _parseC4DiagramWithDiagnostics([
            "C4Context",
            "Boundary(outer, \"Outer\")",
            "Boundary(inner, \"Inner\") $parent=outer"
        ])
        let inner = try #require(diagram.boundaries.first { $0.alias == "inner" })
        #expect(inner.parentBoundary == "outer")
    }

    @Test func enterpriseBoundaryFlatEmitHonoursParent() throws {
        let (diagram, _) = try _parseC4DiagramWithDiagnostics([
            "C4Context",
            "Boundary(outer, \"Outer\")",
            "Enterprise_Boundary(inner, \"Inner\") $parent=outer"
        ])
        let inner = try #require(diagram.boundaries.first { $0.alias == "inner" })
        #expect(inner.parentBoundary == "outer")
    }

    @Test func systemBoundaryFlatEmitHonoursParent() throws {
        let (diagram, _) = try _parseC4DiagramWithDiagnostics([
            "C4Context",
            "Boundary(outer, \"Outer\")",
            "System_Boundary(inner, \"Inner\") $parent=outer"
        ])
        let inner = try #require(diagram.boundaries.first { $0.alias == "inner" })
        #expect(inner.parentBoundary == "outer")
    }

    @Test func containerBoundaryFlatEmitHonoursParent() throws {
        let (diagram, _) = try _parseC4DiagramWithDiagnostics([
            "C4Container",
            "Boundary(outer, \"Outer\")",
            "Container_Boundary(inner, \"Inner\") $parent=outer"
        ])
        let inner = try #require(diagram.boundaries.first { $0.alias == "inner" })
        #expect(inner.parentBoundary == "outer")
    }

    @Test func deploymentNodeFlatEmitHonoursParent() throws {
        let (diagram, _) = try _parseC4DiagramWithDiagnostics([
            "C4Deployment",
            "Deployment_Node(outer, \"Outer\")",
            "Deployment_Node(inner, \"Inner\") $parent=outer"
        ])
        let inner = try #require(diagram.boundaries.first { $0.alias == "inner" })
        #expect(inner.parentBoundary == "outer")
    }

    // MARK: - Lexical-only path still works

    @Test func nestedWithoutNamedArgUsesLexical() throws {
        let (diagram, diagnostics) = try _parseC4DiagramWithDiagnostics([
            "C4Context",
            "Boundary(outer, \"Outer\") {",
            "  System(s, \"S\")",
            "}"
        ])
        let s = try #require(diagram.shapes.first { $0.alias == "s" })
        #expect(s.parentBoundary == "outer")
        #expect(diagnostics.allSatisfy { $0.severity != .warning })
    }

    // MARK: - Mismatch warning

    @Test func mismatchEmitsWarningAndNamedWins() throws {
        let (diagram, diagnostics) = try _parseC4DiagramWithDiagnostics([
            "C4Context",
            "Boundary(outer, \"Outer\")",
            "Boundary(other, \"Other\")",
            "Boundary(outer, \"Outer\") {",
            "  System(s, \"S\") $boundary=other",
            "}"
        ])
        let s = try #require(diagram.shapes.first { $0.alias == "s" })
        #expect(s.parentBoundary == "other")
        let warnings = diagnostics.filter { $0.severity == .warning }
        #expect(warnings.count == 1)
        #expect(warnings[0].message.contains("outer"))
        #expect(warnings[0].message.contains("other"))
    }

    // MARK: - Forward-ref OK

    @Test func forwardRefSetsParentNoWarning() throws {
        let (diagram, diagnostics) = try _parseC4DiagramWithDiagnostics([
            "C4Context",
            "System(s, \"S\") $boundary=later",
            "Boundary(later, \"Later\")"
        ])
        let s = try #require(diagram.shapes.first { $0.alias == "s" })
        #expect(s.parentBoundary == "later")
        #expect(diagnostics.allSatisfy { $0.severity != .warning })
    }

    // MARK: - Unresolved-ref warning

    @Test func unresolvedRefEmitsWarning() throws {
        let (diagram, diagnostics) = try _parseC4DiagramWithDiagnostics([
            "C4Context",
            "System(s, \"S\") $boundary=nowhere"
        ])
        let s = try #require(diagram.shapes.first { $0.alias == "s" })
        #expect(s.parentBoundary == "nowhere")
        let warnings = diagnostics.filter { $0.severity == .warning }
        #expect(warnings.count == 1)
        #expect(warnings[0].message.contains("nowhere"))
    }
}
```

- [ ] **Step 2: Run the new tests and confirm they fail.**

Run: `swift test --filter C4BoundaryNamedArgTests`
Expected: tests compile but fail. Most should fail with `parentBoundary == "global"` (the dispatcher still writes the lexical value). The mismatch / forward-ref / unresolved-ref tests fail on the warning-count assertions.

- [ ] **Step 3: Commit the failing tests.**

```bash
git add Tests/DiagramKitTests/C4BoundaryNamedArgTests.swift
git commit -m "$(cat <<'EOF'
test(c4): pin $boundary / $parent named-arg parser contract (red)

Twelve failing @Tests covering Person/System/Container/Component
shape-side $boundary=, Boundary/Enterprise/System/Container_Boundary
and Deployment_Node $parent=, lexical fallback, mismatch warning,
forward-ref, and unresolved-ref warning. Wiring lands in the next
commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Wire the resolver into the dispatch switch (TDD green)

**Files:**
- Modify: `Sources/DiagramKitModel/src_c4_parser.swift` — 28 dispatch-site rewrites + one validator call.

After Task 1 the helpers exist but are unreachable. This task replaces each `_addPersonOrSystem`/`_addContainerOrComponent`/`_addBoundary`/`_addDeploymentNode` callsite's `currentBoundary: currentBoundaryParse` argument with `currentBoundary: <resolved>`, where `<resolved>` is computed by `_resolveParentBoundary`.

- [ ] **Step 1: Add the validator call before `return (diagram, diagnostics)`** (currently `return diagram` at the original line 265, moved into the SPI variant after Task 1).

Locate the lines (in the SPI variant body):

```swift
    diagram.shapes = shapes
    diagram.boundaries = boundaries
    diagram.relationships = relationships

    return (diagram, diagnostics)
}
```

Insert immediately above the `return`:

```swift
    _validateBoundaryReferences(shapes: shapes, boundaries: boundaries, diagnostics: &diagnostics)
```

- [ ] **Step 2: Rewrite the 8 `_addPersonOrSystem` dispatch sites** (Person/Person_Ext/System/SystemDb/SystemQueue/System_Ext/SystemDb_Ext/SystemQueue_Ext, currently at lines 144–158).

For each call, replace the `currentBoundary: currentBoundaryParse` argument with the resolver call. Example for `case "Person":`:

```swift
case "Person":
    let alias = positional.safe(0) ?? ""
    let effectiveBoundary = _resolveParentBoundary(
        named: named, lexical: currentBoundaryParse, key: "boundary",
        macroName: "Person", alias: alias, diagnostics: &diagnostics
    )
    _addPersonOrSystem(
        type: .person, alias: alias,
        label: positional.safe(1) ?? "",
        descr: positional.safe(2), sprite: positional.safe(3), tags: positional.safe(4),
        named: named, shapes: &shapes,
        currentBoundary: effectiveBoundary, wrap: wrapEnabled
    )
```

Apply the same pattern to the remaining seven cases. The `macroName` string must match the macro name (`"Person_Ext"`, `"System"`, `"SystemDb"`, `"SystemQueue"`, `"System_Ext"`, `"SystemDb_Ext"`, `"SystemQueue_Ext"`).

- [ ] **Step 3: Rewrite the 12 `_addContainerOrComponent` dispatch sites** (Container/ContainerDb/ContainerQueue/Container_Ext/ContainerDb_Ext/ContainerQueue_Ext at lines 162–172; Component/ComponentDb/ComponentQueue/Component_Ext/ComponentDb_Ext/ComponentQueue_Ext at lines 176–186).

For each, the pattern is:

```swift
case "Container":
    let alias = positional.safe(0) ?? ""
    let effectiveBoundary = _resolveParentBoundary(
        named: named, lexical: currentBoundaryParse, key: "boundary",
        macroName: "Container", alias: alias, diagnostics: &diagnostics
    )
    _addContainerOrComponent(
        type: .container, alias: alias,
        label: positional.safe(1) ?? "",
        techn: positional.safe(2), descr: positional.safe(3),
        sprite: positional.safe(4), tags: positional.safe(5),
        named: named, shapes: &shapes,
        currentBoundary: effectiveBoundary, wrap: wrapEnabled
    )
```

Apply to the eleven other container/component cases with the matching `macroName`.

- [ ] **Step 4: Rewrite the 4 `_addBoundary` dispatch sites** (Boundary/Enterprise_Boundary/System_Boundary/Container_Boundary at lines 189–199).

For each, the resolver uses `key: "parent"`. Example:

```swift
case "Boundary":
    let alias = positional.safe(0) ?? ""
    let effectiveParent = _resolveParentBoundary(
        named: named, lexical: currentBoundaryParse, key: "parent",
        macroName: "Boundary", alias: alias, diagnostics: &diagnostics
    )
    _addBoundary(
        alias: alias, label: positional.safe(1) ?? "",
        type: positional.safe(2) ?? "system", tags: positional.safe(3),
        named: named, nodeType: nil, boundaries: &boundaries,
        currentBoundary: &currentBoundaryParse,
        parentBoundary: &parentBoundaryParse,
        stack: &boundaryParseStack, wrap: wrapEnabled
    )
    if let idx = boundaries.firstIndex(where: { $0.alias == alias }) {
        boundaries[idx].parentBoundary = effectiveParent
    }
    if hasBrace { if braceLine != nil { i += 1 } }
```

Note the post-`_addBoundary` rewrite of `parentBoundary` — `_addBoundary` mutates `currentBoundaryParse` and pushes onto the stack as a side-effect, so we let it run normally and then override the just-appended/just-updated boundary's `parentBoundary` field. This keeps `_addBoundary`'s stack semantics intact while letting the named-arg override land.

Apply the same shape to `Enterprise_Boundary`, `System_Boundary`, `Container_Boundary`.

- [ ] **Step 5: Rewrite the 4 `_addDeploymentNode` dispatch sites** (Deployment_Node/Node/Node_L/Node_R at lines 204–213).

Same shape as `_addBoundary` — `_addDeploymentNode` also pushes onto the stack. Resolver uses `key: "parent"`:

```swift
case "Deployment_Node":
    let alias = positional.safe(0) ?? ""
    let effectiveParent = _resolveParentBoundary(
        named: named, lexical: currentBoundaryParse, key: "parent",
        macroName: "Deployment_Node", alias: alias, diagnostics: &diagnostics
    )
    _addDeploymentNode(
        nodeType: "node", alias: alias,
        label: positional.safe(1) ?? "",
        type: positional.safe(2), descr: positional.safe(3),
        sprite: positional.safe(4), tags: positional.safe(5),
        named: named, boundaries: &boundaries,
        currentBoundary: &currentBoundaryParse,
        parentBoundary: &parentBoundaryParse,
        stack: &boundaryParseStack, wrap: wrapEnabled
    )
    if let idx = boundaries.firstIndex(where: { $0.alias == alias }) {
        boundaries[idx].parentBoundary = effectiveParent
    }
```

Apply to `Node` (nodeType `"node"`), `Node_L` (nodeType `"nodeL"`), `Node_R` (nodeType `"nodeR"`).

- [ ] **Step 6: Run the new tests; they should pass.**

Run: `swift test --filter C4BoundaryNamedArgTests`
Expected: all twelve `@Test`s pass.

- [ ] **Step 7: Run the existing C4 tests; they should still pass.**

Run: `swift test --filter C4ParserTests`
Expected: every existing test in `C4ParserTests` still passes — those fixtures don't use `$boundary`/`$parent` named args, and the lexical-only path is preserved.

- [ ] **Step 8: Commit.**

```bash
git add Sources/DiagramKitModel/src_c4_parser.swift
git commit -m "$(cat <<'EOF'
fix(c4): honour \$boundary= / \$parent= named args on flat-emit

Closes REVIEW.md Deferred Effort §7. Twenty-eight dispatch sites in
_parseC4DiagramWithDiagnostics's macro switch now route through the
new _resolveParentBoundary helper, which prefers the named arg over
the lexical stack and emits a .warning on mismatch. Post-pass
_validateBoundaryReferences flags references to undefined boundaries.

C4BoundaryNamedArgTests (twelve @Tests) goes green; existing
C4ParserTests stays green (lexical-only path unchanged).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Switch production registry sites to the SPI variant

**Files:**
- Modify: `Sources/DiagramKit/DiagramRegistry+C4.swift:16`
- Modify: `Sources/DiagramKit/AsciiRenderRegistry.swift:223`

Both registry shapes currently return `DiagramDocument` / `String` and have no diagnostic channel. Calling the SPI variant lets the parser's diagnostic flow start at this layer; surfacing them upward to `DiagramImportResult.diagnostics` is a separate concern (deferred — noted in the spec's "Risks" section). Until that lands, the registry sites discard the diagnostics but the call shape is correct.

- [ ] **Step 1: Update `DiagramRegistry+C4.swift:16`.**

Replace:

```swift
parse: { source, frontmatter in
    try parseC4Diagram(DiagramSourceNormalizer.rawLines(source), frontmatter: frontmatter)
},
```

With:

```swift
parse: { source, frontmatter in
    let (diagram, _) = try _parseC4DiagramWithDiagnostics(
        DiagramSourceNormalizer.rawLines(source),
        frontmatter: frontmatter
    )
    return diagram
},
```

- [ ] **Step 2: Update `AsciiRenderRegistry.swift:223`.**

Replace:

```swift
let model = try parseC4Diagram(rawLines, frontmatter: frontmatter)
return renderC4Ascii(model)
```

With:

```swift
let (model, _) = try _parseC4DiagramWithDiagnostics(rawLines, frontmatter: frontmatter)
return renderC4Ascii(model)
```

- [ ] **Step 3: Build to confirm both modules still link.**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Run the existing C4 tests and the new boundary-named-arg tests together.**

Run: `swift test --filter "C4ParserTests|C4BoundaryNamedArgTests|C4SlotSemanticsTests|C4LayoutTests|C4SvgTests"`
Expected: all green.

- [ ] **Step 5: Commit.**

```bash
git add Sources/DiagramKit/DiagramRegistry+C4.swift Sources/DiagramKit/AsciiRenderRegistry.swift
git commit -m "$(cat <<'EOF'
refactor(c4): registry sites call _parseC4DiagramWithDiagnostics

Both Mermaid C4 registry entry points (DiagramRegistry+C4 parse
closure and AsciiRenderRegistry render closure) switch to the SPI
variant. Diagnostics are discarded at this layer for now —
surfacing them upward through DiagramImportResult is a separate
concern. Public parseC4Diagram unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Mermaid → Mermaid round-trip tests

**Files:**
- Create: `Tests/DiagramKitTests/MermaidC4BoundaryRoundTripTests.swift`

- [ ] **Step 1: Write the round-trip tests.**

Write `Tests/DiagramKitTests/MermaidC4BoundaryRoundTripTests.swift`:

```swift
import Testing
import Foundation
@testable import DiagramKitModel
@testable import DiagramKitMermaid

@Suite struct MermaidC4BoundaryRoundTripTests {

    @Test func flatEmitBoundaryRoundTripPreservesParent() throws {
        let source = """
        C4Context
        Boundary(biz, "Biz")
        System(s, "S") $boundary=biz
        Boundary(outer, "Outer")
        Boundary(inner, "Inner") $parent=outer
        """
        let (firstPass, _) = try _parseC4DiagramWithDiagnostics(source.components(separatedBy: "\n"))
        let exported = try MermaidC4Export.emit(firstPass)
        let (secondPass, _) = try _parseC4DiagramWithDiagnostics(exported.source.components(separatedBy: "\n"))

        let firstS = try #require(firstPass.shapes.first { $0.alias == "s" })
        let secondS = try #require(secondPass.shapes.first { $0.alias == "s" })
        #expect(firstS.parentBoundary == secondS.parentBoundary)
        #expect(secondS.parentBoundary == "biz")

        let firstInner = try #require(firstPass.boundaries.first { $0.alias == "inner" })
        let secondInner = try #require(secondPass.boundaries.first { $0.alias == "inner" })
        #expect(firstInner.parentBoundary == secondInner.parentBoundary)
        #expect(secondInner.parentBoundary == "outer")
    }

    @Test func nestedFormParsesToSameShapeAsFlatEmit() throws {
        let nested = """
        C4Context
        Boundary(biz, "Biz") {
          System(s, "S")
        }
        """
        let flat = """
        C4Context
        Boundary(biz, "Biz")
        System(s, "S") $boundary=biz
        """
        let (nestedDoc, _) = try _parseC4DiagramWithDiagnostics(nested.components(separatedBy: "\n"))
        let (flatDoc, _) = try _parseC4DiagramWithDiagnostics(flat.components(separatedBy: "\n"))

        let nestedS = try #require(nestedDoc.shapes.first { $0.alias == "s" })
        let flatS = try #require(flatDoc.shapes.first { $0.alias == "s" })
        #expect(nestedS.parentBoundary == flatS.parentBoundary)
        #expect(nestedS.parentBoundary == "biz")
    }
}
```

- [ ] **Step 2: Run the round-trip tests.**

Run: `swift test --filter MermaidC4BoundaryRoundTripTests`
Expected: both `@Test`s pass.

- [ ] **Step 3: Commit.**

```bash
git add Tests/DiagramKitTests/MermaidC4BoundaryRoundTripTests.swift
git commit -m "$(cat <<'EOF'
test(c4): Mermaid → Mermaid \$boundary / \$parent round-trip

Two @Tests pin the round-trip closure: flat-emit through
parse → export → parse preserves both shape \$boundary and
boundary \$parent; nested Boundary(...) { ... } form and
flat-emit form parse to the same C4Diagram shape.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Extend Session 6's Structurizr → Mermaid round-trip

**Files:**
- Modify: `Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift`

Session 6's `structurizrToMermaidEmit` stops short of re-parsing the Mermaid output because flat-emit `$boundary=` was dropped. Now that's fixed.

- [ ] **Step 1: Remove the obsolete "intentionally NOT asserted" comment block** at the top of `structurizrToMermaidEmit` (lines 93–100). The closure note for §7 makes it inaccurate.

- [ ] **Step 2: Extend `structurizrToMermaidEmit` to re-parse the Mermaid output.**

The existing fixture has one shape with alias `p1` inside `group "G0" { … }`. After the existing three `#expect(mermaidSource.contains(...))` assertions (lines 118–120), add:

```swift
// Now that Mermaid C4 parser honours $boundary= named args, re-parse the
// emitted Mermaid and assert the boundary linkage survives end-to-end.
let (reparsed, _) = try _parseC4DiagramWithDiagnostics(
    mermaidSource.components(separatedBy: "\n")
)
let reparsedP1 = try #require(reparsed.shapes.first { $0.alias == "p1" })
#expect(reparsedP1.parentBoundary == "G0")
#expect(reparsed.boundaries.contains { $0.alias == "G0" })
```

The `mermaidSource` variable is already in scope from line 116.

- [ ] **Step 3: Run the extended test.**

Run: `swift test --filter StructurizrBoundaryRoundTripTests`
Expected: all tests in the suite pass, including the now-extended `structurizrToMermaidEmit`.

- [ ] **Step 4: Commit.**

```bash
git add Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift
git commit -m "$(cat <<'EOF'
test(structurizr): re-parse Mermaid output in structurizrToMermaidEmit

Session 6 left this assertion short because Mermaid C4 \$boundary=
named args were dropped on re-parse. With Deferred Effort §7 closed,
the Mermaid emit now round-trips. The test re-parses and asserts
that the shapes originally inside a Structurizr group { ... } block
carry the expected boundary alias.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Sync REVIEW.md and CLAUDE.md

**Files:**
- Modify: `REVIEW.md` — close §7 in Deferred Effort.
- Modify: `CLAUDE.md` — bump test source count.

- [ ] **Step 1: Add a "Session 9 (2026-05-14)" Resolution Status block to `REVIEW.md`** above the Deferred Effort section (mirroring Sessions 1–8 conventions).

Open `REVIEW.md` and locate the boundary between Session 8's block and the `## Deferred Effort — Recommendations` heading (around line 183). Insert before that heading:

```markdown
## Resolution Status — Session 9 (2026-05-14)

Closes Deferred Effort §7 → Mermaid C4 parser ignores `$boundary` named arg (surfaced Session 6). Spec at `docs/superpowers/specs/2026-05-14-mermaid-c4-boundary-named-arg-design.md`; plan at `docs/superpowers/plans/2026-05-14-mermaid-c4-boundary-named-arg.md`. Six commits on `main` (two docs + four implementation + test).

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | §7 SPI variant + helpers | `<sha1>` | `Sources/DiagramKitModel/src_c4_parser.swift` gains `_parseC4DiagramWithDiagnostics` returning `(C4Diagram, [DiagramDiagnostic])`. Existing `parseC4Diagram` shrinks to a one-line wrapper. Two private helpers (`_resolveParentBoundary`, `_validateBoundaryReferences`) land but aren't wired yet. |
| 2 | §7 Parser unit tests (red) | `<sha2>` | New `Tests/DiagramKitTests/C4BoundaryNamedArgTests.swift` — twelve `@Test`s covering shape `$boundary`, boundary `$parent`, deployment-node `$parent`, lexical fallback, mismatch warning, forward-ref, unresolved-ref. |
| 3 | §7 Dispatch rewrite (green) | `<sha3>` | 28 macro-dispatch sites in the SPI variant route through `_resolveParentBoundary`. Validator call lands before `return`. Both `_addBoundary` and `_addDeploymentNode` sites override the just-appended boundary's `parentBoundary` so the stack semantics stay intact. |
| 4 | §7 Registry sites | `<sha4>` | `Sources/DiagramKit/DiagramRegistry+C4.swift:16` and `Sources/DiagramKit/AsciiRenderRegistry.swift:223` call `_parseC4DiagramWithDiagnostics`. Diagnostics are discarded at this layer for now — surfacing through `DiagramImportResult.diagnostics` is a separate concern. |
| 5 | §7 Round-trip tests | `<sha5>` | New `Tests/DiagramKitTests/MermaidC4BoundaryRoundTripTests.swift` — two `@Test`s pinning flat-emit round-trip and nested↔flat semantic equivalence. |
| 6 | §7 Structurizr extension | `<sha6>` | `Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift`'s `structurizrToMermaidEmit` re-parses the Mermaid output and asserts the boundary alias survives. |

Session-end verification: `swift test --filter "C4ParserTests|C4BoundaryNamedArgTests|MermaidC4BoundaryRoundTripTests|C4SlotSemanticsTests|C4LayoutTests|C4SvgTests|StructurizrBoundaryRoundTripTests"` all green. `Scripts/check-sendable-annotations.sh` ✓ green. `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings; `src_c4_parser.swift` grows by ~90 lines but stays well under the 500-line warn threshold.

**Deferred follow-up**: surfacing parser diagnostics through `DiagramImportResult.diagnostics` requires widening the registry `parse:` closure shape. Out of scope for this session.

---
```

Fill in the six commit shas after running `git log --oneline -n 8 main`.

- [ ] **Step 2: Update the `§7` bullet in Deferred Effort to reflect closure.**

Find the existing `### 7. Mermaid C4 parser ignores $boundary named arg (new, surfaced Session 6)` section (around line 263) and prepend a closure note:

```markdown
### 7. Mermaid C4 parser ignores `$boundary` named arg (new, surfaced Session 6)

✅ **Closed by Session 9 (`<sha1>` → `<sha6>`):** `_parseC4DiagramWithDiagnostics` is the SPI variant that surfaces diagnostics; `_resolveParentBoundary` honours `named["boundary"]` for shapes and `named["parent"]` for boundaries / deployment nodes, with `.warning` on lexical-vs-named mismatch and on unresolved refs. Mermaid → Mermaid round-trip pinned; Session 6's `structurizrToMermaidEmit` now re-parses end-to-end.
```

Leave the original prose below the closure note for historical context (mirroring the §1–§6 pattern).

- [ ] **Step 3: Bump the `CLAUDE.md` test source count.**

Run: `find Tests/DiagramKitTests -name '*.swift' | wc -l`
Expected: 238 (was 236 before this work; two new test files added).

Open `CLAUDE.md`, locate the line `- Current test source count: 236 Swift files under \`Tests/DiagramKitTests\`.` and update to `238`.

- [ ] **Step 4: Verify all green.**

Run: `swift test --filter "C4ParserTests|C4BoundaryNamedArgTests|MermaidC4BoundaryRoundTripTests|StructurizrBoundaryRoundTripTests"`
Expected: all green.

- [ ] **Step 5: Commit.**

```bash
git add REVIEW.md CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(review,claude): close REVIEW §7; bump test source count to 238

Records Session 9 closure of Mermaid C4 \$boundary / \$parent
named-arg round-trip across six commits. CLAUDE.md test source
count synced for the two new test files
(C4BoundaryNamedArgTests, MermaidC4BoundaryRoundTripTests).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Done

All seven tasks complete. Final verification:

- [ ] **Final check: full C4 + Structurizr-boundary suite green.**

Run: `swift test --filter "C4ParserTests|C4BoundaryNamedArgTests|MermaidC4BoundaryRoundTripTests|C4SlotSemanticsTests|C4LayoutTests|C4SvgTests|StructurizrBoundaryRoundTripTests"`
Expected: all green.

- [ ] **Final check: sendable + file-size gates.**

Run: `Scripts/check-sendable-annotations.sh && Scripts/check-file-sizes.sh`
Expected: both green (file-size will report pre-existing yellow warnings only).

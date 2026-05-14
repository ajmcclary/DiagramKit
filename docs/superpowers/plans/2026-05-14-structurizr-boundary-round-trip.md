# Structurizr Boundary Round-Trip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Mermaid C4 ⇄ Structurizr round-trip for `C4Diagram.boundaries` via Structurizr DSL's `group "label" { … }` directive.

**Architecture:** Tag each `C4Boundary` with a `C4BoundaryOrigin` so the Structurizr exporter can distinguish boundaries the user authored (re-emit as `group { … }`) from boundaries the importer synthesized from the view scope (silent drop — they re-derive on next import). Add `group: String?` to `StructurizrModelElement`; parser tags elements that appear inside `group "label" { … }`; mapper materializes one `.authored` `C4Boundary` per group label; exporter partitions on origin. Mermaid's nested boundaries flatten to sibling Structurizr groups with one `.warning` per dropped parent link.

**Tech Stack:** Swift 6, swift-testing (`@Suite`, `@Test`, `#expect`, `#require`), SwiftPM. Library targets `DiagramKitModel` (where `C4Boundary` lives) and `DiagramKitStructurizr` (parser/mapper/exporter). Test target `DiagramKitTests`. Run tests with `swift test --filter <name>`.

**Spec reference:** `docs/superpowers/specs/2026-05-14-structurizr-boundary-round-trip-design.md` (commit `e26795a`).

**Working directory:** `/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift`. Commit-by-commit on `main` — no branches, no worktrees (per project standing default).

---

## Task 1: `C4BoundaryOrigin` enum and `C4Boundary.origin` field

**Files:**
- Create: `Tests/DiagramKitTests/C4BoundaryOriginTests.swift`
- Modify: `Sources/DiagramKitModel/src_c4_types.swift` (around line 375–415)

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/C4BoundaryOriginTests.swift`:

```swift
import Foundation
import Testing
import DiagramKitModel

@Suite("C4BoundaryOrigin")
struct C4BoundaryOriginTests {

    @Test("Default origin is .authored")
    func defaultOriginIsAuthored() {
        let boundary = C4Boundary(alias: "b0", label: "Group 0")
        #expect(boundary.origin == .authored)
    }

    @Test("Origin round-trips through Equatable")
    func originRoundTrips() {
        let a = C4Boundary(alias: "b0", label: "G", origin: .authored)
        let b = C4Boundary(alias: "b0", label: "G", origin: .authored)
        let c = C4Boundary(alias: "b0", label: "G", origin: .viewScopeSynthesized)
        #expect(a == b)
        #expect(a != c)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter C4BoundaryOriginTests`
Expected: build error referencing `C4BoundaryOrigin` not in scope (the type doesn't exist yet) or `origin:` argument label not found on `C4Boundary.init`.

- [ ] **Step 3: Add the enum and the field**

In `Sources/DiagramKitModel/src_c4_types.swift`, immediately above the existing `public struct C4Boundary` (around line 374), add:

```swift
public enum C4BoundaryOrigin: Sendable, Equatable {
    /// Boundary was authored explicitly in the source (Mermaid `Boundary(...)`,
    /// Structurizr `group "..." { ... }`). Exporters re-emit it.
    case authored

    /// Boundary was synthesized by the importer from the view scope.
    /// Exporters do not re-emit it because the next import re-derives it
    /// from the same view scope.
    case viewScopeSynthesized
}
```

Inside `C4Boundary`, add the stored property after `borderColor`:

```swift
public var origin: C4BoundaryOrigin
```

Add the parameter at the end of the `init` signature (default `.authored`):

```swift
public init(
    alias: String,
    label: String,
    type: String? = nil,
    description: String? = nil,
    tags: String? = nil,
    link: String? = nil,
    parentBoundary: String = "",
    nodeType: String? = nil,
    wrap: Bool = false,
    bgColor: String? = nil,
    fontColor: String? = nil,
    borderColor: String? = nil,
    origin: C4BoundaryOrigin = .authored
) {
```

And inside the init body, after the existing `self.borderColor = borderColor` line, add:

```swift
self.origin = origin
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter C4BoundaryOriginTests`
Expected: `Test run with 2 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitModel/src_c4_types.swift Tests/DiagramKitTests/C4BoundaryOriginTests.swift
git commit -m "$(cat <<'EOF'
feat(model): C4BoundaryOrigin enum and C4Boundary.origin field

Adds the origin tag (.authored vs .viewScopeSynthesized) so the
Structurizr exporter can partition boundaries the user authored from
boundaries the importer synthesized from view scope. Non-breaking init
change (default .authored).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `StructurizrModelElement.group` field

**Files:**
- Create: `Tests/DiagramKitTests/StructurizrASTGroupTests.swift`
- Modify: `Sources/DiagramKitStructurizr/StructurizrAST.swift` (around line 44–73)

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/StructurizrASTGroupTests.swift`:

```swift
import Foundation
import Testing
import DiagramKitStructurizr

@Suite("StructurizrModelElement.group")
struct StructurizrASTGroupTests {

    @Test("Group defaults to nil")
    func groupDefaultsToNil() {
        let element = StructurizrModelElement(
            alias: "u",
            kind: .person,
            name: "User"
        )
        #expect(element.group == nil)
    }

    @Test("Group accepts a label string")
    func groupAcceptsLabel() {
        var element = StructurizrModelElement(
            alias: "u",
            kind: .person,
            name: "User"
        )
        element.group = "Group 0"
        #expect(element.group == "Group 0")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter StructurizrASTGroupTests`
Expected: build error referencing `group` property not found on `StructurizrModelElement`.

- [ ] **Step 3: Add the field**

In `Sources/DiagramKitStructurizr/StructurizrAST.swift`, inside `public struct StructurizrModelElement` (around line 44), add a new stored property after `children`:

```swift
public var group: String?
```

In the `init` signature, add a parameter just before the closing paren (default `nil`):

```swift
public init(
    alias: String,
    kind: StructurizrElementKind,
    name: String,
    description: String? = nil,
    technology: String? = nil,
    tags: [String] = [],
    parentAlias: String? = nil,
    children: [StructurizrModelElement] = [],
    group: String? = nil
) {
```

In the init body, after `self.children = children`, add:

```swift
self.group = group
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter StructurizrASTGroupTests`
Expected: `Test run with 2 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrAST.swift Tests/DiagramKitTests/StructurizrASTGroupTests.swift
git commit -m "$(cat <<'EOF'
feat(structurizr): StructurizrModelElement.group field

Optional `group: String?` carries the group label set by parseGroup
when an element appears inside `group "label" { ... }`. Non-breaking
init change (default nil).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Parser — `parseGroup` happy path

**Files:**
- Create: `Tests/DiagramKitTests/StructurizrParserGroupTests.swift`
- Modify: `Sources/DiagramKitStructurizr/StructurizrParser.swift` (around line 75–98 and add helper)

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/StructurizrParserGroupTests.swift`:

```swift
import Foundation
import Testing
import DiagramKitImport
@testable import DiagramKitStructurizr

@Suite("StructurizrParser group")
struct StructurizrParserGroupTests {

    private func parse(_ source: String) throws -> (workspace: StructurizrWorkspace, diagnostics: [DiagramDiagnostic]) {
        let tokens = StructurizrLexer().tokenize(source)
        return try StructurizrParser().parse(tokens)
    }

    private func elementsByAlias(_ workspace: StructurizrWorkspace) -> [String: StructurizrModelElement] {
        var map: [String: StructurizrModelElement] = [:]
        func walk(_ el: StructurizrModelElement) {
            map[el.alias] = el
            for child in el.children { walk(child) }
        }
        for el in workspace.model?.elements ?? [] { walk(el) }
        return map
    }

    @Test("Single group tags its element")
    func singleGroupTags() throws {
        let source = """
        workspace {
          model {
            group "Group 0" {
              u = person "User"
            }
          }
          views {
            systemContext u {
              include *
            }
          }
        }
        """
        let (workspace, _) = try parse(source)
        let map = elementsByAlias(workspace)
        #expect(map["u"]?.group == "Group 0")
    }

    @Test("Two adjacent groups produce two tagged sets")
    func twoAdjacentGroups() throws {
        let source = """
        workspace {
          model {
            group "A" {
              p1 = person "P1"
            }
            group "B" {
              p2 = person "P2"
            }
          }
          views {
            systemContext p1 {
              include *
            }
          }
        }
        """
        let (workspace, _) = try parse(source)
        let map = elementsByAlias(workspace)
        #expect(map["p1"]?.group == "A")
        #expect(map["p2"]?.group == "B")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter StructurizrParserGroupTests`
Expected: both tests FAIL — the parser currently emits an `unexpected model statement: group` diagnostic, so `u` and `p1`/`p2` may be missing entirely or untagged (group field is nil).

- [ ] **Step 3: Add `parseGroup` and dispatch in `parseModel`**

In `Sources/DiagramKitStructurizr/StructurizrParser.swift`, inside `parseModel(_:)` at the top of the `while let token = s.peek()` loop body — after the `closeBrace`/`tags`/`bang` branches and BEFORE the `.identifier` element-def/relationship branch — add:

```swift
if case .identifier("group") = token {
    let tagged = try parseGroup(&s, scopedRelationships: &relationships)
    elements.append(contentsOf: tagged)
    continue
}
```

At the bottom of the file (just before the closing `}` of the parser struct), add the helper:

```swift
// MARK: - group

private func parseGroup(
    _ s: inout StructurizrParserState,
    scopedRelationships: inout [StructurizrRelationshipDef]
) throws -> [StructurizrModelElement] {
    _ = s.advance() // 'group'
    guard let label = s.consumeString() else {
        throw DiagramError.malformedSource(message: "Expected string label after 'group'")
    }
    guard s.peek() == .openBrace else {
        throw DiagramError.malformedSource(message: "Expected '{' after group label")
    }
    _ = s.advance()

    var groupElements: [StructurizrModelElement] = []
    while let token = s.peek() {
        if token == .closeBrace { break }
        if case .identifier("group") = token {
            s.diagnostic("Structurizr `group` cannot nest; dropping inner group")
            _ = s.advance() // inner 'group'
            _ = s.consumeString() // optional inner label
            if s.peek() == .openBrace { s.skipBlock() }
            continue
        }
        if case .identifier("tags") = token { s.skipTags(); continue }
        if case .bang = token {
            _ = s.advance()
            if let directive = s.consumeIdentifier() { s.skipDirective(directive: directive) }
            continue
        }
        if case .identifier = token {
            if s.peekAhead(1) == .equals {
                if let element = try parseElementDef(&s, parentAlias: nil, scopedRelationships: &scopedRelationships) {
                    var tagged = element
                    tagged.group = label
                    groupElements.append(tagged)
                }
                continue
            }
            if s.peekAhead(1) == .arrow {
                if let rel = try parseRelationshipDef(&s) { scopedRelationships.append(rel) }
                continue
            }
            if let word = s.consumeIdentifier() { s.diagnostic("unexpected statement in group block: \(word)") }
            continue
        }
        _ = s.advance()
    }

    guard s.peek() == .closeBrace else {
        throw DiagramError.malformedSource(message: "Unbalanced braces in group: missing '}'")
    }
    _ = s.advance()
    return groupElements
}
```

Add `import DiagramKitModel` at the top of `StructurizrParser.swift` if not already present (used by `DiagramError.malformedSource`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter StructurizrParserGroupTests`
Expected: `Test run with 2 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrParser.swift Tests/DiagramKitTests/StructurizrParserGroupTests.swift
git commit -m "$(cat <<'EOF'
feat(structurizr): parseGroup recognizes `group "label" { ... }` inside model

Parser now consumes the Structurizr DSL group directive inside `model { }`,
tags each contained element with the group label, and forwards inner
relationships to the model's relationship list. Nested groups inside a
group block are dropped with a `.unsupported` diagnostic.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Parser — error paths (nested, in-element, missing-label)

**Files:**
- Modify: `Tests/DiagramKitTests/StructurizrParserGroupTests.swift` (append three more `@Test` methods)
- Modify: `Sources/DiagramKitStructurizr/StructurizrParser.swift` (add `group` rejection inside `parseElementDef` body loop, around line 153–176)

- [ ] **Step 1: Write the failing tests**

Append to `Tests/DiagramKitTests/StructurizrParserGroupTests.swift` inside the `struct StructurizrParserGroupTests { ... }`:

```swift
    @Test("Nested group emits .unsupported and skips inner body")
    func nestedGroupUnsupported() throws {
        let source = """
        workspace {
          model {
            group "Outer" {
              group "Inner" {
                inner_p = person "Inner P"
              }
              outer_p = person "Outer P"
            }
          }
          views {
            systemContext outer_p {
              include *
            }
          }
        }
        """
        let (workspace, diagnostics) = try parse(source)
        let map = elementsByAlias(workspace)
        #expect(map["inner_p"] == nil)
        #expect(map["outer_p"]?.group == "Outer")
        #expect(diagnostics.contains { $0.message.contains("`group` cannot nest") })
    }

    @Test("group inside softwareSystem block emits .unsupported")
    func groupInsideElementUnsupported() throws {
        let source = """
        workspace {
          model {
            app = softwareSystem "App" {
              group "Inner" {
                api = container "API"
              }
              web = container "Web"
            }
          }
          views {
            container app {
              include *
            }
          }
        }
        """
        let (workspace, diagnostics) = try parse(source)
        let map = elementsByAlias(workspace)
        #expect(map["api"] == nil)
        #expect(map["web"] != nil)
        #expect(diagnostics.contains { $0.message.contains("`group` inside element blocks") })
    }

    @Test("Missing label throws malformedSource")
    func missingLabelThrows() {
        let source = """
        workspace {
          model {
            group {
              p = person "P"
            }
          }
        }
        """
        #expect(throws: DiagramError.self) {
            _ = try self.parse(source)
        }
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter StructurizrParserGroupTests`
Expected: the three new tests FAIL. `nestedGroupUnsupported` may pass partially (the parser hasn't seen the nested case; current behavior likely produces an unhelpful diagnostic or accepts the inner element); `groupInsideElementUnsupported` likely fails because the inner `group` token currently produces `unexpected statement in element block: group` instead of the targeted message; `missingLabelThrows` may already throw something but not necessarily `DiagramError`.

- [ ] **Step 3: Tighten the parser**

The nested-group case is already handled by `parseGroup` (Task 3 added the `Structurizr \`group\` cannot nest` branch). Verify it's emitted as `"cannot nest"` — that's what the test asserts.

Add `group` rejection inside `parseElementDef`'s inner body loop. In `Sources/DiagramKitStructurizr/StructurizrParser.swift`, locate the `while let token = s.peek() { ... }` loop inside `parseElementDef` (the one after `if s.peek() == .openBrace`, around line 153). After the `closeBrace`/`tags`/`bang` branches and BEFORE the `if case .identifier = token` block, add:

```swift
if case .identifier("group") = token {
    s.diagnostic("`group` inside element blocks not yet supported; dropping block")
    _ = s.advance() // 'group'
    _ = s.consumeString() // label (optional)
    if s.peek() == .openBrace { s.skipBlock() }
    continue
}
```

The `missingLabelThrows` test already passes if Task 3 was implemented correctly — `parseGroup` throws `DiagramError.malformedSource` when `consumeString()` returns nil. Confirm that path is in place; no code change needed.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter StructurizrParserGroupTests`
Expected: `Test run with 5 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrParser.swift Tests/DiagramKitTests/StructurizrParserGroupTests.swift
git commit -m "$(cat <<'EOF'
feat(structurizr): parser error paths for `group` directive

Rejects `group` inside softwareSystem/container element blocks with a
targeted `.unsupported` diagnostic; nested `group` inside `group` also
diagnoses. Missing-label `group { ... }` throws DiagramError.malformedSource.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Mapper — group → `.authored` `C4Boundary` + view-scope origin tag

**Files:**
- Create: `Tests/DiagramKitTests/StructurizrMapperGroupTests.swift`
- Modify: `Sources/DiagramKitStructurizr/StructurizrMapper.swift` (around lines 28–166 and 181–198)

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/StructurizrMapperGroupTests.swift`:

```swift
import Foundation
import Testing
import DiagramKitModel
import DiagramKitImport
@testable import DiagramKitStructurizr

@Suite("StructurizrMapper group")
struct StructurizrMapperGroupTests {

    private func mapped(_ source: String) throws -> (C4Diagram, [DiagramDiagnostic]) {
        let tokens = StructurizrLexer().tokenize(source)
        let (workspace, parseDiags) = try StructurizrParser().parse(tokens)
        let (diagram, mapDiags) = StructurizrMapper().map(workspace)
        return (diagram, parseDiags + mapDiags)
    }

    @Test("Single group becomes one .authored C4Boundary")
    func singleGroupBoundary() throws {
        let source = """
        workspace {
          model {
            group "Group 0" {
              u = person "User"
            }
          }
          views {
            systemContext u {
              include *
            }
          }
        }
        """
        let (diagram, _) = try mapped(source)
        let authored = diagram.boundaries.filter { $0.origin == .authored }
        #expect(authored.count == 1)
        #expect(authored.first?.label == "Group 0")
        #expect(authored.first?.type == "group")
        #expect(authored.first?.parentBoundary == "global")
    }

    @Test("Group label sanitizes to a valid alias")
    func sanitizedAlias() throws {
        let source = """
        workspace {
          model {
            group "Bank Boundary" {
              u = person "U"
            }
          }
          views {
            systemContext u {
              include *
            }
          }
        }
        """
        let (diagram, _) = try mapped(source)
        let authored = diagram.boundaries.filter { $0.origin == .authored }
        #expect(authored.first?.alias == "Bank_Boundary")
    }

    @Test("Labels that sanitize to the same alias get disambiguated")
    func sanitizeCollisionDisambiguates() throws {
        let source = """
        workspace {
          model {
            group "X Y" {
              p1 = person "P1"
            }
            group "X_Y" {
              p2 = person "P2"
            }
          }
          views {
            systemContext p1 {
              include *
            }
          }
        }
        """
        let (diagram, _) = try mapped(source)
        let authored = diagram.boundaries.filter { $0.origin == .authored }
        let aliases = Set(authored.map(\.alias))
        // Both labels sanitize to "X_Y" via sanitizeStructurizrIdentifier
        // (space → "_"). uniqueSanitizedGroupAlias appends "_2" on the
        // collision. The mapper iterates registry.elementsByAlias.values
        // which is unordered, so we assert on the SET, not which label
        // got "X_Y" vs "X_Y_2".
        #expect(aliases == ["X_Y", "X_Y_2"])
        #expect(authored.count == 2)
    }

    @Test("View-scope synthesized boundary is tagged .viewScopeSynthesized")
    func viewScopeSynthesizedOrigin() throws {
        let source = """
        workspace {
          model {
            app = softwareSystem "App" {
              web = container "Web"
            }
          }
          views {
            container app {
              include *
            }
          }
        }
        """
        let (diagram, diagnostics) = try mapped(source)
        let synthesized = diagram.boundaries.filter { $0.origin == .viewScopeSynthesized }
        #expect(synthesized.count == 1)
        #expect(synthesized.first?.alias == "app")
        #expect(diagnostics.contains { $0.message.contains("synthesized from the Structurizr view scope") })
    }

    @Test("Shape parentBoundary points at the synthesized group alias")
    func shapeParentBoundaryUsesGroupAlias() throws {
        let source = """
        workspace {
          model {
            group "G0" {
              u = person "U"
            }
          }
          views {
            systemContext u {
              include *
            }
          }
        }
        """
        let (diagram, _) = try mapped(source)
        let shape = try #require(diagram.shapes.first { $0.alias == "u" })
        #expect(shape.parentBoundary == "G0")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter StructurizrMapperGroupTests`
Expected: most tests FAIL. The mapper currently doesn't materialize boundaries from `element.group`, and the view-scope synthesis sets no `origin` (defaulting to `.authored` after Task 1's data-model change).

- [ ] **Step 3: Update the mapper**

In `Sources/DiagramKitStructurizr/StructurizrMapper.swift`, near the top of `map(_:)`, after the `registry = StructurizrModelRegistry(...)` line (around line 31), insert:

```swift
// Build a stable alias for each unique group label encountered in the model.
var groupAliasMap: [String: String] = [:]
var usedGroupAliases: Set<String> = []
for element in registry.elementsByAlias.values {
    guard let label = element.group, groupAliasMap[label] == nil else { continue }
    let alias = uniqueSanitizedGroupAlias(label, used: &usedGroupAliases)
    groupAliasMap[label] = alias
}
```

Inside the existing shape-mapping loop (around line 124), after `boundaryName` has been computed by the existing parent-element logic and before `let shape = C4Shape(...)`, add:

```swift
// Group tagging takes precedence over view-scope-derived boundaryName.
if let groupLabel = element.group, let groupAlias = groupAliasMap[groupLabel] {
    boundaryName = groupAlias
}
```

After the shape loop and BEFORE the existing `// Map boundaries.` comment (around line 168), append one `C4Boundary` per group:

```swift
// Authored boundaries from `group "..." { ... }`.
for (label, alias) in groupAliasMap {
    c4Boundaries.append(C4Boundary(
        alias: alias,
        label: label,
        type: "group",
        parentBoundary: "global",
        origin: .authored
    ))
}
```

In the existing view-scope synthesis block (around line 185), change the `C4Boundary(...)` initialization to pass `origin: .viewScopeSynthesized`:

```swift
let boundary = C4Boundary(
    alias: element.alias,
    label: element.name,
    type: boundaryType(for: element.kind),
    description: element.description,
    parentBoundary: "global",
    origin: .viewScopeSynthesized
)
```

At the bottom of the file (above the closing `}` of the struct), add the helper:

```swift
// MARK: - group alias helper

private func uniqueSanitizedGroupAlias(
    _ label: String,
    used: inout Set<String>
) -> String {
    let sanitized = StructurizrExporter.sanitizeStructurizrIdentifier(label)
    var candidate = sanitized
    var counter = 2
    while used.contains(candidate) {
        candidate = "\(sanitized)_\(counter)"
        counter += 1
    }
    used.insert(candidate)
    return candidate
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter StructurizrMapperGroupTests`
Expected: `Test run with 5 tests passed`.

Then re-run the existing Structurizr corpus tests to confirm no regression:

Run: `swift test --filter StructurizrCorpusFixtureTests`
Expected: all four existing fixtures still pass (their assertions don't check `origin` and the synthesized-from-view-scope `.warning` is unchanged).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrMapper.swift Tests/DiagramKitTests/StructurizrMapperGroupTests.swift
git commit -m "$(cat <<'EOF'
feat(structurizr): mapper materializes group boundaries with origin tag

For each unique element.group label, the mapper now appends one
.authored C4Boundary with a sanitized alias, and overrides the
shape's parentBoundary to point at it. The existing view-scope
synthesis path is tagged .viewScopeSynthesized so downstream
exporters can distinguish authored from synthesized boundaries.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Exporter — partition emit (`.authored` → `group { … }`; `.viewScopeSynthesized` drop)

**Files:**
- Create: `Tests/DiagramKitTests/StructurizrExporterGroupTests.swift`
- Modify: `Sources/DiagramKitStructurizr/StructurizrExporter.swift` (replace lines 60–91 with partition emit; preserve the existing relationship-emit block and view block)

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/StructurizrExporterGroupTests.swift`:

```swift
import Foundation
import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
@testable import DiagramKitStructurizr

@Suite("StructurizrExporter group emission")
struct StructurizrExporterGroupTests {

    private func emit(_ model: C4Diagram) throws -> DiagramExportResult {
        let document = DiagramDocument(payload: .c4(model))
        return try StructurizrExporter().export(document)
    }

    private func makeDiagram(
        kind: C4DiagramKind = .context,
        shapes: [C4Shape] = [],
        boundaries: [C4Boundary] = [],
        relationships: [C4Relationship] = []
    ) -> C4Diagram {
        C4Diagram(
            kind: kind,
            shapes: shapes,
            boundaries: boundaries,
            relationships: relationships
        )
    }

    @Test("Authored boundary emits a group block containing its shapes")
    func authoredBoundaryEmitsGroup() throws {
        let model = makeDiagram(
            shapes: [
                C4Shape(alias: "u", label: "User", typeC4Shape: .person, parentBoundary: "g0")
            ],
            boundaries: [
                C4Boundary(alias: "g0", label: "Group 0", type: "group", parentBoundary: "global", origin: .authored)
            ]
        )
        let result = try emit(model)
        #expect(result.source.contains("group \"Group 0\" {"))
        #expect(result.source.contains("u = person \"User\""))
    }

    @Test("View-scope synthesized boundary is silently dropped")
    func viewScopeSynthesizedDropped() throws {
        let model = makeDiagram(
            shapes: [
                C4Shape(alias: "app", label: "App", typeC4Shape: .system, parentBoundary: "global")
            ],
            boundaries: [
                C4Boundary(alias: "app", label: "App", type: "system", parentBoundary: "global", origin: .viewScopeSynthesized)
            ]
        )
        let result = try emit(model)
        #expect(!result.source.contains("group \""))
        #expect(!result.diagnostics.contains { $0.message.contains("group") })
    }

    @Test("Nested authored boundary flattens with one .warning")
    func nestedAuthoredFlattens() throws {
        let model = makeDiagram(
            shapes: [
                C4Shape(alias: "s0", label: "S0", typeC4Shape: .system, parentBoundary: "outer"),
                C4Shape(alias: "s1", label: "S1", typeC4Shape: .system, parentBoundary: "inner")
            ],
            boundaries: [
                C4Boundary(alias: "outer", label: "Outer", type: "group", parentBoundary: "global", origin: .authored),
                C4Boundary(alias: "inner", label: "Inner", type: "group", parentBoundary: "outer", origin: .authored)
            ]
        )
        let result = try emit(model)
        #expect(result.source.contains("group \"Outer\" {"))
        #expect(result.source.contains("group \"Inner\" {"))
        let warnings = result.diagnostics.filter { $0.severity == .warning && $0.message.contains("non-nestable") }
        #expect(warnings.count == 1)
    }

    @Test("Empty authored boundary warns and is dropped")
    func emptyAuthoredDropped() throws {
        let model = makeDiagram(
            shapes: [],
            boundaries: [
                C4Boundary(alias: "g0", label: "Empty Group", type: "group", parentBoundary: "global", origin: .authored)
            ]
        )
        let result = try emit(model)
        #expect(!result.source.contains("group \"Empty Group\""))
        let warnings = result.diagnostics.filter { $0.severity == .warning && $0.message.contains("Empty group") }
        #expect(warnings.count == 1)
    }

    @Test("Multiple authored boundaries emit in order")
    func multipleAuthoredOrdered() throws {
        let model = makeDiagram(
            shapes: [
                C4Shape(alias: "p1", label: "P1", typeC4Shape: .person, parentBoundary: "a"),
                C4Shape(alias: "p2", label: "P2", typeC4Shape: .person, parentBoundary: "b")
            ],
            boundaries: [
                C4Boundary(alias: "a", label: "First", type: "group", parentBoundary: "global", origin: .authored),
                C4Boundary(alias: "b", label: "Second", type: "group", parentBoundary: "global", origin: .authored)
            ]
        )
        let result = try emit(model)
        let firstIdx = try #require(result.source.range(of: "group \"First\""))
        let secondIdx = try #require(result.source.range(of: "group \"Second\""))
        #expect(firstIdx.lowerBound < secondIdx.lowerBound)
    }

    @Test("Root-level shapes still emit at model root")
    func rootShapesEmit() throws {
        let model = makeDiagram(
            shapes: [
                C4Shape(alias: "root", label: "Root", typeC4Shape: .person, parentBoundary: "global")
            ],
            boundaries: []
        )
        let result = try emit(model)
        #expect(result.source.contains("root = person \"Root\""))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter StructurizrExporterGroupTests`
Expected: most tests FAIL. The current exporter drops every boundary with `.unsupported` regardless of origin, and never emits `group { … }`.

- [ ] **Step 3: Replace the exporter's boundary-drop block with partition emit**

In `Sources/DiagramKitStructurizr/StructurizrExporter.swift`, locate the existing block that walks `for shape in model.shapes` (around lines 61–79) and the subsequent boundary-drop block (lines 84–91). Replace both with the partitioning emit. The full replacement starts after `lines.append("  model {")` (around line 58) and ends just before `// Relationships` (current line 93).

New code:

```swift
let authoredBoundaries = model.boundaries.filter { $0.origin == .authored }
let authoredAliases = Set(authoredBoundaries.map(\.alias))
let shapesByBoundary: [String: [C4Shape]] = Dictionary(grouping: model.shapes) { $0.parentBoundary }

// Authored boundaries → `group "label" { ... }`. Nested authored boundaries
// flatten to siblings with one `.warning` per dropped parent link. Empty
// authored boundaries (no direct shape members) are dropped with a `.warning`.
for boundary in authoredBoundaries {
    if !boundary.parentBoundary.isEmpty && boundary.parentBoundary != "global" {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Structurizr `group` is non-nestable; flattening boundary '\(boundary.alias)' (parent: '\(boundary.parentBoundary)') to top-level"
        ))
    }

    let members = shapesByBoundary[boundary.alias] ?? []
    if members.isEmpty {
        diagnostics.append(DiagramDiagnostic(
            severity: .warning,
            message: "Empty group '\(boundary.label)' (alias '\(boundary.alias)') has no direct shapes after Structurizr flattening; dropping"
        ))
        continue
    }

    lines.append("    group \"\(escape(boundary.label))\" {")
    for shape in members {
        emitShape(shape, indent: "      ", aliasMap: aliasMap, into: &lines, diagnostics: &diagnostics)
    }
    lines.append("    }")
}

// Shapes whose parentBoundary is "global", missing, or points to a
// non-authored boundary (e.g. view-scope-synthesized) emit at the model root.
for shape in model.shapes {
    let parent = shape.parentBoundary
    if parent == "global" || parent.isEmpty || !authoredAliases.contains(parent) {
        emitShape(shape, indent: "    ", aliasMap: aliasMap, into: &lines, diagnostics: &diagnostics)
    }
}
```

Extract the shape-emit body into a small helper at the bottom of `StructurizrC4Export`. Add this just before the existing `private static func structurizrType(_:)`:

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
        diagnostics.append(DiagramDiagnostic(
            severity: .unsupported,
            message: "Structurizr parser does not currently support element-scoped tags; dropping `tags \"\(tags)\"` for alias '\(shape.alias)'"
        ))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter StructurizrExporterGroupTests`
Expected: `Test run with 6 tests passed`.

Then confirm the existing Structurizr corpus fixtures still pass:

Run: `swift test --filter StructurizrCorpusFixtureTests`
Expected: all four existing fixtures still pass — the view-scope-synthesized boundaries are now silently dropped on export, which doesn't affect the existing fixture-decode/import assertions.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrExporter.swift Tests/DiagramKitTests/StructurizrExporterGroupTests.swift
git commit -m "$(cat <<'EOF'
feat(structurizr): exporter emits `.authored` boundaries as group blocks

Partitions model.boundaries by origin. `.authored` entries emit as
`group "label" { ... }` blocks containing their direct member shapes.
`.viewScopeSynthesized` entries silently drop (the next import
re-derives them from the view scope). Nested authored boundaries
flatten to siblings with one .warning per dropped parent link;
empty groups drop with a .warning.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: End-to-end round-trip tests

**Files:**
- Create: `Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift`

- [ ] **Step 1: Write the round-trip tests**

Create `Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift`:

```swift
import Foundation
import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
import DiagramKitMermaid
@testable import DiagramKit
@testable import DiagramKitStructurizr

@Suite("Structurizr boundary round-trip")
struct StructurizrBoundaryRoundTripTests {

    private func mermaidImport(_ source: String) throws -> C4Diagram {
        let result = try MermaidImporter().parse(source)
        guard case .c4(let diagram) = result.document.payload else {
            throw DiagramError.notYetImplemented("Expected Mermaid source to import as C4")
        }
        return diagram
    }

    private func structurizrExport(_ diagram: C4Diagram) throws -> String {
        let document = DiagramDocument(payload: .c4(diagram))
        return try StructurizrExporter().export(document).source
    }

    private func structurizrImport(_ source: String) throws -> C4Diagram {
        let result = try StructurizrImporter().parse(source)
        guard case .c4(let diagram) = result.document.payload else {
            throw DiagramError.notYetImplemented("Expected Structurizr source to import as C4")
        }
        return diagram
    }

    @Test("Single-boundary Mermaid round-trips through Structurizr")
    func singleBoundaryRoundTrip() throws {
        let mermaidSource = """
        C4Context
          Boundary(b0, "Group 0") {
            Person(p1, "P1")
          }
        """
        let first = try mermaidImport(mermaidSource)
        let structurizr = try structurizrExport(first)
        let second = try structurizrImport(structurizr)

        let authored = second.boundaries.filter { $0.origin == .authored }
        #expect(authored.count == 1)
        #expect(authored.first?.label == "Group 0")
        let p1 = try #require(second.shapes.first { $0.alias == "p1" })
        #expect(p1.parentBoundary == authored.first?.alias)
    }

    @Test("Two-level Mermaid nesting flattens to sibling groups")
    func twoLevelNestingFlattens() throws {
        let mermaidSource = """
        C4Context
          Enterprise_Boundary(b0, "Outer") {
            System(s0, "S0")
            Enterprise_Boundary(b1, "Inner") {
              System(s1, "S1")
            }
          }
        """
        let first = try mermaidImport(mermaidSource)
        let document = DiagramDocument(payload: .c4(first))
        let exportResult = try StructurizrExporter().export(document)
        let second = try structurizrImport(exportResult.source)

        let authored = second.boundaries.filter { $0.origin == .authored }
        let labels = Set(authored.map(\.label))
        #expect(labels == ["Outer", "Inner"])

        let outerAlias = try #require(authored.first { $0.label == "Outer" }?.alias)
        let innerAlias = try #require(authored.first { $0.label == "Inner" }?.alias)
        let s0 = try #require(second.shapes.first { $0.alias == "s0" })
        let s1 = try #require(second.shapes.first { $0.alias == "s1" })
        #expect(s0.parentBoundary == outerAlias)
        #expect(s1.parentBoundary == innerAlias)

        let flattenWarnings = exportResult.diagnostics.filter {
            $0.severity == .warning && $0.message.contains("non-nestable")
        }
        #expect(flattenWarnings.count == 1)
    }

    @Test("Structurizr group survives via Mermaid round-trip")
    func structurizrViaMermaidRoundTrip() throws {
        let structurizrSource = """
        workspace {
          model {
            group "G0" {
              p1 = person "P1"
            }
          }
          views {
            systemContext p1 {
              include *
            }
          }
        }
        """
        let first = try structurizrImport(structurizrSource)
        let mermaidSource = try MermaidExporter().export(DiagramDocument(payload: .c4(first))).source
        let viaMermaid = try mermaidImport(mermaidSource)

        let boundary = try #require(viaMermaid.boundaries.first { $0.label == "G0" })
        let p1 = try #require(viaMermaid.shapes.first { $0.alias == "p1" })
        #expect(p1.parentBoundary == boundary.alias)
    }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter StructurizrBoundaryRoundTripTests`
Expected: `Test run with 3 tests passed`.

If any test fails, the failure is most likely in one of the earlier-task implementations. Inspect the diagnostic message in the failure output and trace back to the parser/mapper/exporter task that produced the relevant code path. Do not retry the test without investigating.

- [ ] **Step 3: Commit**

```bash
git add Tests/DiagramKitTests/StructurizrBoundaryRoundTripTests.swift
git commit -m "$(cat <<'EOF'
test(structurizr): end-to-end boundary round-trip coverage

Three tests: single-boundary Mermaid → Structurizr → re-import preserves
labels and membership; two-level Mermaid nesting flattens to sibling
groups with one .warning; Structurizr group round-trips through itself
unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Corpus fixture `structurizr-5-group`

**Files:**
- Modify: `Examples/DiagramPlayground/Resources/test-diagrams.json` (insert after the existing `structurizr-4-scoped-rel` entry)
- Modify: `Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift` (append a new `@Test`)

- [ ] **Step 1: Locate the insertion point in the corpus file**

Run: `grep -n '"structurizr-4-scoped-rel"' Examples/DiagramPlayground/Resources/test-diagrams.json`
Expected output: a single hit reporting the line number of the entry's `"id"` field.

Note the closing-brace line number for that entry — the new entry slots in immediately after.

- [ ] **Step 2: Insert the new corpus entry**

Open `Examples/DiagramPlayground/Resources/test-diagrams.json`. After the closing `}` of the `structurizr-4-scoped-rel` entry (and after the comma that follows it), insert this object on its own line (preserve the comma after the previous entry; add a trailing comma if more entries follow):

```json
    {
      "id": "structurizr-5-group",
      "category": "c4",
      "name": "Structurizr: Group Block",
      "source": "C4Context\n  Boundary(b0, \"Group 0\") {\n    Person(u, \"User\")\n    System(app, \"My App\")\n  }\n  Rel(u, app, \"Uses\")",
      "sources": {
        "mermaid": "C4Context\n  Boundary(b0, \"Group 0\") {\n    Person(u, \"User\")\n    System(app, \"My App\")\n  }\n  Rel(u, app, \"Uses\")",
        "structurizr": "workspace {\n  model {\n    group \"Group 0\" {\n      u = person \"User\"\n      app = softwareSystem \"My App\"\n    }\n    u -> app \"Uses\"\n  }\n  views {\n    systemContext app {\n      include *\n    }\n  }\n}"
      },
      "expectedImporters": {
        "mermaid": "Mermaid",
        "structurizr": "Structurizr"
      },
      "skipSnapshots": ["structurizr"]
    }
```

- [ ] **Step 3: Add a fixture decode/import test**

Append to `Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift` inside the existing `struct StructurizrCorpusFixtureTests { ... }`:

```swift
    @Test("Structurizr group fixture decodes and tags element with group")
    func structurizrGroupFixtureDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "structurizr-5-group",
                    "category": "c4",
                    "name": "Structurizr: Group Block",
                    "source": "C4Context\\n  Boundary(b0, \\\"Group 0\\\") {\\n    Person(u, \\\"User\\\")\\n    System(app, \\\"My App\\\")\\n  }\\n  Rel(u, app, \\\"Uses\\\")",
                    "sources": {
                        "mermaid": "C4Context\\n  Boundary(b0, \\\"Group 0\\\") {\\n    Person(u, \\\"User\\\")\\n    System(app, \\\"My App\\\")\\n  }\\n  Rel(u, app, \\\"Uses\\\")",
                        "structurizr": "workspace {\\n  model {\\n    group \\\"Group 0\\\" {\\n      u = person \\\"User\\\"\\n      app = softwareSystem \\\"My App\\\"\\n    }\\n    u -> app \\\"Uses\\\"\\n  }\\n  views {\\n    systemContext app {\\n      include *\\n    }\\n  }\\n}"
                    },
                    "expectedImporters": {
                        "mermaid": "Mermaid",
                        "structurizr": "Structurizr"
                    },
                    "skipSnapshots": ["structurizr"]
                }
            ]
        }
        """.data(using: .utf8)!
        let entry = try decodeEntry(json)
        #expect(entry.id == "structurizr-5-group")
        #expect(entry.expectedImporters?["structurizr"] == "Structurizr")

        let (diagram, _) = try structurizrDiagram(for: entry)
        let authored = diagram.boundaries.filter { $0.origin == .authored }
        #expect(authored.count == 1)
        #expect(authored.first?.label == "Group 0")
    }
```

- [ ] **Step 4: Run the corpus fixture suite**

Run: `swift test --filter StructurizrCorpusFixtureTests`
Expected: `Test run with 5 tests passed` (four original fixtures + the new group fixture).

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/Resources/test-diagrams.json Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift
git commit -m "$(cat <<'EOF'
test(corpus): add structurizr-5-group fixture exercising group { ... }

Inline corpus entry exercising the Structurizr group directive
mapped to a Mermaid Boundary on the other side. Snapshot-skipped
for Structurizr (the existing four entries are also skipped).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Sync `CLAUDE.md` test source count

**Files:**
- Modify: `CLAUDE.md` (line currently reading "Current test source count: 225 Swift files under `Tests/DiagramKitTests`.")

- [ ] **Step 1: Count test source files**

Run: `find Tests/DiagramKitTests -type f -name '*.swift' | wc -l`
Expected output: a single integer. Compare against `225` (the value documented in `CLAUDE.md` today). After this plan's tasks, expect `225 + 5 = 230` (five new files: `C4BoundaryOriginTests`, `StructurizrASTGroupTests`, `StructurizrParserGroupTests`, `StructurizrMapperGroupTests`, `StructurizrExporterGroupTests`, `StructurizrBoundaryRoundTripTests` — six new files; total 231).

Recount: this plan adds six files (`C4BoundaryOriginTests`, `StructurizrASTGroupTests`, `StructurizrParserGroupTests`, `StructurizrMapperGroupTests`, `StructurizrExporterGroupTests`, `StructurizrBoundaryRoundTripTests`). Expected count: 231.

- [ ] **Step 2: Update `CLAUDE.md`**

In `CLAUDE.md`, find the line:

```
- Current test source count: 225 Swift files under `Tests/DiagramKitTests`.
```

Replace `225` with the value reported by Step 1 (expected `231`; trust the actual count).

- [ ] **Step 3: Run the broader Structurizr suites once more to confirm clean state**

Run: `swift test --filter StructurizrParserGroupTests`
Run: `swift test --filter StructurizrMapperGroupTests`
Run: `swift test --filter StructurizrExporterGroupTests`
Run: `swift test --filter StructurizrBoundaryRoundTripTests`
Run: `swift test --filter StructurizrCorpusFixtureTests`
Run: `swift test --filter C4BoundaryOriginTests`
Run: `swift test --filter StructurizrASTGroupTests`
Run: `swift test --filter C4SlotSemanticsTests`

Expected: all suites pass. Run each filter exactly once — do not re-run for confidence.

- [ ] **Step 4: Run discipline gates**

Run: `Scripts/check-sendable-annotations.sh`
Expected: `✓ All @unchecked Sendable usages are properly annotated or allowlisted.`

Run: `Scripts/check-file-sizes.sh`
Expected: no new yellow/red threshold crossings beyond the existing allowlisted set.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(claude): sync test source count after Structurizr group work

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review

**Spec coverage:**
- Data model: `C4BoundaryOrigin` + `origin` field — Task 1. `StructurizrModelElement.group` — Task 2.
- Parser: `parseGroup` happy path — Task 3. Nested-group / in-element / missing-label error paths — Task 4.
- Mapper: group→`.authored` boundary, alias sanitization, disambiguation, view-scope `.viewScopeSynthesized` tagging, shape parentBoundary override — Task 5.
- Exporter: `.authored` group emit, `.viewScopeSynthesized` drop, nested flatten + `.warning`, empty drop + `.warning`, multi-group order, root-shape emit — Task 6.
- Round-trip semantics: end-to-end tests — Task 7 (3 tests covering preserved labels/memberships, nested flatten + warning count, Structurizr→Structurizr stability).
- Corpus fixture: `structurizr-5-group` — Task 8.
- CLAUDE.md test count sync + final verification gates — Task 9.

No gaps.

**Placeholder scan:** No `TBD` / `TODO` / "implement later" / "similar to Task N" in the body. Each step shows the code or runs an exact command. The "expected output" of the count step is conditional but the engineer is told to trust the actual count.

**Type consistency:**
- `C4BoundaryOrigin` enum used identically across Tasks 1, 5, 6, 7.
- `uniqueSanitizedGroupAlias` declared in Task 5 (mapper-private) and not referenced elsewhere.
- `emitShape` helper introduced in Task 6 (exporter-private) and not referenced elsewhere.
- `parseGroup` signature `(inout state, scopedRelationships: inout) throws -> [StructurizrModelElement]` consistent between Tasks 3 and 4.
- `boundary.type == "group"` checked in Task 5 and assigned in Task 5; no drift.

Plan is internally consistent.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-14-structurizr-boundary-round-trip.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?

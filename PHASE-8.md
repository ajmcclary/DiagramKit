# Phase 8: Interactivity Primitives

Goal: expose stable identity and geometry without building a full editor.

Date: 2026-05-12. This is the implementation plan for Phase 8 of the DiagramKit
multi-format roadmap. It follows the completed Phase 7 (exporter protocol) and
precedes Phase 9 (optional interactive model).

## Table of Contents

1. [Motivation and Scope](#1-motivation-and-scope)
2. [Architecture Overview](#2-architecture-overview)
3. [Slice 8A: Portable Geometry and Foundation Types](#3-slice-8a-portable-geometry-and-foundation-types)
4. [Slice 8B: Stable IDs and Bounds for Flowchart + State](#4-slice-8b-stable-ids-and-bounds-for-flowchart--state)
5. [Slice 8C: Sequence Diagrams](#5-slice-8c-sequence-diagrams)
6. [Slice 8D: Class Diagrams](#6-slice-8d-class-diagrams)
7. [Slice 8E: ER Diagrams](#7-slice-8e-er-diagrams)
8. [Slice 8F: C4 Diagrams](#8-slice-8f-c4-diagrams)
9. [Slice 8G: Long Tail](#9-slice-8g-long-tail)
10. [Pipeline Integration](#10-pipeline-integration)
11. [Test Strategy](#11-test-strategy)
12. [Verification Gates](#12-verification-gates)
13. [Deferred / Out of Scope](#13-deferred--out-of-scope)

---

## 1. Motivation and Scope

### 1.1 Why Interactivity Primitives

DiagramKit currently has zero interactivity surface. A consumer who wants
click-to-highlight, tooltips, hover feedback, marquee selection, or
deep-linking into a diagram must either parse the SVG DOM or reverse-engineer
the layout coordinates. The library should ship the primitives that make these
features trivial to implement without building a full editor.

MusicToolkit's `BoundsLookup` and `ScoreSelection` demonstrate the pattern
(see `ANALYSIS.md` §2.4): stable, model-level element identifiers combined with
a spatial index built by the renderer, read-only after construction. Consumers
use these to answer "what did the user click on?" and "where is element X?",
then build their own UI on top.

### 1.2 What Phase 8 Delivers

- **Portable geometry types** in `DiagramKitCommon` — `DiagramPoint` and
  `DiagramRect` that work on Linux and Apple without leaking CoreGraphics into
  format-neutral surfaces.
- **Guaranteed stable element IDs** for every positioned element across all 28
  diagram families. IDs are source-derived, deterministic, and survive
  re-layouts.
- **`DiagramSelection`** — a lightweight value type carrying a `DiagramType`
  and an opaque stable `elementID`. Survives parse/layout/render cycles.
- **`DiagramBoundsLookup`** — a spatial index built from `PositionedGraph` that
  provides hit-testing (`element(at:)`), marquee selection
  (`elements(in:)`), and reverse lookup (`bounds(of:)`).
- **Pipeline integration** — lookup is constructed during `prepare()` and
  accessible via `PreparedDiagram.positioned.lookup`.

### 1.3 What Phase 8 Does NOT Deliver

- No editor model (`DiagramEditor` with undo stack — Phase 9).
- No hit-testing UI integration (views, gesture recognizers — Phase 9 / consumer).
- No selection-highlight rendering changes.
- No export of selection state.
- No per-element styling or mutation APIs.
- No new SPM target — all types land in existing targets.

---

## 2. Architecture Overview

### 2.1 Target Placement

```
DiagramKitCommon          ← DiagramPoint, DiagramRect (+ CG bridging)
  → DiagramKitModel       ← StableID conformance, DiagramSelection,
                             DiagramBoundsLookup, PositionedGraph factory
    → DiagramKitRenderingCG ← PreparedDiagram (inherits lookup via positioned)
```

No new target. All work fits into the existing layered architecture.

### 2.2 Design Principles

1. **Stable IDs are source-derived.** An element's ID is deterministic from the
   source text. The same source → parse → layout produces the same IDs. This
   means consumers can store a `DiagramSelection` across sessions and it remains
   valid as long as the diagram source hasn't changed structurally.

2. **IDs survive re-layouts.** Changing `LayoutConfig` (padding, spacing) does
   not change element IDs — only geometry changes. This is the property that
   makes stable selection possible in editors that toggle layout parameters.

3. **IDs are opaque.** Consumers treat `elementID` as a black-box string. They
   use `BoundsLookup.bounds(of: selection)` to get geometry and
   `BoundsLookup.label(for: selection)` for human-readable text. No consumer
   should parse the ID string.

4. **No CG leakage into format-neutral surfaces.** `DiagramPoint` and
   `DiagramRect` use `Double` fields. `DiagramRect.contains(DiagramPoint)` and
   `DiagramRect.intersects(DiagramRect)` provide the essential spatial
   operations. Platform bridging to `CGPoint`/`CGRect` is a one-way extension
   guarded by `#if canImport(CoreGraphics)`.

5. **Lookup is read-only after construction.** `DiagramBoundsLookup` is a
   `Sendable` struct built once from a `PositionedGraph`. It has no mutable
   state. Consumers create a new lookup when they re-layout.

6. **Coverage is exhaustive but incremental.** Slice 8A provides the foundation
   types. Slices 8B-8F cover the five priority families (flowchart/state,
   sequence, class, ER, C4). Slice 8G covers the remaining 23 families.
   Families without explicit coverage return empty lookup results — they do not
   crash or throw.

---

## 3. Slice 8A: Portable Geometry and Foundation Types

**Goal**: Add `DiagramPoint`, `DiagramRect`, `DiagramSelection`, and
`DiagramBoundsLookup` to the appropriate targets. These are the foundation on
which all family-specific slices build.

### 3.1 DiagramPoint and DiagramRect

**Where**: `Sources/DiagramKitCommon/DiagramGeometry.swift`

```swift
// Sources/DiagramKitCommon/DiagramGeometry.swift

/// A language-neutral 2D point.
public struct DiagramPoint: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = DiagramPoint(x: 0, y: 0)
}

/// A language-neutral axis-aligned rectangle.
public struct DiagramRect: Sendable, Hashable {
    public var origin: DiagramPoint
    public var size: DiagramSize

    public init(origin: DiagramPoint, size: DiagramSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.origin = DiagramPoint(x: x, y: y)
        self.size = DiagramSize(width: width, height: height)
    }

    public var x: Double { origin.x }
    public var y: Double { origin.y }
    public var width: Double { size.width }
    public var height: Double { size.height }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var midX: Double { origin.x + size.width / 2 }
    public var midY: Double { origin.y + size.height / 2 }

    /// Whether `point` lies inside this rectangle (inclusive on bottom-right
    /// edge for hit-testing tolerance).
    public func contains(_ point: DiagramPoint) -> Bool {
        point.x >= minX && point.x <= maxX
            && point.y >= minY && point.y <= maxY
    }

    /// Whether this rectangle intersects `other`.
    public func intersects(_ other: DiagramRect) -> Bool {
        !(maxX < other.minX || other.maxX < minX
            || maxY < other.minY || other.maxY < minY)
    }

    /// The intersection of this rectangle with `other`, or nil if they don't
    /// overlap.
    public func intersection(_ other: DiagramRect) -> DiagramRect? {
        guard intersects(other) else { return nil }
        let ix = Swift.max(minX, other.minX)
        let iy = Swift.max(minY, other.minY)
        let iw = Swift.min(maxX, other.maxX) - ix
        let ih = Swift.min(maxY, other.maxY) - iy
        return DiagramRect(x: ix, y: iy, width: iw, height: ih)
    }

    public static let zero = DiagramRect(x: 0, y: 0, width: 0, height: 0)
}

/// A language-neutral 2D size.
public struct DiagramSize: Sendable, Hashable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = DiagramSize(width: 0, height: 0)
}
```

**Platform bridging** (same file, guarded):

```swift
#if canImport(CoreGraphics)
import CoreGraphics

extension DiagramPoint {
    public init(_ point: CGPoint) {
        self.init(x: Double(point.x), y: Double(point.y))
    }

    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

extension DiagramRect {
    public init(_ rect: CGRect) {
        self.init(x: Double(rect.origin.x), y: Double(rect.origin.y),
                  width: Double(rect.size.width), height: Double(rect.size.height))
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
#endif
```

**Estimated**: ~120 lines. Under 500-line threshold.

### 3.2 Stable Element ID Protocol

**Where**: `Sources/DiagramKitModel/DiagramStableElement.swift`

Every positioned element type that participates in the lookup must provide a
stable ID and a bounding rectangle. Rather than requiring every existing type
to conform to a protocol (which would touch ~40+ structs), we define the
protocol and add conformance in each family slice.

```swift
// Sources/DiagramKitModel/DiagramStableElement.swift

import DiagramKitCommon

/// A positioned diagram element with a stable, source-derived identifier
/// and a bounding rectangle suitable for spatial lookup.
public protocol DiagramStableElement: Sendable {
    /// A stable, source-derived identifier for this element.
    /// Must be deterministic: same source text → same ID.
    /// Must survive re-layouts with different `LayoutConfig`.
    var stableElementID: String { get }

    /// The bounding rectangle of this element in diagram coordinates.
    var stableElementBounds: DiagramRect { get }

    /// A human-readable label for display, or nil.
    var stableElementLabel: String? { get }
}
```

**Estimated**: ~30 lines.

### 3.3 DiagramSelection

**Where**: `Sources/DiagramKitModel/DiagramSelection.swift`

```swift
// Sources/DiagramKitModel/DiagramSelection.swift

/// A stable reference to a diagram element that survives re-layouts.
///
/// Consumers treat `elementID` as an opaque string. Use
/// `DiagramBoundsLookup.bounds(of:)` to recover geometry, and
/// `DiagramBoundsLookup.label(for:)` for a human-readable label.
public struct DiagramSelection: Sendable, Hashable {
    /// The diagram family this element belongs to.
    public var diagramType: DiagramType

    /// Opaque stable element identifier.
    /// Derived from source text; same source → same ID.
    public var elementID: String

    public init(diagramType: DiagramType, elementID: String) {
        self.diagramType = diagramType
        self.elementID = elementID
    }
}
```

**Estimated**: ~25 lines.

### 3.4 DiagramBoundsLookup

**Where**: `Sources/DiagramKitModel/DiagramBoundsLookup.swift`

The lookup is a spatial index built from an array of positioned elements. For
the element counts typical in diagrams (hundreds, not millions), a sorted flat
array with linear scan for hit-testing and marquee selection is
straightforward and correct. A grid or R-tree can replace the implementation
later without changing the API.

```swift
// Sources/DiagramKitModel/DiagramBoundsLookup.swift

import DiagramKitCommon

/// A read-only spatial index over positioned diagram elements.
///
/// Built from a `PositionedGraph` via `DiagramBoundsLookup.Builder`.
/// Provides hit-testing, marquee selection, and reverse geometry lookup.
///
/// ## Concurrency Contract
/// `DiagramBoundsLookup` is `Sendable`. It is constructed once and read
/// concurrently. All state is immutable value-type data.
public struct DiagramBoundsLookup: Sendable {
    /// Internal entry: element bounds + opaque ID + human-readable label.
    private struct Entry: Sendable {
        var bounds: DiagramRect
        var elementID: String
        var label: String?
    }

    /// Entries sorted by minY then minX for efficient hit-testing.
    private var entries: [Entry]
    private var diagramType: DiagramType

    /// The number of elements in this lookup.
    public var count: Int { entries.count }

    /// All element IDs in this lookup.
    public var allElementIDs: [String] {
        entries.map(\.elementID)
    }

    // MARK: - Hit-testing

    /// Returns the topmost element at `point` in diagram coordinates,
    /// or nil if no element contains the point.
    ///
    /// When multiple elements overlap at the given point, the element with
    /// the smallest area is returned (the most "specific" element).
    /// Z-order tiebreaking: nodes beat edges beat groups beat boundaries.
    public func element(at point: DiagramPoint) -> DiagramSelection? {
        var best: (entry: Entry, area: Double)? = nil
        for entry in entries {
            guard entry.bounds.contains(point) else { continue }
            let area = entry.bounds.width * entry.bounds.height
            if let current = best, area >= current.area { continue }
            best = (entry, area)
        }
        return best.map {
            DiagramSelection(diagramType: diagramType, elementID: $0.entry.elementID)
        }
    }

    // MARK: - Marquee selection

    /// Returns all elements whose bounding rectangles intersect `rect`.
    public func elements(in rect: DiagramRect) -> [DiagramSelection] {
        entries.compactMap { entry in
            guard entry.bounds.intersects(rect) else { return nil }
            return DiagramSelection(diagramType: diagramType, elementID: entry.elementID)
        }
    }

    /// Returns all elements whose bounding rectangles are fully contained
    /// within `rect`.
    public func elements(containedIn rect: DiagramRect) -> [DiagramSelection] {
        entries.compactMap { entry in
            guard rect.contains(DiagramPoint(x: entry.bounds.minX, y: entry.bounds.minY))
                    && rect.contains(DiagramPoint(x: entry.bounds.maxX, y: entry.bounds.maxY))
            else { return nil }
            return DiagramSelection(diagramType: diagramType, elementID: entry.elementID)
        }
    }

    // MARK: - Reverse lookup

    /// Returns the bounding rectangle for the given selection, or nil if the
    /// element ID is unknown.
    public func bounds(of selection: DiagramSelection) -> DiagramRect? {
        guard selection.diagramType == diagramType else { return nil }
        return entries.first(where: { $0.elementID == selection.elementID })?.bounds
    }

    /// Returns the human-readable label for the given selection, or nil.
    public func label(for selection: DiagramSelection) -> String? {
        guard selection.diagramType == diagramType else { return nil }
        return entries.first(where: { $0.elementID == selection.elementID })?.label
    }

    // MARK: - Element lookup by ID

    /// Returns a selection for the given element ID if it exists.
    public func selection(for elementID: String) -> DiagramSelection? {
        guard entries.contains(where: { $0.elementID == elementID }) else { return nil }
        return DiagramSelection(diagramType: diagramType, elementID: elementID)
    }

    // MARK: - Factory

    /// Build a lookup from an arbitrary collection of `DiagramStableElement`
    /// values.
    public static func build(
        diagramType: DiagramType,
        elements: [any DiagramStableElement]
    ) -> DiagramBoundsLookup {
        let entries = elements.map { el in
            Entry(bounds: el.stableElementBounds, elementID: el.stableElementID, label: el.stableElementLabel)
        }
        // Sort by minY then minX for better hit-testing locality.
        let sorted = entries.sorted { a, b in
            if a.bounds.minY != b.bounds.minY { return a.bounds.minY < b.bounds.minY }
            return a.bounds.minX < b.bounds.minX
        }
        return DiagramBoundsLookup(diagramType: diagramType, entries: sorted)
    }

    /// Returns an empty lookup for the given diagram type.
    public static func empty(diagramType: DiagramType) -> DiagramBoundsLookup {
        DiagramBoundsLookup(diagramType: diagramType, entries: [])
    }

    private init(diagramType: DiagramType, entries: [Entry]) {
        self.diagramType = diagramType
        self.entries = entries
    }
}
```

**Estimated**: ~120 lines. Under 500-line threshold.

### 3.5 PositionedGraph Integration

The lookup is built from `PositionedGraph` and stored as a lazy-access
property. The factory method dispatches on `PositionedContent` to extract
bounded elements per family and delegates to `DiagramBoundsLookup.build`.

**Where**: extension on `PositionedGraph` in
`Sources/DiagramKitModel/DiagramBoundsLookup+PositionedGraph.swift`

```swift
// Sources/DiagramKitModel/DiagramBoundsLookup+PositionedGraph.swift

extension PositionedGraph {
    /// A spatial index over all bounded elements in this positioned graph.
    ///
    /// Cached after first access. The lookup is derived from the positioned
    /// content and survives as long as the `PositionedGraph` instance.
    public var lookup: DiagramBoundsLookup {
        mutating get {
            if let cached = _lookupCache { return cached }
            let built = _buildLookup()
            _lookupCache = built
            return built
        }
    }

    private var _lookupCache: DiagramBoundsLookup? {
        get { _lookupStorage.value }
        nonmutating set { _lookupStorage.value = newValue }
    }

    private func _buildLookup() -> DiagramBoundsLookup {
        switch content {
        case .flowchart(let nodes, let edges, let groups):
            return _flowchartLookup(nodes: nodes, edges: edges, groups: groups)
        case .stateDiagram(let nodes, let edges, let groups):
            return _flowchartLookup(nodes: nodes, edges: edges, groups: groups)
        case .sequenceDiagram(let actors, let messages, let blocks,
                              let lifelines, let activations, let notes,
                              let boxes, let bottomActors, let rectHighlights,
                              _, _, _):
            return _sequenceLookup(actors: actors, messages: messages,
                                   blocks: blocks, lifelines: lifelines,
                                   activations: activations, notes: notes,
                                   boxes: boxes, bottomActors: bottomActors,
                                   rectHighlights: rectHighlights)
        case .classDiagram(let classes, let relationships, let namespaces,
                           let notes, _, _, _):
            return _classLookup(classes: classes, relationships: relationships,
                                namespaces: namespaces, notes: notes)
        case .erDiagram(let entities, let relationships, _, _, _):
            return _erLookup(entities: entities, relationships: relationships)
        case .c4(let c4):
            return _c4Lookup(c4)
        // Long-tail families: return empty lookup.
        // Each family gets a dedicated function in Slice 8G.
        default:
            return DiagramBoundsLookup.empty(diagramType: diagram.type)
        }
    }
}
```

The `_lookupStorage` is an internal associated-object-style storage:
```swift
// Inside PositionedGraph or a helper:
private var _lookupStorage: _LookupBox {
    // Use a class-backed box for mutating access in a struct.
    ...
}
```

Actually, since `PositionedGraph` is `Sendable` and a struct, we need a
non-mutating cache. The simplest approach: make `lookup` a computed property
that builds eagerly (not lazily), or use a `_LookupBox` class-holder. The
eager approach is simpler and safe — building the lookup from a few hundred
elements is sub-millisecond.

```swift
extension PositionedGraph {
    /// A spatial index over all bounded elements in this positioned graph.
    /// Built eagerly; element counts are small enough that construction
    /// cost is negligible.
    public var lookup: DiagramBoundsLookup {
        _buildLookup()
    }
}
```

This avoids the mutating/caching problem entirely.

**Estimated**: ~100 lines across the factory method. Family-specific builders
are in their respective slice files.

---

## 4. Slice 8B: Stable IDs and Bounds for Flowchart + State

**Goal**: Ensure every flowchart and state diagram positioned element has a
guaranteed stable ID, and the lookup builder extracts them correctly.

### 4.1 Current State

Flowchart and state diagrams share identical positioned payloads:

- `PositionedNode` (`_PositionedNodePayload`): has `id: String` ✅ stable
- `PositionedEdge` (`_PositionedEdgePayload`): has `edgeId: String?` ⚠️ optional
- `PositionedGroup` (`_PositionedGroupPayload`): has `id: String` ✅ stable

The `edgeId` field is optional — some edges have it, some don't. For stable
identity, every edge must have a guaranteed ID.

### 4.2 Edge ID Guarantee

**Approach**: Do not modify `_PositionedEdgePayload` (it's generated by
layout code that may live in multiple files). Instead, add a computed
property that provides a deterministic fallback.

**Where**: extension in `DiagramKitModel`:

```swift
// Sources/DiagramKitModel/DiagramSelection+Flowchart.swift

extension PositionedNode: DiagramStableElement {
    public var stableElementID: String { "node:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

extension PositionedEdge {
    /// Guaranteed stable edge identifier.
    /// Uses `edgeId` when present; falls back to a deterministic synthetic
    /// ID derived from source and target nodes.
    public var guaranteedEdgeID: String {
        if let edgeId, !edgeId.isEmpty { return edgeId }
        // Deterministic synthesis: source + target + label + first point.
        let components = [source, target, label ?? "", points.first.map { "\($0.x),\($0.y)" } ?? ""]
        let seed = components.joined(separator: "→")
        return "edge:\(StableID.derive(from: seed))"
    }
}

extension PositionedEdge: DiagramStableElement {
    public var stableElementID: String { guaranteedEdgeID }
    public var stableElementBounds: DiagramRect {
        // Bounding box of all edge points with some padding for hit-target.
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            minX = Swift.min(minX, p.x)
            minY = Swift.min(minY, p.y)
            maxX = Swift.max(maxX, p.x)
            maxY = Swift.max(maxY, p.y)
        }
        let pad = 8.0 // hit-target padding
        return DiagramRect(x: minX - pad, y: minY - pad,
                           width: maxX - minX + pad * 2,
                           height: maxY - minY + pad * 2)
    }
    public var stableElementLabel: String? { label }
}

extension PositionedGroup: DiagramStableElement {
    public var stableElementID: String { "group:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}
```

And recursively include nested child groups:

```swift
extension PositionedGroup {
    /// All elements in this group hierarchy (self + children).
    func allGroupElements() -> [any DiagramStableElement] {
        var result: [any DiagramStableElement] = [self]
        for child in children {
            result.append(contentsOf: child.allGroupElements())
        }
        return result
    }
}
```

**Estimated**: ~80 lines.

### 4.3 Flowchart Lookup Builder

```swift
// Sources/DiagramKitModel/DiagramBoundsLookup+Flowchart.swift

private func _flowchartLookup(
    nodes: [PositionedNode],
    edges: [PositionedEdge],
    groups: [PositionedGroup]
) -> DiagramBoundsLookup {
    var elements: [any DiagramStableElement] = []
    elements.append(contentsOf: nodes.map { $0 as any DiagramStableElement })
    elements.append(contentsOf: edges.map { $0 as any DiagramStableElement })
    for group in groups {
        elements.append(contentsOf: group.allGroupElements())
    }
    return DiagramBoundsLookup.build(diagramType: .flowchart, elements: elements)
}
```

**Estimated**: ~25 lines.

---

## 5. Slice 8C: Sequence Diagrams

### 5.1 Current State

Sequence positioned types with identity:

| Type | Has ID? | Stable? |
|------|---------|---------|
| `PositionedSequenceActor` | `id: String` ✅ | Yes (source-derived alias) |
| `SequenceLifeline` | `actorId: String` | Tied to actor |
| `PositionedSequenceMessage` | none ❌ | None — needs synthesis |
| `SequenceActivation` | `actorId: String` | Tied to actor + position |
| `PositionedSequenceBlock` | none ❌ | Needs synthesis from type + index |
| `PositionedSequenceNote` | none ❌ | Needs synthesis from text + position |
| `PositionedSequenceBox` | `id: String` ✅ | Yes (source-derived) |
| `PositionedRectHighlight` | none ❌ | Needs synthesis |

### 5.2 Stable ID Design

```swift
// Sources/DiagramKitModel/DiagramSelection+Sequence.swift

extension PositionedSequenceActor: DiagramStableElement {
    public var stableElementID: String { "actor:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

extension SequenceLifeline: DiagramStableElement {
    public var stableElementID: String { "lifeline:\(actorId)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x - 1, y: topY, width: 2, height: max(1, bottomY - topY))
    }
    public var stableElementLabel: String? { actorId }
}

extension PositionedSequenceMessage {
    /// Synthetic stable ID from from+to+label+sequenceNumber.
    public var guaranteedMessageID: String {
        let seed = [from, to, label, sequenceNumber.map(String.init) ?? ""]
            .joined(separator: "→")
        return "message:\(StableID.derive(from: seed))"
    }
}

extension PositionedSequenceMessage: DiagramStableElement {
    public var stableElementID: String { guaranteedMessageID }
    public var stableElementBounds: DiagramRect {
        let halfHeight: Double = 6
        return DiagramRect(
            x: min(x1, x2),
            y: y - halfHeight,
            width: abs(x2 - x1),
            height: halfHeight * 2
        )
    }
    public var stableElementLabel: String? { label.isEmpty ? nil : label }
}

extension SequenceActivation: DiagramStableElement {
    public var stableElementID: String { "activation:\(actorId):\(topY)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: topY, width: width, height: max(1, bottomY - topY))
    }
    public var stableElementLabel: String? { nil }
}

extension PositionedSequenceBlock: DiagramStableElement {
    public var stableElementID: String {
        let seed = "\(type):\(label):\(x):\(y)"
        return "block:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label.isEmpty ? type : "\(type): \(label)" }
}

extension PositionedSequenceNote: DiagramStableElement {
    public var stableElementID: String {
        let seed = "note:\(text):\(x):\(y)"
        return "note:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { text }
}

extension PositionedSequenceBox: DiagramStableElement {
    public var stableElementID: String { "box:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { name ?? id }
}

extension PositionedRectHighlight: DiagramStableElement {
    public var stableElementID: String {
        "highlight:\(x):\(y):\(width):\(height)"
    }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { nil }
}
```

Bottom actors get the same treatment as top actors but with a distinct
prefix to avoid ID collision:

```swift
extension PositionedSequenceActor {
    public func asBottomActorStableElement() -> any DiagramStableElement {
        _BottomActorWrapper(actor: self)
    }
}

private struct _BottomActorWrapper: DiagramStableElement {
    let actor: PositionedSequenceActor
    var stableElementID: String { "bottom-actor:\(actor.id)" }
    var stableElementBounds: DiagramRect {
        DiagramRect(x: actor.x, y: actor.y, width: actor.width, height: actor.height)
    }
    var stableElementLabel: String? { actor.label }
}
```

### 5.3 Sequence Lookup Builder

```swift
private func _sequenceLookup(
    actors: [PositionedSequenceActor],
    messages: [PositionedSequenceMessage],
    blocks: [PositionedSequenceBlock],
    lifelines: [SequenceLifeline],
    activations: [SequenceActivation],
    notes: [PositionedSequenceNote],
    boxes: [PositionedSequenceBox],
    bottomActors: [PositionedSequenceActor],
    rectHighlights: [PositionedRectHighlight]
) -> DiagramBoundsLookup {
    var elements: [any DiagramStableElement] = []
    elements.append(contentsOf: actors.map { $0 as any DiagramStableElement })
    elements.append(contentsOf: messages.map { $0 as any DiagramStableElement })
    elements.append(contentsOf: blocks.map { $0 as any DiagramStableElement })
    elements.append(contentsOf: lifelines.map { $0 as any DiagramStableElement })
    elements.append(contentsOf: activations.map { $0 as any DiagramStableElement })
    elements.append(contentsOf: notes.map { $0 as any DiagramStableElement })
    elements.append(contentsOf: boxes.map { $0 as any DiagramStableElement })
    elements.append(contentsOf: bottomActors.map { $0.asBottomActorStableElement() })
    elements.append(contentsOf: rectHighlights.map { $0 as any DiagramStableElement })
    return DiagramBoundsLookup.build(diagramType: .sequenceDiagram, elements: elements)
}
```

**Estimated**: ~150 lines across conformance + builder.

---

## 6. Slice 8D: Class Diagrams

### 6.1 Stable ID Design

```swift
// Sources/DiagramKitModel/DiagramSelection+Class.swift

extension PositionedClassNode: DiagramStableElement {
    public var stableElementID: String { "class:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

extension PositionedClassRelationship: DiagramStableElement {
    public var stableElementID: String {
        let seed = [from, to, title ?? ""].joined(separator: "→")
        return "rel:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            minX = Swift.min(minX, p.x)
            minY = Swift.min(minY, p.y)
            maxX = Swift.max(maxX, p.x)
            maxY = Swift.max(maxY, p.y)
        }
        let pad = 8.0
        return DiagramRect(x: minX - pad, y: minY - pad,
                           width: maxX - minX + pad * 2,
                           height: maxY - minY + pad * 2)
    }
    public var stableElementLabel: String? { title }
}

extension PositionedClassNamespace: DiagramStableElement {
    public var stableElementID: String { "namespace:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }

    func allNamespaceElements() -> [any DiagramStableElement] {
        var result: [any DiagramStableElement] = [self]
        for child in children {
            result.append(contentsOf: child.allNamespaceElements())
        }
        return result
    }
}

extension PositionedClassNote: DiagramStableElement {
    public var stableElementID: String {
        "class-note:\(id)"
    }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { text }
}
```

**Estimated**: ~80 lines.

---

## 7. Slice 8E: ER Diagrams

### 7.1 Stable ID Design

```swift
// Sources/DiagramKitModel/DiagramSelection+ER.swift

extension PositionedErEntity: DiagramStableElement {
    public var stableElementID: String { "entity:\(nodeId)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label.isEmpty ? id : label }
}

extension PositionedErRelationship: DiagramStableElement {
    public var stableElementID: String {
        let seed = [entity1, entity2, label].joined(separator: "↔")
        return "er-rel:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            minX = Swift.min(minX, p.x)
            minY = Swift.min(minY, p.y)
            maxX = Swift.max(maxX, p.x)
            maxY = Swift.max(maxY, p.y)
        }
        let pad = 8.0
        return DiagramRect(x: minX - pad, y: minY - pad,
                           width: maxX - minX + pad * 2,
                           height: maxY - minY + pad * 2)
    }
    public var stableElementLabel: String? { label.isEmpty ? nil : label }
}
```

**Estimated**: ~50 lines.

---

## 8. Slice 8F: C4 Diagrams

### 8.1 Current State

C4 positioned types:

| Type | Key Field |
|------|-----------|
| `PositionedC4Shape` | `alias: String` |
| `PositionedC4Boundary` | `alias: String` |
| `PositionedC4Relationship` | `from: String`, `to: String` |

### 8.2 Stable ID Design

```swift
// Sources/DiagramKitModel/DiagramSelection+C4.swift

extension PositionedC4Shape: DiagramStableElement {
    public var stableElementID: String { "c4-shape:\(alias)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

extension PositionedC4Boundary: DiagramStableElement {
    public var stableElementID: String { "c4-boundary:\(alias)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

extension PositionedC4Relationship: DiagramStableElement {
    public var stableElementID: String {
        let seed = [from, to, label].joined(separator: "→")
        return "c4-rel:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        // startPoint and endPoint are CGPoint, so bridge them.
        let minX = Swift.min(Double(startPoint.x), Double(endPoint.x))
        let maxX = Swift.max(Double(startPoint.x), Double(endPoint.x))
        let minY = Swift.min(Double(startPoint.y), Double(endPoint.y))
        let maxY = Swift.max(Double(startPoint.y), Double(endPoint.y))
        let pad: Double = 8
        return DiagramRect(x: minX - pad, y: minY - pad,
                           width: maxX - minX + pad * 2,
                           height: maxY - minY + pad * 2)
    }
    public var stableElementLabel: String? { label.isEmpty ? nil : label }
}
```

**Note**: `PositionedC4Relationship.startPoint` and `endPoint` are `CGPoint`,
which is an Apple-only type. The `PositionedC4Relationship` struct already has
`#if canImport(CoreGraphics)` guarding the `CGPoint` import. The conformance
here must be guarded similarly, or we should consider migrating those fields
to `DiagramPoint` in a future cleanup. For Phase 8, the conformance file
lives in `DiagramKitModel` and uses the existing `#if canImport(CoreGraphics)`
guard.

**Estimated**: ~60 lines.

---

## 9. Slice 8G: Long Tail

The remaining 23 diagram families produce positioned payloads. Most have
element types with string IDs already. The work per family is:

1. Conform each positioned element type to `DiagramStableElement`.
2. Add a lookup builder case in `PositionedGraph._buildLookup()`.

### 9.1 Family Inventory

| Family | Positioned Types | ID Field | Complexity |
|--------|-----------------|----------|------------|
| xyChart | `PositionedXYChart` (bars, lines, axes) | synthetic | Medium |
| pie | `PositionedPieChart` (slices) | index-based | Low |
| journey | `PositionedJourneyDiagram` (sections, tasks) | text-based | Low |
| gantt | `PositionedGanttDiagram` (sections, tasks) | id strings ✅ | Low |
| quadrantChart | `PositionedQuadrantChart` (points) | text-based | Low |
| requirement | `PositionedRequirementNode`, `PositionedRequirementEdge` | `id: String` ✅ | Low |
| gitGraph | `PositionedGitGraphCommit` (id ✅), `BranchLine`, `BranchLabel`, `Arrow` | Mixed | Medium |
| mindmap | `PositionedMindmapNode` (nodeId ✅, id Int), `PositionedMindmapEdge` (id ✅) | Mixed | Low |
| timeline | `PositionedTimelineSection`, `Task`, `Event` | Int IDs ✅ | Low |
| sankey | `PositionedSankeyNode` (id ✅), `PositionedSankeyLink` (sourceID/targetID) | Mixed | Low |
| block | `PositionedBlockNode` (id ✅), `PositionedBlockEdge` (id ✅) | String IDs ✅ | Low |
| packet | `PositionedPacketBlock` | Int ranges | Low |
| kanban | `PositionedKanbanSection` (id ✅), `PositionedKanbanCard` (id ✅) | String IDs ✅ | Low |
| architecture | `PositionedArchitectureService` (id ✅), `Junction`, `Group`, `Edge` | Mixed | Medium |
| radar | `PositionedRadarDiagram` | synthetic | Low |
| treemap | `PositionedTreemapDiagram` | synthetic | Low |
| venn | `PositionedVennDiagram` | synthetic | Low |
| ishikawa | `PositionedIshikawaDiagram` | synthetic | Low |
| treeView | `PositionedTreeViewDiagram` | synthetic | Low |
| eventModeling | `PositionedEventModelingDiagram` | synthetic | Low |
| wardleyBeta | `PositionedWardleyMapDiagram` | synthetic | Low |
| zenuml | `PositionedZenUMLParticipant` (name ✅), `Message`, `Fragment`, etc. | Mixed | Medium |

### 9.2 Implementation Strategy

For each family, create a `DiagramSelection+<Family>.swift` file containing:

1. `DiagramStableElement` conformances for each positioned type.
2. ID synthesis for types lacking a string `id` field.
3. Bounds computation from the available geometry fields.

**Prioritization within 8G**:

- **Tier 1** (families with explicit string IDs — low effort): gantt, requirement, mindmap, block, kanban, gitGraph
- **Tier 2** (families with mostly string IDs): architecture, zenuml, sankey, timeline
- **Tier 3** (families needing synthetic IDs — medium effort): xyChart, pie, quadrantChart, radar, treemap, venn, ishikawa, treeView, eventModeling, wardleyBeta, packet
- **Tier 4** (diagrams with minimal positioned geometry): journey

Each family file is ~30-80 lines. The lookup builder dispatch grows by one
`case` per family in `_buildLookup()`.

**Estimated total for 8G**: ~1,200 lines across ~25 files. No file over 150 lines.

---

## 10. Pipeline Integration

### 10.1 Changes to DiagramPipeline

The `prepare()` method already constructs `PreparedDiagram(positioned:theme:)`.
No changes needed — the `lookup` is accessed via `prepared.positioned.lookup`.

For consumers using `DiagramPipeline.prepare()`:

```swift
let prepared = try DiagramPipeline.prepare(source: "...", theme: .default)
let lookup = prepared.positioned.lookup

// Hit-testing
if let selection = lookup.element(at: DiagramPoint(x: 150, y: 80)) {
    print("Clicked on \(selection.elementID)")
    if let bounds = lookup.bounds(of: selection) {
        print("Bounds: \(bounds)")
    }
    if let label = lookup.label(for: selection) {
        print("Label: \(label)")
    }
}

// Marquee selection
let rect = DiagramRect(x: 50, y: 0, width: 200, height: 300)
let selected = lookup.elements(in: rect)
```

### 10.2 Font Registration

The `lookup` property accesses `PositionedGraph` which is constructed after
layout. Font registration (`registerBundledFontsIfNeeded()`) runs at the
start of `runPipeline` in `DiagramPipeline`, before layout. No change to
the font registration invariant.

### 10.3 Worker Thread

The lookup is built on whatever thread `prepare()` runs on (via `_runOnWorker`
→ 8 MB-stack `Thread`). Building the lookup is CPU-bound but not
stack-intensive. No new threading concerns.

### 10.4 PreparedDiagram Access

`PreparedDiagram` already exposes `positioned: PositionedGraph`. Consumers
access `prepared.positioned.lookup`. No API changes to `PreparedDiagram`.

---

## 11. Test Strategy

### 11.1 Unit Tests

**Per-family lookup tests** verify:

1. **Stable ID determinism**: Same source → same IDs across multiple
   parse+layout cycles.
2. **Stable ID across layout configs**: Changing `LayoutConfig` (padding,
   spacing) does not change element IDs.
3. **Hit-testing accuracy**: `element(at:)` returns the correct element for
   known positions (node centers, edge midpoints).
4. **Hit-testing at empty space**: `element(at:)` returns nil for points
   outside all elements.
5. **Marquee selection**: `elements(in:)` returns correct elements for
   rectangles covering known regions.
6. **Reverse lookup**: `bounds(of:)` returns the correct `DiagramRect` for
   a known `DiagramSelection`.
7. **Label retrieval**: `label(for:)` returns the correct label.
8. **Edge cases**: zero-element diagrams, single-element diagrams, overlapping
   elements.
9. **All elements accounted**: `lookup.count` matches the expected element
   count for known fixtures.

### 11.2 Test File Structure

```
Tests/DiagramKitTests/Interactivity/
├── DiagramGeometryTests.swift           (~15 tests)
├── DiagramSelectionTests.swift          (~10 tests)
├── DiagramBoundsLookupTests.swift       (~15 tests, generic lookup behavior)
├── FlowchartLookupTests.swift           (~20 tests)
├── StateLookupTests.swift               (~15 tests)
├── SequenceLookupTests.swift            (~25 tests)
├── ClassLookupTests.swift               (~15 tests)
├── ERLookupTests.swift                  (~10 tests)
├── C4LookupTests.swift                  (~10 tests)
├── LongTailLookupTests.swift            (~15 tests, spot-checks)
└── StableIDDeterminismTests.swift       (~10 tests)
```

**Total estimated tests**: ~160 across 10 files.

### 11.3 Regression Safety

Lookup construction does not modify any existing types' stored properties.
Conformances are additive extensions. No parsing, layout, or rendering code
changes. Existing snapshot baselines are unaffected.

---

## 12. Verification Gates

### 12.1 Per-Slice Gates

For each slice, before marking complete:

```bash
swift build --build-tests
swift test --filter DiagramGeometryTests
swift test --filter DiagramSelectionTests
swift test --filter DiagramBoundsLookupTests
swift test --filter <slice-specific lookup tests>
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
```

### 12.2 Full Phase 8 Gate

```bash
swift test                                                  # full suite
swift test --filter Interactivity                           # all lookup tests
swift test --filter CorpusSnapshotTests                     # no regressions
Scripts/bootstrap-smoke-check.sh                             # if Docker/Xcode available
git diff --check
```

### 12.3 File-Size Constraint

No new `.swift` file exceeds 500 lines. Family conformance files are split by
diagram type. `DiagramBoundsLookup.swift` is ~120 lines. `DiagramGeometry.swift`
is ~120 lines.

### 12.4 Sendable Annotation

- `DiagramPoint`, `DiagramRect`, `DiagramSize` — implicitly `Sendable` (all
  `Double` fields).
- `DiagramSelection` — implicitly `Sendable` (all `Sendable` fields).
- `DiagramBoundsLookup` — explicitly `Sendable` via struct with `Sendable`
  fields. The internal `Entry` type is private and `Sendable`.
- `DiagramStableElement` — protocol requires `Sendable` conformance.

### 12.5 Snapshot Baseline Policy

No snapshot baselines are created or modified. The lookup is a new
read-only surface. Existing SVG/image/ASCII baselines remain unchanged.

---

## 13. Deferred / Out of Scope

The following are **explicitly deferred** from Phase 8:

- **`DiagramEditor` model with undo stack.** Phase 8 ships primitives;
  Phase 9 adds the `@MainActor` editor model with selection state, undo,
  and typed mutations.
- **Turnkey editor UI (`DiagramEditorView`).** Phase 8 intentionally ships
  no views. Consumers build their own UI on top of the lookup primitives.
- **Hit-testing with CoreGraphics event integration.** The lookup accepts
  `DiagramPoint`; bridging to `NSEvent` / `UITouch` / `CGPoint` is consumer
  responsibility.
- **Selection-highlight rendering.** No overlay rendering changes.
  Consumers draw their own selection rects/highlights using the bounds from
  `lookup.bounds(of:)`.
- **Element mutation APIs.** `insertNode`, `deleteNode`, `setEdgeLabel` etc.
  belong in Phase 9.
- **Source-pane sync via exporters.** The exporters exist (Phase 7); wiring
  them to an editor model's mutation cycle is Phase 9.
- **Per-element styling queries.** `lookup` returns labels and bounds, not
  colors/fonts/shapes. Those stay in the renderer layer.
- **Replacing `CGRect` in `PreparedDiagram` with `DiagramRect`.** This would
  be a breaking API change. `PreparedDiagram.bounds` remains `CGRect` for
  backward compatibility. The `DiagramRect` is used in the format-neutral
  lookup path only.
- **`DiagramPoint`/`DiagramRect` migration for existing positioned types.**
  Positioned types currently use bare `Double` fields (`x`, `y`, `width`,
  `height`). Migrating them to `DiagramRect` would be a large refactor.
  Phase 8's `DiagramStableElement` conformance wraps the existing fields.
  Full migration is Phase 10 cleanup.

---

## Delivery Cadence

Each slice is independently shippable. Slice 8A (foundation types) must
be implemented first. Slices 8B-8F can proceed in any order after 8A.
Slice 8G (long tail) follows.

| Slice | Content | Est. Lines | Est. Tests | Depends On |
|-------|---------|------------|------------|------------|
| 8A    | Foundation (geometry, selection, lookup, protocol) | ~420 | ~40 | — |
| 8B    | Flowchart + state | ~105 | ~35 | 8A |
| 8C    | Sequence | ~150 | ~25 | 8A |
| 8D    | Class | ~80 | ~15 | 8A |
| 8E    | ER | ~50 | ~10 | 8A |
| 8F    | C4 | ~60 | ~10 | 8A |
| 8G    | Long tail (23 families) | ~1,200 | ~25 | 8A |
| **Total** | | **~2,065** | **~160** | |

**Estimated total source**: ~2,065 lines across ~35 new files. All files
under 500 lines. No existing files materially modified beyond additive
extensions.

**Slice order is 8A first**, then 8B-8F in parallel (they touch disjoint
families), then 8G. A single implementer working sequentially should budget
~1 day for 8A, ~0.5 days per priority family (8B-8F), and ~1-2 days for
the long tail (8G).

---

*This plan was written against the post-Phase-7 codebase described in
`PHASES.md` and `PHASE-7.md`. The positioned types surveyed (2026-05-12)
span 28 families in `Sources/DiagramKitModel/`. The architecture follows
MusicToolkit's `BoundsLookup`/`ScoreSelection` pattern (`ANALYSIS.md` §2.4)
adapted to DiagramKit's typed `PositionedContent` model.*

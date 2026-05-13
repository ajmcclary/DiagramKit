// Phase 8: Interactivity Primitives — Slice 8A
// Read-only spatial index over positioned diagram elements.

import DiagramKitCommon

// MARK: - DiagramBoundsLookup

/// A read-only spatial index over positioned diagram elements.
///
/// Built from a `PositionedGraph` via `PositionedGraph.lookup`.
/// Provides hit-testing, marquee selection, and reverse geometry lookup.
///
/// ## Concurrency Contract
/// `DiagramBoundsLookup` is `Sendable`. It is constructed once and read
/// concurrently. All state is immutable value-type data.
public struct DiagramBoundsLookup: Sendable {

    // MARK: - ElementKind

    /// The category of a diagram element, used for hit-test z-order.
    /// Lower raw values draw first (further back); higher values draw last
    /// (on top) and win hit-test tiebreaking.
    public enum ElementKind: Int, Sendable, Comparable {
        case boundary = 0
        case lifeline = 1
        case group = 2
        case highlight = 3
        case edge = 4
        case activation = 5
        case block = 6
        case note = 7
        case box = 8
        case node = 9
        case actor = 10

        public static func < (lhs: ElementKind, rhs: ElementKind) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Entry

    /// Internal entry: element bounds + opaque ID + human-readable label
    /// + kind + draw order for correct z-order hit-testing.
    private struct Entry: Sendable {
        var bounds: DiagramRect
        var elementID: String
        var label: String?
        var kind: ElementKind
        var drawOrder: Int
    }

    // MARK: - Storage

    /// Entries sorted by minY then minX for efficient hit-testing.
    private var entries: [Entry]
    private var diagramType: DiagramType

    /// The number of elements in this lookup.
    public var count: Int { entries.count }

    /// All element IDs in this lookup. Uniqueness is guaranteed by the
    /// builder layer (duplicate IDs are a builder bug).
    public var allElementIDs: [String] {
        entries.map(\.elementID)
    }

    // MARK: - Hit-testing

    /// Returns the topmost element at `point` in diagram coordinates,
    /// or nil if no element contains the point.
    ///
    /// When multiple elements overlap at the given point, the element with
    /// the highest element-kind priority wins. When kind ties, the highest
    /// draw order wins. When draw order also ties, the element with the
    /// smallest area wins.
    ///
    /// Entries are stored sorted by `minY` ascending, so any entry with
    /// `minY > point.y` cannot contain `point` and is skipped via a binary
    /// search for the upper bound. Hit-test cost is therefore O(log N)
    /// for the cutoff plus a linear scan over the qualifying y-range —
    /// typically a small fraction of the full entry list for realistic
    /// diagrams.
    public func element(at point: DiagramPoint) -> DiagramSelection? {
        // Binary-search the first index whose minY > point.y. Everything
        // before that index has minY <= point.y and is a hit-test candidate.
        var lo = 0
        var hi = entries.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if entries[mid].bounds.minY > point.y {
                hi = mid
            } else {
                lo = mid + 1
            }
        }
        let upper = lo

        var best: (entry: Entry, area: Double)? = nil
        for i in 0..<upper {
            let entry = entries[i]
            guard entry.bounds.contains(point) else { continue }
            let area = entry.bounds.width * entry.bounds.height
            if let current = best {
                // Higher kind priority wins; then draw order; then smaller area.
                if entry.kind < current.entry.kind { continue }
                if entry.kind == current.entry.kind {
                    if entry.drawOrder < current.entry.drawOrder { continue }
                    if entry.drawOrder == current.entry.drawOrder && area >= current.area { continue }
                }
            }
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

    /// Build a lookup from an array of `(element, kind)` tuples.
    /// Draw order is assigned by array position: element at index 0 draws
    /// first (lowest z), element at last index draws last (highest z).
    public static func build(
        diagramType: DiagramType,
        elements: [(any DiagramStableElement, kind: ElementKind)]
    ) -> DiagramBoundsLookup {
        let entries = elements.enumerated().map { idx, pair in
            let el = pair.0
            return Entry(
                bounds: el.stableElementBounds,
                elementID: el.stableElementID,
                label: el.stableElementLabel,
                kind: pair.kind,
                drawOrder: idx
            )
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

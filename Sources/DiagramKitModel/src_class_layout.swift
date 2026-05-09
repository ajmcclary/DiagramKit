// Ported from original/src/class/layout.ts
// Expanded with direction support, namespace groups, notes, config-aware sizing.
import Foundation
import DiagramKitCommon

public enum CLS {
    public static let padding: Double = 40
    public static let boxPadX: Double = 8
    public static let headerBaseHeight: Double = 32
    public static let annotationHeight: Double = 16
    public static let memberRowHeight: Double = 20
    public static let sectionPadY: Double = 8
    public static let emptySectionHeight: Double = 8
    public static let minWidth: Double = 120
    public static let memberFontSize: Double = 11
    public static let memberFontWeight: Double = 400
    public static let nodeSpacing: Double = 40
    public static let layerSpacing: Double = 60
    public static let defaultClassPadding: Double = 12
}

private typealias ClassSizeMap = [String: (width: Double, height: Double, headerHeight: Double, attrHeight: Double, methodHeight: Double)]

private func _asDouble(_ value: Any?) -> Double? {
    if let v = value as? Double { return v }
    if let v = value as? Int { return Double(v) }
    if let v = value as? Float { return Double(v) }
    if let v = value as? NSNumber { return v.doubleValue }
    return nil
}

private func _asString(_ value: Any?) -> String? {
    value as? String
}

private func _asDict(_ value: Any?) -> [String: Any]? {
    value as? [String: Any]
}

private func _asDictArray(_ value: Any?) -> [[String: Any]] {
    if let direct = value as? [[String: Any]] { return direct }
    if let anyArray = value as? [Any] { return anyArray.compactMap { $0 as? [String: Any] } }
    return []
}

private func elkhDirection(from mermaidDir: String) -> String {
    switch mermaidDir.uppercased() {
    case "BT": return "UP"
    case "LR": return "RIGHT"
    case "RL": return "LEFT"
    default: return "DOWN"
    }
}

public func layoutClassDiagramSync(
    _ diagram: ClassDiagram,
    options: RenderOptions = RenderOptions()
) throws -> PositionedClassDiagram {
    try _layoutClassDiagramSyncEntry(diagram, options: options)
}

private func _layoutClassDiagramSyncEntry(
    _ diagram: ClassDiagram,
    options: RenderOptions
) throws -> PositionedClassDiagram {
    if diagram.classes.isEmpty {
        return PositionedClassDiagram(width: 0, height: 0, classes: [], relationships: [], namespaces: [], notes: [], accTitle: diagram.accTitle, accDescription: diagram.accDescription, diagramTitle: diagram.diagramTitle)
    }

    let built = buildClassElkGraph(diagram, options)
    let result = try layoutEngineSync(built.elkGraph)
    return extractClassLayout(result, diagram, built.classSizes)
}

private func buildClassElkGraph(
    _ diagram: ClassDiagram,
    _ options: RenderOptions
) -> (elkGraph: LayoutNode, classSizes: ClassSizeMap) {
    _ = options

    let config = diagram.config
    let hideEmpty = config?.hideEmptyMembersBox ?? false
    let classPad = config?.padding ?? CLS.defaultClassPadding
    var classSizes: ClassSizeMap = [:]

    for cls in diagram.classes {
        let hasAnnotation = !cls.annotations.isEmpty
        let annotCount = cls.annotations.count
        let headerHeight = hasAnnotation
            ? CLS.headerBaseHeight + CLS.annotationHeight * Double(annotCount)
            : CLS.headerBaseHeight

        let hasAttrs = !cls.attributes.isEmpty
        let hasMethods = !cls.methods.isEmpty
        let attrHeight: Double
        let methodHeight: Double

        if hideEmpty && !hasAttrs && !hasMethods {
            attrHeight = 0
            methodHeight = 0
        } else {
            attrHeight = hasAttrs
                ? Double(cls.attributes.count) * CLS.memberRowHeight + CLS.sectionPadY
                : (hideEmpty ? 0 : CLS.emptySectionHeight)
            methodHeight = hasMethods
                ? Double(cls.methods.count) * CLS.memberRowHeight + CLS.sectionPadY
                : (hideEmpty ? 0 : CLS.emptySectionHeight)
        }

        let headerTextW = original_src_styles.estimateTextWidth(
            cls.text.isEmpty ? cls.label : cls.text,
            original_src_styles.FONT_SIZES.nodeLabel,
            original_src_styles.FONT_WEIGHTS.nodeLabel
        )
        let maxAttrW = maxMemberWidth(cls.attributes)
        let maxMethodW = maxMemberWidth(cls.methods)

        let width = max(
            CLS.minWidth,
            headerTextW + classPad * 2,
            maxAttrW + classPad * 2,
            maxMethodW + classPad * 2
        )
        let height = headerHeight + attrHeight + methodHeight

        classSizes[cls.id] = (
            width: width,
            height: height,
            headerHeight: headerHeight,
            attrHeight: attrHeight,
            methodHeight: methodHeight
        )
    }

    var children: [[String: Any]] = []
    for cls in diagram.classes {
        guard let size = classSizes[cls.id] else { continue }
        children.append([
            "id": cls.id,
            "width": size.width,
            "height": size.height,
        ])
    }

    // Add note nodes
    var noteBoxes: [[String: Any]] = []
    for note in diagram.notes {
        let textMetrics = original_src_text_metrics.measureMultilineText(
            note.text,
            fontSize: original_src_styles.FONT_SIZES.edgeLabel,
            fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
        )
        let noteW = max(CLS.minWidth * 0.6, textMetrics.width + 20)
        let noteH = max(40, textMetrics.height + 20)
        noteBoxes.append([
            "id": note.id,
            "width": noteW,
            "height": noteH,
        ])
    }
    children.append(contentsOf: noteBoxes)

    // Add interface nodes (for lollipops)
    var interfaceBoxes: [[String: Any]] = []
    for iface in diagram.interfaces {
        interfaceBoxes.append([
            "id": iface.id,
            "width": 1,
            "height": 1,
        ])
    }
    children.append(contentsOf: interfaceBoxes)

    var edges: [[String: Any]] = []
    for (i, rel) in diagram.relationships.enumerated() {
        var edge: [String: Any] = [
            "id": "e\(i)",
            "sources": [rel.id1],
            "targets": [rel.id2],
        ]

        if !rel.title.isEmpty {
            let metrics = original_src_text_metrics.measureMultilineText(
                rel.title,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
            )
            edge["labels"] = [[
                "text": rel.title,
                "width": metrics.width + 8,
                "height": metrics.height + 6,
            ]]
        }

        edges.append(edge)
    }

    // Add note-to-class edges
    for note in diagram.notes {
        guard let classId = note.class_ else { continue }
        // Check if the class exists
        guard diagram.classMap[classId] != nil else { continue }
        edges.append([
            "id": "note-edge-\(note.id)",
            "sources": [note.id],
            "targets": [classId],
        ])
    }

    let elkDir = elkhDirection(from: diagram.direction)
    let padding = CLS.padding

    let elkGraph: LayoutNode = [
        "id": "root",
        "layoutOptions": [
            "elk.algorithm": "layered",
            "elk.direction": elkDir,
            "elk.spacing.nodeNode": String(CLS.nodeSpacing),
            "elk.layered.spacing.nodeNodeBetweenLayers": String(CLS.layerSpacing),
            "elk.padding": "[top=\(padding),left=\(padding),bottom=\(padding),right=\(padding)]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.edgeLabels.placement": "CENTER",
            "elk.layered.edgeLabels.sideSelection": "ALWAYS_DOWN",
        ],
        "children": children,
        "edges": edges,
    ]

    return (elkGraph, classSizes)
}

private func extractClassLayout(
    _ result: LayoutNode,
    _ diagram: ClassDiagram,
    _ classSizes: ClassSizeMap
) -> PositionedClassDiagram {
    let classLookup = Dictionary(diagram.classes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

    var positionedClasses: [PositionedClassNode] = []
    for child in _asDictArray(result["children"]) {
        guard let id = _asString(child["id"]), let cls = classLookup[id], let size = classSizes[id] else { continue }

        positionedClasses.append(
            PositionedClassNode(
                id: cls.id,
                label: cls.label,
                text: cls.text,
                annotations: cls.annotations,
                attributes: cls.attributes,
                methods: cls.methods,
                x: _asDouble(child["x"]) ?? 0,
                y: _asDouble(child["y"]) ?? 0,
                width: _asDouble(child["width"]) ?? size.width,
                height: _asDouble(child["height"]) ?? size.height,
                headerHeight: size.headerHeight,
                attrHeight: size.attrHeight,
                methodHeight: size.methodHeight,
                cssClasses: cls.cssClasses.isEmpty ? nil : cls.cssClasses,
                styles: cls.styles.isEmpty ? nil : cls.styles,
                link: cls.link,
                linkTarget: cls.linkTarget,
                tooltip: cls.tooltip
            )
        )
    }

    var relationships: [PositionedClassRelationship] = []
    let resultEdges = _asDictArray(result["edges"])
    let relEdgeCount = diagram.relationships.count

    for (i, elkEdge) in resultEdges.enumerated() {
        guard i < relEdgeCount else { break }
        let rel = diagram.relationships[i]

        var points: [ClassPoint] = []
        if let section = _asDictArray(elkEdge["sections"]).first {
            if let start = _asDict(section["startPoint"]),
               let sx = _asDouble(start["x"]),
               let sy = _asDouble(start["y"]) {
                points.append(ClassPoint(x: sx, y: sy))
            }

            for bp in _asDictArray(section["bendPoints"]) {
                if let bx = _asDouble(bp["x"]), let by = _asDouble(bp["y"]) {
                    points.append(ClassPoint(x: bx, y: by))
                }
            }

            if let end = _asDict(section["endPoint"]),
               let ex = _asDouble(end["x"]),
               let ey = _asDouble(end["y"]) {
                points.append(ClassPoint(x: ex, y: ey))
            }
        }

        var labelPosition: ClassPoint?
        if let label = _asDictArray(elkEdge["labels"]).first,
           let lx = _asDouble(label["x"]),
           let ly = _asDouble(label["y"]) {
            labelPosition = ClassPoint(
                x: lx + (_asDouble(label["width"]) ?? 0) / 2,
                y: ly + (_asDouble(label["height"]) ?? 0) / 2
            )
        }

        relationships.append(
            PositionedClassRelationship(
                from: rel.id1,
                to: rel.id2,
                relation: rel.relation,
                title: rel.title.isEmpty ? nil : rel.title,
                relationTitle1: rel.relationTitle1.isEmpty ? nil : rel.relationTitle1,
                relationTitle2: rel.relationTitle2.isEmpty ? nil : rel.relationTitle2,
                points: points,
                labelPosition: labelPosition
            )
        )
    }

    var positionedNamespaces: [PositionedClassNamespace] = []

    // Extract note positions
    var positionedNotes: [PositionedClassNote] = []
    let noteMap = diagram.noteMap
    for child in _asDictArray(result["children"]) {
        guard let id = _asString(child["id"]), noteMap[id] != nil else { continue }
        let note = noteMap[id]!

        // Find note-to-class edge
        var edgePoints: [ClassPoint]? = nil
        let noteEdgeId = "note-edge-\(note.id)"
        for edge in _asDictArray(result["edges"]) {
            if _asString(edge["id"]) == noteEdgeId {
                var pts: [ClassPoint] = []
                if let section = _asDictArray(edge["sections"]).first {
                    if let start = _asDict(section["startPoint"]),
                       let sx = _asDouble(start["x"]),
                       let sy = _asDouble(start["y"]) { pts.append(ClassPoint(x: sx, y: sy)) }
                    for bp in _asDictArray(section["bendPoints"]) {
                        if let bx = _asDouble(bp["x"]), let by = _asDouble(bp["y"]) { pts.append(ClassPoint(x: bx, y: by)) }
                    }
                    if let end = _asDict(section["endPoint"]),
                       let ex = _asDouble(end["x"]),
                       let ey = _asDouble(end["y"]) { pts.append(ClassPoint(x: ex, y: ey)) }
                }
                if !pts.isEmpty { edgePoints = pts }
                break
            }
        }

        positionedNotes.append(
            PositionedClassNote(
                id: note.id,
                text: note.text,
                x: _asDouble(child["x"]) ?? 0,
                y: _asDouble(child["y"]) ?? 0,
                width: _asDouble(child["width"]) ?? 80,
                height: _asDouble(child["height"]) ?? 40,
                classId: note.class_,
                edgePoints: edgePoints
            )
        )
    }

    positionedNamespaces = computePositionedClassNamespaces(
        diagram,
        classes: positionedClasses,
        notes: positionedNotes
    )

    return PositionedClassDiagram(
        width: _asDouble(result["width"]) ?? 600,
        height: _asDouble(result["height"]) ?? 400,
        classes: positionedClasses,
        relationships: relationships,
        namespaces: positionedNamespaces,
        notes: positionedNotes,
        accTitle: diagram.accTitle,
        accDescription: diagram.accDescription,
        diagramTitle: diagram.diagramTitle
    )
}

private func maxMemberWidth(_ members: [ClassMember]) -> Double {
    if members.isEmpty { return 0 }
    var maxW = 0.0
    for member in members {
        let text = member.text
        let w = original_src_styles.estimateMonoTextWidth(text, CLS.memberFontSize)
        if w > maxW { maxW = w }
    }
    return maxW
}

private func computePositionedClassNamespaces(
    _ diagram: ClassDiagram,
    classes: [PositionedClassNode],
    notes: [PositionedClassNote]
) -> [PositionedClassNamespace] {
    guard !diagram.namespaces.isEmpty else { return [] }

    let namespaceMap = diagram.namespaceMap
    let classPositions = Dictionary(classes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    let notePositions = Dictionary(notes.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    let hierarchical = diagram.config?.hierarchicalNamespaces ?? true
    let padding = diagram.config?.padding ?? 16
    let labelPad = 18.0

    func shouldRender(_ namespace: ClassNamespace) -> Bool {
        hierarchical || namespace.explicit
    }

    func explicitAncestor(for namespaceId: String?) -> String? {
        var current = namespaceId
        while let id = current {
            guard let namespace = namespaceMap[id] else { return nil }
            if namespace.explicit { return namespace.id }
            current = namespace.parent
        }
        return nil
    }

    var memo: [String: PositionedClassNamespace] = [:]
    var visiting = Set<String>()

    func buildNamespace(_ namespaceId: String) -> PositionedClassNamespace? {
        if let cached = memo[namespaceId] { return cached }
        guard !visiting.contains(namespaceId),
              let namespace = namespaceMap[namespaceId],
              shouldRender(namespace)
        else { return nil }

        visiting.insert(namespaceId)
        defer { visiting.remove(namespaceId) }

        let directClassIds = diagram.classes.compactMap { cls -> String? in
            if hierarchical {
                return cls.parent == namespace.id ? cls.id : nil
            }
            return explicitAncestor(for: cls.parent) == namespace.id ? cls.id : nil
        }

        let directNoteIds = diagram.notes.compactMap { note -> String? in
            if hierarchical {
                return note.parent == namespace.id ? note.id : nil
            }
            return explicitAncestor(for: note.parent) == namespace.id ? note.id : nil
        }

        let childNamespaces: [PositionedClassNamespace] = hierarchical
            ? namespaceMap.values
                .filter { $0.parent == namespace.id && shouldRender($0) }
                .sorted { $0.id < $1.id }
                .compactMap { buildNamespace($0.id) }
            : []

        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity

        func includeRect(x: Double, y: Double, width: Double, height: Double) {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x + width)
            maxY = max(maxY, y + height)
        }

        for classId in directClassIds {
            if let cls = classPositions[classId] {
                includeRect(x: cls.x, y: cls.y, width: cls.width, height: cls.height)
            }
        }

        for noteId in directNoteIds {
            if let note = notePositions[noteId] {
                includeRect(x: note.x, y: note.y, width: note.width, height: note.height)
            }
        }

        for child in childNamespaces {
            includeRect(x: child.x, y: child.y, width: child.width, height: child.height)
        }

        guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite else {
            return nil
        }

        let positioned = PositionedClassNamespace(
            id: namespace.id,
            label: hierarchical ? namespace.label : namespace.id,
            x: minX - padding,
            y: minY - padding - labelPad,
            width: (maxX - minX) + padding * 2,
            height: (maxY - minY) + padding * 2 + labelPad,
            children: childNamespaces
        )
        memo[namespace.id] = positioned
        return positioned
    }

    return diagram.namespaces.compactMap { buildNamespace($0.id) }
}

public func memberToString(_ m: ClassMember) -> String {
    _memberToStringEntry(m)
}

private func _memberToStringEntry(_ m: ClassMember) -> String {
    m.text
}

open class original_src_class_layout {
    public init() {}

    public static func layoutClassDiagramSync(
        _ diagram: ClassDiagram,
        options: RenderOptions = RenderOptions()
    ) throws -> PositionedClassDiagram {
        try _layoutClassDiagramSyncEntry(diagram, options: options)
    }

    public static func memberToString(_ member: ClassMember) -> String {
        _memberToStringEntry(member)
    }
}

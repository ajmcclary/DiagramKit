// Ported from original/src/class/parser.ts
// Expanded with full Mermaid parity: two-ended relations, namespaces, notes,
// annotations array, lollipop normalization, styling, interactions, config.
import Foundation

// MARK: - Type Model (Phase 2)

public struct ClassDiagram: Sendable {
    public var classes: [ClassNode]
    public var classMap: [String: ClassNode]
    public var relationships: [ClassRelationship]
    public var namespaces: [ClassNamespace]
    public var namespaceMap: [String: ClassNamespace]
    public var notes: [ClassNote]
    public var noteMap: [String: ClassNote]
    public var interfaces: [ClassInterface]
    public var styleClasses: [ClassStyleClass]
    public var direction: String
    public var accTitle: String?
    public var accDescription: String?
    public var diagramTitle: String?
    public var config: ClassConfig?

    public init(
        classes: [ClassNode] = [],
        classMap: [String: ClassNode] = [:],
        relationships: [ClassRelationship] = [],
        namespaces: [ClassNamespace] = [],
        namespaceMap: [String: ClassNamespace] = [:],
        notes: [ClassNote] = [],
        noteMap: [String: ClassNote] = [:],
        interfaces: [ClassInterface] = [],
        styleClasses: [ClassStyleClass] = [],
        direction: String = "TB",
        accTitle: String? = nil,
        accDescription: String? = nil,
        diagramTitle: String? = nil,
        config: ClassConfig? = nil
    ) {
        self.classes = classes
        self.classMap = classMap
        self.relationships = relationships
        self.namespaces = namespaces
        self.namespaceMap = namespaceMap
        self.notes = notes
        self.noteMap = noteMap
        self.interfaces = interfaces
        self.styleClasses = styleClasses
        self.direction = direction
        self.accTitle = accTitle
        self.accDescription = accDescription
        self.diagramTitle = diagramTitle
        self.config = config
    }
}

public struct ClassConfig: Sendable {
    public var hideEmptyMembersBox: Bool = false
    public var hierarchicalNamespaces: Bool = true
    public var padding: Double? = nil

    public init(
        hideEmptyMembersBox: Bool = false,
        hierarchicalNamespaces: Bool = true,
        padding: Double? = nil
    ) {
        self.hideEmptyMembersBox = hideEmptyMembersBox
        self.hierarchicalNamespaces = hierarchicalNamespaces
        self.padding = padding
    }
}

// MARK: - ClassNode

public struct ClassNode: Sendable {
    public var id: String
    public var label: String
    public var type: String?
    public var text: String
    public var shape: String
    public var cssClasses: String
    public var attributes: [ClassMember]
    public var methods: [ClassMember]
    public var annotations: [String]
    public var domId: String
    public var styles: [String]
    public var parent: String?
    public var link: String?
    public var linkTarget: String?
    public var haveCallback: Bool
    public var tooltip: String?
    public var look: String?

    public init(
        id: String,
        label: String,
        type: String? = nil,
        text: String? = nil,
        shape: String = "classBox",
        cssClasses: String = "default",
        attributes: [ClassMember] = [],
        methods: [ClassMember] = [],
        annotations: [String] = [],
        domId: String = "",
        styles: [String] = [],
        parent: String? = nil,
        link: String? = nil,
        linkTarget: String? = nil,
        haveCallback: Bool = false,
        tooltip: String? = nil,
        look: String? = nil
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.text = text ?? "\(label)\(type.map { "<\($0)>" } ?? "")"
        self.shape = shape
        self.cssClasses = cssClasses
        self.attributes = attributes
        self.methods = methods
        self.annotations = annotations
        self.domId = domId
        self.styles = styles
        self.parent = parent
        self.link = link
        self.linkTarget = linkTarget
        self.haveCallback = haveCallback
        self.tooltip = tooltip
        self.look = look
    }
}

// MARK: - ClassMember

public struct ClassMember: Sendable {
    public var id: String
    public var visibility: String
    public var classifier: String
    public var memberType: ClassMemberType
    public var parameters: String
    public var returnType: String
    public var text: String
    public var cssStyle: String

    public enum ClassMemberType: String, Sendable {
        case attribute
        case method
    }

    public init(
        id: String,
        visibility: String = "",
        classifier: String = "",
        memberType: ClassMemberType = .attribute,
        parameters: String = "",
        returnType: String = "",
        text: String? = nil,
        cssStyle: String = ""
    ) {
        self.id = id
        self.visibility = visibility
        self.classifier = classifier
        self.memberType = memberType
        self.parameters = parameters
        self.returnType = returnType
        self.text = text ?? {
            let vis = visibility.isEmpty ? "" : "\(visibility) "
            let genId = parseGenericTypes(id)
            let genParams = parseGenericTypes(parameters)
            let genReturn = parseGenericTypes(returnType)
            let methodPart = memberType == .method ? "(\(genParams))" : ""
            let returnPart = !returnType.isEmpty ? " : \(genReturn)" : ""
            return "\(vis)\(genId)\(methodPart)\(returnPart)"
        }()
        self.cssStyle = cssStyle
    }
}

public typealias RelationshipType = String

// MARK: - ClassRelationship (two-ended)

public struct ClassRelationship: Sendable {
    public var id1: String
    public var id2: String
    public var relationTitle1: String
    public var relationTitle2: String
    public var title: String
    public var text: String
    public var style: [String]
    public var relation: ClassRelationEndpoint
}

public struct ClassRelationEndpoint: Sendable {
    public var type1: Int
    public var type2: Int
    public var lineType: Int
}

public enum ClassRelationType: Int, Sendable {
    case none = -1
    case aggregation = 0
    case inheritance = 1
    case composition = 2
    case dependency = 3
    case lollipop = 4
}

public enum ClassLineType: Int, Sendable {
    case solid = 0
    case dotted = 1
}

// MARK: - New types (Note, Interface, StyleClass)

public struct ClassNote: Sendable {
    public var id: String
    public var class_: String?
    public var text: String
    public var index: Int
    public var parent: String?
}

public struct ClassInterface: Sendable {
    public var id: String
    public var label: String
    public var classId: String
}

public struct ClassStyleClass: Sendable {
    public var id: String
    public var styles: [String]
    public var textStyles: [String]
}

// MARK: - Namespace (hierarchical)

public struct ClassNamespace: Sendable {
    public var id: String
    public var label: String
    public var domId: String
    public var classIds: [String]
    public var noteIds: [String]
    public var children: [ClassNamespace]
    public var parent: String?
    public var explicit: Bool
}

// MARK: - Positioned types (Phase 2.7)

public struct PositionedClassDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var classes: [PositionedClassNode]
    public var relationships: [PositionedClassRelationship]
    public var namespaces: [PositionedClassNamespace]
    public var notes: [PositionedClassNote]
    public var accTitle: String?
    public var accDescription: String?
    public var diagramTitle: String?
}

public struct PositionedClassNode: Sendable {
    public var id: String
    public var label: String
    public var text: String
    public var annotations: [String]
    public var attributes: [ClassMember]
    public var methods: [ClassMember]
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var headerHeight: Double
    public var attrHeight: Double
    public var methodHeight: Double
    public var cssClasses: String?
    public var styles: [String]?
    public var link: String?
    public var linkTarget: String?
    public var tooltip: String?
}

public struct PositionedClassRelationship: Sendable {
    public var from: String
    public var to: String
    public var relation: ClassRelationEndpoint
    public var title: String?
    public var relationTitle1: String?
    public var relationTitle2: String?
    public var points: [ClassPoint]
    public var labelPosition: ClassPoint?
}

public struct PositionedClassNamespace: Sendable {
    public var id: String
    public var label: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var children: [PositionedClassNamespace]
}

public struct PositionedClassNote: Sendable {
    public var id: String
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var classId: String?
    public var edgePoints: [ClassPoint]?
}

public struct ClassPoint: Sendable {
    public var x: Double
    public var y: Double
}

// MARK: - DiagramFrontmatter (Phase 1)

public struct DiagramFrontmatter: Sendable {
    public var title: String?
    public var diagramTitle: String?
    public var classConfig: ClassConfig?
    public var flowchartConfig: original_src_types.FlowchartConfig?
    public var erConfig: ErDiagramConfig?
    public var xyChartConfig: XYChartConfig?
    public var xyChartTheme: XYChartThemeConfig?
    public var pieConfig: PieChartConfig?
    public var pieTheme: PieChartThemeConfig?
    public var sequenceConfig: SequenceDiagramConfig?
    public var stateConfig: original_src_types.StateConfig?
    public var journeyConfig: JourneyDiagramConfig?
    public var ganttConfig: GanttDiagramConfig?
    public var quadrantChartConfig: QuadrantChartConfig?
    public var quadrantChartTheme: QuadrantChartThemeConfig?
    public var requirementConfig: RequirementDiagramConfig?

    public init(
        title: String? = nil,
        diagramTitle: String? = nil,
        classConfig: ClassConfig? = nil,
        flowchartConfig: original_src_types.FlowchartConfig? = nil,
        erConfig: ErDiagramConfig? = nil,
        xyChartConfig: XYChartConfig? = nil,
        xyChartTheme: XYChartThemeConfig? = nil,
        pieConfig: PieChartConfig? = nil,
        pieTheme: PieChartThemeConfig? = nil,
        sequenceConfig: SequenceDiagramConfig? = nil,
        stateConfig: original_src_types.StateConfig? = nil,
        journeyConfig: JourneyDiagramConfig? = nil,
        ganttConfig: GanttDiagramConfig? = nil,
        quadrantChartConfig: QuadrantChartConfig? = nil,
        quadrantChartTheme: QuadrantChartThemeConfig? = nil,
        requirementConfig: RequirementDiagramConfig? = nil
    ) {
        self.title = title
        self.diagramTitle = diagramTitle ?? title
        self.classConfig = classConfig
        self.flowchartConfig = flowchartConfig
        self.erConfig = erConfig
        self.xyChartConfig = xyChartConfig
        self.xyChartTheme = xyChartTheme
        self.pieConfig = pieConfig
        self.pieTheme = pieTheme
        self.sequenceConfig = sequenceConfig
        self.stateConfig = stateConfig
        self.journeyConfig = journeyConfig
        self.ganttConfig = ganttConfig
        self.quadrantChartConfig = quadrantChartConfig
        self.quadrantChartTheme = quadrantChartTheme
        self.requirementConfig = requirementConfig
    }
}

// MARK: - Errors

public enum ClassParserError: Error, LocalizedError, _MermaidRecoverableError {
    case invalidHeader(expected: String, found: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidHeader(expected, found):
            return "Invalid class diagram header. Expected '\(expected)', found '\(found)'."
        }
    }
}

// MARK: - Generic Type Helpers (Slice 1)

public func parseGenericTypes(_ input: String) -> String {
    var result = ""
    var i = input.startIndex
    while i < input.endIndex {
        if input[i] == "~" {
            result.append("<")
            i = input.index(after: i)
            while i < input.endIndex && input[i] != "~" {
                if input[i] == "," {
                    result.append(", ")
                } else {
                    result.append(input[i])
                }
                i = input.index(after: i)
            }
            if i < input.endIndex { i = input.index(after: i) }
            result.append(">")
        } else {
            result.append(input[i])
            i = input.index(after: i)
        }
    }
    return result
}

public func splitClassNameAndType(_ rawId: String) -> (className: String, type: String?) {
    // If backtick-quoted, the entire content is the name (no generic extraction)
    if rawId.hasPrefix("`") && rawId.hasSuffix("`") {
        let inner = String(rawId.dropFirst().dropLast())
        return (inner.trimmingCharacters(in: .whitespacesAndNewlines), nil)
    }
    let cleaned = rawId
    if let tildeIdx = cleaned.firstIndex(of: "~") {
        let className = String(cleaned[..<tildeIdx])
        let typeStart = cleaned.index(after: tildeIdx)
        var type = String(cleaned[typeStart...])
        // Strip trailing ~ if present (closing generic)
        if type.hasSuffix("~") { type = String(type.dropLast()) }
        type = type.trimmingCharacters(in: .whitespacesAndNewlines)
        return (className.trimmingCharacters(in: .whitespacesAndNewlines), type.isEmpty ? nil : type)
    }
    return (cleaned.trimmingCharacters(in: .whitespacesAndNewlines), nil)
}

public func cleanupLabel(_ label: String) -> String {
    var cleaned = label
    if cleaned.hasPrefix(":") { cleaned = String(cleaned.dropFirst()) }
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    if (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) ||
       (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) {
        cleaned = String(cleaned.dropFirst().dropLast())
    }
    return cleaned
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

// MARK: - Parser (Slices 1-9 integrated)

private struct _ParsedMember {
    var member: ClassMember
    var isMethod: Bool
}

private struct _RelationParseResult {
    var type1: Int
    var type2: Int
    var lineType: Int
}

public func parseClassDiagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> ClassDiagram {
    try _parseClassDiagramEntry(lines, frontmatter: frontmatter)
}

private func _parseClassDiagramEntry(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> ClassDiagram {
    // Find the header line (skip blank lines and %% comments)
    var headerIdx = 0
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("%%") {
            headerIdx += 1
            continue
        }
        break
    }

    if headerIdx >= lines.count {
        return ClassDiagram(classes: [], relationships: [], namespaces: [])
    }

    let header = lines[headerIdx]
    if header.range(of: #"^classdiagram(-v2)?\s*$"#, options: [.regularExpression, .caseInsensitive]) == nil {
        throw ClassParserError.invalidHeader(expected: "classDiagram", found: header)
    }

    var diagram = ClassDiagram()
    var classMap: [String: ClassNode] = [:]
    var classOrder: [String] = []
    var namespaceStack: [String] = []
    var currentClassId: String?
    var braceDepth = 0
    var inAccDescrBlock = false
    var accDescrLines: [String] = []

    if let fm = frontmatter {
        diagram.diagramTitle = fm.title
        diagram.config = fm.classConfig
    }

    let bodyLines = Array(lines[(headerIdx + 1)...])

    func storeNamespace(_ namespace: ClassNamespace) {
        diagram.namespaceMap[namespace.id] = namespace
        if let idx = diagram.namespaces.firstIndex(where: { $0.id == namespace.id }) {
            diagram.namespaces[idx] = namespace
        } else {
            diagram.namespaces.append(namespace)
        }
    }

    @discardableResult
    func addNamespace(id rawId: String, label: String?, explicit: Bool) -> String {
        let localId = rawId
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let qualifiedId = namespaceStack.last.map { "\($0).\(localId)" } ?? localId
        let components = qualifiedId.split(separator: ".").map(String.init)
        var parentId: String? = nil

        for (i, comp) in components.enumerated() {
            let path = components.prefix(i + 1).joined(separator: ".")
            let isLeaf = i == components.count - 1
            let displayLabel = isLeaf ? cleanupLabel(label ?? comp) : comp

            if var existing = diagram.namespaceMap[path] {
                existing.parent = existing.parent ?? parentId
                if isLeaf {
                    existing.explicit = existing.explicit || explicit
                    if label != nil {
                        existing.label = displayLabel
                    }
                }
                storeNamespace(existing)
            } else {
                let ns = ClassNamespace(
                    id: path,
                    label: displayLabel,
                    domId: "",
                    classIds: [],
                    noteIds: [],
                    children: [],
                    parent: parentId,
                    explicit: isLeaf ? explicit : false
                )
                storeNamespace(ns)
            }

            if let p = parentId,
               var parent = diagram.namespaceMap[p],
               let child = diagram.namespaceMap[path],
               !parent.children.contains(where: { $0.id == child.id }) {
                parent.children.append(child)
                storeNamespace(parent)
            }

            parentId = path
        }

        return qualifiedId
    }

    func addClassToCurrentNamespace(_ classId: String) {
        guard let nsId = namespaceStack.last, var namespace = diagram.namespaceMap[nsId] else { return }
        if !namespace.classIds.contains(classId) {
            namespace.classIds.append(classId)
        }
        storeNamespace(namespace)

        if var cls = classMap[classId] {
            cls.parent = nsId
            classMap[classId] = cls
        }
    }

    func addNoteToCurrentNamespace(_ noteId: String) {
        guard let nsId = namespaceStack.last, var namespace = diagram.namespaceMap[nsId] else { return }
        if !namespace.noteIds.contains(noteId) {
            namespace.noteIds.append(noteId)
        }
        storeNamespace(namespace)
    }

    func applyStyleClassesToClassMap() {
        guard !diagram.styleClasses.isEmpty else { return }

        for classId in classMap.keys {
            guard var cls = classMap[classId] else { continue }
            let classNames = Set(cls.cssClasses.split(separator: " ").map(String.init))
            var mergedStyles = cls.styles

            for styleClass in diagram.styleClasses {
                if styleClass.id == "default" || classNames.contains(styleClass.id) {
                    for style in styleClass.styles where !mergedStyles.contains(style) {
                        mergedStyles.append(style)
                    }
                }
            }

            cls.styles = mergedStyles
            classMap[classId] = cls
        }
    }

    func relationEndpointClassTypes(_ line: String) -> [(id: String, type: String?)] {
        let tokens = line.trimmingCharacters(in: .whitespacesAndNewlines).tokenizeForRelation()
        guard let arrowIdx = tokens.firstIndex(where: { regexTestForArrow($0) }) else { return [] }

        var fromId = ""
        for token in tokens[..<arrowIdx] {
            if token.hasPrefix("\"") && token.hasSuffix("\"") {
                continue
            } else if token.hasPrefix("`") && token.hasSuffix("`") {
                fromId = String(token.dropFirst().dropLast())
            } else {
                fromId = token
            }
        }

        var toId = ""
        for token in tokens[(arrowIdx + 1)...] {
            if token.hasPrefix(":") { break }
            if token.hasPrefix("\"") && token.hasSuffix("\"") {
                continue
            } else if token.hasPrefix("`") && token.hasSuffix("`") {
                toId = String(token.dropFirst().dropLast())
            } else {
                toId = token
            }
        }

        return [fromId, toId].compactMap { rawId in
            guard !rawId.isEmpty else { return nil }
            let (className, genericType) = splitClassNameAndType(rawId)
            return (className, genericType)
        }
    }

    for line in bodyLines {
        let rawLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle multiline accDescr
        if inAccDescrBlock {
            if rawLine == "}" {
                diagram.accDescription = accDescrLines.joined(separator: "\n")
                inAccDescrBlock = false
                accDescrLines = []
                continue
            }
            accDescrLines.append(rawLine)
            continue
        }

        if rawLine.isEmpty { continue }
        if rawLine.hasPrefix("%%") { continue }

        // Inside class brace block
        if let activeClassId = currentClassId, braceDepth > 0 {
            if rawLine == "}" {
                braceDepth -= 1
                if braceDepth == 0 { currentClassId = nil }
                continue
            }

            // Annotation inside class: <<interface>>
            if let annot = _firstGroup(#"^<<(.+)>>$"#, rawLine) {
                var cls = _ensureClass(&classMap, &classOrder, activeClassId)
                cls.annotations.append(annot)
                classMap[activeClassId] = cls
                continue
            }

            // Separator lines (skip)
            if _regexTest(#"^\.\.$"#, rawLine) || _regexTest(#"^==$"#, rawLine) || _regexTest(#"^__$"#, rawLine) || _regexTest(#"^--$"#, rawLine) {
                continue
            }

            // Comment inside class
            if rawLine.hasPrefix("%%") { continue }

            if let parsed = _parseMember(rawLine) {
                var cls = _ensureClass(&classMap, &classOrder, activeClassId)
                if parsed.isMethod {
                    cls.methods.append(parsed.member)
                } else {
                    cls.attributes.append(parsed.member)
                }
                classMap[activeClassId] = cls
            }
            continue
        }

        // Namespace: namespace Name { or namespace Name["Label"] {
        if rawLine.hasPrefix("namespace") {
            let remainder = String(rawLine.dropFirst("namespace".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            var nsId = remainder
            var nsLabel: String? = nil
            var hasBrace = false

            // Check for label ["..."]
            if let labelGroups = _groups(#"^(\S+?)\s*\["([^"]+)"\]"#, remainder) {
                nsId = labelGroups[safe: 1] ?? remainder
                nsLabel = labelGroups[safe: 2]
            }

            if remainder.hasSuffix("{") || nsId.hasSuffix("{") {
                hasBrace = true
                nsId = nsId.replacingOccurrences(of: "{", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let cleanedId = nsId.replacingOccurrences(of: "`", with: "")
            if hasBrace {
                let qualifiedId = addNamespace(id: cleanedId, label: nsLabel, explicit: true)
                namespaceStack.append(qualifiedId)
            }
            continue
        }

        // End namespace
        if rawLine == "}" && !namespaceStack.isEmpty {
            namespaceStack.removeLast()
            continue
        }

        // Direction
        if let dir = _firstGroup(#"^direction\s+(TB|BT|RL|LR)\s*$"#, rawLine, caseInsensitive: true) {
            diagram.direction = dir.uppercased()
            continue
        }

        // Accessibility
        if let group = _firstGroup(#"^accTitle\s*:\s*(.+)$"#, rawLine) {
            diagram.accTitle = group.trimmingCharacters(in: .whitespacesAndNewlines)
            continue
        }
        if let group = _firstGroup(#"^accDescr\s*:\s*(.+)$"#, rawLine) {
            diagram.accDescription = group.trimmingCharacters(in: .whitespacesAndNewlines)
            continue
        }
        if rawLine == "accDescr {" {
            inAccDescrBlock = true
            continue
        }

        // Note: note "text" or note for ClassName "text"
        if let groups = _groups(#"^note\s+for\s+(\S+?)\s+"([^"]*)"\s*$"#, rawLine) {
            let classId = groups[safe: 1] ?? ""
            let noteText = groups[safe: 2] ?? ""
            let noteIdx = diagram.notes.count
            var note = ClassNote(id: "note\(noteIdx)", class_: classId, text: noteText, index: noteIdx)
            note.parent = namespaceStack.last
            diagram.notes.append(note)
            diagram.noteMap["note\(noteIdx)"] = note
            addNoteToCurrentNamespace("note\(noteIdx)")
            continue
        }
        if let groups = _groups(#"^note\s+"([^"]*)"\s*$"#, rawLine) {
            let noteText = groups[safe: 1] ?? ""
            let noteIdx = diagram.notes.count
            var note = ClassNote(id: "note\(noteIdx)", class_: nil, text: noteText, index: noteIdx)
            note.parent = namespaceStack.last
            diagram.notes.append(note)
            diagram.noteMap["note\(noteIdx)"] = note
            addNoteToCurrentNamespace("note\(noteIdx)")
            continue
        }

        // Separate-line annotation: <<interface>> ClassName
        if let groups = _groups(#"^<<(.+)>>\s+(\S+)$"#, rawLine) {
            let annot = groups[safe: 1] ?? ""
            let classId = groups[safe: 2] ?? ""
            var cls = _ensureClass(&classMap, &classOrder, classId)
            cls.annotations.append(annot)
            classMap[classId] = cls
            continue
        }

        // ::: shorthand declaration: class Shape:::exClass or class Shape:::exClass {
        if let groups = _groups(#"^class\s+(\S+?):::\s*(\S+)\s*(\{\s*)?$"#, rawLine) {
            let idRaw = groups[safe: 1] ?? ""
            let styleName = groups[safe: 2] ?? ""
            let hasBrace = groups[safe: 3]
            let (className, genericType) = splitClassNameAndType(idRaw)
            var cls = _ensureClass(&classMap, &classOrder, className)
            if let t = genericType, !t.isEmpty { cls.type = t; cls.text = "\(cls.label)<\(t)>" }
            cls.cssClasses += " \(styleName)"
            classMap[className] = cls
            if let brace = hasBrace, !brace.isEmpty { currentClassId = className; braceDepth = 1 }
            addClassToCurrentNamespace(className)
            continue
        }

        // Backtick-escaped class: class `Animal Class!` or class `Animal Class!` { ... } or class `Animal Class!` ~T~
        if let groups = _groups(#"^class\s+`([^`]+)`\s*(?:~(\w+)~)?\s*(\{\s*)?$"#, rawLine) {
            let idRaw = groups[safe: 1] ?? ""
            let genericType = groups[safe: 2]
            let hasBrace = groups[safe: 3]
            let (className, _) = splitClassNameAndType(idRaw)
            var cls = _ensureClass(&classMap, &classOrder, className)
            if let t = genericType, !t.isEmpty { cls.type = t; cls.text = "\(cls.label)<\(t)>" }
            classMap[className] = cls
            if let brace = hasBrace, !brace.isEmpty { currentClassId = className; braceDepth = 1 }
            addClassToCurrentNamespace(className)
            continue
        }

        // Class with square-bracket label: class Animal["Animal with a label"]
        if let groups = _groups(#"^class\s+(\S+?)\s*\["([^"]*)"\]\s*(?:\{\s*$)?$"#, rawLine) {
            let idRaw = groups[safe: 1] ?? ""
            let label = groups[safe: 2] ?? idRaw
            let (className, genericType) = splitClassNameAndType(idRaw)
            var cls = _ensureClass(&classMap, &classOrder, className)
            cls.label = cleanupLabel(label)
            cls.type = genericType
            cls.text = "\(cleanupLabel(label))\(genericType.map { "<\($0)>" } ?? "")"
            classMap[className] = cls
            if rawLine.hasSuffix("{") { currentClassId = className; braceDepth = 1 }
            addClassToCurrentNamespace(className)
            continue
        }

        // Class definition: class ClassName { ... }, class ClassName ~T~ { ... }, class ClassName ~T~
        if let groups = _groups(#"^class\s+(\S+?)\s*(?:~(\w+)~)?\s*(\{\s*)$"#, rawLine) {
            let idRaw = groups[safe: 1] ?? ""
            let genericType = groups[safe: 2]
            let (className, _) = splitClassNameAndType(idRaw)
            var cls = _ensureClass(&classMap, &classOrder, className)
            if let t = genericType, !t.isEmpty { cls.type = t; cls.text = "\(cls.label)<\(t)>" }
            classMap[className] = cls
            currentClassId = className
            braceDepth = 1
            addClassToCurrentNamespace(className)
            continue
        }
        if let groups = _groups(#"^class\s+(\S+?)\s*(?:~(\w+)~)?\s*$"#, rawLine) {
            let idRaw = groups[safe: 1] ?? ""
            let genericType = groups[safe: 2]
            let (className, _) = splitClassNameAndType(idRaw)
            var cls = _ensureClass(&classMap, &classOrder, className)
            if let t = genericType, !t.isEmpty { cls.type = t; cls.text = "\(cls.label)<\(t)>" }
            classMap[className] = cls
            addClassToCurrentNamespace(className)
            continue
        }

        // Inline annotation with members: class Shape <<interface>> { ... }
        if let groups = _groups(#"^class\s+(\S+?)\s+<<(.+)>>\s*(\{\s*)$"#, rawLine) {
            let idRaw = groups[safe: 1] ?? ""
            let annot = groups[safe: 2] ?? ""
            let (className, _) = splitClassNameAndType(idRaw)
            let annotations = annot.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            var cls = _ensureClass(&classMap, &classOrder, className)
            cls.annotations = annotations
            classMap[className] = cls
            currentClassId = className
            braceDepth = 1
            addClassToCurrentNamespace(className)
            continue
        }

        // Inline annotated class (no body): class Shape <<interface>>
        if let groups = _groups(#"^class\s+(\S+?)\s+<<(.+)>>\s*$"#, rawLine) {
            let idRaw = groups[safe: 1] ?? ""
            let annot = groups[safe: 2] ?? ""
            let (className, _) = splitClassNameAndType(idRaw)
            let annotations = annot.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            var cls = _ensureClass(&classMap, &classOrder, className)
            cls.annotations = annotations
            classMap[className] = cls
            addClassToCurrentNamespace(className)
            continue
        }

        // Inline empty annotated class: class Shape <<interface>> {}
        if let groups = _groups(#"^class\s+(\S+?)\s+<<(.+)>>\s*\{\s*\}\s*$"#, rawLine) {
            let idRaw = groups[safe: 1] ?? ""
            let annot = groups[safe: 2] ?? ""
            let (className, _) = splitClassNameAndType(idRaw)
            let annotations = annot.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            var cls = _ensureClass(&classMap, &classOrder, className)
            cls.annotations = annotations
            classMap[className] = cls
            addClassToCurrentNamespace(className)
            continue
        }

        // Inline member shorthand: ClassName : member
        if let groups = _groups(#"^(\S+?)\s*:\s*(.+)$"#, rawLine),
           let idRaw = groups[safe: 1], let rest = groups[safe: 2] {
            let (className, _) = splitClassNameAndType(idRaw)
            if !_regexTest(#"<\|--|--|\*--|o--|-->|\.\.>|\.\.\|>|--o|--\*|--\|>|<\|\.\.|<--|<\.\.|\(\)"#, rest) {
                var cls = _ensureClass(&classMap, &classOrder, className)
                if let parsed = _parseMember(rest) {
                    if parsed.isMethod {
                        cls.methods.append(parsed.member)
                    } else {
                        cls.attributes.append(parsed.member)
                    }
                    classMap[className] = cls
                }
                continue
            }
        }

        // Style/Class definitions
        if let groups = _groups(#"^style\s+(\S+?)\s+(.+)$"#, rawLine) {
            let classId = groups[safe: 1] ?? ""
            let styleStr = groups[safe: 2] ?? ""
            if var cls = classMap[classId] {
                for style in styleStr.splitByTopLevelCommas() {
                    let cleaned = style.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty && !cls.styles.contains(cleaned) {
                        cls.styles.append(cleaned)
                    }
                }
                classMap[classId] = cls
            }
            continue
        }
        if let groups = _groups(#"^classDef\s+(\S+?)\s+(.+)$"#, rawLine) {
            let defNames = (groups[safe: 1] ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let rawStyles = groups[safe: 2] ?? ""
            var nodeStyles: [String] = []
            var textStyles: [String] = []
            // Split by comma but be aware of url(...) and hex colors
            let tokens = rawStyles.splitByTopLevelCommas()
            for token in tokens {
                let t = token.trimmingCharacters(in: .whitespaces)
                if t.isEmpty { continue }
                nodeStyles.append(t)
                if _regexTest(#"\bcolor\b"#, t) {
                    textStyles.append(t.replacingOccurrences(of: "fill", with: "bgFill"))
                }
            }
            for defName in defNames {
                diagram.styleClasses.append(ClassStyleClass(id: defName, styles: nodeStyles, textStyles: textStyles))
            }
            continue
        }
        // cssClass "Class01" exClass
        if let groups = _groups(#"^cssClass\s+"([^"]*)"\s+(\S+)\s*$"#, rawLine) {
            let classList = groups[safe: 1] ?? ""
            let styleName = groups[safe: 2] ?? ""
            for cid in classList.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                if var cls = classMap[cid] {
                    cls.cssClasses += " \(styleName)"
                    classMap[cid] = cls
                }
            }
            continue
        }
        // ::: shorthand: class Shape ::: exClass
        if let groups = _groups(#"^class\s+(\S+?)\s+:::\s+(\S+)\s*$"#, rawLine) {
            let classId = groups[safe: 1] ?? ""
            let styleName = groups[safe: 2] ?? ""
            if var cls = classMap[classId] {
                cls.cssClasses += " \(styleName)"
                classMap[classId] = cls
            }
            continue
        }

        // Interaction: link ClassName "url" "tooltip" [_self|_blank]
        if let groups = _groups(#"^link\s+(\S+?)\s+"([^"]*)"(?:\s+"([^"]*)")?(?:\s+(.+))?$"#, rawLine) {
            let classId = groups[safe: 1] ?? ""
            let url = groups[safe: 2] ?? ""
            guard !_isUnsafeURL(url) else { continue }
            let tooltip = groups[safe: 3]
            let target = groups[safe: 4].flatMap { $0.isEmpty ? nil : $0 }
            var cls = _ensureClass(&classMap, &classOrder, classId)
            cls.link = url
            cls.tooltip = tooltip
            cls.linkTarget = target ?? "_self"
            cls.cssClasses += " clickable"
            classMap[classId] = cls
            continue
        }
        // click ClassName href "url" "tooltip" [_self|_blank]
        if let groups = _groups(#"^click\s+(\S+?)\s+href\s+"([^"]*)"(?:\s+"([^"]*)")?(?:\s+(.+))?$"#, rawLine) {
            let classId = groups[safe: 1] ?? ""
            let url = groups[safe: 2] ?? ""
            guard !_isUnsafeURL(url) else { continue }
            let tooltip = groups[safe: 3]
            let target = groups[safe: 4].flatMap { $0.isEmpty ? nil : $0 }
            var cls = _ensureClass(&classMap, &classOrder, classId)
            cls.link = url
            cls.tooltip = tooltip
            cls.linkTarget = target ?? "_self"
            cls.cssClasses += " clickable"
            classMap[classId] = cls
            continue
        }
        // click ClassName call callback() "tooltip"
        if let groups = _groups(#"^click\s+(\S+?)\s+call\s+(\S+)(?:\s+"([^"]*)")?\s*$"#, rawLine) {
            let classId = groups[safe: 1] ?? ""
            let tooltip = groups[safe: 3]
            var cls = _ensureClass(&classMap, &classOrder, classId)
            cls.haveCallback = true
            cls.tooltip = tooltip
            cls.cssClasses += " clickable"
            classMap[classId] = cls
            continue
        }
        // callback ClassName "functionName" "tooltip"
        if let groups = _groups(#"^callback\s+(\S+?)\s+"([^"]*)"(?:\s+"([^"]*)")?\s*$"#, rawLine) {
            let classId = groups[safe: 1] ?? ""
            let tooltip = groups[safe: 3]
            var cls = _ensureClass(&classMap, &classOrder, classId)
            cls.haveCallback = true
            cls.tooltip = tooltip
            cls.cssClasses += " clickable"
            classMap[classId] = cls
            continue
        }

        // Relationship parsing
        if let rel = _parseRelationship(rawLine) {
            for endpoint in relationEndpointClassTypes(rawLine) {
                var cls = _ensureClass(&classMap, &classOrder, endpoint.id)
                if let type = endpoint.type, !type.isEmpty {
                    cls.type = type
                    cls.text = "\(cls.label)<\(type)>"
                    classMap[endpoint.id] = cls
                }
            }
            _ = _ensureClass(&classMap, &classOrder, rel.id1)
            _ = _ensureClass(&classMap, &classOrder, rel.id2)
            diagram.relationships.append(rel)
            continue
        }
    }

    applyStyleClassesToClassMap()
    diagram.classes = classOrder.compactMap { classMap[$0] }
    diagram.classMap = classMap

    // Lollipop normalization (Phase 3.6)
    diagram = _finalizeLollipops(diagram)

    return diagram
}

private func _ensureClass(_ map: inout [String: ClassNode], _ order: inout [String], _ id: String) -> ClassNode {
    if let cls = map[id] { return cls }
    let cls = ClassNode(id: id, label: id, attributes: [], methods: [], annotations: [])
    map[id] = cls
    order.append(id)
    return cls
}

// MARK: - Member Parsing (Slice 3)

private func _parseMember(_ line: String) -> _ParsedMember? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #";$"#, with: "", options: .regularExpression)
    if trimmed.isEmpty { return nil }

    var visibility = ""
    var rest = trimmed

    // Visibility
    if let first = rest.first, "+-#~".contains(first) {
        visibility = String(first)
        rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Method detection: name(params) returnType with optional classifier
    if let groups = _groups(#"^(.+?)\(([^)]*)\)(?:\s*([\s$*]))?(?:\s*(.+?))?([$*])?$"#, rest),
       let nameRaw = groups[safe: 1] {
        let params = groups[safe: 2]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let classifierMiddle = groups[safe: 3]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let returnRaw = groups[safe: 4]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let classifierEnd = groups[safe: 5]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let classifier: String
        if classifierEnd.contains("$") || classifierEnd.contains("*") {
            classifier = classifierEnd
        } else if !classifierMiddle.isEmpty {
            classifier = classifierMiddle.trimmingCharacters(in: .whitespaces)
        } else {
            classifier = ""
        }

        let hasStatic = classifier == "$" || classifierEnd == "$" || nameRaw.hasSuffix("$")
        let hasAbstract = classifier == "*" || classifierEnd == "*" || nameRaw.hasSuffix("*")
        let cleanName = nameRaw.replacingOccurrences(of: #"[$*]$"#, with: "", options: .regularExpression)
        let cleanReturn = returnRaw.replacingOccurrences(of: #"[$*]$"#, with: "", options: .regularExpression)

        // Build text: visibility + name(params) : returnType (with generic conversion)
        let genName = parseGenericTypes(cleanName)
        let genParams = parseGenericTypes(params)
        let genReturn = parseGenericTypes(cleanReturn)
        let text: String = {
            let vis = visibility.isEmpty ? "" : "\(visibility) "
            let methodSig = "\(genName)(\(genParams))"
            if !cleanReturn.isEmpty {
                return "\(vis)\(methodSig) : \(genReturn)"
            }
            return "\(vis)\(methodSig)"
        }()

        // cssStyle
        var cssStyle = ""
        if hasAbstract { cssStyle = "font-style:italic;" }
        else if hasStatic { cssStyle = "text-decoration:underline;" }

        let member = ClassMember(
            id: cleanName,
            visibility: visibility,
            classifier: classifier,
            memberType: .method,
            parameters: params,
            returnType: cleanReturn,
            text: text,
            cssStyle: cssStyle
        )
        return _ParsedMember(member: member, isMethod: true)
    }

    // Attribute: just name/type (no parentheses)
    // The full text is the display string (no type/name split!)
    // Scan for classifier ($ or *) anywhere in the text and strip it
    var rawAttr = rest

    var attrClassifier = ""
    if let last = rawAttr.last, String(last) == "$" || String(last) == "*" {
        attrClassifier = String(last)
        rawAttr = String(rawAttr.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
    } else if rawAttr.contains("$ ") {
        attrClassifier = "$"
        rawAttr = rawAttr.replacingOccurrences(of: "$ ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    } else if rawAttr.contains("* ") {
        attrClassifier = "*"
        rawAttr = rawAttr.replacingOccurrences(of: "* ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    } else if rawAttr.contains("$") {
        // $ might be part of a string like "count$"
        if let range = rawAttr.range(of: "$") {
            attrClassifier = "$"
            rawAttr = rawAttr.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    } else if rawAttr.contains("*") && !rawAttr.contains("*/") {
        // * might be part of a pointer or comment
        if let range = rawAttr.range(of: "*") {
            attrClassifier = "*"
            rawAttr = rawAttr.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    let hasAbstract = attrClassifier == "*"
    let hasStatic = attrClassifier == "$"

    let attrText = parseGenericTypes(rawAttr)
    let attrId = rawAttr

    var cssStyle = ""
    if hasAbstract { cssStyle = "font-style:italic;" }
    else if hasStatic { cssStyle = "text-decoration:underline;" }

    let member = ClassMember(
        id: attrId,
        visibility: visibility,
        classifier: attrClassifier,
        memberType: .attribute,
        parameters: "",
        returnType: "",
        text: visibility.isEmpty ? attrText : "\(visibility) \(attrText)",
        cssStyle: cssStyle
    )
    return _ParsedMember(member: member, isMethod: false)
}

// MARK: - Relationship Parsing (Slice 4 - Two-ended tokenizer)

private func _parseRelationship(_ line: String) -> ClassRelationship? {
    // Tokenize the line to find arrow patterns and extract from/to/cardinality/label
    // Using a custom tokenizer to handle quoted strings and complex arrow syntax

    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

    // Split by whitespace tokens to identify from/to/arrow
    let tokens = trimmed.tokenizeForRelation()
    guard tokens.count >= 3 else { return nil }

    // Find arrow token index first
    var arrowIdx = -1
    var arrowToken = ""
    for (i, token) in tokens.enumerated() {
        if regexTestForArrow(token) {
            arrowIdx = i
            arrowToken = token
            break
        }
    }

    guard arrowIdx >= 0 else { return nil }

    // Tokens before the arrow: fromId + optional fromCardinality
    let beforeTokens = Array(tokens[..<arrowIdx])
    let afterTokens = Array(tokens[(arrowIdx + 1)...])

    var fromId = ""
    var fromCard: String? = nil
    var toId = ""
    var toCard: String? = nil
    var label: String? = nil

    // Parse left side: [fromId] or [fromCard fromId] or [fromId fromCard]
    for token in beforeTokens {
        if token.hasPrefix("\"") && token.hasSuffix("\"") {
            fromCard = String(token.dropFirst().dropLast())
        } else if token.hasPrefix("`") && token.hasSuffix("`") {
            fromId = String(token.dropFirst().dropLast())
        } else {
            fromId = token
        }
    }

    // Parse right side: [toCard] [toId] or [toId] [toCard] or [toId] [toCard] [: label...]
    var foundColon = false
    var labelTokens: [String] = []
    for token in afterTokens {
        if foundColon {
            labelTokens.append(token)
            continue
        }
        if token.hasPrefix(":") {
            foundColon = true
            let rest = String(token.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rest.isEmpty { labelTokens.append(rest) }
            continue
        }
        if token.hasPrefix("\"") && token.hasSuffix("\"") {
            if toId.isEmpty {
                toCard = String(token.dropFirst().dropLast())
            } else {
                toCard = String(token.dropFirst().dropLast())
            }
        } else if token.hasPrefix("`") && token.hasSuffix("`") {
            toId = String(token.dropFirst().dropLast())
        } else {
            toId = token
        }
    }
    if !labelTokens.isEmpty {
        label = labelTokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if arrowIdx < 0 || fromId.isEmpty || toId.isEmpty { return nil }

    // Clean backtick-escaped IDs
    fromId = _unbacktick(fromId)
    toId = _unbacktick(toId)
    fromId = splitClassNameAndType(fromId).className
    toId = splitClassNameAndType(toId).className

    // Check for label after toId
    if label == nil, let labelGroup = _firstGroup(#":\s*(.+)$"#, trimmed) {
        label = labelGroup.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Parse the arrow into type1/type2/lineType
    guard let parsed = _tokenizeArrow(arrowToken) else { return nil }

    return ClassRelationship(
        id1: fromId,
        id2: toId,
        relationTitle1: fromCard ?? "",
        relationTitle2: toCard ?? "",
        title: label ?? "",
        text: trimmed,
        style: [],
        relation: ClassRelationEndpoint(
            type1: parsed.type1,
            type2: parsed.type2,
            lineType: parsed.lineType
        )
    )
}

private func regexTestForArrow(_ token: String) -> Bool {
    _regexTest(#"^(<\|--\|>|<\|\.\.\|>|<\|--|<\|\.\.|--\|>|\.\.\|>|\*--\*|\*--|--\*|o--o|o--|--o|-->|<--|\.\.>|<\.\.|--|\.\.|\(\)--|--\(\)|\*\.\.\*|\*\.\.|\.\.\*|o\.\.o|o\.\.|\.\.o|<\|--\*|<\|\.\.\*|<--\*|\.\.>\*|\*--\|>|\*\.\.\|>|o--\|>|o\.\.\|>|--\|>\*|\.\.\|>\*)$"#, token)
}

private func _tokenizeArrow(_ arrow: String) -> _RelationParseResult? {
    let chars = Array(arrow)
    var i = 0
    var type1 = ClassRelationType.none.rawValue
    var type2 = ClassRelationType.none.rawValue
    var lineType = ClassLineType.solid.rawValue

    // Parse left side marker
    if i < chars.count {
        if chars[i] == "<" && i + 1 < chars.count && chars[i + 1] == "|" { type1 = ClassRelationType.inheritance.rawValue; i += 2 }
        else if chars[i] == "*" { type1 = ClassRelationType.composition.rawValue; i += 1 }
        else if chars[i] == "o" { type1 = ClassRelationType.aggregation.rawValue; i += 1 }
        else if chars[i] == "<" { type1 = ClassRelationType.dependency.rawValue; i += 1 }
        else if chars[i] == "(" && i + 1 < chars.count && chars[i + 1] == ")" { type1 = ClassRelationType.lollipop.rawValue; i += 2 }
    }

    // Parse line type
    if i + 1 < chars.count && chars[i] == "." && chars[i + 1] == "." { lineType = ClassLineType.dotted.rawValue; i += 2 }
    else if i + 1 < chars.count && chars[i] == "-" && chars[i + 1] == "-" { lineType = ClassLineType.solid.rawValue; i += 2 }
    else {
        // Single character remaining?
        if i < chars.count && (chars[i] == "." || chars[i] == "-") { i += 1 }
    }

    // Parse right side marker
    while i < chars.count {
        if chars[i] == "|" && i + 1 < chars.count && chars[i + 1] == ">" { type2 = ClassRelationType.inheritance.rawValue; i += 2; break }
        else if i < chars.count && chars[i] == "*" { type2 = ClassRelationType.composition.rawValue; i += 1 }
        else if i < chars.count && chars[i] == "o" { type2 = ClassRelationType.aggregation.rawValue; i += 1 }
        else if i < chars.count && chars[i] == ">" { type2 = ClassRelationType.dependency.rawValue; i += 1 }
        else if chars[i] == "(" && i + 1 < chars.count && chars[i + 1] == ")" { type2 = ClassRelationType.lollipop.rawValue; i += 2; break }
        else { i += 1 }
        break
    }

    return _RelationParseResult(type1: type1, type2: type2, lineType: lineType)
}

private func _unbacktick(_ id: String) -> String {
    if id.hasPrefix("`") && id.hasSuffix("`") {
        return String(id.dropFirst().dropLast())
    }
    return id
}

// MARK: - Lollipop Normalization (Phase 3.6)

private func _finalizeLollipops(_ diagram: ClassDiagram) -> ClassDiagram {
    var result = diagram
    var interfaceCount = result.interfaces.count

    for i in 0..<result.relationships.count {
        var rel = result.relationships[i]

        if rel.relation.type1 == ClassRelationType.lollipop.rawValue &&
            rel.relation.type2 == ClassRelationType.none.rawValue {
            let ifaceId = "interface\(interfaceCount)"
            let iface = ClassInterface(id: ifaceId, label: rel.id1, classId: rel.id2)
            result.interfaces.append(iface)
            rel.id1 = ifaceId
            interfaceCount += 1

            // Ensure class exists
            if result.classMap[rel.id2] == nil {
                let cls = ClassNode(id: rel.id2, label: rel.id2)
                result.classMap[rel.id2] = cls
                if !result.classes.contains(where: { $0.id == rel.id2 }) {
                    result.classes.append(cls)
                }
            }
        }

        if rel.relation.type2 == ClassRelationType.lollipop.rawValue &&
            rel.relation.type1 == ClassRelationType.none.rawValue {
            let ifaceId = "interface\(interfaceCount)"
            let iface = ClassInterface(id: ifaceId, label: rel.id2, classId: rel.id1)
            result.interfaces.append(iface)
            rel.id2 = ifaceId
            interfaceCount += 1

            if result.classMap[rel.id1] == nil {
                let cls = ClassNode(id: rel.id1, label: rel.id1)
                result.classMap[rel.id1] = cls
                if !result.classes.contains(where: { $0.id == rel.id1 }) {
                    result.classes.append(cls)
                }
            }
        }

        result.relationships[i] = rel
    }

    return result
}

// MARK: - Regex Helpers

private func _regexTest(_ pattern: String, _ value: String, caseInsensitive: Bool = false) -> Bool {
    let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return false }
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    return regex.firstMatch(in: value, options: [], range: range) != nil
}

private func _firstGroup(_ pattern: String, _ value: String, caseInsensitive: Bool = false) -> String? {
    _groups(pattern, value, caseInsensitive: caseInsensitive)?[safe: 1]
}

private func _groups(_ pattern: String, _ value: String, caseInsensitive: Bool = false) -> [String]? {
    let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
    let nsValue = value as NSString
    let range = NSRange(location: 0, length: nsValue.length)
    guard let match = regex.firstMatch(in: value, options: [], range: range) else { return nil }

    var results: [String] = []
    for idx in 0..<match.numberOfRanges {
        let r = match.range(at: idx)
        if r.location == NSNotFound {
            results.append("")
        } else {
            results.append(nsValue.substring(with: r))
        }
    }
    return results
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    func tokenizeForRelation() -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuote = false
        var inBacktick = false
        for ch in self {
            if ch == "\"" && !inBacktick {
                inQuote.toggle()
                current.append(ch)
                continue
            }
            if ch == "`" && !inQuote {
                inBacktick.toggle()
                current.append(ch)
                continue
            }
            if !inQuote && !inBacktick && ch.isWhitespace {
                if !current.isEmpty { tokens.append(current); current = "" }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    func splitByTopLevelCommas() -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        for ch in self {
            if ch == "(" { depth += 1 }
            else if ch == ")" { depth -= 1 }
            if ch == "," && depth == 0 {
                if !current.isEmpty { parts.append(current); current = "" }
                continue
            }
            current.append(ch)
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }
}

// MARK: - URL Security Validation

private func _isUnsafeURL(_ url: String) -> Bool {
    let lower = url.trimmingCharacters(in: .whitespaces).lowercased()
    let dangerousPrefixes = ["javascript:", "data:", "vbscript:", "file:"]
    for prefix in dangerousPrefixes {
        if lower.hasPrefix(prefix) { return true }
    }
    return false
}

// MARK: - Wrapper class

open class original_src_class_parser {
    public init() {}

    public static func parseClassDiagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> ClassDiagram {
        try _parseClassDiagramEntry(lines, frontmatter: frontmatter)
    }
}

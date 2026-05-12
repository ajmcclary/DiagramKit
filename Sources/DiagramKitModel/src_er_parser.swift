// Ported from original/src/er/parser.ts — expanded for Mermaid parity
import Foundation
import DiagramKitCommon

// MARK: - Cardinality & Identification Enums

public enum ErCardinality: String, Sendable, CaseIterable {
    case zeroOrOne = "ZERO_OR_ONE"
    case zeroOrMore = "ZERO_OR_MORE"
    case oneOrMore = "ONE_OR_MORE"
    case onlyOne = "ONLY_ONE"
    case mdParent = "MD_PARENT"
}

public enum ErIdentification: String, Sendable {
    case identifying = "IDENTIFYING"
    case nonIdentifying = "NON_IDENTIFYING"
}

// MARK: - RelSpec

public struct ErRelSpec: Sendable {
    public var cardA: ErCardinality
    public var cardB: ErCardinality
    public var relType: ErIdentification

    public init(cardA: ErCardinality, cardB: ErCardinality, relType: ErIdentification) {
        self.cardA = cardA
        self.cardB = cardB
        self.relType = relType
    }
}

// MARK: - EntityClass

public struct ErEntityClass: Sendable {
    public var id: String
    public var styles: [String]
    public var textStyles: [String]

    public init(id: String, styles: [String] = [], textStyles: [String] = []) {
        self.id = id
        self.styles = styles
        self.textStyles = textStyles
    }
}

// MARK: - Core Types

public struct ErDiagram: Sendable {
    public var entities: [ErEntity]
    public var relationships: [ErRelationship]
    public var classes: [String: ErEntityClass]
    public var direction: ErDirection
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: ErDiagramConfig?

    public init(
        entities: [ErEntity] = [],
        relationships: [ErRelationship] = [],
        classes: [String: ErEntityClass] = [:],
        direction: ErDirection = .tb,
        accTitle: String? = nil,
        accDescr: String? = nil,
        diagramTitle: String? = nil,
        config: ErDiagramConfig? = nil
    ) {
        self.entities = entities
        self.relationships = relationships
        self.classes = classes
        self.direction = direction
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
    }
}

public struct ErEntity: Sendable {
    public var key: String
    public var nodeId: String
    public var label: String
    public var alias: String
    public var attributes: [ErAttribute]
    public var shape: String
    public var look: String
    public var cssClasses: String
    public var cssStyles: [String]
    public var cssCompiledStyles: [String]
    public var labelType: String
    public var colorIndex: Int?

    public var id: String { key }

    public init(
        key: String,
        nodeId: String? = nil,
        label: String,
        alias: String = "",
        attributes: [ErAttribute] = [],
        shape: String = "erBox",
        look: String = "default",
        cssClasses: String = "default",
        cssStyles: [String] = [],
        cssCompiledStyles: [String] = [],
        labelType: String = "markdown",
        colorIndex: Int? = nil
    ) {
        self.key = key
        self.nodeId = nodeId ?? "entity-\(key)-0"
        self.label = label
        self.alias = alias
        self.attributes = attributes
        self.shape = shape
        self.look = look
        self.cssClasses = cssClasses
        self.cssStyles = cssStyles
        self.cssCompiledStyles = cssCompiledStyles
        self.labelType = labelType
        self.colorIndex = colorIndex
    }
}

public struct ErAttribute: Sendable {
    public var type: String
    public var name: String
    public var keys: [String]
    public var comment: String

    public init(
        type: String,
        name: String,
        keys: [String] = [],
        comment: String = ""
    ) {
        self.type = type
        self.name = name
        self.keys = keys
        self.comment = comment
    }
}

public struct ErRelationship: Sendable {
    public var entity1: String
    public var entity2: String
    public var entityAId: String
    public var entityBId: String
    public var roleA: String
    public var relSpec: ErRelSpec

    public var cardinality1: String { relSpec.cardB.rawValue }
    public var cardinality2: String { relSpec.cardA.rawValue }
    public var label: String { roleA }
    public var identifying: Bool { relSpec.relType == .identifying }

    public init(
        entity1: String,
        entity2: String,
        entityAId: String,
        entityBId: String,
        roleA: String,
        relSpec: ErRelSpec
    ) {
        self.entity1 = entity1
        self.entity2 = entity2
        self.entityAId = entityAId
        self.entityBId = entityBId
        self.roleA = roleA
        self.relSpec = relSpec
    }
}

// MARK: - Positioned Types

public struct PositionedErDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var entities: [PositionedErEntity]
    public var relationships: [PositionedErRelationship]
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: ErDiagramConfig?

    public init(
        width: Double,
        height: Double,
        entities: [PositionedErEntity],
        relationships: [PositionedErRelationship],
        accTitle: String? = nil,
        accDescr: String? = nil,
        diagramTitle: String? = nil,
        config: ErDiagramConfig? = nil
    ) {
        self.width = width
        self.height = height
        self.entities = entities
        self.relationships = relationships
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
    }
}

public struct PositionedErEntity: Sendable {
    public var id: String
    public var nodeId: String
    public var label: String
    public var attributes: [ErAttribute]
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var headerHeight: Double
    public var rowHeight: Double
    public var cssClasses: String
    public var cssStyles: [String]
    public var cssCompiledStyles: [String]
    public var look: String
    public var alias: String
    public var labelType: String

    public init(
        id: String,
        nodeId: String = "",
        label: String,
        attributes: [ErAttribute] = [],
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        headerHeight: Double = 0,
        rowHeight: Double = 0,
        cssClasses: String = "default",
        cssStyles: [String] = [],
        cssCompiledStyles: [String] = [],
        look: String = "default",
        alias: String = "",
        labelType: String = "markdown"
    ) {
        self.id = id
        self.nodeId = nodeId
        self.label = label
        self.attributes = attributes
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.headerHeight = headerHeight
        self.rowHeight = rowHeight
        self.cssClasses = cssClasses
        self.cssStyles = cssStyles
        self.cssCompiledStyles = cssCompiledStyles
        self.look = look
        self.alias = alias
        self.labelType = labelType
    }
}

public struct PositionedErRelationship: Sendable {
    public var entity1: String
    public var entity2: String
    public var entityAId: String
    public var entityBId: String
    public var cardinality1: String
    public var cardinality2: String
    public var label: String
    public var identifying: Bool
    public var points: [ErPoint]
    public var relSpec: ErRelSpec

    public init(
        entity1: String,
        entity2: String,
        entityAId: String = "",
        entityBId: String = "",
        cardinality1: String,
        cardinality2: String,
        label: String,
        identifying: Bool,
        points: [ErPoint],
        relSpec: ErRelSpec = ErRelSpec(cardA: .onlyOne, cardB: .onlyOne, relType: .identifying)
    ) {
        self.entity1 = entity1
        self.entity2 = entity2
        self.entityAId = entityAId
        self.entityBId = entityBId
        self.cardinality1 = cardinality1
        self.cardinality2 = cardinality2
        self.label = label
        self.identifying = identifying
        self.points = points
        self.relSpec = relSpec
    }
}

public struct ErPoint: Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// MARK: - Errors

public enum ErParserError: Error, LocalizedError, _RecoverableDiagramError {
    case invalidHeader(expected: String, found: String)
    case invalidRelationship(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidHeader(expected, found):
            return "Invalid ER diagram header. Expected '\(expected)', found '\(found)'."
        case let .invalidRelationship(detail):
            return "Invalid ER relationship: \(detail)"
        }
    }
}

// MARK: - Public API

public func parseErDiagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> ErDiagram {
    try _parseErDiagramEntry(lines, frontmatter: frontmatter)
}

// MARK: - Parser Implementation

private func _parseErDiagramEntry(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> ErDiagram {
    guard let header = lines.first else {
        return ErDiagram(entities: [], relationships: [])
    }
    if header.range(of: #"^erdiagram\s*$"#, options: [.regularExpression, .caseInsensitive]) == nil {
        throw ErParserError.invalidHeader(expected: "erDiagram", found: header)
    }

    var diagram = ErDiagram(
        entities: [],
        relationships: [],
        diagramTitle: frontmatter?.diagramTitle ?? frontmatter?.title,
        config: frontmatter?.erConfig
    )
    var entityMap: [String: ErEntity] = [:]
    var entityOrder: [String] = []
    var currentEntityId: String?
    var accDescrLines: [String]?
    var entityCount = 0

    func allocNodeId(_ key: String) -> String {
        entityCount += 1
        return "entity-\(_sanitizeErNodeIdKey(key))-\(entityCount)"
    }

    func ensureEntity(_ name: String) -> (ErEntity, String) {
        if let entity = entityMap[name] {
            return (entity, entity.nodeId)
        }
        let nid = allocNodeId(name)
        let entity = ErEntity(
            key: name,
            nodeId: nid,
            label: name,
            attributes: [],
            look: diagram.config?.look ?? "default",
            labelType: diagram.config?.htmlLabels == false ? "text" : "markdown"
        )
        entityMap[name] = entity
        entityOrder.append(name)
        return (entity, nid)
    }

    func applyClasses(_ entityName: String, _ classNames: [String]) {
        guard !classNames.isEmpty else { return }
        _ = ensureEntity(entityName)
        guard var entity = entityMap[entityName] else { return }
        _appendErClasses(&entity, classNames)
        entityMap[entityName] = entity
    }

    if lines.count <= 1 {
        return diagram
    }

    for line in lines.dropFirst() {
        let rawLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawLine.isEmpty {
            continue
        }

        if accDescrLines != nil {
            if let closeIndex = rawLine.firstIndex(of: "}") {
                let beforeClose = String(rawLine[..<closeIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !beforeClose.isEmpty {
                    accDescrLines?.append(beforeClose)
                }
                diagram.accDescr = accDescrLines?
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                accDescrLines = nil
            } else {
                accDescrLines?.append(rawLine)
            }
            continue
        }

        // Inside an entity block — accumulate attributes until '}'
        if let activeEntityId = currentEntityId {
            if rawLine == "}" {
                currentEntityId = nil
                continue
            }
            if let attr = _parseAttribute(rawLine) {
                var entity = entityMap[activeEntityId] ?? {
                    let nid = allocNodeId(activeEntityId)
                    let e = ErEntity(key: activeEntityId, nodeId: nid, label: activeEntityId, attributes: [])
                    entityMap[activeEntityId] = e
                    entityOrder.append(activeEntityId)
                    return e
                }()
                entity.attributes.append(attr)
                entityMap[activeEntityId] = entity
            }
            continue
        }

        // Accessibility directives
        if let accTitle = _parseAccTitle(rawLine) {
            diagram.accTitle = accTitle
            continue
        }
        if let accDescr = _parseAccDescr(rawLine) {
            diagram.accDescr = accDescr
            continue
        }
        if let firstLine = _parseAccDescrMultilineStart(rawLine) {
            accDescrLines = []
            if let closeIndex = firstLine.firstIndex(of: "}") {
                let beforeClose = String(firstLine[..<closeIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !beforeClose.isEmpty {
                    accDescrLines?.append(beforeClose)
                }
                diagram.accDescr = accDescrLines?
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                accDescrLines = nil
            } else if !firstLine.isEmpty {
                accDescrLines?.append(firstLine)
            }
            continue
        }

        // Inline title directive (Mermaid grammar: title title_value)
        if let diagTitle = _parseInlineTitle(rawLine) {
            diagram.diagramTitle = diagTitle
            continue
        }

        // Direction
        if let dir = _parseDirection(rawLine) {
            diagram.direction = dir
            continue
        }

        // Style statement
        if rawLine.hasPrefix("style ") {
            _ = _parseStyle(rawLine, &entityMap)
            continue
        }

        // classDef statement
        if rawLine.hasPrefix("classDef ") {
            if let cd = _parseClassDef(rawLine) {
                for clsName in cd.names {
                    diagram.classes[clsName] = ErEntityClass(id: clsName, styles: cd.styles, textStyles: cd.textStyles)
                    // "default" class applies to all entities
                    if clsName == "default" {
                        for key in entityOrder {
                            if var ent = entityMap[key] {
                                ent.cssCompiledStyles = cd.styles
                                entityMap[key] = ent
                            }
                        }
                    }
                }
            }
            continue
        }

        // class statement
        if rawLine.hasPrefix("class ") {
            _ = _parseClass(rawLine, &entityMap, diagram.classes)
            continue
        }

        // Try entity block with optional alias and class shorthand
        if let blockResult = _parseEntityBlock(rawLine) {
            let id = blockResult.id
            let alias = blockResult.alias
            let classNames = blockResult.classNames
            let label = alias.isEmpty ? id : alias

            if let existing = entityMap[id] {
                var entity = existing
                if !alias.isEmpty && entity.alias.isEmpty {
                    entity.label = label
                    entity.alias = alias
                }
                if !classNames.isEmpty {
                    _appendErClasses(&entity, classNames)
                }
                if let inline = blockResult.inlineContent, !inline.isEmpty, let attr = _parseAttribute(inline) {
                    entity.attributes.append(attr)
                }
                entityMap[id] = entity
            } else {
                let nid = allocNodeId(id)
                var entity = ErEntity(
                    key: id,
                    nodeId: nid,
                    label: label,
                    alias: alias,
                    shape: "erBox",
                    look: diagram.config?.look ?? "default",
                    cssClasses: classNames.isEmpty ? "default" : classNames.joined(separator: " "),
                    labelType: diagram.config?.htmlLabels == false ? "text" : "markdown"
                )
                if let inline = blockResult.inlineContent, !inline.isEmpty, let attr = _parseAttribute(inline) {
                    entity.attributes.append(attr)
                }
                entityMap[id] = entity
                if !entityOrder.contains(id) {
                    entityOrder.append(id)
                }
            }

            if blockResult.hasAttributes && blockResult.inlineContent == nil {
                currentEntityId = id
            }
            continue
        }

        // Relationship line
        if let rel = _parseRelationshipLine(rawLine, ensureEntity, applyClasses) {
            diagram.relationships.append(rel)
            continue
        }

        // Try standalone entity with optional alias and class shorthand
        if let entResult = _parseStandaloneEntity(rawLine) {
            let id = entResult.id
            let alias = entResult.alias
            let classNames = entResult.classNames
            let label = alias.isEmpty ? id : alias

            // If entity already exists (e.g., from a relationship), merge alias
            if let existing = entityMap[id] {
                var entity = existing
                if !alias.isEmpty && entity.alias.isEmpty {
                    entity.label = label
                    entity.alias = alias
                }
                if !classNames.isEmpty {
                    _appendErClasses(&entity, classNames)
                }
                entityMap[id] = entity
            } else {
                let nid = allocNodeId(id)
                let entity = ErEntity(
                    key: id,
                    nodeId: nid,
                    label: label,
                    alias: alias,
                    shape: "erBox",
                    look: diagram.config?.look ?? "default",
                    cssClasses: classNames.isEmpty ? "default" : classNames.joined(separator: " "),
                    labelType: diagram.config?.htmlLabels == false ? "text" : "markdown"
                )
                entityMap[id] = entity
                entityOrder.append(id)
            }
            continue
        }

        // Unrecognized line — throw for invalid relationship-like syntax
        if rawLine.contains("--") || rawLine.contains("..") || rawLine.contains(".-") || rawLine.contains("-.") || rawLine.contains(" to ") || rawLine.contains(" optionally ") {
            throw ErParserError.invalidRelationship("Unrecognized relationship syntax: \(rawLine)")
        }
        // Also check for lines that look like failed relationships (multiple words with :)
        if rawLine.contains(":") && rawLine.split(separator: " ", omittingEmptySubsequences: true).count >= 3 {
            throw ErParserError.invalidRelationship("Unrecognized relationship syntax: \(rawLine)")
        }
    }

    diagram.entities = entityOrder.compactMap { key in
        guard var entity = entityMap[key] else { return nil }
        entity.cssCompiledStyles = _compiledStyles(for: entity, classes: diagram.classes)
        return entity
    }
    return diagram
}

private func _sanitizeErNodeIdKey(_ key: String) -> String {
    key
        .replacingOccurrences(of: #"[^A-Za-z0-9_-]+"#, with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

private func _appendErClasses(_ entity: inout ErEntity, _ classNames: [String]) {
    let existing = entity.cssClasses
        .split(separator: " ")
        .map(String.init)
        .filter { !$0.isEmpty }
    var merged = existing
    for className in classNames where !className.isEmpty && !merged.contains(className) {
        merged.append(className)
    }
    entity.cssClasses = merged.isEmpty ? "default" : merged.joined(separator: " ")
}

private func _compiledStyles(for entity: ErEntity, classes: [String: ErEntityClass]) -> [String] {
    var compiled: [String] = []
    for className in entity.cssClasses.split(separator: " ").map(String.init) {
        guard let cls = classes[className] else { continue }
        compiled.append(contentsOf: cls.styles.map { $0.trimmingCharacters(in: .whitespaces) })
        compiled.append(contentsOf: cls.textStyles.map { $0.trimmingCharacters(in: .whitespaces) })
    }
    return compiled
}

// MARK: - Entity Name Parsing

private func _isQuotedEntityName(_ text: String) -> String? {
    let pattern = #"^"([^"%\r\n\v\b\\]+)"$"#
    guard let groups = _groups(pattern, text), let name = groups[safe: 1] else { return nil }
    return name
}

private func _isUnquotedEntityName(_ text: String) -> Bool {
    let pattern = #"^[\p{L}\p{N}_\-\.\*]+$"#
    return text.range(of: pattern, options: .regularExpression) != nil && !text.isEmpty
}

private func _isStandaloneEntityName(_ text: String) -> Bool {
    if _isQuotedEntityName(text) != nil { return true }
    if _isUnquotedEntityName(text) { return true }
    // Numbers and decimals as entity names
    if Double(text) != nil { return true }
    return false
}

// MARK: - Standalone Entity + Alias + Class

private struct _EntityParseResult {
    var id: String
    var alias: String
    var classNames: [String]
}

private struct _EntityBlockResult {
    var id: String
    var alias: String
    var classNames: [String]
    var hasAttributes: Bool
    var inlineContent: String?
}

private func _parseStandaloneEntity(_ line: String) -> _EntityParseResult? {
    // ENTITY [alias]:::className (put more specific patterns first)
    if let groups = _groups(#"^([^\[]+)\s*\[([^\]]+)\]\s*:::\s*(.+)$"#, line) {
        let name = groups[1].trimmingCharacters(in: .whitespaces)
        guard _isStandaloneEntityName(name) else { return nil }
        let alias = _stripQuotes(groups[2].trimmingCharacters(in: .whitespaces))
        let classStr = groups[3].trimmingCharacters(in: .whitespaces)
        let classNames = classStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return _EntityParseResult(id: name, alias: alias, classNames: classNames)
    }
    
    // ENTITY [alias]
    if let groups = _groups(#"^([^\[]+)\s*\[([^\]]+)\]\s*$"#, line) {
        let name = groups[1].trimmingCharacters(in: .whitespaces)
        guard _isStandaloneEntityName(name) else { return nil }
        let alias = _stripQuotes(groups[2].trimmingCharacters(in: .whitespaces))
        return _EntityParseResult(id: name, alias: alias, classNames: [])
    }

    // ENTITY:::className
    if let groups = _groups(#"^([^:]+):::\s*(.+)$"#, line) {
        let name = groups[1].trimmingCharacters(in: .whitespaces)
        guard _isStandaloneEntityName(name) else { return nil }
        let classStr = groups[2].trimmingCharacters(in: .whitespaces)
        let classNames = classStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return _EntityParseResult(id: name, alias: "", classNames: classNames)
    }
    
    // ENTITY (standalone name, no alias, no class)
    if _isStandaloneEntityName(line) {
        return _EntityParseResult(id: line, alias: "", classNames: [])
    }
    
    return nil
}

private func _parseEntityBlock(_ line: String) -> _EntityBlockResult? {
    // ENTITY:::className { ... } or ENTITY:::className{} 
    if let groups = _groups(#"^(\S+)\s*:::\s*(.+?)\s*\{$"#, line) {
        guard let name = groups[safe: 1], _isStandaloneEntityName(name) else { return nil }
        let classStr = groups[2].trimmingCharacters(in: .whitespaces)
        let classNames = classStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return _EntityBlockResult(id: name, alias: "", classNames: classNames, hasAttributes: true, inlineContent: nil)
    }

    // ENTITY:::className{}
    if let groups = _groups(#"^(\S+)\s*:::\s*(.+?)\s*\{\s*\}$"#, line) {
        guard let name = groups[safe: 1], _isStandaloneEntityName(name) else { return nil }
        let classStr = groups[2].trimmingCharacters(in: .whitespaces)
        let classNames = classStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return _EntityBlockResult(id: name, alias: "", classNames: classNames, hasAttributes: false, inlineContent: nil)
    }

    // ENTITY [alias]:::className { ... }
    if let groups = _groups(#"^(\S+)\s*\[([^\]]+)\]\s*:::\s*(.+?)\s*\{$"#, line) {
        guard let name = groups[safe: 1], _isStandaloneEntityName(name) else { return nil }
        let alias = _stripQuotes(groups[2].trimmingCharacters(in: .whitespaces))
        let classStr = groups[3].trimmingCharacters(in: .whitespaces)
        let classNames = classStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return _EntityBlockResult(id: name, alias: alias, classNames: classNames, hasAttributes: true, inlineContent: nil)
    }

    // ENTITY [alias]:::className{}
    if let groups = _groups(#"^(\S+)\s*\[([^\]]+)\]\s*:::\s*(.+?)\s*\{\s*\}$"#, line) {
        guard let name = groups[safe: 1], _isStandaloneEntityName(name) else { return nil }
        let alias = _stripQuotes(groups[2].trimmingCharacters(in: .whitespaces))
        let classStr = groups[3].trimmingCharacters(in: .whitespaces)
        let classNames = classStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return _EntityBlockResult(id: name, alias: alias, classNames: classNames, hasAttributes: false, inlineContent: nil)
    }

    // ENTITY [alias] { ... }
    if let groups = _groups(#"^(\S+)\s*\[([^\]]+)\]\s*\{$"#, line) {
        guard let name = groups[safe: 1], _isStandaloneEntityName(name) else { return nil }
        let alias = _stripQuotes(groups[2].trimmingCharacters(in: .whitespaces))
        return _EntityBlockResult(id: name, alias: alias, classNames: [], hasAttributes: true, inlineContent: nil)
    }

    // ENTITY [alias]{}
    if let groups = _groups(#"^(\S+)\s*\[([^\]]+)\]\s*\{\s*\}$"#, line) {
        guard let name = groups[safe: 1], _isStandaloneEntityName(name) else { return nil }
        let alias = _stripQuotes(groups[2].trimmingCharacters(in: .whitespaces))
        return _EntityBlockResult(id: name, alias: alias, classNames: [], hasAttributes: false, inlineContent: nil)
    }

    // ENTITY { (space before brace) — current form
    if let groups = _groups(#"^(\S+)\s*\{$"#, line) {
        guard let name = groups[safe: 1], _isStandaloneEntityName(name) else { return nil }
        return _EntityBlockResult(id: name, alias: "", classNames: [], hasAttributes: true, inlineContent: nil)
    }

    // ENTITY{} (no-whitespace empty block)
    if let groups = _groups(#"^(\S+)\s*\{\s*\}$"#, line) {
        guard let name = groups[safe: 1], _isStandaloneEntityName(name) else { return nil }
        return _EntityBlockResult(id: name, alias: "", classNames: [], hasAttributes: false, inlineContent: nil)
    }

    // ENTITY{ attr } (no-whitespace inline block)
    if let groups = _groups(#"^(\S+)\s*\{([^}]+)\}$"#, line) {
        guard let name = groups[safe: 1], _isStandaloneEntityName(name) else { return nil }
        let inlineContent = groups[2].trimmingCharacters(in: .whitespaces)
        if !inlineContent.isEmpty {
            return _EntityBlockResult(id: name, alias: "", classNames: [], hasAttributes: true, inlineContent: inlineContent)
        }
        return _EntityBlockResult(id: name, alias: "", classNames: [], hasAttributes: false, inlineContent: nil)
    }

    return nil
}

private func _stripQuotes(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("\"") && t.hasSuffix("\"") && t.count >= 2 {
        let start = t.index(after: t.startIndex)
        let end = t.index(before: t.endIndex)
        return String(t[start..<end])
    }
    return t
}

// MARK: - Attribute Parsing

private func _parseAttribute(_ line: String) -> ErAttribute? {
    // Try generic type: type~T~ name
    if let groups = _groups(#"^([^\s]*)[~]([^~]*)[~]\s+(\S+)$"#, line) {
        guard let typeRaw = groups[safe: 1], let generic = groups[safe: 2], let namePart = groups[safe: 3] else { return nil }
        let type = "\(typeRaw)<\(generic)>"
        let (name, keys, comment) = _parseAttributeRest(namePart)
        return ErAttribute(type: type, name: name, keys: keys, comment: comment)
    }

    // Standard form: type name [keys] ["comment"]
    guard let groups = _groups(#"^(\S+)\s+(\S+)(?:\s+(.+))?$"#, line),
          let type = groups[safe: 1],
          let nameRaw = groups[safe: 2]
    else {
        return nil
    }

    // Validate attribute tokens match Mermaid's ATTRIBUTE_WORD pattern:
    // must start with *, letter, underscore, or Unicode ≥ U+00C0 (not digit-first)
    if !_isAttributeWord(type) || !_isAttributeWord(nameRaw) {
        return nil
    }

    let rest = groups[safe: 3]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let (keys, comment) = _parseKeyAndComment(rest)

    return ErAttribute(type: type, name: nameRaw, keys: keys, comment: comment)
}

/// Mermaid erDiagram.jison ATTRIBUTE_WORD: first char must be *, letter, _, or Unicode ≥ U+00C0
private func _isAttributeWord(_ text: String) -> Bool {
    guard let first = text.first else { return false }
    if first == "*" { return true }
    if first.isLetter { return true }
    if first == "_" { return true }
    // Unicode characters ≥ U+00C0
    if let scalar = first.unicodeScalars.first, scalar.value >= 0x00C0 {
        return true
    }
    return false
}

private func _parseAttributeRest(_ rest: String) -> (name: String, keys: [String], comment: String) {
    let parts = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
    let name = parts.first ?? rest
    let remainder = parts.count > 1 ? parts[1] : ""
    let (keys, comment) = _parseKeyAndComment(remainder)
    return (name, keys, comment)
}

private func _parseKeyAndComment(_ text: String) -> (keys: [String], comment: String) {
    var keys: [String] = []
    var comment = ""
    var rest = text

    // Extract quoted comment first
    if let commentMatch = _firstGroup(#""([^"]*)""#, rest) {
        comment = original_src_multiline_utils.normalizeBrTags(commentMatch)
        rest = rest.replacingOccurrences(of: #""[^"]*""#, with: "", options: .regularExpression)
    }

    // Parse comma-separated keys from remaining text
    let cleaned = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: ",", with: " ")
    for part in cleaned.split(separator: " ", omittingEmptySubsequences: true) {
        let token = String(part).uppercased().trimmingCharacters(in: CharacterSet(charactersIn: ","))
        if token == "PK" || token == "FK" || token == "UK" {
            keys.append(token)
        }
    }

    return (keys, comment)
}

// MARK: - Direction Parsing

private func _parseDirection(_ line: String) -> ErDirection? {
    guard let groups = _groups(#"^direction\s+(TB|BT|LR|RL)$"#, line, caseInsensitive: true),
          let dirStr = groups[safe: 1]?.uppercased() else { return nil }
    return ErDirection(rawValue: dirStr)
}

// MARK: - Accessibility Directive Parsing

private func _parseAccTitle(_ line: String) -> String? {
    guard let groups = _groups(#"^accTitle:\s*(.+)$"#, line, caseInsensitive: true),
          let value = groups[safe: 1] else { return nil }
    return _stripQuotes(value.trimmingCharacters(in: .whitespaces))
}

private func _parseAccDescr(_ line: String) -> String? {
    guard let groups = _groups(#"^accDescr:\s*(.+)$"#, line, caseInsensitive: true),
          let value = groups[safe: 1] else { return nil }
    return _stripQuotes(value.trimmingCharacters(in: .whitespaces))
}

private func _parseAccDescrMultilineStart(_ line: String) -> String? {
    guard let groups = _groups(#"^accDescr\s*\{\s*(.*)$"#, line, caseInsensitive: true),
          let value = groups[safe: 1] else { return nil }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func _parseInlineTitle(_ line: String) -> String? {
    // Mermaid grammar: title title_value (inline title directive)
    // Does NOT match accTitle: or accDescr: or accDescr { — those are handled separately
    if line.lowercased().hasPrefix("acctitle") || line.lowercased().hasPrefix("accdescr") {
        return nil
    }
    guard let groups = _groups(#"^title:\s*(.+)$"#, line, caseInsensitive: true),
          let value = groups[safe: 1] else { return nil }
    return _stripQuotes(value.trimmingCharacters(in: .whitespaces))
}

// MARK: - Style Parsing

private struct _ClassDefResult {
    var names: [String]
    var styles: [String]
    var textStyles: [String]
}

private func _parseStyle(_ line: String, _ entityMap: inout [String: ErEntity]) -> [String]? {
    // style ENTITY_NAME fill:#f9f,stroke:#333,stroke-width:4px
    let rest = String(line.dropFirst("style".count)).trimmingCharacters(in: .whitespaces)
    guard let entityEnd = rest.firstIndex(where: { $0 == " " || $0 == "\t" }),
          let styleStart = rest[entityEnd...].firstIndex(where: { !$0.isWhitespace }) else { return nil }
    let entityPart = String(rest[..<entityEnd]).trimmingCharacters(in: .whitespaces)
    let stylePart = String(rest[styleStart...]).trimmingCharacters(in: .whitespaces)

    let entityNames = entityPart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let styles = _parseStyleValues(stylePart)

    for name in entityNames {
        if var ent = entityMap[name] {
            ent.cssStyles.append(contentsOf: styles)
            entityMap[name] = ent
        }
    }
    return styles
}

private func _parseClassDef(_ line: String) -> _ClassDefResult? {
    // classDef className fill:#f9f,stroke:#333
    // classDef firstClass,secondClass font-size:12pt
    let rest = String(line.dropFirst("classDef".count)).trimmingCharacters(in: .whitespaces)
    guard let nameEnd = rest.firstIndex(where: { $0 == " " || $0 == "\t" }),
          let styleStart = rest[nameEnd...].firstIndex(where: { !$0.isWhitespace }) else { return nil }
    let namePart = String(rest[..<nameEnd]).trimmingCharacters(in: .whitespaces)
    let stylePart = String(rest[styleStart...]).trimmingCharacters(in: .whitespaces)

    let names = namePart.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let allStyles = _parseStyleValues(stylePart)
    // Separate text styles (color) from fill/stroke styles
    var textStyles: [String] = []
    var boxStyles: [String] = []
    for style in allStyles {
        if style.hasPrefix("color:") || style.hasPrefix("font-") {
            textStyles.append(style)
        } else {
            boxStyles.append(style)
        }
    }
    // Duplicate color to textStyles (Mermaid behavior)
    textStyles.append(contentsOf: boxStyles.filter { $0.hasPrefix("color:") })
    return _ClassDefResult(names: names, styles: boxStyles + textStyles, textStyles: textStyles)
}

private func _parseClass(_ line: String, _ entityMap: inout [String: ErEntity], _ classes: [String: ErEntityClass]) -> [String]? {
    // class nodeId1 className
    // class nodeId1,nodeId2 className
    // class nodeId1 className1,className2
    let rest = String(line.dropFirst("class".count)).trimmingCharacters(in: .whitespaces)
    let words = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    guard words.count >= 2 else { return nil }
    // The last word(s) are class names, preceding are node IDs
    // Find the division: node IDs contain no commas in the node part, class names can contain commas
    // Simple heuristic: first comma-separated segment is nodes, rest is classes
    var nodeWords: [String] = []
    var classWords: [String] = []
    var foundSplit = false
    for word in words {
        if !foundSplit {
            if nodeWords.isEmpty || (!word.contains(",") && nodeWords.last?.contains(",") != true) {
                nodeWords.append(word)
                if word.contains(",") { foundSplit = true }
            } else {
                foundSplit = true
            }
        }
        if foundSplit {
            classWords.append(word)
        }
    }

    if classWords.isEmpty && nodeWords.count >= 2 {
        classWords = [nodeWords.removeLast()]
    }
    if nodeWords.isEmpty || classWords.isEmpty { return nil }

    let entityNames = nodeWords.joined(separator: " ").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let classNames = classWords.joined(separator: " ").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

    for name in entityNames {
        if var ent = entityMap[name] {
            let current = ent.cssClasses
            let extra = classNames.joined(separator: " ")
            ent.cssClasses = current == "default" ? extra : "\(current) \(extra)".trimmingCharacters(in: .whitespaces)
            // Compile styles from class definitions
            for cls in classNames {
                if let def = classes[cls] {
                    ent.cssCompiledStyles.append(contentsOf: def.styles)
                }
            }
            entityMap[name] = ent
        }
    }
    return classNames
}

private func _parseStyleValues(_ text: String) -> [String] {
    // Split by comma, but preserve commas inside values (e.g. url(...))
    var values: [String] = []
    var current = ""
    var depth = 0
    for ch in text {
        if ch == "(" { depth += 1 }
        else if ch == ")" { depth -= 1 }
        if ch == "," && depth == 0 {
            values.append(_normalizeErStyleValue(current))
            current = ""
        } else {
            current.append(ch)
        }
    }
    let last = _normalizeErStyleValue(current)
    if !last.isEmpty {
        values.append(last)
    }
    return values
}

private func _normalizeErStyleValue(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard let colon = trimmed.firstIndex(of: ":") else {
        return trimmed
    }
    let property = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
    let rawValue = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    guard !property.isEmpty else { return trimmed }
    return "\(property):\(rawValue)"
}

// MARK: - Relationship Parsing (Token-Based)

private func _parseRelationshipLine(
    _ line: String,
    _ ensureEntity: (String) -> (ErEntity, String),
    _ applyClasses: (String, [String]) -> Void
) -> ErRelationship? {
    // Preprocess: insert spaces around identification operators (--, .., .-, -.)
    // so that combined tokens like "||--o{" become "|| -- o{"
    var preprocessed = line
    for op in ["--", "..", ".-", "-."] {
        preprocessed = preprocessed.replacingOccurrences(of: op, with: " \(op) ")
    }
    preprocessed = preprocessed.replacingOccurrences(of: ":::", with: " __ER_CLASS__ ")
    // Also separate cardinality symbols from each other
    // e.g., "||" stays "||", "o{" stays "o{", but "}o" stays "}o"
    // Already handled by the cardinality prefix parser.

    let tokens = _tokenizeRelationshipLine(preprocessed).map { $0 == "__ER_CLASS__" ? ":::" : $0 }
    guard tokens.count >= 3 else { return nil }

    var idx = 0

    // Parse entity1 with optional class shorthand.
    guard let endpoint1 = _parseRelationshipEndpoint(tokens, &idx) else { return nil }
    let entity1Name = endpoint1.name

    // Parse cardinality1 (long-form or symbolic)
    guard idx < tokens.count else { return nil }
    let card1Result = _parseCardinalityTokens(tokens, &idx)
    guard let card1 = card1Result else { return nil }

    // Parse identification operator
    guard idx < tokens.count else { return nil }
    let identToken = tokens[idx]
    let identResult = _parseIdentification(identToken, tokens, &idx)
    guard let relType = identResult else { return nil }

    // Parse cardinality2
    guard idx < tokens.count else { return nil }
    let card2Result = _parseCardinalityTokens(tokens, &idx)
    guard let card2 = card2Result else { return nil }

    // Parse entity2 with optional class shorthand.
    guard let endpoint2 = _parseRelationshipEndpoint(tokens, &idx) else { return nil }
    let entity2Name = endpoint2.name

    // Optional label after ':'
    var label = ""
    if idx < tokens.count, tokens[idx] == ":" {
        idx += 1
        if idx < tokens.count {
            label = tokens[idx]
            idx += 1
        }
        // Remaining tokens (until end) could be part of label
        var labelParts = [label]
        while idx < tokens.count {
            labelParts.append(tokens[idx])
            idx += 1
        }
        label = labelParts.joined(separator: " ")
    }

    label = _stripQuotes(label.trimmingCharacters(in: .whitespaces))
    label = original_src_multiline_utils.normalizeBrTags(label)

    let (_, e1NodeId) = ensureEntity(entity1Name)
    let (_, e2NodeId) = ensureEntity(entity2Name)
    applyClasses(entity1Name, endpoint1.classNames)
    applyClasses(entity2Name, endpoint2.classNames)

    let relSpec = ErRelSpec(cardA: card2, cardB: card1, relType: relType)
    return ErRelationship(
        entity1: entity1Name,
        entity2: entity2Name,
        entityAId: e1NodeId,
        entityBId: e2NodeId,
        roleA: label,
        relSpec: relSpec
    )
}

private struct _RelationshipEndpoint {
    var name: String
    var classNames: [String]
}

private func _parseRelationshipEndpoint(_ tokens: [String], _ idx: inout Int) -> _RelationshipEndpoint? {
    guard idx < tokens.count else { return nil }

    var rawName = tokens[idx]
    idx += 1
    var classNames: [String] = []

    if let shorthand = rawName.range(of: ":::") {
        let namePart = String(rawName[..<shorthand.lowerBound])
        let classPart = String(rawName[shorthand.upperBound...])
        rawName = namePart
        classNames.append(contentsOf: _splitErClassNames(classPart))
    }

    if idx < tokens.count {
        if tokens[idx] == ":::" {
            idx += 1
            if idx < tokens.count {
                classNames.append(contentsOf: _splitErClassNames(tokens[idx]))
                idx += 1
            }
        } else if tokens[idx].hasPrefix(":::") {
            classNames.append(contentsOf: _splitErClassNames(String(tokens[idx].dropFirst(3))))
            idx += 1
        }
    }

    let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return nil }
    return _RelationshipEndpoint(name: name, classNames: classNames)
}

private func _splitErClassNames(_ raw: String) -> [String] {
    raw.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func _tokenizeRelationshipLine(_ line: String) -> [String] {
    var tokens: [String] = []
    var current = ""
    var inQuotes = false
    var quoteChar: Character = "\""

    for ch in line {
        if inQuotes {
            if ch == quoteChar {
                inQuotes = false
                tokens.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        } else {
            if ch == "\"" || ch == "'" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                inQuotes = true
                quoteChar = ch
            } else if ch == ":" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(":")
            } else if ch.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(ch)
            }
        }
    }
    if !current.isEmpty {
        tokens.append(current)
    }
    return tokens
}

// MARK: - Cardinality Parsing

private func _parseCardinalityTokens(_ tokens: [String], _ idx: inout Int) -> ErCardinality? {
    guard idx < tokens.count else { return nil }
    let token = tokens[idx]

    // Try symbolic cardinality on the token
    if let card = _parseSymbolicCardinality(token) {
        idx += 1
        return card
    }

    // Try parent marker 'u' — must be followed by identification operator or cardinality symbol
    // Mermaid erDiagram.jison: u(?=[\.\-\|]) — only match when followed by ., -, |
    if token == "u" || token.lowercased() == "u" {
        if idx + 1 < tokens.count {
            let next = tokens[idx + 1]
            if _isIdentificationOp(next) || next.hasPrefix("|") || next.hasPrefix(".") {
                idx += 1
                return .mdParent
            }
        }
        // Not a parent marker in this context — could be an entity name
        return nil
    }

    // Long-form aliases that span multiple tokens
    if let card = _parseLongFormCardinality(tokens, &idx) {
        return card
    }

    // "1" as cardinality — check context (Mermaid erDiagram.jison lookahead rules)
    if token == "1" {
        if idx + 1 < tokens.count {
            let next = tokens[idx + 1]
            // Mermaid: 1(?=(\-\-|\.\.|\.\-|\-\.)) → ONLY_ONE before identification operator
            if _isIdentificationOp(next) { idx += 1; return .onlyOne }
            // Mermaid: 1(?=\s+[A-Za-z_"']) or followed by cardinality keyword
            if next == "one" || next == "zero" || next == "many" || next == "only"
                || next.range(of: #"^[A-Za-z_\u00C0-\uFFFF]"#, options: .regularExpression) != nil
                || next.hasPrefix("\"") || next.hasPrefix("'") {
                idx += 1; return .onlyOne
            }
            // Mermaid: 1(?=\s+[0-9]) → ONLY_ONE followed by number
            if Double(next) != nil { idx += 1; return .onlyOne }
        }
        // Ambiguous — could be an entity name. Fall through.
    }

    // Numeric entity names like "2.5" — these are entity names, not cardinalities
    if Double(token) != nil {
        return nil
    }

    return nil
}

private func _parseSymbolicCardinality(_ raw: String) -> ErCardinality? {
    if raw == "||" { return .onlyOne }
    if raw == "|o" || raw == "o|" { return .zeroOrOne }
    if raw == "}|" || raw == "|{" { return .oneOrMore }
    if raw == "}o" || raw == "o{" { return .zeroOrMore }
    return nil
}

private func _isIdentificationOp(_ token: String) -> Bool {
    token == "--" || token == ".." || token == ".-" || token == "-." || token == "to"
}

private func _parseLongFormCardinality(_ tokens: [String], _ idx: inout Int) -> ErCardinality? {
    guard idx < tokens.count else { return nil }

    // Check multi-token forms
    let remaining = Array(tokens[idx...])
    let joined = remaining.prefix(3).joined(separator: " ").lowercased()

    var advance = 0

    switch joined {
    case let s where s.hasPrefix("one or zero"):
        advance = 3
        idx += advance
        return .zeroOrOne
    case let s where s.hasPrefix("zero or one"):
        advance = 3
        idx += advance
        return .zeroOrOne
    case let s where s.hasPrefix("one or more"):
        advance = 3
        idx += advance
        return .oneOrMore
    case let s where s.hasPrefix("one or many"):
        advance = 3
        idx += advance
        return .oneOrMore
    case let s where s.hasPrefix("zero or more"):
        advance = 3
        idx += advance
        return .zeroOrMore
    case let s where s.hasPrefix("zero or many"):
        advance = 3
        idx += advance
        return .zeroOrMore
    case let s where s.hasPrefix("only one"):
        advance = 2
        idx += advance
        return .onlyOne
    default:
        break
    }

    // Single-token forms
    let single = remaining.first?.lowercased() ?? ""
    switch single {
    case "one":
        idx += 1
        return .onlyOne
    case "1+":
        idx += 1
        return .oneOrMore
    case "0+":
        idx += 1
        return .zeroOrMore
    case "many":
        idx += 1
        return .zeroOrMore
    case let s where s.hasPrefix("many(") && s.hasSuffix(")"):
        let inner = String(s.dropFirst(5).dropLast())
        idx += 1
        if inner == "0" { return .zeroOrMore }
        if inner == "1" { return .oneOrMore }
        return .zeroOrMore
    default:
        break
    }

    return nil
}

// MARK: - Identification Parsing

private func _parseIdentification(_ token: String, _ tokens: [String], _ idx: inout Int) -> ErIdentification? {
    switch token {
    case "--":
        idx += 1
        return .identifying
    case "..":
        idx += 1
        return .nonIdentifying
    case ".-":
        idx += 1
        return .nonIdentifying
    case "-.":
        idx += 1
        return .nonIdentifying
    case "to":
        idx += 1
        return .identifying
    case "optionally":
        if idx + 1 < tokens.count, tokens[idx + 1] == "to" {
            idx += 2
            return .nonIdentifying
        }
        return nil
    default:
        return nil
    }
}

// MARK: - Regex Helpers

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

// MARK: - Legacy Export Class

open class original_src_er_parser {
    public init() {}

    public static func parseErDiagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> ErDiagram {
        try _parseErDiagramEntry(lines, frontmatter: frontmatter)
    }
}

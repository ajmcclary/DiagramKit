import Foundation
import DiagramKitCommon

// MARK: - Requirement Diagram Model

public enum RequirementType: String, Sendable, Equatable, CaseIterable {
    case requirement = "Requirement"
    case functionalRequirement = "Functional Requirement"
    case interfaceRequirement = "Interface Requirement"
    case performanceRequirement = "Performance Requirement"
    case physicalRequirement = "Physical Requirement"
    case designConstraint = "Design Constraint"
}

public enum RiskLevel: String, Sendable, Equatable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

public enum VerifyMethod: String, Sendable, Equatable, CaseIterable {
    case analysis = "Analysis"
    case demonstration = "Demonstration"
    case inspection = "Inspection"
    case test = "Test"
}

public enum RequirementRelationshipType: String, Sendable, Equatable, CaseIterable {
    case contains = "contains"
    case copies = "copies"
    case derives = "derives"
    case satisfies = "satisfies"
    case verifies = "verifies"
    case refines = "refines"
    case traces = "traces"
}

public enum RequirementDirection: String, Sendable, Equatable {
    case TB, BT, LR, RL
}

public struct RequirementNode: Sendable, Equatable {
    public var name: String
    public var type: RequirementType
    public var requirementId: String
    public var text: String
    public var risk: RiskLevel?
    public var verifyMethod: VerifyMethod?
    public var cssStyles: [String]
    public var classes: [String]
    public var sourceOrder: Int
}

public struct ElementNode: Sendable, Equatable {
    public var name: String
    public var type: String
    public var docRef: String
    public var cssStyles: [String]
    public var classes: [String]
    public var sourceOrder: Int
}

public struct RequirementRelationship: Sendable, Equatable {
    public var type: RequirementRelationshipType
    public var sourceName: String
    public var destinationName: String
    public var isReversed: Bool
}

public struct RequirementClassDef: Sendable, Equatable {
    public var id: String
    public var styles: [String]
    public var textStyles: [String]
}

public struct RequirementDiagram: Sendable, Equatable {
    public var requirements: [RequirementNode]
    public var elements: [ElementNode]
    public var relationships: [RequirementRelationship]
    public var classDefs: [RequirementClassDef]
    public var direction: RequirementDirection
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: RequirementDiagramConfig
}

public struct RequirementDiagramConfig: Sendable, Equatable {
    public var useMaxWidth: Bool = true
    public var useWidth: Double?
    public var rect_fill: String?
    public var text_color: String?
    public var rect_border_size: String?
    public var rect_border_color: String?
    public var rect_min_width: Double?
    public var rect_min_height: Double?
    public var fontSize: Double?
    public var rect_padding: Double?
    public var line_height: Double?
    public var nodeSpacing: Double = 50
    public var rankSpacing: Double = 50
    public var theme: RequirementThemeVariables?
    public var htmlLabels: Bool?
}

public struct RequirementThemeVariables: Sendable, Equatable {
    public var requirementBackground: String?
    public var requirementBorderColor: String?
    public var requirementBorderSize: String?
    public var requirementTextColor: String?
    public var relationColor: String?
    public var relationLabelBackground: String?
    public var relationLabelColor: String?
    public var requirementEdgeLabelBackground: String?
    public var strokeWidth: String?
    public var borderColorArray: [String]?
    public var bkgColorArray: [String]?
    public var nodeTextColor: String?
    public var textColor: String?
    public var nodeBorder: String?
    public var edgeLabelBackground: String?
}

// MARK: - Positioned Types

public struct PositionedRequirementDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var nodes: [PositionedRequirementNode]
    public var edges: [PositionedRequirementEdge]
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: RequirementDiagramConfig
}

public struct PositionedRequirementNode: Sendable {
    public var id: String
    public var isRequirement: Bool
    public var requirementType: RequirementType?
    public var requirementId: String?
    public var text: String?
    public var risk: RiskLevel?
    public var verifyMethod: VerifyMethod?
    public var elementType: String?
    public var docRef: String?
    public var cssStyles: [String]
    public var classes: [String]
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var colorIndex: Int
}

public struct PositionedRequirementEdge: Sendable {
    public var id: String
    public var relationshipType: RequirementRelationshipType
    public var sourceId: String
    public var destinationId: String
    public var path: [CGPoint]
    public var labelPosition: CGPoint?
    public var labelText: String
    public var isDashed: Bool
    public var startMarker: String?
    public var endMarker: String?
}

// MARK: - Parser Errors

public enum RequirementParserError: Error, LocalizedError, _MermaidRecoverableError {
    case invalidHeader(String)
    case missingRequirementName(String)
    case missingElementName(String)
    case unexpectedToken(String, line: Int)
    case unclosedBlock(String, line: Int)
    case invalidRiskLevel(String, line: Int)
    case invalidVerifyMethod(String, line: Int)
    case invalidRequirementType(String, line: Int)
    case invalidRelationshipType(String, line: Int)
    case invalidDirection(String, line: Int)
    case malformedStyle(String, line: Int)
    case malformedClassDef(String, line: Int)
    case malformedClass(String, line: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let h): return "Invalid requirement diagram header: \(h)"
        case .missingRequirementName(let d): return "Missing requirement name: \(d)"
        case .missingElementName(let d): return "Missing element name: \(d)"
        case .unexpectedToken(let t, let l): return "Unexpected token '\(t)' at line \(l)"
        case .unclosedBlock(let n, let l): return "Unclosed block for '\(n)' at line \(l)"
        case .invalidRiskLevel(let r, let l): return "Invalid risk level '\(r)' at line \(l)"
        case .invalidVerifyMethod(let v, let l): return "Invalid verification method '\(v)' at line \(l)"
        case .invalidRequirementType(let t, let l): return "Invalid requirement type '\(t)' at line \(l)"
        case .invalidRelationshipType(let t, let l): return "Invalid relationship type '\(t)' at line \(l)"
        case .invalidDirection(let d, let l): return "Invalid direction '\(d)' at line \(l)"
        case .malformedStyle(let s, let l): return "Malformed style statement '\(s)' at line \(l)"
        case .malformedClassDef(let s, let l): return "Malformed classDef statement '\(s)' at line \(l)"
        case .malformedClass(let s, let l): return "Malformed class statement '\(s)' at line \(l)"
        }
    }
}

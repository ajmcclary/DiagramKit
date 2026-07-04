// Ported from original/src/types.ts
import Foundation

open class original_src_types {
    public init() {}

    public enum Direction: String, Sendable {
        case TD
        case TB
        case LR
        case BT
        case RL
    }

    public enum NodeShape: String, Sendable, CaseIterable {
        case rectangle
        case rounded
        case diamond
        case stadium
        case circle
        case subroutine
        case doublecircle
        case hexagon
        case cylinder
        case asymmetric
        case trapezoid
        case trapezoidAlt = "trapezoid-alt"
        case stateStart = "state-start"
        case stateEnd = "state-end"
        case stateDivider = "state-divider"
        case stateNote = "state-note"
        case roundedWithTitle = "rounded-with-title"
        case ellipse
        case parallelogram
        case parallelogramAlt = "parallelogram-alt"
        case bang
        case cloud
        case dataStore = "data-store"
        case text
        case notchedRectangle = "notched-rectangle"
        case linedRectangle = "lined-rectangle"
        case smallCircle = "small-circle"
        case framedCircle = "framed-circle"
        case fork
        case join
        case hourglass
        case braceL = "brace-l"
        case braceR = "brace-r"
        case braces
        case lightningBolt = "lightning-bolt"
        case document
        case delay
        case horizontalCylinder = "horizontal-cylinder"
        case linedCylinder = "lined-cylinder"
        case curvedTrapezoid = "curved-trapezoid"
        case dividedRectangle = "divided-rectangle"
        case triangle
        case windowPane = "window-pane"
        case filledCircle = "filled-circle"
        case linedDocument = "lined-document"
        case notchedPentagon = "notched-pentagon"
        case flippedTriangle = "flipped-triangle"
        case slopedRectangle = "sloped-rectangle"
        case stackedDocument = "stacked-document"
        case stackedRectangle = "stacked-rectangle"
        case flag
        case bowTieRectangle = "bow-tie-rectangle"
        case crossedCircle = "crossed-circle"
        case taggedDocument = "tagged-document"
        case taggedRectangle = "tagged-rectangle"
        case iconSquare = "icon-square"
        case iconCircle = "icon-circle"
        case icon
        case iconRounded = "icon-rounded"
        case imageSquare = "image-square"
        case state
        case choice
        case note
        case rectWithTitle = "rect-with-title"
        case labelRect = "label-rect"
        case anchor
        case invisible

        public static func resolve(alias: String) -> NodeShape? {
            switch alias.lowercased() {
            case "rect", "proc", "process", "rectangle": return .rectangle
            case "rounded", "fr-rect", "rounded-rectangle": return .rounded
            case "stadium": return .stadium
            case "subroutine", "subproc", "sub-routine": return .subroutine
            case "cylinder", "cyl": return .cylinder
            case "diamond", "diam", "decision", "rhombus": return .diamond
            case "hexagon", "hex": return .hexagon
            case "circle", "circ": return .circle
            case "double-circle", "dbl-circ", "doublecircle": return .doublecircle
            case "trapezoid", "trap-b": return .trapezoid
            case "inv-trapezoid", "trap-t", "trapezoid-alt": return .trapezoidAlt
            case "odd", "rect-left-inv-arrow", "asymmetric": return .asymmetric
            case "ellipse": return .ellipse
            case "lean-right", "lean_right", "parallelogram": return .parallelogram
            case "lean-left", "lean_left", "parallelogram-alt": return .parallelogramAlt
            case "bang": return .bang
            case "cloud": return .cloud
            case "data-store", "datastore": return .dataStore
            case "text": return .text
            case "card", "notched-rectangle", "notch-rect": return .notchedRectangle
            case "lined-process", "lined-rectangle", "lin-rect", "lin-proc", "shaded-process": return .linedRectangle
            case "start", "small-circle", "sm-circ": return .smallCircle
            case "stop", "framed-circle", "fr-circ": return .framedCircle
            case "fork": return .fork
            case "join": return .join
            case "collate", "hourglass": return .hourglass
            case "brace-l", "comment", "brace": return .braceL
            case "brace-r": return .braceR
            case "braces": return .braces
            case "com-link", "bolt", "lightning-bolt": return .lightningBolt
            case "doc", "document": return .document
            case "delay", "half-rounded-rectangle": return .delay
            case "horizontal-cylinder", "h-cyl", "das": return .horizontalCylinder
            case "lined-cylinder", "lin-cyl", "disk": return .linedCylinder
            case "curbed-trapezoid", "curved-trapezoid", "curv-trap", "display": return .curvedTrapezoid
            case "divided-rectangle", "div-rect", "div-proc", "divided-process": return .dividedRectangle
            case "triangle", "tri", "extract": return .triangle
            case "internal-storage", "win-pane", "window-pane": return .windowPane
            case "filled-circle", "f-circ", "junction": return .filledCircle
            case "lined-document", "lin-doc": return .linedDocument
            case "loop-limit", "notch-pent", "notched-pentagon": return .notchedPentagon
            case "manual-file", "flip-tri", "flipped-triangle": return .flippedTriangle
            case "manual-input", "sl-rect", "sloped-rectangle": return .slopedRectangle
            case "stacked-document", "docs", "documents", "st-doc": return .stackedDocument
            case "stacked-rectangle", "st-rect", "procs", "processes": return .stackedRectangle
            case "paper-tape", "flag": return .flag
            case "bow-tie-rectangle", "bow-rect", "stored-data": return .bowTieRectangle
            case "crossed-circle", "cross-circ", "summary": return .crossedCircle
            case "tagged-document", "tag-doc": return .taggedDocument
            case "tagged-rectangle", "tag-rect", "tag-proc", "tagged-process": return .taggedRectangle
            case "icon-square": return .iconSquare
            case "icon-circle": return .iconCircle
            case "icon": return .icon
            case "icon-rounded": return .iconRounded
            case "image-square": return .imageSquare
            case "state": return .state
            case "choice": return .choice
            case "note": return .note
            case "state-note": return .stateNote
            case "state-start": return .stateStart
            case "state-end": return .stateEnd
            case "state-divider": return .stateDivider
            case "rounded-with-title": return .roundedWithTitle
            case "rect-with-title": return .rectWithTitle
            case "label-rect": return .labelRect
            case "anchor": return .anchor
            case "invisible": return .invisible
            default: return nil
            }
        }
    }

    public enum EdgeStyle: String, Sendable {
        case solid
        case dotted
        case thick
        case invisible
    }

    public struct NodeProperties: Sendable {
        public var shape: String?
        public var label: String?
        public var icon: String?
        public var form: String?
        public var pos: String?
        public var img: String?
        public var w: Double?
        public var h: Double?
        public var constraint: String?
        public var animate: Bool?
        public var animation: String?
        public var curve: String?

        public init(
            shape: String? = nil,
            label: String? = nil,
            icon: String? = nil,
            form: String? = nil,
            pos: String? = nil,
            img: String? = nil,
            w: Double? = nil,
            h: Double? = nil,
            constraint: String? = nil,
            animate: Bool? = nil,
            animation: String? = nil,
            curve: String? = nil
        ) {
            self.shape = shape
            self.label = label
            self.icon = icon
            self.form = form
            self.pos = pos
            self.img = img
            self.w = w
            self.h = h
            self.constraint = constraint
            self.animate = animate
            self.animation = animation
            self.curve = curve
        }
    }

    public struct Point: Hashable, Sendable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct MermaidNode: Sendable {
        public var id: String
        public var label: String
        public var descriptions: [String]
        public var shape: NodeShape
        public var properties: NodeProperties?

        public init(
            id: String,
            label: String,
            shape: NodeShape,
            properties: NodeProperties? = nil,
            descriptions: [String] = []
        ) {
            self.id = id
            self.label = label
            self.descriptions = descriptions
            self.shape = shape
            self.properties = properties
        }
    }

    public struct MermaidEdge: Sendable {
        public var source: String
        public var target: String
        public var label: String?
        public var style: EdgeStyle
        /// Edge ID from eN@ prefix syntax (e.g. "e1" from `A e1@--> B`)
        public var id: String?
        public var arrowHeadStart: ArrowHeadType
        public var arrowHeadEnd: ArrowHeadType
        public var inlineStyle: [String: String]?
        public var properties: NodeProperties?
        public var animate: Bool?
        public var animationSpeed: String?
        public var classes: [String]?
        public var curve: String?
        public var minlen: Int?

        public init(
            source: String,
            target: String,
            label: String? = nil,
            style: EdgeStyle,
            id: String? = nil,
            arrowHeadStart: ArrowHeadType = .none,
            arrowHeadEnd: ArrowHeadType = .arrow,
            inlineStyle: [String: String]? = nil,
            properties: NodeProperties? = nil,
            animate: Bool? = nil,
            animationSpeed: String? = nil,
            classes: [String]? = nil,
            curve: String? = nil,
            minlen: Int? = nil
        ) {
            self.source = source
            self.target = target
            self.label = label
            self.style = style
            self.id = id
            self.arrowHeadStart = arrowHeadStart
            self.arrowHeadEnd = arrowHeadEnd
            self.inlineStyle = inlineStyle
            self.properties = properties
            self.animate = animate
            self.animationSpeed = animationSpeed
            self.classes = classes
            self.curve = curve
            self.minlen = minlen
        }

        @available(*, deprecated, message: "Use arrowHeadStart instead")
        public var hasArrowStart: Bool { arrowHeadStart != .none }
        @available(*, deprecated, message: "Use arrowHeadEnd instead")
        public var hasArrowEnd: Bool { arrowHeadEnd != .none }
    }

    public enum ArrowHeadType: String, Sendable {
        case none
        case arrow
        case open
        case circle
        case cross
        case diamond
    }

    public final class MermaidSubgraph: @unchecked Sendable {
        public var id: String
        public var label: String
        public var nodeIds: [String]
        public var children: [MermaidSubgraph]
        public var direction: Direction?
        public var shape: NodeShape?
        public var altBkg: Bool

        public init(
            id: String,
            label: String,
            nodeIds: [String],
            children: [MermaidSubgraph] = [],
            direction: Direction? = nil,
            shape: NodeShape? = nil,
            altBkg: Bool = false
        ) {
            self.id = id
            self.label = label
            self.nodeIds = nodeIds
            self.children = children
            self.direction = direction
            self.shape = shape
            self.altBkg = altBkg
        }
    }

    public struct MermaidGraph: Sendable {
        public var direction: Direction
        // Ordered node list to preserve TS Map insertion order.
        public var nodesInOrder: [(id: String, node: MermaidNode)]
        public var edges: [MermaidEdge]
        public var subgraphs: [MermaidSubgraph]
        public var classDefs: [String: [String: String]]
        public var classAssignments: [String: [String]]
        public var nodeStyles: [String: [String: String]]
        /// Maps edge indices (or -1 for 'default') to inline styles from `linkStyle` directives
        public var linkStyles: [Int: [String: String]]
        public var accTitle: String?
        public var accDescr: String?
        public var config: FlowchartConfig?
        public var rendererType: String?
        public var nodeInteractions: [String: NodeInteraction]
        public var edgeClassAssignments: [String: String]
        public var defaultClassDef: [String: String]?
        public var edgeProperties: [String: NodeProperties]
        public var stateConfig: StateConfig

        public init(
            direction: Direction,
            nodesInOrder: [(id: String, node: MermaidNode)],
            edges: [MermaidEdge],
            subgraphs: [MermaidSubgraph] = [],
            classDefs: [String: [String: String]] = [:],
            classAssignments: [String: [String]] = [:],
            nodeStyles: [String: [String: String]] = [:],
            linkStyles: [Int: [String: String]] = [:],
            accTitle: String? = nil,
            accDescr: String? = nil,
            config: FlowchartConfig? = nil,
            rendererType: String? = nil,
            nodeInteractions: [String: NodeInteraction] = [:],
            edgeClassAssignments: [String: String] = [:],
            defaultClassDef: [String: String]? = nil,
            edgeProperties: [String: NodeProperties] = [:],
            stateConfig: StateConfig = StateConfig()
        ) {
            self.direction = direction
            self.nodesInOrder = nodesInOrder
            self.edges = edges
            self.subgraphs = subgraphs
            self.classDefs = classDefs
            self.classAssignments = classAssignments
            self.nodeStyles = nodeStyles
            self.linkStyles = linkStyles
            self.accTitle = accTitle
            self.accDescr = accDescr
            self.config = config
            self.rendererType = rendererType
            self.nodeInteractions = nodeInteractions
            self.edgeClassAssignments = edgeClassAssignments
            self.defaultClassDef = defaultClassDef
            self.edgeProperties = edgeProperties
            self.stateConfig = stateConfig
        }

        public var nodesById: [String: MermaidNode] {
            var map: [String: MermaidNode] = [:]
            for entry in nodesInOrder {
                map[entry.id] = entry.node
            }
            return map
        }
    }

    public struct NodeInteraction: Sendable {
        public enum InteractionType: Sendable {
            case callback(String)
            case call(String, String)
            case href(String)
        }
        public var type: InteractionType
        public var tooltip: String?
        public var target: String?

        public init(type: InteractionType, tooltip: String? = nil, target: String? = nil) {
            self.type = type
            self.tooltip = tooltip
            self.target = target
        }
    }

    public struct FlowchartConfig: Sendable {
        public var curve: String?
        public var htmlLabels: Bool?
        public var markdownAutoWrap: Bool?
        public var width: Int?
        public var inheritDir: Bool?
        public var securityLevel: String?
        /// Layout preset name from frontmatter ("adaptive"; nil =
        /// hierarchical default). Visual editor plan 6.
        public var layoutPreset: String?

        public init(
            curve: String? = nil,
            htmlLabels: Bool? = nil,
            markdownAutoWrap: Bool? = nil,
            width: Int? = nil,
            inheritDir: Bool? = nil,
            securityLevel: String? = nil,
            layoutPreset: String? = nil
        ) {
            self.curve = curve
            self.htmlLabels = htmlLabels
            self.markdownAutoWrap = markdownAutoWrap
            self.width = width
            self.inheritDir = inheritDir
            self.securityLevel = securityLevel
            self.layoutPreset = layoutPreset
        }
    }

    public enum ParsedStateType: String, Sendable {
        case choice
        case fork
        case join
        case divider
    }

    public struct ParsedStateNote: Sendable {
        public enum Position: String, Sendable {
            case left
            case right
        }
        public var position: Position
        public var text: String

        public init(position: Position, text: String) {
            self.position = position
            self.text = text
        }
    }

    public struct StateConfig: Sendable {
        public var titleTopMargin: Double = 25
        public var useMaxWidth: Bool = true
        public var defaultRenderer: String = "dagre-wrapper"
        public var arrowMarkerAbsolute: Bool = false
        public var dividerMargin: Double = 10
        public var sizeUnit: Double = 5
        public var padding: Double = 8
        public var textHeight: Double = 10
        public var titleShift: Double = -15
        public var noteMargin: Double = 10
        public var nodeSpacing: Int = 50
        public var rankSpacing: Int = 50
        public var forkWidth: Double = 70
        public var forkHeight: Double = 7
        public var miniPadding: Double = 2
        public var fontSizeFactor: Double = 5.02
        public var fontSize: Double = 24
        public var labelHeight: Double = 16
        public var edgeLengthFactor: String = "20"
        public var compositTitleSize: Double = 35
        public var radius: Double = 5
        public var scaleWidth: Int?
        public var hideEmptyDescription: Bool = false
        public var securityLevel: String?

        public init() {}
    }

    public struct PositionedNode: Sendable {
        public var id: String
        public var label: String
        public var descriptions: [String]
        public var shape: NodeShape
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
        public var inlineStyle: [String: String]?
        public var properties: NodeProperties?
        public var interaction: NodeInteraction?

        public init(
            id: String,
            label: String,
            shape: NodeShape,
            x: Double,
            y: Double,
            width: Double,
            height: Double,
            descriptions: [String] = [],
            inlineStyle: [String: String]? = nil,
            properties: NodeProperties? = nil,
            interaction: NodeInteraction? = nil
        ) {
            self.id = id
            self.label = label
            self.descriptions = descriptions
            self.shape = shape
            self.x = x
            self.y = y
            self.width = width
            self.height = height
            self.inlineStyle = inlineStyle
            self.properties = properties
            self.interaction = interaction
        }
    }

    public struct PositionedEdge: Sendable {
        public var source: String
        public var target: String
        public var label: String?
        public var style: EdgeStyle
        public var arrowHeadStart: ArrowHeadType
        public var arrowHeadEnd: ArrowHeadType
        public var points: [Point]
        public var labelPosition: Point?
        public var inlineStyle: [String: String]?
        public var id: String?
        public var properties: NodeProperties?
        public var animate: Bool?
        public var animationSpeed: String?
        public var classes: [String]?
        public var curve: String?

        public init(
            source: String,
            target: String,
            label: String? = nil,
            style: EdgeStyle,
            arrowHeadStart: ArrowHeadType = .none,
            arrowHeadEnd: ArrowHeadType = .arrow,
            points: [Point],
            labelPosition: Point? = nil,
            inlineStyle: [String: String]? = nil,
            id: String? = nil,
            properties: NodeProperties? = nil,
            animate: Bool? = nil,
            animationSpeed: String? = nil,
            classes: [String]? = nil,
            curve: String? = nil
        ) {
            self.source = source
            self.target = target
            self.label = label
            self.style = style
            self.arrowHeadStart = arrowHeadStart
            self.arrowHeadEnd = arrowHeadEnd
            self.points = points
            self.labelPosition = labelPosition
            self.inlineStyle = inlineStyle
            self.id = id
            self.properties = properties
            self.animate = animate
            self.animationSpeed = animationSpeed
            self.classes = classes
            self.curve = curve
        }

        @available(*, deprecated, message: "Use arrowHeadStart instead")
        public var hasArrowStart: Bool { arrowHeadStart != .none }
        @available(*, deprecated, message: "Use arrowHeadEnd instead")
        public var hasArrowEnd: Bool { arrowHeadEnd != .none }
    }

    public struct RenderOptions: Sendable {
        public var bg: String?
        public var fg: String?
        public var line: String?
        public var accent: String?
        public var muted: String?
        public var surface: String?
        public var border: String?
        public var font: String?
        public var padding: Double?
        public var nodeSpacing: Double?
        public var layerSpacing: Double?
        public var componentSpacing: Double?
        public var transparent: Bool?

        public init(
            bg: String? = nil,
            fg: String? = nil,
            line: String? = nil,
            accent: String? = nil,
            muted: String? = nil,
            surface: String? = nil,
            border: String? = nil,
            font: String? = nil,
            padding: Double? = nil,
            nodeSpacing: Double? = nil,
            layerSpacing: Double? = nil,
            componentSpacing: Double? = nil,
            transparent: Bool? = nil
        ) {
            self.bg = bg
            self.fg = fg
            self.line = line
            self.accent = accent
            self.muted = muted
            self.surface = surface
            self.border = border
            self.font = font
            self.padding = padding
            self.nodeSpacing = nodeSpacing
            self.layerSpacing = layerSpacing
            self.componentSpacing = componentSpacing
            self.transparent = transparent
        }
    }
}

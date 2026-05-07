import Foundation

// MARK: - Source strategy enum

public enum WardleySourceStrategy: String, Sendable, Equatable, CaseIterable {
    case build
    case buy
    case outsource
    case market
}

// MARK: - Flow direction enum

public enum WardleyFlowDirection: String, Sendable, Equatable, CaseIterable {
    case forward
    case backward
    case bidirectional
}

// MARK: - Node class enum (renderer-visible)

public enum WardleyNodeClass: String, Sendable, Equatable, CaseIterable {
    case component
    case anchor
    case pipelineComponent = "pipeline-component"
}

// MARK: - Parsed model types

public struct WardleyNode: Sendable, Equatable {
    public var id: String
    public var label: String
    public var x: Double
    public var y: Double
    public var className: WardleyNodeClass?
    public var labelOffsetX: Double?
    public var labelOffsetY: Double?
    public var inPipeline: Bool
    public var isPipelineParent: Bool
    public var inertia: Bool
    public var sourceStrategy: WardleySourceStrategy?

    public init(
        id: String,
        label: String,
        x: Double,
        y: Double,
        className: WardleyNodeClass? = nil,
        labelOffsetX: Double? = nil,
        labelOffsetY: Double? = nil,
        inPipeline: Bool = false,
        isPipelineParent: Bool = false,
        inertia: Bool = false,
        sourceStrategy: WardleySourceStrategy? = nil
    ) {
        self.id = id
        self.label = label
        self.x = x
        self.y = y
        self.className = className
        self.labelOffsetX = labelOffsetX
        self.labelOffsetY = labelOffsetY
        self.inPipeline = inPipeline
        self.isPipelineParent = isPipelineParent
        self.inertia = inertia
        self.sourceStrategy = sourceStrategy
    }
}

public struct WardleyLink: Sendable, Equatable {
    public var source: String
    public var target: String
    public var dashed: Bool
    public var label: String?
    public var flow: WardleyFlowDirection?

    public init(
        source: String,
        target: String,
        dashed: Bool = false,
        label: String? = nil,
        flow: WardleyFlowDirection? = nil
    ) {
        self.source = source
        self.target = target
        self.dashed = dashed
        self.label = label
        self.flow = flow
    }
}

public struct WardleyTrend: Sendable, Equatable {
    public var nodeId: String
    public var targetX: Double
    public var targetY: Double

    public init(nodeId: String, targetX: Double, targetY: Double) {
        self.nodeId = nodeId
        self.targetX = targetX
        self.targetY = targetY
    }
}

public struct WardleyPipeline: Sendable, Equatable {
    public var nodeId: String
    public var componentIds: [String]

    public init(nodeId: String, componentIds: [String] = []) {
        self.nodeId = nodeId
        self.componentIds = componentIds
    }
}

public struct WardleyCoordinate: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct WardleyAnnotation: Sendable, Equatable {
    public var number: Int
    public var coordinates: [WardleyCoordinate]
    public var text: String?

    public init(number: Int, coordinates: [WardleyCoordinate] = [], text: String? = nil) {
        self.number = number
        self.coordinates = coordinates
        self.text = text
    }
}

public struct WardleyNote: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double

    public init(text: String, x: Double, y: Double) {
        self.text = text
        self.x = x
        self.y = y
    }
}

public struct WardleyAccelerator: Sendable, Equatable {
    public var name: String
    public var x: Double
    public var y: Double

    public init(name: String, x: Double, y: Double) {
        self.name = name
        self.x = x
        self.y = y
    }
}

public struct WardleyDeaccelerator: Sendable, Equatable {
    public var name: String
    public var x: Double
    public var y: Double

    public init(name: String, x: Double, y: Double) {
        self.name = name
        self.x = x
        self.y = y
    }
}

public struct WardleyAxesConfig: Sendable, Equatable {
    public var xLabel: String?
    public var yLabel: String?
    public var stages: [String]?
    public var stageBoundaries: [Double]?

    public init(
        xLabel: String? = nil,
        yLabel: String? = nil,
        stages: [String]? = nil,
        stageBoundaries: [Double]? = nil
    ) {
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.stages = stages
        self.stageBoundaries = stageBoundaries
    }
}

public struct WardleySize: Sendable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

// MARK: - Top-level diagram model

public struct WardleyMapDiagram: Sendable, Equatable {
    public var nodes: [WardleyNode]
    public var links: [WardleyLink]
    public var trends: [WardleyTrend]
    public var pipelines: [WardleyPipeline]
    public var annotations: [WardleyAnnotation]
    public var notes: [WardleyNote]
    public var accelerators: [WardleyAccelerator]
    public var deaccelerators: [WardleyDeaccelerator]
    public var annotationsBox: WardleyCoordinate?
    public var axes: WardleyAxesConfig
    public var size: WardleySize?
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: WardleyDiagramConfig
    public var theme: WardleyThemeVariables?

    public static let empty = WardleyMapDiagram(
        nodes: [], links: [], trends: [], pipelines: [],
        annotations: [], notes: [], accelerators: [], deaccelerators: [],
        axes: WardleyAxesConfig(), config: .default
    )

    public init(
        nodes: [WardleyNode] = [],
        links: [WardleyLink] = [],
        trends: [WardleyTrend] = [],
        pipelines: [WardleyPipeline] = [],
        annotations: [WardleyAnnotation] = [],
        notes: [WardleyNote] = [],
        accelerators: [WardleyAccelerator] = [],
        deaccelerators: [WardleyDeaccelerator] = [],
        annotationsBox: WardleyCoordinate? = nil,
        axes: WardleyAxesConfig = WardleyAxesConfig(),
        size: WardleySize? = nil,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: WardleyDiagramConfig = .default,
        theme: WardleyThemeVariables? = nil
    ) {
        self.nodes = nodes
        self.links = links
        self.trends = trends
        self.pipelines = pipelines
        self.annotations = annotations
        self.notes = notes
        self.accelerators = accelerators
        self.deaccelerators = deaccelerators
        self.annotationsBox = annotationsBox
        self.axes = axes
        self.size = size
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
    }

    public func resolveNodeId(_ name: String) -> String {
        if nodes.contains(where: { $0.id == name }) {
            return name
        }
        if let match = nodes.first(where: { $0.label == name }) {
            return match.id
        }
        return name
    }
}

// MARK: - Configuration

public struct WardleyDiagramConfig: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public var padding: Double
    public var nodeRadius: Double
    public var nodeLabelOffset: Double
    public var axisFontSize: Double
    public var labelFontSize: Double
    public var showGrid: Bool
    public var useMaxWidth: Bool

    public static let `default` = WardleyDiagramConfig()

    public init(
        width: Double = 900,
        height: Double = 600,
        padding: Double = 48,
        nodeRadius: Double = 6,
        nodeLabelOffset: Double = 8,
        axisFontSize: Double = 12,
        labelFontSize: Double = 10,
        showGrid: Bool = false,
        useMaxWidth: Bool = true
    ) {
        self.width = width
        self.height = height
        self.padding = padding
        self.nodeRadius = nodeRadius
        self.nodeLabelOffset = nodeLabelOffset
        self.axisFontSize = axisFontSize
        self.labelFontSize = labelFontSize
        self.showGrid = showGrid
        self.useMaxWidth = useMaxWidth
    }
}

// MARK: - Theme variables

public struct WardleyThemeVariables: Sendable, Equatable {
    public var backgroundColor: String
    public var axisColor: String
    public var axisTextColor: String
    public var gridColor: String
    public var componentFill: String
    public var componentStroke: String
    public var componentLabelColor: String
    public var linkStroke: String
    public var evolutionStroke: String
    public var annotationStroke: String
    public var annotationTextColor: String
    public var annotationFill: String
    public var evolutionColor: String

    public static let `default` = WardleyThemeVariables()

    public init(
        backgroundColor: String = "#FFFFFF",
        axisColor: String = "#000000",
        axisTextColor: String = "#222222",
        gridColor: String = "rgba(100, 100, 100, 0.2)",
        componentFill: String = "#FFFFFF",
        componentStroke: String = "#000000",
        componentLabelColor: String = "#222222",
        linkStroke: String = "#000000",
        evolutionStroke: String = "#dc3545",
        annotationStroke: String = "#000000",
        annotationTextColor: String = "#222222",
        annotationFill: String = "#FFFFFF",
        evolutionColor: String = "#dc3545"
    ) {
        self.backgroundColor = backgroundColor
        self.axisColor = axisColor
        self.axisTextColor = axisTextColor
        self.gridColor = gridColor
        self.componentFill = componentFill
        self.componentStroke = componentStroke
        self.componentLabelColor = componentLabelColor
        self.linkStroke = linkStroke
        self.evolutionStroke = evolutionStroke
        self.annotationStroke = annotationStroke
        self.annotationTextColor = annotationTextColor
        self.annotationFill = annotationFill
        self.evolutionColor = evolutionColor
    }
}

// MARK: - Positioned types

public struct PositionedWardleyNode: Sendable {
    public var id: String
    public var label: String
    public var x: Double
    public var y: Double
    public var className: WardleyNodeClass?
    public var labelOffsetX: Double?
    public var labelOffsetY: Double?
    public var inPipeline: Bool
    public var isPipelineParent: Bool
    public var inertia: Bool
    public var sourceStrategy: WardleySourceStrategy?
}

public struct PositionedWardleyLink: Sendable {
    public var source: String
    public var target: String
    public var dashed: Bool
    public var label: String?
    public var flow: WardleyFlowDirection?
    public var sourceX: Double
    public var sourceY: Double
    public var targetX: Double
    public var targetY: Double
    public var labelX: Double?
    public var labelY: Double?
    public var labelAngle: Double?
}

public struct PositionedWardleyTrend: Sendable {
    public var nodeId: String
    public var originX: Double
    public var originY: Double
    public var targetX: Double
    public var targetY: Double
}

public struct PositionedWardleyPipelineBox: Sendable {
    public var nodeId: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var parentX: Double
    public var parentY: Double
    public var childLinks: [PositionedWardleyPipelineChildLink]
}

public struct PositionedWardleyPipelineChildLink: Sendable {
    public var fromId: String
    public var toId: String
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
}

public struct PositionedWardleyAnnotationPoint: Sendable {
    public var number: Int
    public var x: Double
    public var y: Double
    public var connectingLines: [(x1: Double, y1: Double, x2: Double, y2: Double)]
}

public struct PositionedWardleyAnnotationBox: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var entries: [PositionedWardleyAnnotationBoxEntry]
}

public struct PositionedWardleyAnnotationBoxEntry: Sendable {
    public var number: Int
    public var text: String
    public var x: Double
    public var y: Double
}

public struct PositionedWardleyNote: Sendable {
    public var text: String
    public var x: Double
    public var y: Double
}

public struct PositionedWardleyAccelerator: Sendable {
    public var name: String
    public var x: Double
    public var y: Double
}

public struct PositionedWardleyDeaccelerator: Sendable {
    public var name: String
    public var x: Double
    public var y: Double
}

public struct PositionedWardleyStage: Sendable {
    public var name: String
    public var startX: Double
    public var endX: Double
    public var centerX: Double
    public var labelY: Double
}

public struct PositionedWardleyMapDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var padding: Double
    public var nodes: [PositionedWardleyNode]
    public var validLinks: [PositionedWardleyLink]
    public var trends: [PositionedWardleyTrend]
    public var pipelineBoxes: [PositionedWardleyPipelineBox]
    public var annotationPoints: [PositionedWardleyAnnotationPoint]
    public var annotationBox: PositionedWardleyAnnotationBox?
    public var notes: [PositionedWardleyNote]
    public var accelerators: [PositionedWardleyAccelerator]
    public var deaccelerators: [PositionedWardleyDeaccelerator]
    public var stages: [PositionedWardleyStage]
    public var axes: WardleyAxesConfig
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: WardleyDiagramConfig
    public var theme: WardleyThemeVariables?
    public var showGrid: Bool
    public var gridLines: [(x1: Double, y1: Double, x2: Double, y2: Double)]

    public static let empty = PositionedWardleyMapDiagram(
        width: 0, height: 0, padding: 48,
        nodes: [], validLinks: [], trends: [], pipelineBoxes: [],
        annotationPoints: [], notes: [], accelerators: [], deaccelerators: [],
        stages: [], axes: WardleyAxesConfig(), config: .default, showGrid: false,
        gridLines: []
    )

    public init(
        width: Double,
        height: Double,
        padding: Double,
        nodes: [PositionedWardleyNode],
        validLinks: [PositionedWardleyLink],
        trends: [PositionedWardleyTrend],
        pipelineBoxes: [PositionedWardleyPipelineBox],
        annotationPoints: [PositionedWardleyAnnotationPoint],
        annotationBox: PositionedWardleyAnnotationBox? = nil,
        notes: [PositionedWardleyNote],
        accelerators: [PositionedWardleyAccelerator],
        deaccelerators: [PositionedWardleyDeaccelerator],
        stages: [PositionedWardleyStage],
        axes: WardleyAxesConfig,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: WardleyDiagramConfig,
        theme: WardleyThemeVariables? = nil,
        showGrid: Bool = false,
        gridLines: [(x1: Double, y1: Double, x2: Double, y2: Double)] = []
    ) {
        self.width = width
        self.height = height
        self.padding = padding
        self.nodes = nodes
        self.validLinks = validLinks
        self.trends = trends
        self.pipelineBoxes = pipelineBoxes
        self.annotationPoints = annotationPoints
        self.annotationBox = annotationBox
        self.notes = notes
        self.accelerators = accelerators
        self.deaccelerators = deaccelerators
        self.stages = stages
        self.axes = axes
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
        self.showGrid = showGrid
        self.gridLines = gridLines
    }
}

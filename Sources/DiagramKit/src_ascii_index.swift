// Ported from original/src/ascii/index.ts
import Foundation
import DiagramKitModel

private func _bmParseMermaid(_ text: String, config: original_src_types.FlowchartConfig? = nil) throws -> MermaidGraph {
    try parseMermaid(text, config: config)
}

private func _bmConvertToAsciiGraph(
    _ parsed: original_src_ascii_index.ParsedMermaid,
    _ config: original_src_ascii_index.AsciiConfig
) -> original_src_ascii_converter.AsciiGraph {
    let converterConfig = original_src_ascii_converter.AsciiConfig(
        useAscii: config.useAscii,
        paddingX: config.paddingX,
        paddingY: config.paddingY,
        boxBorderPadding: config.boxBorderPadding,
        graphDirection: config.graphDirection
    )

    // Bridge parser output (original_src_types.MermaidGraph) to converter input
    let tsGraph: original_src_types.MermaidGraph
    switch parsed.graph.payload {
    case .flowchart(let graph), .stateDiagram(let graph):
        tsGraph = graph
    default:
        // Fallback: empty graph if payload isn't the expected type
        return original_src_ascii_converter.convertToAsciiGraph(
            original_src_ascii_converter.MermaidGraphInput(
                nodes: [], edges: [], subgraphs: [], classAssignments: [], classDefs: [:]
            ),
            converterConfig
        )
    }

    // Map nodes: (id, MermaidNode) → (id, MermaidNodeInput)
    let nodes: [(id: String, node: original_src_ascii_converter.MermaidNodeInput)] = tsGraph.nodesInOrder.map { entry in
        (
            id: entry.id,
            node: original_src_ascii_converter.MermaidNodeInput(
                label: entry.node.label,
                shape: entry.node.shape.rawValue
            )
        )
    }

    // Map edges: MermaidEdge → MermaidEdgeInput
    let edges: [original_src_ascii_converter.MermaidEdgeInput] = tsGraph.edges.map { e in
        original_src_ascii_converter.MermaidEdgeInput(
            source: e.source,
            target: e.target,
            label: e.label,
            style: e.style.rawValue,
            hasArrowStart: e.arrowHeadStart != .none,
            hasArrowEnd: e.arrowHeadEnd != .none
        )
    }

    // Map subgraphs recursively: MermaidSubgraph → MermaidSubgraphInput
    func convertSubgraph(_ sg: original_src_types.MermaidSubgraph) -> original_src_ascii_converter.MermaidSubgraphInput {
        let children = sg.children.map { convertSubgraph($0) }
        return original_src_ascii_converter.MermaidSubgraphInput(
            label: sg.label,
            nodeIds: sg.nodeIds,
            children: children,
            direction: sg.direction?.rawValue
        )
    }
    let subgraphs = tsGraph.subgraphs.map { convertSubgraph($0) }

    // Map class assignments: [String: [String]] → [(nodeId, className)]
    let classAssignments: [(nodeId: String, className: String)] = tsGraph.classAssignments.flatMap { (nodeId, classNames) in
        classNames.map { (nodeId: nodeId, className: $0) }
    }

    let converterInput = original_src_ascii_converter.MermaidGraphInput(
        nodes: nodes,
        edges: edges,
        subgraphs: subgraphs,
        classAssignments: classAssignments,
        classDefs: tsGraph.classDefs
    )

    return original_src_ascii_converter.convertToAsciiGraph(converterInput, converterConfig)
}

private func _bmCreateMapping(_ graph: original_src_ascii_converter.AsciiGraph) throws {
    try original_src_ascii_grid.createMapping(graph)
}

private func _bmToAsciiTypeGraph(_ graph: original_src_ascii_converter.AsciiGraph) -> AsciiGraph {
    var nodesByKey: [String: AsciiNode] = [:]
    let nodes: [AsciiNode] = graph.nodes.map { node in
        let mapped = AsciiNode(
            name: node.name,
            displayLabel: node.displayLabel,
            shape: node.shape,
            index: node.index,
            gridCoord: node.gridCoord.map { GridCoord(x: $0.x, y: $0.y) },
            drawingCoord: node.drawingCoord.map { DrawingCoord(x: $0.x, y: $0.y) },
            drawing: node.drawing,
            drawn: node.drawn,
            styleClassName: node.styleClassName,
            styleClass: AsciiStyleClass(name: node.styleClass.name, styles: node.styleClass.styles)
        )
        nodesByKey["\(mapped.name)#\(mapped.index)"] = mapped
        return mapped
    }

    let subgraphs: [AsciiSubgraph] = graph.subgraphs.map { sg in
        let sgNodes = sg.nodes.compactMap { node in nodesByKey["\(node.name)#\(node.index)"] }
        return AsciiSubgraph(
            name: sg.name,
            nodes: sgNodes,
            parent: nil,
            children: [],
            minX: sg.minX,
            minY: sg.minY,
            maxX: sg.maxX,
            maxY: sg.maxY,
            direction: sg.direction
        )
    }

    let edgeStyleMap: [String: AsciiEdgeStyle] = [
        "solid": .solid,
        "dotted": .dotted,
        "thick": .thick,
    ]

    let edges: [AsciiEdge] = graph.edges.map { edge in
        let from = nodesByKey["\(edge.from.name)#\(edge.from.index)"] ??
            AsciiNode(name: edge.from.name, displayLabel: edge.from.displayLabel, shape: edge.from.shape, index: edge.from.index)
        let to = nodesByKey["\(edge.to.name)#\(edge.to.index)"] ??
            AsciiNode(name: edge.to.name, displayLabel: edge.to.displayLabel, shape: edge.to.shape, index: edge.to.index)
        return AsciiEdge(
            from: from,
            to: to,
            text: edge.text,
            path: edge.path.map { GridCoord(x: $0.x, y: $0.y) },
            labelLine: edge.labelLine.map { GridCoord(x: $0.x, y: $0.y) },
            startDir: Direction(x: edge.startDir.x, y: edge.startDir.y),
            endDir: Direction(x: edge.endDir.x, y: edge.endDir.y),
            style: edgeStyleMap[edge.style ?? "solid"] ?? .solid,
            hasArrowStart: edge.hasArrowStart,
            hasArrowEnd: edge.hasArrowEnd,
            bundle: nil,
            pathToJunction: nil
        )
    }

    let grid: [String: AsciiNode] = Dictionary(graph.grid.compactMap { key, node -> (String, AsciiNode)? in
        guard let mapped = nodesByKey["\(node.name)#\(node.index)"] else {
            return nil
        }
        return (key, mapped)
    }, uniquingKeysWith: { _, last in last })

    return AsciiGraph(
        nodes: nodes,
        edges: edges,
        canvas: graph.canvas,
        roleCanvas: mkRoleCanvas(max(0, graph.canvas.count - 1), max(0, (graph.canvas.first?.count ?? 1) - 1)),
        grid: grid,
        columnWidth: graph.columnWidth,
        rowHeight: graph.rowHeight,
        subgraphs: subgraphs,
        config: AsciiConfig(
            useAscii: graph.config.useAscii,
            paddingX: graph.config.paddingX,
            paddingY: graph.config.paddingY,
            boxBorderPadding: graph.config.boxBorderPadding,
            graphDirection: graph.config.graphDirection
        ),
        offsetX: graph.offsetX,
        offsetY: graph.offsetY,
        bundles: []
    )
}

private func _bmDrawGraph(_ graph: inout AsciiGraph) {
    _ = drawGraph(&graph)
}

private func _bmCanvasToString(
    _ canvas: Canvas,
    roleCanvas: RoleCanvas,
    colorMode: ColorMode,
    theme: AsciiTheme
) -> String {
    canvasToString(canvas, options: CanvasToStringOptions(roleCanvas: roleCanvas, colorMode: colorMode, theme: theme))
}

private func _bmRenderSequenceAscii(
    _ text: String,
    _ config: AsciiConfig,
    _ colorMode: ColorMode?,
    _ theme: AsciiTheme?
) throws -> String {
    try renderSequenceAscii(text, config, colorMode, theme)
}

private func _bmRenderClassAscii(
    _ text: String,
    _ config: AsciiConfig,
    _ colorMode: ColorMode?,
    _ theme: AsciiTheme?
) throws -> String {
    try renderClassAscii(text, config, colorMode, theme)
}

private func _bmRenderErAscii(
    _ text: String,
    _ config: AsciiConfig,
    _ colorMode: ColorMode?,
    _ theme: AsciiTheme?
) throws -> String {
    try renderErAscii(text, config, colorMode, theme)
}

open class original_src_ascii_index {
    public init() {}

    // MARK: - Ported types (index.ts public API surface)

    public enum AsciiThemeColorMode: String, Sendable {
        case none
        case ansi16
        case ansi256
        case truecolor
        case html
    }

    public enum AsciiColorModeOption: Sendable {
        case auto
        case explicit(AsciiThemeColorMode)
    }

    public struct AsciiTheme: Sendable {
        public var values: [String: String]

        public init(values: [String: String] = [:]) {
            self.values = values
        }

        public func merged(with partial: AsciiTheme?) -> AsciiTheme {
            guard let partial else { return self }
            var mergedValues = values
            for (k, v) in partial.values {
                mergedValues[k] = v
            }
            return AsciiTheme(values: mergedValues)
        }
    }

    public static let DEFAULT_ASCII_THEME = AsciiTheme(values: [:])

    public struct AsciiRenderOptions: Sendable {
        public var useAscii: Bool?
        public var paddingX: Int?
        public var paddingY: Int?
        public var boxBorderPadding: Int?
        public var colorMode: AsciiColorModeOption?
        public var theme: AsciiTheme?

        public init(
            useAscii: Bool? = nil,
            paddingX: Int? = nil,
            paddingY: Int? = nil,
            boxBorderPadding: Int? = nil,
            colorMode: AsciiColorModeOption? = nil,
            theme: AsciiTheme? = nil
        ) {
            self.useAscii = useAscii
            self.paddingX = paddingX
            self.paddingY = paddingY
            self.boxBorderPadding = boxBorderPadding
            self.colorMode = colorMode
            self.theme = theme
        }
    }

    // `DetectedDiagramType` previously lived here as a parallel enum to
    // the global `DiagramType`. Header detection now routes through
    // `DiagramRegistry.detect`, so the enum and its bespoke
    // `detectDiagramTypeInternal` chain have both been removed.

    struct AsciiConfig {
        var useAscii: Bool
        var paddingX: Int
        var paddingY: Int
        var boxBorderPadding: Int
        var graphDirection: String
    }

    struct ParsedMermaid {
        var direction: String
        var graph: MermaidGraph
    }

    private struct AsciiGraphModel {
        var flowGraph: original_src_ascii_converter.AsciiGraph
        var drawGraph: AsciiGraph
    }

    // MARK: - Re-exported API parity

    public static func detectColorMode() -> AsciiThemeColorMode {
        .none
    }

    public static func diagramColorsToAsciiTheme(_ colors: [String: String]) -> AsciiTheme {
        AsciiTheme(values: colors)
    }

    // MARK: - Internal theme/colorMode mapping helpers

    private static func _mapColorMode(_ colorMode: AsciiThemeColorMode) -> ColorMode {
        switch colorMode {
        case .none:   return .none
        case .ansi16: return .ansi16
        case .ansi256: return .ansi256
        case .truecolor: return .truecolor
        case .html:   return .html
        }
    }

    private static func _mapTheme(_ theme: AsciiTheme, includeAccentBg: Bool = false) -> original_src_ascii_types.AsciiTheme {
        original_src_ascii_types.AsciiTheme(
            fg: theme.values["fg"] ?? "#27272a",
            border: theme.values["border"] ?? "#a1a1aa",
            line: theme.values["line"] ?? "#71717a",
            arrow: theme.values["arrow"] ?? "#52525b",
            corner: theme.values["corner"],
            junction: theme.values["junction"],
            accent: includeAccentBg ? theme.values["accent"] : nil,
            bg: includeAccentBg ? theme.values["bg"] : nil
        )
    }

    /// Detect the diagram type from the mermaid source text.
    /// Delegates to `DiagramRegistry.detect` and maps the resulting
    /// `DiagramType` back to the legacy ASCII-side name strings so the
    /// public return value stays stable. State diagrams report as
    /// "flowchart" (they share the renderer).
    public static func detectDiagramType(_ text: String) -> String {
        let preprocessed = _preprocessMermaidSource(text).source
        switch DiagramRegistry.detect(from: preprocessed).type {
        case .sequenceDiagram:  return "sequence"
        case .classDiagram:     return "class"
        case .erDiagram:        return "er"
        case .xyChart:          return "xychart"
        case .pie:              return "pie"
        case .journey:          return "journey"
        case .gantt:            return "gantt"
        case .quadrantChart:    return "quadrantChart"
        case .requirement:      return "requirement"
        case .gitGraph:         return "gitGraph"
        case .mindmap:          return "mindmap"
        case .timeline:         return "timeline"
        case .sankey:           return "sankey"
        case .block:            return "block"
        case .packet:           return "packet"
        case .kanban:           return "kanban"
        case .architecture:     return "architecture"
        case .radar:            return "radar"
        case .treemap:          return "treemap"
        case .venn:             return "venn"
        case .ishikawa:         return "ishikawa"
        case .treeView:         return "treeView"
        case .eventModeling:    return "eventmodeling"
        case .wardleyBeta:      return "wardley-beta"
        case .zenuml:           return "zenuml"
        case .c4:               return "c4"
        case .flowchart, .stateDiagram:
            return "flowchart"
        }
    }

    /// Render Mermaid diagram text to an ASCII/Unicode string.
    /// Control-flow/API parity with original/src/ascii/index.ts.
    public static func renderMermaidASCII(
        _ text: String,
        options: AsciiRenderOptions = AsciiRenderOptions()
    ) throws -> String {
        let preprocessed = _preprocessMermaidSource(text)
        let preprocessedText = preprocessed.source
        var config = AsciiConfig(
            useAscii: options.useAscii ?? false,
            paddingX: options.paddingX ?? 5,
            paddingY: options.paddingY ?? 5,
            boxBorderPadding: options.boxBorderPadding ?? 1,
            graphDirection: "TD"
        )

        let resolvedColorMode: AsciiThemeColorMode
        switch options.colorMode ?? .auto {
        case .auto:
            resolvedColorMode = detectColorMode()
        case let .explicit(mode):
            resolvedColorMode = mode
        }

        let theme = DEFAULT_ASCII_THEME.merged(with: options.theme)

        switch DiagramRegistry.detect(from: preprocessedText).type {
        case .sequenceDiagram:
            return try renderSequenceAscii(preprocessedText, config, resolvedColorMode, theme)

        case .classDiagram:
            return try renderClassAscii(preprocessedText, config, resolvedColorMode, theme)

        case .erDiagram:
            return try renderErAscii(preprocessedText, config, resolvedColorMode, theme)

        case .xyChart:
            let mappedColorMode = _mapColorMode(resolvedColorMode)
            let mappedTheme = _mapTheme(theme, includeAccentBg: true)
            let mappedConfig = original_src_ascii_types.AsciiConfig(
                useAscii: config.useAscii,
                paddingX: config.paddingX,
                paddingY: config.paddingY,
                boxBorderPadding: config.boxBorderPadding,
                graphDirection: config.graphDirection
            )
            return renderXYChartAscii(preprocessedText, mappedConfig, mappedColorMode, mappedTheme)

        case .pie:
            throw BeautifulMermaidError.notYetImplemented("Pie Chart ASCII rendering")

        case .journey:
            throw BeautifulMermaidError.notYetImplemented("ASCII rendering for User Journey diagrams")

        case .gantt:
            throw BeautifulMermaidError.notYetImplemented("ASCII rendering for Gantt diagrams")

        case .quadrantChart:
            throw BeautifulMermaidError.notYetImplemented("Quadrant Chart ASCII rendering")

        case .requirement:
            throw BeautifulMermaidError.notYetImplemented("Requirement Diagram ASCII rendering")

        case .gitGraph:
            throw BeautifulMermaidError.notYetImplemented("GitGraph ASCII rendering")

        case .mindmap:
            throw BeautifulMermaidError.notYetImplemented("Mindmap ASCII rendering")

        case .timeline:
            throw BeautifulMermaidError.notYetImplemented("Timeline ASCII rendering")

        case .sankey:
            throw BeautifulMermaidError.notYetImplemented("Sankey ASCII rendering")

        case .block:
            throw BeautifulMermaidError.notYetImplemented("Block Diagram ASCII rendering")

        case .packet:
            throw BeautifulMermaidError.notYetImplemented("Packet ASCII rendering is not yet implemented.")

        case .kanban:
            throw BeautifulMermaidError.notYetImplemented("Kanban ASCII rendering")

        case .architecture:
            throw BeautifulMermaidError.notYetImplemented("Architecture Diagram ASCII rendering")

        case .radar:
            throw BeautifulMermaidError.notYetImplemented("Radar Chart ASCII rendering")

        case .treemap:
            throw BeautifulMermaidError.notYetImplemented("Treemap ASCII rendering")

        case .venn:
            throw BeautifulMermaidError.notYetImplemented("Venn Diagram ASCII rendering")

        case .ishikawa:
            throw BeautifulMermaidError.notYetImplemented("Ishikawa Diagram ASCII rendering")

        case .treeView:
            throw BeautifulMermaidError.notYetImplemented("TreeView ASCII rendering")

        case .eventModeling:
            throw BeautifulMermaidError.notYetImplemented("Event Modeling ASCII rendering")

        case .wardleyBeta:
            throw BeautifulMermaidError.notYetImplemented("Wardley Map ASCII rendering")

        case .zenuml:
            throw BeautifulMermaidError.notYetImplemented("ZenUML ASCII rendering")

        case .c4:
            throw BeautifulMermaidError.notYetImplemented("C4 Diagram ASCII rendering")

        case .flowchart, .stateDiagram:
            let parsed = try parseMermaid(preprocessedText)

            if parsed.direction == "LR" || parsed.direction == "RL" {
                config.graphDirection = "LR"
            } else {
                config.graphDirection = "TD"
            }

            var graph = try convertToAsciiGraph(parsed, config)
            try createMapping(&graph)
            try drawGraph(&graph)

            if parsed.direction == "BT" {
                flipCanvasVertically(&graph.drawGraph.canvas)
                flipRoleCanvasVertically(&graph.drawGraph.roleCanvas)
            }

            let result = try canvasToString(
                graph.drawGraph.canvas,
                roleCanvas: graph.drawGraph.roleCanvas,
                colorMode: resolvedColorMode,
                theme: theme
            )
            return result
        }
    }

    /// @deprecated Use `renderMermaidASCII`.
    public static func renderMermaidAscii(
        _ text: String,
        options: AsciiRenderOptions = AsciiRenderOptions()
    ) throws -> String {
        try renderMermaidASCII(text, options: options)
    }

    // MARK: - Internal detection
    //
    // Header detection now lives in `DiagramRegistry.detect(from:)`; the
    // bespoke `detectDiagramTypeInternal` regex-and-prefix chain that
    // previously lived here has been removed.

    // MARK: - Downstream call sites (explicit placeholders)

    private static func parseMermaid(_ text: String) throws -> ParsedMermaid {
        let preprocessed = _preprocessMermaidSource(text)
        let preprocessedText = preprocessed.source
        let parsed = try _bmParseMermaid(preprocessedText, config: preprocessed.frontmatter?.flowchartConfig)
        let lines = _mermaidSourceLines(from: preprocessedText, separatedBy: .newlines)
        let header = (lines.first ?? "").uppercased()

        let direction: String
        if header.contains(" LR") || header.hasSuffix("LR") {
            direction = "LR"
        } else if header.contains(" RL") || header.hasSuffix("RL") {
            direction = "RL"
        } else if header.contains(" BT") || header.hasSuffix("BT") {
            direction = "BT"
        } else if header.contains(" TB") || header.hasSuffix("TB") {
            direction = "TB"
        } else {
            direction = "TD"
        }

        return ParsedMermaid(direction: direction, graph: parsed)
    }

    private static func convertToAsciiGraph(_ parsed: ParsedMermaid, _ config: AsciiConfig) throws -> AsciiGraphModel {
        let flowGraph = _bmConvertToAsciiGraph(parsed, config)
        let drawGraph = _bmToAsciiTypeGraph(flowGraph)
        return AsciiGraphModel(flowGraph: flowGraph, drawGraph: drawGraph)
    }

    private static func createMapping(_ graph: inout AsciiGraphModel) throws {
        try _bmCreateMapping(graph.flowGraph)
        graph.drawGraph = _bmToAsciiTypeGraph(graph.flowGraph)
    }

    private static func drawGraph(_ graph: inout AsciiGraphModel) throws {
        _bmDrawGraph(&graph.drawGraph)
    }

    private static func canvasToString(
        _ canvas: Canvas,
        roleCanvas: RoleCanvas,
        colorMode: AsciiThemeColorMode,
        theme: AsciiTheme
    ) throws -> String {
        return _bmCanvasToString(canvas, roleCanvas: roleCanvas, colorMode: _mapColorMode(colorMode), theme: _mapTheme(theme))
    }

    private static func renderSequenceAscii(
        _ text: String,
        _ config: AsciiConfig,
        _ colorMode: AsciiThemeColorMode,
        _ theme: AsciiTheme
    ) throws -> String {
        let mappedConfig = original_src_ascii_types.AsciiConfig(
            useAscii: config.useAscii,
            paddingX: config.paddingX,
            paddingY: config.paddingY,
            boxBorderPadding: config.boxBorderPadding,
            graphDirection: config.graphDirection
        )
        return try _bmRenderSequenceAscii(text, mappedConfig, _mapColorMode(colorMode), _mapTheme(theme))
    }

    private static func renderClassAscii(
        _ text: String,
        _ config: AsciiConfig,
        _ colorMode: AsciiThemeColorMode,
        _ theme: AsciiTheme
    ) throws -> String {
        let mappedConfig = original_src_ascii_types.AsciiConfig(
            useAscii: config.useAscii,
            paddingX: config.paddingX,
            paddingY: config.paddingY,
            boxBorderPadding: config.boxBorderPadding,
            graphDirection: config.graphDirection
        )
        return try _bmRenderClassAscii(text, mappedConfig, _mapColorMode(colorMode), _mapTheme(theme))
    }

    private static func renderErAscii(
        _ text: String,
        _ config: AsciiConfig,
        _ colorMode: AsciiThemeColorMode,
        _ theme: AsciiTheme
    ) throws -> String {
        let mappedConfig = original_src_ascii_types.AsciiConfig(
            useAscii: config.useAscii,
            paddingX: config.paddingX,
            paddingY: config.paddingY,
            boxBorderPadding: config.boxBorderPadding,
            graphDirection: config.graphDirection
        )
        return try _bmRenderErAscii(text, mappedConfig, _mapColorMode(colorMode), _mapTheme(theme))
    }
}

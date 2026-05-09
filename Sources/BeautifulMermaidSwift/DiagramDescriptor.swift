import Foundation
import DiagramKitModel
import DiagramKitCommon

// MARK: - Diagram Header

/// The first meaningful statement from a Mermaid diagram source.
/// Used by `DiagramDescriptor.matches` for routing decisions.
public struct DiagramHeader: Sendable {
    /// The raw first statement (untrimmed, case-preserved).
    public let raw: String

    /// Lowercased version for prefix matching.
    public var normalized: String { raw.lowercased() }

    /// The raw text split into lines.
    public let rawLines: [String]

    public init(raw: String, rawLines: [String] = []) {
        self.raw = raw
        self.rawLines = rawLines
    }

    /// Convenience: detect from a preprocessed source string.
    public static func detect(from processedSource: String) -> DiagramHeader {
        let rawLines = MermaidSourceNormalizer.rawLines(processedSource)
        let firstLine = rawLines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return DiagramHeader(raw: firstLine, rawLines: rawLines)
    }
}

// MARK: - Diagram Descriptor

/// Describes one diagram family: how to detect it, parse it, and lay it out.
/// New diagram types are added by appending a descriptor to `DiagramRegistry.all`.
public struct DiagramDescriptor: Sendable {
    public let type: DiagramType

    /// Returns `true` when `header` matches this diagram family.
    /// Order matters: `DiagramRegistry.all` is evaluated in array order;
    /// the first match wins.
    public let matches: @Sendable (DiagramHeader) -> Bool

    /// Parse the preprocessed source into a `MermaidGraph`.
    /// `frontmatter` is the parsed and bound frontmatter (optional).
    public let parse: @Sendable (String, DiagramFrontmatter?) throws -> MermaidGraph

    /// Layout a parsed graph into a `PositionedGraph`.
    public let layout: @Sendable (MermaidGraph, LayoutConfig) throws -> PositionedGraph

    public init(
        type: DiagramType,
        matches: @escaping @Sendable (DiagramHeader) -> Bool,
        parse: @escaping @Sendable (String, DiagramFrontmatter?) throws -> MermaidGraph,
        layout: @escaping @Sendable (MermaidGraph, LayoutConfig) throws -> PositionedGraph
    ) {
        self.type = type
        self.matches = matches
        self.parse = parse
        self.layout = layout
    }
}

// MARK: - Diagram Registry

/// The canonical source of truth for diagram detection, parsing, and layout
/// routing. Replaces the duplicated `hasPrefix` chains in `Parser.swift`,
/// `src_index.swift`, and `Layout.swift`.
public enum DiagramRegistry {

    /// All registered diagram descriptors, in priority order.
    /// Detection is first-match-wins, so narrower prefixes must come before
    /// broader ones (e.g. `stateDiagram-v2` before `stateDiagram`).
    public static let all: [DiagramDescriptor] = [
        // --- Narrowest / most-specific first ---
        _journey,
        _sequenceDiagram,
        _classDiagram,
        _erDiagram,
        _xyChart,
        _pie,
        _gantt,
        _quadrantChart,
        _gitGraph,
        _requirement,
        _mindmap,
        _timeline,
        _sankey,
        _block,
        _packet,
        _kanban,
        _architecture,
        _radar,
        _treemap,
        _venn,
        _ishikawa,
        _treeView,
        _eventModeling,
        _wardley,
        _zenuml,
        _c4,
        // --- Broadest / fallback ---
        _stateDiagram,  // must come after stateDiagram-v2 handled inside
        _flowchart,     // fallback for unrecognized headers
    ]

    /// Find the descriptor matching `header`, or the flowchart fallback.
    public static func detect(_ header: DiagramHeader) -> DiagramDescriptor {
        all.first { $0.matches(header) } ?? _flowchart
    }

    /// Convenience: detect from a preprocessed source string.
    public static func detect(from source: String) -> DiagramDescriptor {
        detect(DiagramHeader.detect(from: source))
    }

    /// The number of registered descriptors. Should equal `DiagramType.allCases.count`.
    public static var registeredCount: Int { all.count }

    /// Look up a descriptor by `DiagramType`. Throws `MermaidStructuralError` if
    /// no descriptor matches the given type.
    public static func descriptor(for type: DiagramType) throws -> DiagramDescriptor {
        guard let descriptor = all.first(where: { $0.type == type }) else {
            throw MermaidStructuralError.payloadMismatch(type)
        }
        return descriptor
    }

    /// Validates that every `DiagramType` case has a corresponding descriptor.
    /// Call once at app start or in a test. Returns `true` if the registry is
    /// consistent with the `DiagramType` enum.
    public static func validate() -> Bool {
        let typeCount = DiagramType.allCases.count
        guard registeredCount == typeCount else {
            _reportMermaidIssue(
                "DiagramRegistry.validate: \(registeredCount) descriptors registered, but DiagramType has \(typeCount) cases. Add missing descriptors or remove stale enum cases."
            )
            return false
        }
        // Extra safety: ensure every DiagramType case has a descriptor by matching types.
        var seen = Set<DiagramType>()
        for d in all { seen.insert(d.type) }
        let missing = Set(DiagramType.allCases).subtracting(seen)
        if !missing.isEmpty {
            _reportMermaidIssue(
                "DiagramRegistry.validate: missing descriptors for types: \(missing.map(\.rawValue).sorted().joined(separator: ", "))"
            )
            return false
        }
        return true
    }
}

// MARK: - Descriptor Definitions

private extension DiagramRegistry {

    // -- journey --

    static let _journey = DiagramDescriptor(
        type: .journey,
        matches: { $0.normalized.hasPrefix("journey") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.statements(source)
            let parsed = try parseJourneyDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .journey(parsed))
        },
        layout: { graph, _ in
            guard case let .journey(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.journey)
            }
            let config = parsed.config ?? .default
            let positioned = layoutJourneyDiagram(parsed, options: RenderOptions(), config: config)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .journey(positioned))
        }
    )

    // -- sequenceDiagram --

    static let _sequenceDiagram = DiagramDescriptor(
        type: .sequenceDiagram,
        matches: { $0.normalized.hasPrefix("sequencediagram") },
        parse: { source, _ in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            let parsed = try parseSequenceDiagram(lines)
            return MermaidGraph(payload: .sequenceDiagram(parsed))
        },
        layout: { graph, _ in
            guard case let .sequenceDiagram(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.sequenceDiagram)
            }
            let positioned = try layoutSequenceDiagram(parsed)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .sequenceDiagram(
                actors: positioned.actors, messages: positioned.messages,
                blocks: positioned.blocks, lifelines: positioned.lifelines,
                activations: positioned.activations, notes: positioned.notes,
                boxes: positioned.boxes, bottomActors: positioned.bottomActors,
                rectHighlights: positioned.rectHighlights,
                title: positioned.title, accTitle: positioned.accTitle, accDescr: positioned.accDescr
            ))
        }
    )

    // -- classDiagram --

    static let _classDiagram = DiagramDescriptor(
        type: .classDiagram,
        matches: { $0.normalized.hasPrefix("classdiagram") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            let parsed = try parseClassDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .classDiagram(parsed))
        },
        layout: { graph, _ in
            guard case let .classDiagram(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.classDiagram)
            }
            let positioned = try layoutClassDiagramSync(parsed)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .classDiagram(
                classes: positioned.classes, relationships: positioned.relationships,
                namespaces: positioned.namespaces, notes: positioned.notes,
                accTitle: positioned.accTitle, accDescr: positioned.accDescription,
                diagramTitle: positioned.diagramTitle
            ))
        }
    )

    // -- erDiagram --

    static let _erDiagram = DiagramDescriptor(
        type: .erDiagram,
        matches: { $0.normalized.hasPrefix("erdiagram") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            let parsed = try parseErDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .erDiagram(parsed))
        },
        layout: { graph, _ in
            guard case let .erDiagram(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.erDiagram)
            }
            let positioned = try layoutErDiagramSync(parsed, config: parsed.config)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .erDiagram(
                entities: positioned.entities, relationships: positioned.relationships,
                accTitle: positioned.accTitle, accDescr: positioned.accDescr,
                diagramTitle: positioned.diagramTitle
            ))
        }
    )

    // -- xyChart --

    static let _xyChart = DiagramDescriptor(
        type: .xyChart,
        matches: { $0.normalized.hasPrefix("xychart") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            var chart = try parseXYChart(lines)
            if let fm = frontmatter {
                chart.config = fm.xyChartConfig
                chart.theme = fm.xyChartTheme
                if chart.titleText == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .xyChart(chart))
        },
        layout: { graph, _ in
            guard case let .xyChart(chart) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.xyChart)
            }
            let positioned = layoutXYChart(chart)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .xyChart(positioned))
        }
    )

    // -- pie --

    static let _pie = DiagramDescriptor(
        type: .pie,
        matches: { $0.normalized.hasPrefix("pie") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            var chart = try parsePieChart(lines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.pieConfig { chart.config = cfg }
                if let theme = fm.pieTheme { chart.theme = theme }
                if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .pie(chart))
        },
        layout: { graph, _ in
            guard case let .pie(chart) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.pie)
            }
            let positioned = layoutPieChart(chart)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .pie(positioned))
        }
    )

    // -- gantt --

    static let _gantt = DiagramDescriptor(
        type: .gantt,
        matches: { $0.normalized.hasPrefix("gantt") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.statements(source, separators: CharacterSet(charactersIn: "\n"))
            let parsed = try parseGanttDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .gantt(parsed))
        },
        layout: { graph, _ in
            guard case let .gantt(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.gantt)
            }
            let config = parsed.config ?? .default
            var merged = parsed
            merged.config = config
            let positioned = layoutGanttDiagram(merged)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .gantt(positioned))
        }
    )

    // -- quadrantChart --

    static let _quadrantChart = DiagramDescriptor(
        type: .quadrantChart,
        matches: { $0.normalized.hasPrefix("quadrantchart") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            var chart = try parseQuadrantChart(lines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.quadrantChartConfig { chart.config = cfg }
                if let theme = fm.quadrantChartTheme { chart.theme = theme }
                if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            if chart.titleText == nil, let dt = chart.diagramTitle { chart.titleText = dt }
            return MermaidGraph(payload: .quadrantChart(chart))
        },
        layout: { graph, _ in
            guard case let .quadrantChart(chart) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.quadrantChart)
            }
            let positioned = layoutQuadrantChart(chart)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .quadrantChart(positioned))
        }
    )

    // -- gitGraph --

    static let _gitGraph = DiagramDescriptor(
        type: .gitGraph,
        matches: { $0.normalized.hasPrefix("gitgraph") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.statements(source)
            let parsed = try parseGitGraph(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .gitGraph(parsed))
        },
        layout: { graph, _ in
            guard case let .gitGraph(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.gitGraph)
            }
            let positioned = layoutGitGraph(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .gitGraph(positioned))
        }
    )

    // -- requirement --

    static let _requirement = DiagramDescriptor(
        type: .requirement,
        matches: { $0.normalized.hasPrefix("requirement") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.diagramLines(source)
            let diagram = try parseRequirementDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .requirement(diagram))
        },
        layout: { graph, _ in
            guard case let .requirement(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.requirement)
            }
            let positioned = try layoutRequirementDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .requirement(positioned))
        }
    )

    // -- mindmap --

    static let _mindmap = DiagramDescriptor(
        type: .mindmap,
        matches: { $0.normalized.hasPrefix("mindmap") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            let parsed = try parseMindmap(rawLines, frontmatter: frontmatter)
            return MermaidGraph(payload: .mindmap(parsed))
        },
        layout: { graph, _ in
            guard case let .mindmap(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.mindmap)
            }
            let positioned = try layoutMindmap(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .mindmap(positioned))
        }
    )

    // -- timeline --

    static let _timeline = DiagramDescriptor(
        type: .timeline,
        matches: { $0.normalized.hasPrefix("timeline") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            let parsed = try parseTimelineDiagram(rawLines, frontmatter: frontmatter)
            return MermaidGraph(payload: .timeline(parsed))
        },
        layout: { graph, _ in
            guard case let .timeline(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.timeline)
            }
            let positioned = layoutTimelineDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .timeline(positioned))
        }
    )

    // -- sankey --

    static let _sankey = DiagramDescriptor(
        type: .sankey,
        matches: { $0.normalized.hasPrefix("sankey") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.statements(source)
            let parsed = try parseSankeyDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .sankey(parsed))
        },
        layout: { graph, _ in
            guard case let .sankey(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.sankey)
            }
            let positioned = layoutSankeyDiagram(diagram)
            let padding = positioned.config.useMaxWidth ? 0.0 : 10.0
            return PositionedGraph(
                diagram: graph,
                width: positioned.width + padding * 2,
                height: positioned.height + padding * 2,
                content: .sankey(positioned)
            )
        }
    )

    // -- block --

    static let _block = DiagramDescriptor(
        type: .block,
        matches: { $0.normalized.hasPrefix("block") },
        parse: { source, frontmatter in
            let parsed = try parseBlockDiagram(source, frontmatter: frontmatter)
            return MermaidGraph(payload: .block(parsed))
        },
        layout: { graph, _ in
            guard case let .block(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.block)
            }
            let positioned = try layoutBlockDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .block(positioned))
        }
    )

    // -- packet --

    static let _packet = DiagramDescriptor(
        type: .packet,
        matches: { $0.normalized.hasPrefix("packet") },
        parse: { source, frontmatter in
            let lines = MermaidSourceNormalizer.statements(source)
            let parsed = try parsePacketDiagram(lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .packet(parsed))
        },
        layout: { graph, _ in
            guard case let .packet(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.packet)
            }
            let positioned = layoutPacketDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .packet(positioned))
        }
    )

    // -- kanban --

    static let _kanban = DiagramDescriptor(
        type: .kanban,
        matches: { $0.normalized.hasPrefix("kanban") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            let parsed = try parseKanbanDiagram(rawLines, frontmatter: frontmatter)
            return MermaidGraph(payload: .kanban(parsed))
        },
        layout: { graph, _ in
            guard case let .kanban(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.kanban)
            }
            let positioned = layoutKanbanDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .kanban(positioned))
        }
    )

    // -- architecture --

    static let _architecture = DiagramDescriptor(
        type: .architecture,
        matches: { $0.normalized.hasPrefix("architecture") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseArchitectureDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.archConfig { diagram.config = cfg }
                if let theme = fm.archTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .architecture(diagram))
        },
        layout: { graph, _ in
            guard case let .architecture(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.architecture)
            }
            let positioned = layoutArchitectureDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))
        }
    )

    // -- radar --

    static let _radar = DiagramDescriptor(
        type: .radar,
        matches: { $0.normalized.hasPrefix("radar-beta") },
        parse: { source, frontmatter in
            var diagram = try parseRadarDiagram(source: source, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.radarConfig { diagram.config = cfg }
                if let theme = fm.radarTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .radar(diagram))
        },
        layout: { graph, _ in
            guard case let .radar(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.radar)
            }
            let positioned = layoutRadarDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .radar(positioned))
        }
    )

    // -- treemap --

    static let _treemap = DiagramDescriptor(
        type: .treemap,
        matches: { $0.normalized.hasPrefix("treemap") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseTreemapDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.treemapConfig { diagram.config = cfg }
                if let theme = fm.theme { diagram.themeName = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .treemap(diagram))
        },
        layout: { graph, _ in
            guard case let .treemap(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.treemap)
            }
            let positioned = layoutTreemapDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .treemap(positioned))
        }
    )

    // -- venn --

    static let _venn = DiagramDescriptor(
        type: .venn,
        matches: { $0.normalized.hasPrefix("venn-beta") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseVennDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.vennConfig { diagram.config = cfg }
                if let theme = fm.theme { diagram.themeName = theme }
                if let tv = fm.vennThemeVariables { diagram.themeVariables = tv }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .venn(diagram))
        },
        layout: { graph, _ in
            guard case let .venn(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.venn)
            }
            let positioned = layoutVennDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .venn(positioned))
        }
    )

    // -- ishikawa --

    static let _ishikawa = DiagramDescriptor(
        type: .ishikawa,
        matches: { header in
            _isIshikawaDiagramHeader(header.raw)
        },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            let diagram = try parseIshikawaDiagram(rawLines, frontmatter: frontmatter)
            return MermaidGraph(payload: .ishikawa(diagram))
        },
        layout: { graph, _ in
            guard case let .ishikawa(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.ishikawa)
            }
            let positioned = layoutIshikawaDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .ishikawa(positioned))
        }
    )

    // -- treeView --

    static let _treeView = DiagramDescriptor(
        type: .treeView,
        matches: { header in
            _isTreeViewHeader(rawLines: header.rawLines)
        },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseTreeViewDiagram(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.treeViewConfig { diagram.config = cfg }
                if let theme = fm.treeViewTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .treeView(diagram))
        },
        layout: { graph, _ in
            guard case let .treeView(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.treeView)
            }
            let positioned = layoutTreeViewDiagram(diagram)
            return PositionedGraph(diagram: graph, width: positioned.viewBoxWidth, height: positioned.viewBoxHeight, content: .treeView(positioned))
        }
    )

    // -- eventModeling --

    static let _eventModeling = DiagramDescriptor(
        type: .eventModeling,
        matches: { $0.normalized.hasPrefix("eventmodeling") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseEventModeling(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.eventmodelingConfig { diagram.config = cfg }
                if let theme = fm.eventmodelingThemeVariables { diagram.themeVariables = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .eventModeling(diagram))
        },
        layout: { graph, _ in
            guard case let .eventModeling(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.eventModeling)
            }
            let positioned = layoutEventModeling(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .eventModeling(positioned))
        }
    )

    // -- wardley --

    static let _wardley = DiagramDescriptor(
        type: .wardleyBeta,
        matches: { $0.normalized.hasPrefix("wardley-beta") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            var diagram = try parseWardleyMap(rawLines, frontmatter: frontmatter)
            if let fm = frontmatter {
                if let cfg = fm.wardleyBetaConfig { diagram.config = cfg }
                if let theme = fm.wardleyTheme { diagram.theme = theme }
                if diagram.diagramTitle == nil, let fmTitle = fm.diagramTitle { diagram.diagramTitle = fmTitle }
            }
            return MermaidGraph(payload: .wardleyBeta(diagram))
        },
        layout: { graph, _ in
            guard case let .wardleyBeta(diagram) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.wardleyBeta)
            }
            let positioned = layoutWardleyMap(diagram)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .wardleyBeta(positioned))
        }
    )

    // -- zenuml --

    static let _zenuml = DiagramDescriptor(
        type: .zenuml,
        matches: { $0.normalized.hasPrefix("zenuml") },
        parse: { source, frontmatter in
            let rawLines = MermaidSourceNormalizer.rawLines(source)
            let parsed = try parseZenUMLDiagram(rawLines, frontmatter: frontmatter)
            return MermaidGraph(payload: .zenuml(parsed))
        },
        layout: { graph, _ in
            guard case let .zenuml(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.zenuml)
            }
            let positioned = layoutZenUMLDiagram(parsed)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .zenuml(positioned))
        }
    )

    // -- c4 --

    static let _c4 = DiagramDescriptor(
        type: .c4,
        matches: { $0.raw.range(of: #"^C4(?:Context|Container|Component|Dynamic|Deployment)\s*$"#, options: .regularExpression) != nil },
        parse: { source, frontmatter in
            let c4Lines = MermaidSourceNormalizer.rawLines(source)
            let parsed = try parseC4Diagram(c4Lines, frontmatter: frontmatter)
            return MermaidGraph(payload: .c4(parsed))
        },
        layout: { graph, _ in
            guard case let .c4(parsed) = graph.payload else {
                throw MermaidStructuralError.payloadMismatch(.c4)
            }
            let positioned = layoutC4Diagram(parsed)
            return PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .c4(positioned))
        }
    )

    // -- stateDiagram (must come before flowchart) --

    static let _stateDiagram = DiagramDescriptor(
        type: .stateDiagram,
        matches: { $0.normalized.hasPrefix("statediagram") || $0.normalized == "state" },
        parse: { source, frontmatter in
            let parsed = try parseMermaid(source, config: frontmatter?.flowchartConfig, stateConfig: frontmatter?.stateConfig)
            switch parsed.payload {
            case .flowchart(let model), .stateDiagram(let model):
                return MermaidGraph(payload: .stateDiagram(model))
            default:
                return parsed
            }
        },
        layout: { graph, config in
            try layoutGraphSync(graph, config: config)
        }
    )

    // -- flowchart (fallback) --

    static let _flowchart = DiagramDescriptor(
        type: .flowchart,
        matches: { _ in true },  // catches everything
        parse: { source, frontmatter in
            let parsed = try parseMermaid(source, config: frontmatter?.flowchartConfig, stateConfig: frontmatter?.stateConfig)
            switch parsed.payload {
            case .flowchart(let model), .stateDiagram(let model):
                return MermaidGraph(payload: .flowchart(model))
            default:
                return parsed
            }
        },
        layout: { graph, config in
            try layoutGraphSync(graph, config: config)
        }
    )
}

// MARK: - Error type for payload mismatches

public struct MermaidStructuralError: Error, LocalizedError {
    public let expectedType: DiagramType

    public static func payloadMismatch(_ type: DiagramType) -> MermaidStructuralError {
        MermaidStructuralError(expectedType: type)
    }

    public var errorDescription: String? {
        "MermaidStructuralError: expected payload of type \(expectedType.rawValue)"
    }
}

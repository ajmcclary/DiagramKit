import Foundation
import DiagramKitCommon

// MARK: - Core Model Types

public struct TreemapDiagram: Sendable, Equatable {
    public var nodes: [TreemapNode]
    public var classDefs: [TreemapClassDef]
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: TreemapDiagramConfig
    public var themeName: String?
    public var themeVariables: [String: String]?

    public init(
        nodes: [TreemapNode] = [],
        classDefs: [TreemapClassDef] = [],
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: TreemapDiagramConfig = .default,
        themeName: String? = nil,
        themeVariables: [String: String]? = nil
    ) {
        self.nodes = nodes
        self.classDefs = classDefs
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.themeName = themeName
        self.themeVariables = themeVariables
    }
}

public struct TreemapNode: Sendable, Equatable {
    public var name: String
    public var children: [TreemapNode]?
    public var value: Double?
    public var classSelector: String?
    public var cssCompiledStyles: [String]?
    public var cssCompiledTextStyles: [String]?
    public var x0: Double?
    public var x1: Double?
    public var y0: Double?
    public var y1: Double?

    public init(
        name: String,
        children: [TreemapNode]? = nil,
        value: Double? = nil,
        classSelector: String? = nil,
        cssCompiledStyles: [String]? = nil,
        cssCompiledTextStyles: [String]? = nil
    ) {
        self.name = name
        self.children = children
        self.value = value
        self.classSelector = classSelector
        self.cssCompiledStyles = cssCompiledStyles
        self.cssCompiledTextStyles = cssCompiledTextStyles
    }

    public var isLeaf: Bool { children == nil && value != nil }
    public var isSection: Bool { children != nil }
    public var hasChildren: Bool { children != nil && !(children?.isEmpty ?? true) }

    public var aggregateValue: Double {
        if let v = value { return v }
        guard let kids = children else { return 0 }
        return kids.reduce(0) { $0 + $1.aggregateValue }
    }
}

public struct TreemapClassDef: Sendable, Equatable {
    public var className: String
    public var styleText: String
    public var styles: [String]
    public var textStyles: [String]

    public init(className: String, styleText: String, styles: [String] = [], textStyles: [String] = []) {
        self.className = className
        self.styleText = styleText
        self.styles = styles
        self.textStyles = textStyles
    }

    public static func parseStyleText(_ raw: String) -> (nodeStyles: [String], textStyles: [String]) {
        var normalized = raw
        let placeholder = "\u{001A}COMMA\u{001A}"
        normalized = normalized.replacingOccurrences(of: "\\,", with: placeholder)
        normalized = normalized.replacingOccurrences(of: ",", with: ";")
        normalized = normalized.replacingOccurrences(of: placeholder, with: ",")
        let parts = normalized.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        var nodeStyles: [String] = []
        var textStyles: [String] = []

        for part in parts {
            let lower = part.lowercased()
            nodeStyles.append(part)
            if lower.hasPrefix("color:") || lower.hasPrefix("fill:") || lower.hasPrefix("font-size:") || lower.hasPrefix("font-family:") || lower.hasPrefix("font-weight:") || lower.hasPrefix("font-style:") || lower.hasPrefix("text-") {
                textStyles.append(part)
            }
        }

        return (nodeStyles, textStyles)
    }
}

// MARK: - Config

public struct TreemapDiagramConfig: Sendable, Equatable {
    public var useMaxWidth: Bool
    public var padding: Double
    public var diagramPadding: Double
    public var showValues: Bool
    public var nodeWidth: Double
    public var nodeHeight: Double
    public var borderWidth: Double
    public var valueFontSize: Double
    public var labelFontSize: Double
    public var valueFormat: String

    public static let `default` = TreemapDiagramConfig()

    public init(
        useMaxWidth: Bool = true,
        padding: Double = 10,
        diagramPadding: Double = 8,
        showValues: Bool = true,
        nodeWidth: Double = 100,
        nodeHeight: Double = 40,
        borderWidth: Double = 1,
        valueFontSize: Double = 12,
        labelFontSize: Double = 14,
        valueFormat: String = ","
    ) {
        self.useMaxWidth = useMaxWidth
        self.padding = padding
        self.diagramPadding = diagramPadding
        self.showValues = showValues
        self.nodeWidth = nodeWidth
        self.nodeHeight = nodeHeight
        self.borderWidth = borderWidth
        self.valueFontSize = valueFontSize
        self.labelFontSize = labelFontSize
        self.valueFormat = valueFormat
    }
}

// MARK: - Style Options

public struct TreemapStyleOptions: Sendable, Equatable {
    public var sectionStrokeColor: String
    public var sectionStrokeWidth: String
    public var sectionFillColor: String
    public var leafStrokeColor: String
    public var leafStrokeWidth: String
    public var leafFillColor: String
    public var labelColor: String?
    public var labelFontSize: String
    public var valueFontSize: String
    public var valueColor: String?
    public var titleColor: String?
    public var titleFontSize: String

    public static let `default` = TreemapStyleOptions()

    public init(
        sectionStrokeColor: String = "black",
        sectionStrokeWidth: String = "1",
        sectionFillColor: String = "#efefef",
        leafStrokeColor: String = "black",
        leafStrokeWidth: String = "1",
        leafFillColor: String = "#efefef",
        labelColor: String? = nil,
        labelFontSize: String = "12px",
        valueFontSize: String = "10px",
        valueColor: String? = nil,
        titleColor: String? = nil,
        titleFontSize: String = "14px"
    ) {
        self.sectionStrokeColor = sectionStrokeColor
        self.sectionStrokeWidth = sectionStrokeWidth
        self.sectionFillColor = sectionFillColor
        self.leafStrokeColor = leafStrokeColor
        self.leafStrokeWidth = leafStrokeWidth
        self.leafFillColor = leafFillColor
        self.labelColor = labelColor
        self.labelFontSize = labelFontSize
        self.valueFontSize = valueFontSize
        self.valueColor = valueColor
        self.titleColor = titleColor
        self.titleFontSize = titleFontSize
    }
}

// MARK: - Positioned Model

public struct PositionedTreemapDiagram: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public var svgWidth: Double
    public var svgHeight: Double
    public var titleHeight: Double
    public var title: PositionedTreemapTitle?
    public var sections: [PositionedTreemapSection]
    public var leaves: [PositionedTreemapLeaf]
    public var diagramPadding: Double
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: TreemapDiagramConfig
    public var themeName: String?
    public var themeVariables: [String: String]?

    public static var empty: PositionedTreemapDiagram {
        PositionedTreemapDiagram(
            width: 1000, height: 400, svgWidth: 1000, svgHeight: 400,
            titleHeight: 0, title: nil, sections: [], leaves: [],
            diagramPadding: 8, accTitle: nil, accDescr: nil, diagramTitle: nil,
            config: .default
        )
    }

    public init(
        width: Double, height: Double, svgWidth: Double, svgHeight: Double,
        titleHeight: Double, title: PositionedTreemapTitle?,
        sections: [PositionedTreemapSection], leaves: [PositionedTreemapLeaf],
        diagramPadding: Double, accTitle: String?, accDescr: String?,
        diagramTitle: String?, config: TreemapDiagramConfig,
        themeName: String? = nil, themeVariables: [String: String]? = nil
    ) {
        self.width = width
        self.height = height
        self.svgWidth = svgWidth
        self.svgHeight = svgHeight
        self.titleHeight = titleHeight
        self.title = title
        self.sections = sections
        self.leaves = leaves
        self.diagramPadding = diagramPadding
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
        self.themeName = themeName
        self.themeVariables = themeVariables
    }
}

public struct PositionedTreemapTitle: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double

    public init(text: String, x: Double, y: Double) {
        self.text = text
        self.x = x
        self.y = y
    }
}

public struct PositionedTreemapSection: Sendable, Equatable {
    public var index: Int
    public var name: String
    public var depth: Int
    public var x0: Double; public var y0: Double
    public var x1: Double; public var y1: Double
    public var fillColor: String
    public var strokeColor: String
    public var labelColor: String
    public var cssCompiledStyles: [String]?
    public var classSelector: String?
    public var label: PositionedTreemapText?
    public var value: PositionedTreemapText?
    public var clipId: String
    public var aggregateValue: Double
    public var formattedValue: String?
}

public struct PositionedTreemapLeaf: Sendable, Equatable {
    public var index: Int
    public var name: String
    public var x0: Double; public var y0: Double
    public var x1: Double; public var y1: Double
    public var fillColor: String
    public var strokeColor: String
    public var labelColor: String
    public var value: Double?
    public var formattedValue: String?
    public var cssCompiledStyles: [String]?
    public var classSelector: String?
    public var label: PositionedTreemapText?
    public var valueText: PositionedTreemapText?
    public var clipId: String
}

public struct PositionedTreemapText: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double
    public var fontSize: Double
    public var fontWeight: String?
    public var fontStyle: String?
    public var textAnchor: String
    public var dominantBaseline: String
    public var fillColor: String
    public var clipId: String?
    public var hidden: Bool

    public init(
        text: String, x: Double, y: Double, fontSize: Double,
        fontWeight: String? = nil, fontStyle: String? = nil,
        textAnchor: String = "start",
        dominantBaseline: String = "middle",
        fillColor: String = "#000000",
        clipId: String? = nil, hidden: Bool = false
    ) {
        self.text = text
        self.x = x
        self.y = y
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.fontStyle = fontStyle
        self.textAnchor = textAnchor
        self.dominantBaseline = dominantBaseline
        self.fillColor = fillColor
        self.clipId = clipId
        self.hidden = hidden
    }
}

// MARK: - Parser Errors

public enum TreemapParserError: Error, LocalizedError, _MermaidRecoverableError {
    case invalidHeader(String)
    case missingLabel(String)
    case invalidValue(String, String)
    case invalidStatement(String)
    case emptySource

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let h): return "Invalid treemap header: \(h)"
        case .missingLabel(let s): return "Missing label in treemap statement: \(s)"
        case .invalidValue(let label, let value): return "Invalid treemap value '\(value)' for '\(label)'"
        case .invalidStatement(let s): return "Invalid treemap statement: \(s)"
        case .emptySource: return "Treemap source is empty"
        }
    }
}

// MARK: - Theme defaults for treemap color scales

public enum TreemapThemeDefaults {
    public static let defaultCScale: [String] = [
        "transparent",
        "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728",
        "#9467bd", "#8c564b", "#e377c2", "#7f7f7f",
        "#bcbd22", "#17becf", "#aec7e8", "#ff9896"
    ]

    public static let defaultCScalePeer: [String] = [
        "transparent",
        "#0d4a6c", "#944b08", "#1a6a1a", "#8a1719",
        "#5c3a75", "#54332a", "#8a4070", "#4a4a4a",
        "#6b6e12", "#0d7078", "#667b8e", "#c97580"
    ]

    public static let defaultCScaleLabel: [String] = [
        "#ffffff", "#ffffff", "#ffffff", "#ffffff",
        "#ffffff", "#ffffff", "#ffffff", "#ffffff",
        "#ffffff", "#000000", "#000000", "#000000"
    ]
}

public func _treemapStyleMap(_ styles: [String]?) -> [String: String] {
    guard let styles else { return [:] }
    var result: [String: String] = [:]
    for style in styles {
        guard let colon = style.firstIndex(of: ":") else { continue }
        let key = style[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let value = style[style.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard _treemapAllowedStyleProperties.contains(key), _treemapIsSafeStyleValue(value) else { continue }
        result[key] = value
    }
    return result
}

public func _treemapStyleDeclarations(_ styles: [String]?, text: Bool = false) -> [String] {
    _treemapStyleMap(styles)
        .compactMap { key, value -> String? in
            let property = text && key == "color" ? "fill" : key
            guard !text || _treemapAllowedTextStyleProperties.contains(property) else { return nil }
            return "\(property):\(value)"
        }
        .sorted()
}

private let _treemapAllowedStyleProperties: Set<String> = [
    "fill", "stroke", "stroke-width", "stroke-dasharray", "color",
    "font-size", "font-family", "font-weight", "font-style",
    "opacity", "fill-opacity", "stroke-opacity"
]

private let _treemapAllowedTextStyleProperties: Set<String> = [
    "fill", "font-size", "font-family", "font-weight", "font-style", "opacity"
]

private func _treemapIsSafeStyleValue(_ value: String) -> Bool {
    let lower = value.lowercased()
    if lower.contains("url(") || lower.contains("javascript:") || lower.contains("data:") || lower.contains("expression(") {
        return false
    }
    return !value.contains("\"") && !value.contains("'") && !value.contains("<") && !value.contains(">")
}

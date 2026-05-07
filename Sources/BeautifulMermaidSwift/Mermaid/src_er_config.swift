// ErDiagramConfig — Mermaid ER-specific configuration matching ErDiagramConfig from config.type.ts
import Foundation

public enum ErDirection: String, Sendable, CaseIterable {
    case tb = "TB"
    case bt = "BT"
    case lr = "LR"
    case rl = "RL"
}

public struct ErDiagramConfig: Sendable {
    public var titleTopMargin: Double?
    public var diagramPadding: Double?
    public var layoutDirection: ErDirection?
    public var minEntityWidth: Double?
    public var minEntityHeight: Double?
    public var entityPadding: Double?
    public var nodeSpacing: Double?
    public var rankSpacing: Double?
    public var stroke: String?
    public var fill: String?
    public var fontSize: Double?
    public var useMaxWidth: Bool?
    public var layout: String?
    public var look: String?
    public var htmlLabels: Bool?
    public var erEdgeLabelBackground: String?

    public init(
        titleTopMargin: Double? = nil,
        diagramPadding: Double? = nil,
        layoutDirection: ErDirection? = nil,
        minEntityWidth: Double? = nil,
        minEntityHeight: Double? = nil,
        entityPadding: Double? = nil,
        nodeSpacing: Double? = nil,
        rankSpacing: Double? = nil,
        stroke: String? = nil,
        fill: String? = nil,
        fontSize: Double? = nil,
        useMaxWidth: Bool? = nil,
        layout: String? = nil,
        look: String? = nil,
        htmlLabels: Bool? = nil,
        erEdgeLabelBackground: String? = nil
    ) {
        self.titleTopMargin = titleTopMargin
        self.diagramPadding = diagramPadding
        self.layoutDirection = layoutDirection
        self.minEntityWidth = minEntityWidth
        self.minEntityHeight = minEntityHeight
        self.entityPadding = entityPadding
        self.nodeSpacing = nodeSpacing
        self.rankSpacing = rankSpacing
        self.stroke = stroke
        self.fill = fill
        self.fontSize = fontSize
        self.useMaxWidth = useMaxWidth
        self.layout = layout
        self.look = look
        self.htmlLabels = htmlLabels
        self.erEdgeLabelBackground = erEdgeLabelBackground
    }
}

open class original_src_er_config {
    public init() {}
}

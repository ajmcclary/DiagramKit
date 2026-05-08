import Foundation

/// A single packet block as parsed from source, before normalization.
struct RawPacketBlock: Sendable, Equatable {
    var start: Int?
    var end: Int?
    var bits: Int?
    var label: String
}

/// A normalized packet block with all fields populated.
public struct PacketBlock: Sendable, Equatable {
    public var start: Int
    public var end: Int
    public var bits: Int
    public var label: String

    public init(start: Int, end: Int, bits: Int, label: String) {
        self.start = start
        self.end = end
        self.bits = bits
        self.label = label
    }
}

/// One row of the packet diagram (Mermaid's `PacketWord`).
public typealias PacketRow = [PacketBlock]

/// Config for packet diagram layout/rendering.
public struct PacketDiagramConfig: Sendable, Equatable {
    public var rowHeight: Double
    public var bitWidth: Double
    public var bitsPerRow: Int
    public var showBits: Bool
    public var paddingX: Double
    public var paddingY: Double
    public var useMaxWidth: Bool

    public init(
        rowHeight: Double = 32,
        bitWidth: Double = 32,
        bitsPerRow: Int = 32,
        showBits: Bool = true,
        paddingX: Double = 5,
        paddingY: Double = 5,
        useMaxWidth: Bool = true
    ) {
        self.rowHeight = rowHeight
        self.bitWidth = bitWidth
        self.bitsPerRow = bitsPerRow
        self.showBits = showBits
        self.paddingX = paddingX
        self.paddingY = paddingY
        self.useMaxWidth = useMaxWidth
    }

    public static let `default` = PacketDiagramConfig()

    public var clampedToMinimums: PacketDiagramConfig {
        PacketDiagramConfig(
            rowHeight: max(1, rowHeight),
            bitWidth: max(1, bitWidth),
            bitsPerRow: max(1, bitsPerRow),
            showBits: showBits,
            paddingX: max(0, paddingX),
            paddingY: max(0, paddingY),
            useMaxWidth: useMaxWidth
        )
    }
}

/// Theme variables for Packet SVG/Core Graphics styling.
public struct PacketThemeConfig: Sendable, Equatable {
    public var byteFontSize: String
    public var startByteColor: String
    public var endByteColor: String
    public var labelColor: String
    public var labelFontSize: String
    public var titleColor: String
    public var titleFontSize: String
    public var blockStrokeColor: String
    public var blockStrokeWidth: String
    public var blockFillColor: String

    public init(
        byteFontSize: String = "10px",
        startByteColor: String = "black",
        endByteColor: String = "black",
        labelColor: String = "black",
        labelFontSize: String = "12px",
        titleColor: String = "black",
        titleFontSize: String = "14px",
        blockStrokeColor: String = "black",
        blockStrokeWidth: String = "1",
        blockFillColor: String = "#efefef"
    ) {
        self.byteFontSize = byteFontSize
        self.startByteColor = startByteColor
        self.endByteColor = endByteColor
        self.labelColor = labelColor
        self.labelFontSize = labelFontSize
        self.titleColor = titleColor
        self.titleFontSize = titleFontSize
        self.blockStrokeColor = blockStrokeColor
        self.blockStrokeWidth = blockStrokeWidth
        self.blockFillColor = blockFillColor
    }

    public static let `default` = PacketThemeConfig()
}

/// The parsed and validated packet diagram model.
public struct PacketDiagram: Sendable, Equatable {
    public var rows: [PacketRow]
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: PacketDiagramConfig
    public var theme: PacketThemeConfig

    public init(
        rows: [PacketRow] = [],
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: PacketDiagramConfig = .default,
        theme: PacketThemeConfig = .default
    ) {
        self.rows = rows
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
    }

    public static let empty = PacketDiagram()
}

/// A positioned block within a packet row, ready for rendering.
public struct PositionedPacketBlock: Sendable, Equatable {
    public var start: Int
    public var end: Int
    public var bits: Int
    public var label: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(start: Int, end: Int, bits: Int, label: String, x: Double, y: Double, width: Double, height: Double) {
        self.start = start
        self.end = end
        self.bits = bits
        self.label = label
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// A positioned row of packet blocks.
public typealias PositionedPacketRow = [PositionedPacketBlock]

/// The fully laid-out packet diagram.
public struct PositionedPacketDiagram: Sendable, Equatable {
    public var rows: [PositionedPacketRow]
    public var width: Double
    public var height: Double
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: PacketDiagramConfig
    public var theme: PacketThemeConfig

    public init(
        rows: [PositionedPacketRow] = [],
        width: Double = 0,
        height: Double = 0,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: PacketDiagramConfig = .default,
        theme: PacketThemeConfig = .default
    ) {
        self.rows = rows
        self.width = width
        self.height = height
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
    }

    public static let empty = PositionedPacketDiagram()
}

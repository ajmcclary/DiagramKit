import Foundation

public let packetBitLabelBandHeight = 16.0
public let packetBitLabelGapAboveBlock = 5.0

public func packetEffectivePaddingY(_ config: PacketDiagramConfig) -> Double {
    config.paddingY + (config.showBits ? packetBitLabelBandHeight : 0)
}

public func packetBitLabelY(forBlockY blockY: Double) -> Double {
    blockY - packetBitLabelGapAboveBlock
}

public func layoutPacketDiagram(_ diagram: PacketDiagram) -> PositionedPacketDiagram {
    let config = diagram.config
    let rows = diagram.rows

    let effectivePaddingY = packetEffectivePaddingY(config)
    let rowHeightTotal = config.rowHeight + effectivePaddingY
    let diagramWidth = config.bitWidth * Double(config.bitsPerRow) + 2
    let rowCount = rows.count
    let visibleRowCount = max(rowCount, 1)
    let diagramHeight = rowHeightTotal * Double(visibleRowCount + 1)
        - (diagram.diagramTitle != nil ? 0 : config.rowHeight)

    var positionedRows: [PositionedPacketRow] = []

    for (rowIndex, row) in rows.enumerated() {
        let wordY = Double(rowIndex) * rowHeightTotal + effectivePaddingY
        var positionedBlocks: PositionedPacketRow = []

        for block in row {
            let blockX = Double(block.start % config.bitsPerRow) * config.bitWidth + 1
            let blockWidth = Double(block.end - block.start + 1) * config.bitWidth - config.paddingX

            positionedBlocks.append(PositionedPacketBlock(
                start: block.start,
                end: block.end,
                bits: block.bits,
                label: block.label,
                x: blockX,
                y: wordY,
                width: blockWidth,
                height: config.rowHeight
            ))
        }

        positionedRows.append(positionedBlocks)
    }

    return PositionedPacketDiagram(
        rows: positionedRows,
        width: diagramWidth,
        height: diagramHeight,
        diagramTitle: diagram.diagramTitle,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        config: config,
        theme: diagram.theme
    )
}

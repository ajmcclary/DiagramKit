//
//  PlatformParityMatrix.swift
//  DiagramPlayground
//
//  Data for the Settings ▸ Platform Parity table (transcription §5.5).
//

import Foundation

enum PlatformParityMatrix {
    static let columns = ["macOS", "iOS", "Linux"]

    static var rows: [ParityTable.Row] {
        [
            .init(feature: "Parse & layout", cells: [.full, .full, .full]),
            .init(feature: "SVG render", cells: [.full, .full, .partial]),
            .init(feature: "Image render", mono: "CG", cells: [.full, .full, .unsupported]),
            .init(feature: "ASCII render", cells: [.full, .full, .full]),
            .init(feature: "Interactive edit", cells: [.full, .full, .unsupported]),
            .init(feature: "Local LSP", cells: [.full, .unsupported, .unsupported]),
        ]
    }
}

// Ported from original/src/ascii/multiline-utils.ts
import DiagramKitCommon
import Foundation

public func splitLines(_ label: String) -> [String] {
    label.components(separatedBy: "\n")
}

public func maxLineWidth(_ label: String) -> Int {
    let lines = splitLines(label)
    return lines.map { terminalDisplayWidth($0) }.max() ?? 0
}

public func lineCount(_ label: String) -> Int {
    splitLines(label).count
}


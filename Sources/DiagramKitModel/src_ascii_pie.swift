// ASCII renderer for pie charts.
//
// Pie chart rendering doesn't need the canvas/layout machinery used
// by flowcharts and sequence diagrams; a tabular list of slices with
// horizontal value bars carries the same information as the SVG
// pie. Output is deterministic given the parsed `PieChart` payload.
import Foundation

public func renderPieAscii(_ chart: PieChart) -> String {
    let total = chart.sections.reduce(0.0) { $0 + $1.value }

    var lines: [String] = []
    if let title = chart.diagramTitle, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: max(title.count, 1)))
    }

    guard !chart.sections.isEmpty, total > 0 else {
        return lines.joined(separator: "\n")
    }

    let maxLabelWidth = chart.sections.map(\.label.count).max() ?? 0
    let valueColumnWidth = chart.sections
        .map { String(format: "%g", $0.value).count }
        .max() ?? 1

    for slice in chart.sections {
        let percent = slice.value / total * 100
        // Bar width: 0–50 columns, scaled by percent.
        let barWidth = Int((percent / 2.0).rounded())
        let bar = String(repeating: "#", count: max(0, barWidth))
        let paddedLabel = slice.label.padding(
            toLength: maxLabelWidth,
            withPad: " ",
            startingAt: 0
        )
        let valueText = String(format: "%g", slice.value)
        let paddedValue = String(
            repeating: " ",
            count: max(0, valueColumnWidth - valueText.count)
        ) + valueText
        let pctText = String(format: "%5.1f", percent)
        lines.append("\(paddedLabel) | \(paddedValue) | \(bar) \(pctText)%")
    }

    return lines.joined(separator: "\n")
}

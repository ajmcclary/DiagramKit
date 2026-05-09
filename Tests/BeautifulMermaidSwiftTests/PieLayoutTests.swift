import XCTest
@testable import BeautifulMermaid

final class PieLayoutTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    // MARK: - Arc filtering

    func testLowPercentageFiltered() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 100\n\"B\": 1"))
        let positioned = layoutPieChart(chart)

        // B should be filtered (<1%)
        let labels = positioned.arcs.map(\.label)
        XCTAssertTrue(labels.contains("A"), "A should be present")
        XCTAssertFalse(labels.contains("B"), "B should be filtered as <1%")
    }

    func testZeroPercentFiltered() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 10000\n\"B\": 1"))
        let positioned = layoutPieChart(chart)

        // B should be filtered (rounds to 0%)
        let labels = positioned.arcs.map(\.label)
        XCTAssertFalse(labels.contains("B"), "B should be filtered as 0%")
    }

    // MARK: - Legend

    func testAllSectionsInLegend() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 100\n\"B\": 0"))
        let positioned = layoutPieChart(chart)

        let legendLabels = positioned.legend.map(\.label)
        XCTAssertEqual(legendLabels, ["A", "B"])
    }

    func testLegendSwatchAtOrigin() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 100\n\"B\": 50"))
        let positioned = layoutPieChart(chart)

        for entry in positioned.legend {
            XCTAssertEqual(entry.swatchX, 0, "Swatch x should be 0 (group-local)")
            XCTAssertEqual(entry.swatchY, 0, "Swatch y should be 0 (matches Mermaid rect position)")
        }
    }

    // MARK: - Color indexing

    func testColorDomainStability() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 100\n\"B\": 1\n\"C\": 50\n\"D\": 50"))
        let positioned = layoutPieChart(chart)

        // B is hidden, but D should still be color[3]
        let arcs = positioned.arcs
        if let dArc = arcs.first(where: { $0.label == "D" }) {
            XCTAssertEqual(dArc.fillColorIndex, 3, "D should keep index 3 even when B is hidden")
        } else {
            XCTFail("D arc should exist")
        }
    }

    func testColorWrappingBeyond12() throws {
        var source = "pie\n"
        for i in 1...14 {
            source += "\"S\(i)\": \(i * 10)\n"
        }
        let chart = try parsePieChart(lines(String(source.dropLast())))
        let positioned = layoutPieChart(chart)

        // 13th section should get color index 12 % 12 = 0 (pie1)
        let s13 = positioned.arcs.first(where: { $0.label == "S13" })
        XCTAssertNotNil(s13)
        XCTAssertEqual(s13?.fillColorIndex, 12, "13th section (index 12) should wrap to pie1-style color")

        let s14 = positioned.arcs.first(where: { $0.label == "S14" })
        XCTAssertNotNil(s14)
        XCTAssertEqual(s14?.fillColorIndex, 13, "14th section (index 13) should wrap to pie2-style color")

        // Verify legend entries have the right color indexes
        let s13Legend = positioned.legend.first(where: { $0.label == "S13" })
        XCTAssertEqual(s13Legend?.colorIndex, 12)

        let s14Legend = positioned.legend.first(where: { $0.label == "S14" })
        XCTAssertEqual(s14Legend?.colorIndex, 13)
    }

    // MARK: - Source order

    func testArcsInSourceOrder() throws {
        let chart = try parsePieChart(lines("pie\n\"C\": 100\n\"A\": 100\n\"B\": 100"))
        let positioned = layoutPieChart(chart)

        let labels = positioned.arcs.map(\.label)
        XCTAssertEqual(labels, ["C", "A", "B"])
    }

    // MARK: - Percentage labels

    func testWholePercentLabels() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 60\n\"B\": 40"))
        let positioned = layoutPieChart(chart)

        let pctLabels = Set(positioned.sliceLabels.map(\.text))
        XCTAssertTrue(pctLabels.contains("60%") || pctLabels.contains("60%".replacingOccurrences(of: "%", with: "")))
    }

    // MARK: - showData legend

    func testShowDataLegend() throws {
        let chart = try parsePieChart(lines("pie showData\n\"A\": 60\n\"B\": 40"))
        let positioned = layoutPieChart(chart)

        let displayTexts = positioned.legend.map(\.displayText)
        XCTAssertTrue(displayTexts.contains(where: { $0.contains("[60]") }))
    }

    // MARK: - viewBox

    func testViewBoxForTitle() throws {
        let chart = try parsePieChart(lines("pie title A Very Long Title That Should Expand The ViewBox\n\"A\": 100"))
        let positioned = layoutPieChart(chart)

        // viewBox width should expand to accommodate title
        XCTAssertGreaterThan(positioned.width, 450)
    }

    func testLongTitleStoresNegativeViewBoxOrigin() throws {
        let title = String(repeating: "Long title ", count: 20)
        let chart = try parsePieChart(lines("pie title \(title)\n\"A\": 100"))
        let positioned = layoutPieChart(chart)

        XCTAssertLessThan(positioned.viewBoxX, 0)
        XCTAssertGreaterThan(positioned.width, 450)
    }

    func testViewBoxForWideLegend() throws {
        let chart = try parsePieChart(lines("pie showData\n\"A Very Long Label Name\": 100\n\"Another Long Label\": 50"))
        let positioned = layoutPieChart(chart)

        // viewBox width should expand to accommodate legend text
        XCTAssertGreaterThan(positioned.width, 450)
    }

    // MARK: - textPosition

    func testTextPositionCloserToCenter() throws {
        let chart1 = try parsePieChart(lines("pie\n\"A\": 100"))
        let cfg1 = PieChartConfig(textPosition: 0.5)
        let chart1WithConfig = PieChart(
            sections: chart1.sections,
            config: cfg1,
            theme: chart1.theme
        )
        let positioned1 = layoutPieChart(chart1WithConfig)

        let chart2 = try parsePieChart(lines("pie\n\"A\": 100"))
        let cfg2 = PieChartConfig(textPosition: 0.9)
        let chart2WithConfig = PieChart(
            sections: chart2.sections,
            config: cfg2,
            theme: chart2.theme
        )
        let positioned2 = layoutPieChart(chart2WithConfig)

        // Labels at 0.5 should be closer to center than at 0.9
        let d1 = positioned1.sliceLabels.first.map { sqrt($0.x * $0.x + $0.y * $0.y) } ?? 0
        let d2 = positioned2.sliceLabels.first.map { sqrt($0.x * $0.x + $0.y * $0.y) } ?? 0
        XCTAssertLessThan(d1, d2)
    }

    func testTextPositionClampedBelowZero() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 100"))
        let cfg = PieChartConfig(textPosition: -0.5)
        let chartWithConfig = PieChart(
            sections: chart.sections,
            config: cfg,
            theme: chart.theme
        )
        let positioned = layoutPieChart(chartWithConfig)

        // textPosition -0.5 should be clamped to 0 (center)
        let distance = positioned.sliceLabels.first.map { sqrt($0.x * $0.x + $0.y * $0.y) } ?? 0
        XCTAssertEqual(distance, 0.0, accuracy: 0.01, "Negative textPosition should clamp to 0 (center)")
    }

    func testTextPositionClampedAboveOne() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 100"))
        let cfg = PieChartConfig(textPosition: 1.5)
        let chartWithConfig = PieChart(
            sections: chart.sections,
            config: cfg,
            theme: chart.theme
        )
        let positioned = layoutPieChart(chartWithConfig)

        // textPosition 1.5 should be clamped to 1.0 (edge)
        let radius = min(450.0, 450.0) / 2 - 40  // = 185
        let distance = positioned.sliceLabels.first.map { sqrt($0.x * $0.x + $0.y * $0.y) } ?? 0
        XCTAssertEqual(distance, radius, accuracy: 0.01, "textPosition >1 should clamp to 1.0 (edge)")
    }

    // MARK: - Zero-sum edge cases

    func testZeroSumNoArcs() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 0\n\"B\": 0"))
        let positioned = layoutPieChart(chart)

        XCTAssertEqual(positioned.arcs.count, 0)
        XCTAssertEqual(positioned.sliceLabels.count, 0)
        XCTAssertEqual(positioned.legend.count, 2)
        XCTAssertGreaterThan(positioned.width, 450, "Zero-sum charts still render a legend, so the viewBox must expand to fit it")
    }

    func testNoSections() throws {
        let chart = try parsePieChart(lines("pie"))
        let positioned = layoutPieChart(chart)

        XCTAssertEqual(positioned.arcs.count, 0)
        XCTAssertEqual(positioned.legend.count, 0)
        XCTAssertEqual(positioned.width, 450)
    }

    // MARK: - Outer circle

    func testOuterCirclePresent() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 100"))
        let positioned = layoutPieChart(chart)

        XCTAssertEqual(positioned.outerCircle.cx, 0)
        XCTAssertEqual(positioned.outerCircle.cy, 0)
        XCTAssertGreaterThan(positioned.outerCircle.r, 0)
    }

    // MARK: - Title

    func testTitlePresent() throws {
        let chart = try parsePieChart(lines("pie title My Chart\n\"A\": 100"))
        let positioned = layoutPieChart(chart)

        XCTAssertNotNil(positioned.title)
        XCTAssertEqual(positioned.title?.text, "My Chart")
        XCTAssertEqual(positioned.title?.x, 0, "Title x should be 0 in group-local coordinates")
    }

    func testNoTitle() throws {
        let chart = try parsePieChart(lines("pie\n\"A\": 100"))
        let positioned = layoutPieChart(chart)

        XCTAssertNil(positioned.title)
    }

    // MARK: - Accessibility metadata flow-through

    func testAccessibilityFlowThrough() throws {
        let chart = try parsePieChart(lines("pie\naccTitle: AT\naccDescr: AD\n\"A\": 100"))
        let positioned = layoutPieChart(chart)

        XCTAssertEqual(positioned.accTitle, "AT")
        XCTAssertEqual(positioned.accDescr, "AD")
    }
}

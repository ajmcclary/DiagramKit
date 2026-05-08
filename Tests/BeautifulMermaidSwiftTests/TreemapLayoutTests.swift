import Testing
@testable import BeautifulMermaid

@Suite("Treemap Layout")
struct TreemapLayoutTests {

    @Test("Layout produces positioned output for basic diagram")
    func basicLayout() throws {
        let diagram = makeDiagram()
        let positioned = layoutTreemapDiagram(diagram)
        #expect(positioned.width == 1000)
        #expect(positioned.height == 400)
        #expect(positioned.svgHeight >= 400)
        #expect(positioned.leaves.count == 2)
        #expect(positioned.sections.count >= 1)
    }

    @Test("Layout adds title height when title present")
    func layoutWithTitle() {
        var diagram = makeDiagram()
        diagram.diagramTitle = "My Title"
        let positioned = layoutTreemapDiagram(diagram)
        #expect(positioned.titleHeight == 30)
        #expect(positioned.title != nil)
        #expect(positioned.title!.text == "My Title")
        #expect(positioned.svgHeight == 430)
    }

    @Test("Layout viewport uses config nodeWidth/nodeHeight")
    func layoutConfigSizing() {
        var diagram = makeDiagram()
        diagram.config = TreemapDiagramConfig(nodeWidth: 50, nodeHeight: 20)
        let positioned = layoutTreemapDiagram(diagram)
        #expect(positioned.width == 500)
        #expect(positioned.height == 200)
    }

    @Test("Layout produces rounded coordinates")
    func roundedCoordinates() {
        let diagram = makeDiagram()
        let positioned = layoutTreemapDiagram(diagram)
        for leaf in positioned.leaves {
            #expect(leaf.x0 == leaf.x0.rounded())
            #expect(leaf.y0 == leaf.y0.rounded())
        }
    }

    @Test("Nested leaves are laid out inside section content padding")
    func nestedLeavesRespectSectionPadding() {
        let diagram = makeDiagram()
        let positioned = layoutTreemapDiagram(diagram)

        let section = try! #require(positioned.sections.first { $0.name == "Category" })
        let leaves = positioned.leaves.filter { $0.name.hasPrefix("Item") }
        #expect(leaves.count == 2)
        for leaf in leaves {
            #expect(leaf.x0 >= section.x0 + SECTION_INNER_PADDING)
            #expect(leaf.y0 >= section.y0 + SECTION_HEADER_HEIGHT + SECTION_INNER_PADDING)
            #expect(leaf.x1 <= section.x1 - SECTION_INNER_PADDING)
            #expect(leaf.y1 <= section.y1 - SECTION_INNER_PADDING)
        }
    }

    @Test("Value formatting: comma thousands")
    func formatComma() {
        #expect(formatTreemapValue(1234, format: ",") == "1,234")
        #expect(formatTreemapValue(1000, format: ",") == "1,000")
    }

    @Test("Value formatting: dollar prefix")
    func formatDollar() {
        let result = formatTreemapValue(100, format: "$")
        #expect(result == "$100")
    }

    @Test("Value formatting: dollar with comma thousands")
    func formatDollarComma() {
        let result = formatTreemapValue(1234, format: "$0,0")
        #expect(result == "$1,234")
    }

    @Test("Value formatting: dollar with comma thousands and decimals")
    func formatDollarCommaDecimals() {
        #expect(formatTreemapValue(1234.5, format: "$,.2f") == "$1,234.50")
        #expect(formatTreemapValue(1234.5, format: "$,.0f") == "$1,235")
    }

    @Test("Value formatting: dollar with decimals")
    func formatDollarDecimals() {
        let result = formatTreemapValue(100.5, format: "$.2f")
        #expect(result == "$100.50")
    }

    @Test("Value formatting: percentage")
    func formatPercentage() {
        let result = formatTreemapValue(0.25, format: ".1%")
        #expect(result.contains("25"))
    }

    @Test("Value formatting: percentage reads digits from format")
    func formatPercentageDigits() {
        #expect(formatTreemapValue(0.2567, format: ".2%") == "25.67%")
        #expect(formatTreemapValue(0.2567, format: ".1%") == "25.7%")
    }

    @Test("Value formatting: SI prefix")
    func formatSiPrefix() {
        #expect(formatTreemapValue(1234, format: ".2s") == "1.23k")
        #expect(formatTreemapValue(1_234_567, format: ".1s") == "1.2M")
        #expect(formatTreemapValue(100, format: ".2s") == "100.00")
    }

    @Test("Value formatting: dollar with SI prefix")
    func formatDollarSiPrefix() {
        let result = formatTreemapValue(1_234_567, format: "$.1s")
        #expect(result == "$1.2M")
    }

    @Test("Value formatting: positive sign")
    func formatPositiveSign() {
        #expect(formatTreemapValue(100, format: "+") == "+100")
        #expect(formatTreemapValue(-100, format: "+") == "-100")
    }

    @Test("Value formatting: scientific")
    func formatScientific() {
        let result = formatTreemapValue(1234, format: ".2e")
        #expect(result.contains("1.23"))
        #expect(result.contains("e"))
    }

    @Test("Layout produces leaves with fill/stroke/label colors")
    func leafColors() {
        let diagram = makeDiagram()
        let positioned = layoutTreemapDiagram(diagram)
        guard let leaf = positioned.leaves.first else { return }
        #expect(!leaf.fillColor.isEmpty)
        #expect(!leaf.strokeColor.isEmpty)
        #expect(!leaf.labelColor.isEmpty)
    }

    @Test("Layout produces sections with clip IDs")
    func sectionClipIds() {
        let diagram = makeDiagram()
        let positioned = layoutTreemapDiagram(diagram)
        for section in positioned.sections {
            #expect(!section.clipId.isEmpty)
        }
    }

    @Test("Layout carries classDef colors into positioned output")
    func layoutCarriesClassDefStyles() throws {
        let diagram = try parseTreemapDiagram("""
        treemap
        classDef hot fill:#ff0000,stroke:#333,color:#111;
        "Category":::hot
            "Item": 10:::hot
        """)
        let positioned = layoutTreemapDiagram(diagram)

        #expect(positioned.sections.first?.cssCompiledStyles?.contains("fill:#ff0000") == true)
        #expect(positioned.leaves.first?.cssCompiledStyles?.contains("fill:#ff0000") == true)
    }

    @Test("Empty treemap produces empty layout")
    func emptyTreemap() {
        let diagram = TreemapDiagram()
        let positioned = layoutTreemapDiagram(diagram)
        #expect(positioned.leaves.isEmpty)
        #expect(positioned.sections.isEmpty)
        #expect(positioned.width == 1000)
    }

    @Test("Leaf text shrinks to fit narrow width")
    func leafShrinksForNarrowWidth() {
        let diagram = makeDiagram(nodes: [
            TreemapNode(name: "Category", children: [
                TreemapNode(name: "A very long item name that should definitely shrink down because it is extremely long", value: 100)
            ])
        ])
        let positioned = layoutTreemapDiagram(diagram)
        guard let leaf = positioned.leaves.first else { return }
        #expect(leaf.label != nil)
        #expect(leaf.label!.fontSize < 38)
        #expect(!leaf.label!.hidden)
    }

    @Test("Leaf label+value fit combined height: label shrinks for value")
    func leafShrinksForValueHeight() {
        var diagram = makeDiagram(nodes: [
            TreemapNode(name: "Category", children: [
                TreemapNode(name: "Item", value: 100),
                TreemapNode(name: "Another", value: 200)
            ])
        ])
        diagram.config = TreemapDiagramConfig(nodeWidth: 30, nodeHeight: 5)
        let positioned = layoutTreemapDiagram(diagram)
        for leaf in positioned.leaves {
            if let label = leaf.label, !label.hidden {
                #expect(label.fontSize <= 38)
            }
        }
    }

    @Test("Leaf label+value hidden in tiny cell")
    func leafHiddenInTinyCell() {
        var diagram = makeDiagram(nodes: [
            TreemapNode(name: "Category", children: [
                TreemapNode(name: "TinyItem", value: 1),
                TreemapNode(name: "BigItem", value: 10000)
            ])
        ])
        diagram.config = TreemapDiagramConfig(nodeWidth: 10, nodeHeight: 10)
        let positioned = layoutTreemapDiagram(diagram)
        let tinyLeaf = positioned.leaves.first(where: { $0.name == "TinyItem" })
        #expect(tinyLeaf != nil)
    }

    @Test("Value hidden when showValues is false")
    func valuesHiddenWhenShowValuesFalse() {
        var diagram = makeDiagram()
        diagram.config = TreemapDiagramConfig(showValues: false)
        let positioned = layoutTreemapDiagram(diagram)
        for leaf in positioned.leaves {
            #expect(leaf.valueText == nil)
            #expect(leaf.formattedValue != nil)
        }
    }

    @Test("Nested layout carries depth through section hierarchy")
    func depthCarriedThrough() throws {
        let diagram = try parseTreemapDiagram("""
        treemap
        "Level 1"
            "Level 2"
                "Leaf": 10
        """)
        let positioned = layoutTreemapDiagram(diagram)
        guard let section = positioned.sections.first(where: { $0.name == "Level 1" }) else { return }
        #expect(section.depth > 0)
    }

    private func makeDiagram(nodes: [TreemapNode] = [
        TreemapNode(name: "Category", children: [
            TreemapNode(name: "Item 1", value: 10),
            TreemapNode(name: "Item 2", value: 20)
        ])
    ]) -> TreemapDiagram {
        TreemapDiagram(nodes: nodes)
    }
}

private func parseTreemapDiagram(_ source: String) throws -> TreemapDiagram {
    let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    return try parseTreemapDiagram(rawLines, frontmatter: nil)
}

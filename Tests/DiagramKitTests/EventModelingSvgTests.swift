import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

@Suite(.serialized)
@MainActor
struct EventModelingSvgTests {

    @Test func svg_simpleStateChange() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("em-swimlane"))
        #expect(svg.contains("em-box"))
        #expect(svg.contains("em-arrowhead-test-id"))
    }

    @Test func svg_swimlaneClasses() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "test", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("class=\"em-swimlane\""))
        #expect(svg.contains("class=\"em-box\""))
    }

    @Test func svg_hasViewBox() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "test", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("viewBox="))
    }

    @Test func svg_rendersThemeVariables() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        var (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        diagram.themeVariables = EventModelingThemeVariables(
            emCommandFill: "#e3f2fd",
            emCommandStroke: "#1565c0",
            emSwimlaneBackgroundOdd: "#f8f9fa",
            emSwimlaneBackgroundStroke: "#ced4da",
            emArrowhead: "#aa0000"
        )
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "theme", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: true)
        #expect(svg.contains("fill=\"#e3f2fd\""))
        #expect(svg.contains("stroke=\"#1565c0\""))
        #expect(svg.contains("fill=\"#f8f9fa\""))
        #expect(svg.contains("stroke=\"#ced4da\""))
        #expect(svg.contains("fill=\"#aa0000\""))
    }

    @Test func svg_useMaxWidthUsesResponsiveWidth() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        var (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        diagram.config.useMaxWidth = true
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "max-width", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: true)
        #expect(svg.contains(#"width="100%""#))
        #expect(svg.contains("max-width:"))
    }

    @Test func svg_markerIdsAreUniqueAcrossPublicRenders() async throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        let first = try await DiagramEngine.renderSVG(source: source)
        let second = try await DiagramEngine.renderSVG(source: source)
        let firstId = eventModelingExtractMarkerId(from: first)
        let secondId = eventModelingExtractMarkerId(from: second)
        #expect(firstId != nil)
        #expect(secondId != nil)
        #expect(firstId != secondId)
    }

    // MARK: - Mermaid spec test fixtures

    @Test func svg_spec_simpleDefinition() throws {
        let src = "eventmodeling\ntf 01 ui UI\ntf 02 cmd RunAction\ntf 03 evt ActionExecuted"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec1", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("class=\"em-swimlane\""))
        #expect(svg.contains("class=\"em-box\""))
        #expect(svg.contains("class=\"em-relation\""))
        let boxCount = svg.components(separatedBy: "class=\"em-box\"").count - 1
        #expect(boxCount == 3)
    }

    @Test func svg_spec_inlineData() throws {
        let src = "eventmodeling\ntf 01 cmd AddItem { productId: 7 }\ntf 02 evt ItemAdded { productId: 7 }"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec2", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("<code"))
        #expect(svg.contains("productId"))
        #expect(svg.contains("</code>"))
    }

    @Test func svg_spec_dataBlockReferences() throws {
        let src = "eventmodeling\ntf 01 cmd AddItem\ntf 02 evt ItemAdded [[ItemAddedData]]\n\ndata ItemAddedData\n{\n  productId: 7\n}"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec3", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("<code"))
        #expect(svg.contains("productId"))
    }

    @Test func svg_spec_qualifiedNames() throws {
        let src = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd Inventory.AddItem\ntf 03 evt Inventory.ItemAdded"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec4", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("<b>AddItem</b>"))
        #expect(svg.contains("<b>ItemAdded</b>"))
    }

    @Test func svg_spec_multipleSourceFrames() throws {
        let src = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 cmd RemoveItem\ntf 04 evt ItemChanged ->> 02 ->> 03"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec5", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        let relCount = svg.components(separatedBy: "class=\"em-relation\"").count - 1
        #expect(relCount >= 2)
    }

    @Test func svg_spec_resetFrames() throws {
        let src = "eventmodeling\nrf 01 ui CartUI\nrf 02 cmd AddItem\nrf 03 evt ItemAdded"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec6", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        let boxCount = svg.components(separatedBy: "class=\"em-box\"").count - 1
        #expect(boxCount == 3)
        let relCount = svg.components(separatedBy: "class=\"em-relation\"").count - 1
        #expect(relCount == 0)
    }

    @Test func svg_spec_allEntityTypes() throws {
        let src = "eventmodeling\ntf 01 ui UI\ntf 02 ui UI2\ntf 03 cmd Command\ntf 04 command Command2\ntf 05 evt Event\ntf 06 event Event2\ntf 07 pcr Processor\ntf 08 processor Processor2\ntf 09 rmo ReadModel\ntf 10 readmodel ReadModel2"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec7", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        let boxCount = svg.components(separatedBy: "class=\"em-box\"").count - 1
        #expect(boxCount == 10)
    }
}

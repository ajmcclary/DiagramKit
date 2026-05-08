import Testing
import Foundation
import CoreGraphics
@testable import BeautifulMermaid

struct EventModelingParserTests {

    // MARK: - Header detection

    @Test func parse_simpleStateChange() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames.count == 3)
        #expect(diagram.frames[0].name == "01")
        #expect(diagram.frames[0].modelEntityType == .ui)
        #expect(diagram.frames[0].entityIdentifier == "CartUI")
        #expect(diagram.frames[1].name == "02")
        #expect(diagram.frames[1].modelEntityType == .cmd)
        #expect(diagram.frames[2].name == "03")
        #expect(diagram.frames[2].modelEntityType == .evt)
    }

    @Test func parse_relaxedNotation() throws {
        let source = "eventmodeling\ntimeframe 01 ui CartUI\ntimeframe 02 command AddItem\ntimeframe 03 event ItemAdded"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames.count == 3)
        #expect(diagram.frames[0].modelEntityType == .ui)
        #expect(diagram.frames[1].modelEntityType == .cmd)
        #expect(diagram.frames[2].modelEntityType == .evt)
    }

    @Test func parse_resetFrame() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\nrf 03 evt External.InventoryChanged"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames.count == 3)
        #expect(diagram.frames[0].isResetFrame == false)
        #expect(diagram.frames[1].isResetFrame == false)
        #expect(diagram.frames[2].isResetFrame == true)
    }

    @Test func parse_allEntityTypes() throws {
        let source = "eventmodeling\ntf 01 ui UI\ntf 02 cmd Command\ntf 03 evt Event\ntf 04 pcr Processor\ntf 05 rmo ReadModel"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames.map(\.modelEntityType) == [.ui, .cmd, .evt, .pcr, .rmo])
    }

    @Test func parse_allEntityTypesRelaxed() throws {
        let source = "eventmodeling\ntimeframe 01 ui UI\ntimeframe 02 command Command\ntimeframe 03 event Event\ntimeframe 04 processor Processor\ntimeframe 05 readmodel ReadModel"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames.map(\.modelEntityType) == [.ui, .cmd, .evt, .pcr, .rmo])
    }

    // MARK: - Source frame references

    @Test func parse_multiSourceFrames() throws {
        let source = "eventmodeling\nrf 02 evt CartCreated\nrf 03 evt ItemAdded\ntf 01 rmo CartUI ->> 02 ->> 03"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames.count == 3)
        #expect(diagram.frames[2].sourceFrameNames == ["02", "03"])
    }

    // MARK: - Inline data

    @Test func parse_inlineData() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem { description: string }\ntf 03 evt ItemAdded { description: string }"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames[1].dataInlineValue == "description: string")
        #expect(diagram.frames[2].dataInlineValue == "description: string")
    }

    // MARK: - Data references

    @Test func parse_dataBlockReferences() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem [[AddItem01]]\ntf 03 evt ItemAdded [[ItemAdded]]\n\ndata AddItem01 {\n  description: 'john'\n  price: 20.4\n}\n\ndata ItemAdded {\n  description: string\n  price: number\n}"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames[1].dataReferenceName == "AddItem01")
        #expect(diagram.frames[2].dataReferenceName == "ItemAdded")
        #expect(diagram.dataEntities.count == 2)
        #expect(diagram.dataEntities[0].name == "AddItem01")
        #expect(diagram.dataEntities[1].name == "ItemAdded")
    }

    @Test func parse_dataBlockOpeningBraceOnNextLine() throws {
        let source = "eventmodeling\ntf 01 cmd AddItem\ntf 02 evt ItemAdded [[ItemAddedData]]\n\ndata ItemAddedData\n{\n  productId: 7\n}"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.dataEntities.count == 1)
        #expect(diagram.dataEntities[0].name == "ItemAddedData")
        #expect(diagram.dataEntities[0].dataBlockValue.contains("productId: 7"))
    }

    @Test func parse_noteBlockOpeningBraceOnNextLine() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\nnote 01\n{\n  Show cart summary\n}"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.noteEntities.count == 1)
        #expect(diagram.noteEntities[0].sourceFrameName == "01")
        #expect(diagram.noteEntities[0].dataBlockValue.contains("Show cart summary"))
    }

    // MARK: - Qualified identifiers / namespaces

    @Test func parse_namespaces() throws {
        let source = "eventmodeling\nrf 01 evt Inventory.InventoryChanged\nrf 02 evt External.InventoryChanged\ntf 03 rmo Inventory.CartItems\ntf 04 ui CartUI"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames[0].entityIdentifier == "Inventory.InventoryChanged")
        #expect(diagram.frames[1].entityIdentifier == "External.InventoryChanged")
    }

    // MARK: - GWT

    @Test func parse_gwt() throws {
        let source = "eventmodeling\nentity CartUI\nentity AddItem\nentity ItemAdded\ntf 02 cmd AddItem\ngwt 02 given ui CartUI when cmd AddItem then evt ItemAdded"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.modelEntities.count == 3)
        #expect(diagram.gwtEntities.count == 1)
        let gwt = diagram.gwtEntities[0]
        #expect(gwt.sourceFrameName == "02")
        #expect(gwt.givenStatements.count == 1)
        #expect(gwt.givenStatements[0].entityType == .ui)
        #expect(gwt.whenStatements.count == 1)
        #expect(gwt.whenStatements[0].entityType == .cmd)
        #expect(gwt.thenStatements.count == 1)
        #expect(gwt.thenStatements[0].entityType == .evt)
    }

    // MARK: - Title and accessibility

    @Test func parse_titleAndAccessibility() throws {
        let source = "eventmodeling\ntitle Shopping Cart\naccTitle: Cart event flow\naccDescr: Event modeling of shopping cart use case\ntf 01 ui CartUI"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.diagramTitle == "Shopping Cart")
        #expect(diagram.accTitle == "Cart event flow")
        #expect(diagram.accDescr == "Event modeling of shopping cart use case")
    }

    // MARK: - Duplicate frame ID

    @Test func parse_duplicateFrameId() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 01 cmd AddItem"
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(rawLines(source))
        }
    }

    // MARK: - Invalid entity type

    @Test func parse_invalidEntityType() throws {
        let source = "eventmodeling\ntf 01 unknown CartUI"
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(rawLines(source))
        }
    }

    @Test func parse_uppercaseHeaderIsRejected() throws {
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(rawLines("EVENTMODELING\ntf 01 ui CartUI"))
        }
    }

    @Test func parse_missingGwtSourceFrameIsRejected() throws {
        let source = "eventmodeling\nentity CartUI\nentity AddItem\ngwt 99 given ui CartUI then cmd AddItem"
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(rawLines(source))
        }
    }

    @Test func parse_missingNoteSourceFrameIsRejected() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\nnote 99 { Missing frame }"
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(rawLines(source))
        }
    }

    @Test func parse_invalidSourceFrameTypeIsRejected() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 evt ItemAdded ->> 01"
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(rawLines(source))
        }
    }

    @Test func parse_validSourceFrameTypesAreAccepted() throws {
        let source = """
        eventmodeling
        tf 01 ui CartUI
        tf 02 cmd AddItem ->> 01
        tf 03 evt ItemAdded ->> 02
        tf 04 rmo CartItems ->> 03
        tf 05 pcr InventoryProcessor ->> 04
        tf 06 ui InventoryUI ->> 04
        """
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames.count == 6)
    }

    // MARK: - Empty diagram

    @Test func parse_emptyDiagram() throws {
        let source = "eventmodeling"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames.isEmpty)
    }

    @Test func parse_withComments() throws {
        let source = "eventmodeling\n%% this is a comment\ntf 01 ui CartUI\n%% another comment\ntf 02 cmd AddItem"
        let diagram = try parseEventModeling(rawLines(source))
        #expect(diagram.frames.count == 2)
    }
}

struct EventModelingLayoutTests {

    @Test func layout_simpleStateChange() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.boxes.count == 3)
        #expect(positioned.swimlanes.count >= 1)
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
    }

    @Test func layout_allEntityTypes() throws {
        let source = "eventmodeling\ntf 01 ui UI\ntf 02 cmd Command\ntf 03 evt Event\ntf 04 pcr Processor\ntf 05 rmo ReadModel"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.boxes.count == 5)
        // UI and Processor share swimlane; Command and ReadModel share; Event has own 
        #expect(positioned.swimlanes.count >= 2)
    }

    @Test func layout_namespaces() throws {
        let source = "eventmodeling\nrf 01 evt Inventory.InventoryChanged\nrf 02 evt External.InventoryChanged\ntf 03 rmo Inventory.CartItems\ntf 04 ui CartUI"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.boxes.count == 4)
    }

    @Test func layout_multiSwimlanes() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded\ntf 05 pcr InventoryProcessor\ntf 06 cmd ChangeInventory\ntf 07 evt Cart.InventoryChanged"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.boxes.count == 6)
        #expect(positioned.swimlanes.count >= 2)
    }

    @Test func layoutEmpty() throws {
        let diagram = EventModelingDiagram.empty
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.boxes.isEmpty)
        #expect(positioned.swimlanes.isEmpty)
    }

    @Test func layout_paddingDoesNotInflatePositionedDimensions() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        var defaultDiagram = try parseEventModeling(rawLines(source))
        defaultDiagram.config.padding = 30
        var paddedDiagram = defaultDiagram
        paddedDiagram.config.padding = 80

        let defaultPositioned = layoutEventModeling(defaultDiagram)
        let paddedPositioned = layoutEventModeling(paddedDiagram)

        #expect(defaultPositioned.width == paddedPositioned.width)
        #expect(defaultPositioned.height == paddedPositioned.height)
    }

    @Test func layout_explicitMultiSourceRelationsFanOut() throws {
        let source = "eventmodeling\nrf 02 evt CartCreated\nrf 03 evt ItemAdded\nrf 04 evt ItemRemoved\ntf 01 rmo CartUI ->> 02 ->> 03 ->> 04"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.relations.count == 3)
    }

    @Test func layout_implicitRelationSkipsSameSwimlaneBackwardScan() throws {
        let source = "eventmodeling\ntf 01 ui A\ntf 02 ui B\ntf 03 cmd C"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.relations.count == 1)
        // C connects to B (most recent different-swimlane box, not A which shares B's swimlane)
        let rel = positioned.relations[0]
        #expect(rel.sourceBoxIndex == 1) // box index 1 = frame B
        #expect(rel.targetBoxIndex == 2) // box index 2 = frame C
    }

    @Test func layout_implicitRelationNotCreatedForFirstFrame() throws {
        let source = "eventmodeling\ntf 01 ui A"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.relations.isEmpty)
    }

    @Test func layout_implicitRelationNotCreatedForResetFrame() throws {
        let source = "eventmodeling\ntf 01 ui A\nrf 02 cmd B\ntf 03 evt C"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        // B is a reset frame: relation not created FOR B
        // C scans backward: finds B at different swimlane → relation B→C
        // A is first frame: no implicit relation
        #expect(positioned.relations.count == 1)
        let rel = positioned.relations[0]
        #expect(rel.sourceBoxIndex == 1) // B's box
        #expect(rel.targetBoxIndex == 2) // C's box
    }
}

struct EventModelingSvgTests {

    @Test func svg_simpleStateChange() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "test-id", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("em-swimlane"))
        #expect(svg.contains("em-box"))
        #expect(svg.contains("em-arrowhead-test-id"))
    }

    @Test func svg_swimlaneClasses() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "test", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("class=\"em-swimlane\""))
        #expect(svg.contains("class=\"em-box\""))
    }

    @Test func svg_hasViewBox() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        let diagram = try parseEventModeling(rawLines(source))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "test", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("viewBox="))
    }

    @Test func svg_rendersThemeVariables() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        var diagram = try parseEventModeling(rawLines(source))
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
        var diagram = try parseEventModeling(rawLines(source))
        diagram.config.useMaxWidth = true
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "max-width", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: true)
        #expect(svg.contains(#"width="100%""#))
        #expect(svg.contains("max-width:"))
    }

    @Test func svg_markerIdsAreUniqueAcrossPublicRenders() async throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        let first = try await renderMermaidSVG(source)
        let second = try await renderMermaidSVG(source)
        let firstId = extractMarkerId(from: first)
        let secondId = extractMarkerId(from: second)
        #expect(firstId != nil)
        #expect(secondId != nil)
        #expect(firstId != secondId)
    }

    // MARK: - Mermaid spec test fixtures

    @Test func svg_spec_simpleDefinition() throws {
        let src = "eventmodeling\ntf 01 ui UI\ntf 02 cmd RunAction\ntf 03 evt ActionExecuted"
        let diagram = try parseEventModeling(rawLines(src))
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
        let diagram = try parseEventModeling(rawLines(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec2", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("<code"))
        #expect(svg.contains("productId"))
        #expect(svg.contains("</code>"))
    }

    @Test func svg_spec_dataBlockReferences() throws {
        let src = "eventmodeling\ntf 01 cmd AddItem\ntf 02 evt ItemAdded [[ItemAddedData]]\n\ndata ItemAddedData\n{\n  productId: 7\n}"
        let diagram = try parseEventModeling(rawLines(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec3", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("<code"))
        #expect(svg.contains("productId"))
    }

    @Test func svg_spec_qualifiedNames() throws {
        let src = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd Inventory.AddItem\ntf 03 evt Inventory.ItemAdded"
        let diagram = try parseEventModeling(rawLines(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec4", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        #expect(svg.contains("<b>AddItem</b>"))
        #expect(svg.contains("<b>ItemAdded</b>"))
    }

    @Test func svg_spec_multipleSourceFrames() throws {
        let src = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 cmd RemoveItem\ntf 04 evt ItemChanged ->> 02 ->> 03"
        let diagram = try parseEventModeling(rawLines(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec5", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        let relCount = svg.components(separatedBy: "class=\"em-relation\"").count - 1
        #expect(relCount >= 2)
    }

    @Test func svg_spec_resetFrames() throws {
        let src = "eventmodeling\nrf 01 ui CartUI\nrf 02 cmd AddItem\nrf 03 evt ItemAdded"
        let diagram = try parseEventModeling(rawLines(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec6", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        let boxCount = svg.components(separatedBy: "class=\"em-box\"").count - 1
        #expect(boxCount == 3)
        let relCount = svg.components(separatedBy: "class=\"em-relation\"").count - 1
        #expect(relCount == 0)
    }

    @Test func svg_spec_allEntityTypes() throws {
        let src = "eventmodeling\ntf 01 ui UI\ntf 02 ui UI2\ntf 03 cmd Command\ntf 04 command Command2\ntf 05 evt Event\ntf 06 event Event2\ntf 07 pcr Processor\ntf 08 processor Processor2\ntf 09 rmo ReadModel\ntf 10 readmodel ReadModel2"
        let diagram = try parseEventModeling(rawLines(src))
        let positioned = layoutEventModeling(diagram)
        let svg = renderEventModelingSvg(positioned, diagramId: "spec7", colors: DiagramColors(bg: "#fff", fg: "#000"), font: "sans-serif", transparent: false)
        let boxCount = svg.components(separatedBy: "class=\"em-box\"").count - 1
        #expect(boxCount == 10)
    }
}

struct EventModelingEndToEndTests {

    @Test func e2e_simpleStateChange() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let graph = try MermaidParser.parse(source)
        guard case let .eventModeling(diagram) = graph.payload else {
            Issue.record("Expected eventModeling payload")
            return
        }
        #expect(diagram.frames.count == 3)
    }

    @Test func e2e_frontmatterConfig() throws {
        let source = """
        ---
        config:
          eventmodeling:
            padding: 50
        ---
        eventmodeling
        tf 01 ui CartUI
        tf 02 cmd AddItem
        """
        let graph = try MermaidParser.parse(source)
        guard case let .eventModeling(diagram) = graph.payload else {
            Issue.record("Expected eventModeling payload")
            return
        }
        #expect(diagram.config.padding == 50)
    }

    @Test func e2e_frontmatterTheme() throws {
        let source = """
        ---
        config:
          themeVariables:
            emCommandFill: '#e3f2fd'
            emCommandStroke: '#1565c0'
        ---
        eventmodeling
        tf 01 ui CartUI
        tf 02 cmd AddItem
        """
        let graph = try MermaidParser.parse(source)
        guard case let .eventModeling(diagram) = graph.payload else {
            Issue.record("Expected eventModeling payload")
            return
        }
        #expect(diagram.themeVariables.emCommandFill == "#e3f2fd")
        #expect(diagram.themeVariables.emCommandStroke == "#1565c0")
    }

    @Test func e2e_asciiReturnsNotYetImplemented() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        #expect(throws: BeautifulMermaidError.self) {
            _ = try original_src_ascii_index.renderMermaidASCII(source)
        }
    }

    @Test func e2e_svgRendering() async throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let svg = try await renderMermaidSVG(source)
        #expect(svg.contains("em-swimlane"))
        #expect(svg.contains("svg"))
    }

    @Test func e2e_layout() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)
        guard case .eventModeling = positioned.content else {
            Issue.record("Expected eventModeling positioned content")
            return
        }
        #expect(positioned.width > 0)
    }

    @Test func e2e_initDirectiveThemeVariables() throws {
        let source = """
        %%{init: { "themeVariables": { "emCommandFill": "#abc123", "emEventStroke": "#def456" } } }%%
        eventmodeling
        tf 01 ui CartUI
        tf 02 cmd AddItem
        tf 03 evt ItemAdded
        """
        let graph = try MermaidParser.parse(source)
        guard case let .eventModeling(diagram) = graph.payload else {
            Issue.record("Expected eventModeling payload")
            return
        }
        #expect(diagram.themeVariables.emCommandFill == "#abc123")
        #expect(diagram.themeVariables.emEventStroke == "#def456")
    }

    @Test func e2e_initDirectiveConfig() throws {
        let source = """
        %%{init: { "config": { "eventmodeling": { "padding": 60 } } } }%%
        eventmodeling
        tf 01 ui CartUI
        tf 02 cmd AddItem
        """
        let graph = try MermaidParser.parse(source)
        guard case let .eventModeling(diagram) = graph.payload else {
            Issue.record("Expected eventModeling payload")
            return
        }
        #expect(diagram.config.padding == 60)
    }

    @Test func e2e_cgDoesNotThrow() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let graph = try MermaidParser.parse(source)
        let layout = GraphLayout()
        let positioned = try layout.layout(graph)
        let renderer = DiagramRenderer(theme: .default)
        let width = 800
        let height = 600
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("Could not create CGContext")
            return
        }
        renderer.render(positioned, in: ctx, bounds: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        let image = ctx.makeImage()
        #expect(image != nil)
    }
}

// MARK: - Helpers

private func rawLines(_ source: String) -> [String] {
    source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
}

private func extractMarkerId(from svg: String) -> String? {
    guard let range = svg.range(of: "id=\"em-arrowhead-") else { return nil }
    let afterPrefix = svg[range.upperBound...]
    guard let end = afterPrefix.firstIndex(of: "\"") else { return nil }
    return String(afterPrefix[..<end])
}

import Testing
import Foundation
@testable import DiagramKitModel

struct EventModelingParserTests {

    // MARK: - Header detection

    @Test func parse_simpleStateChange() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
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
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames.count == 3)
        #expect(diagram.frames[0].modelEntityType == .ui)
        #expect(diagram.frames[1].modelEntityType == .cmd)
        #expect(diagram.frames[2].modelEntityType == .evt)
    }

    @Test func parse_resetFrame() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\nrf 03 evt External.InventoryChanged"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames.count == 3)
        #expect(diagram.frames[0].isResetFrame == false)
        #expect(diagram.frames[1].isResetFrame == false)
        #expect(diagram.frames[2].isResetFrame == true)
    }

    @Test func parse_allEntityTypes() throws {
        let source = "eventmodeling\ntf 01 ui UI\ntf 02 cmd Command\ntf 03 evt Event\ntf 04 pcr Processor\ntf 05 rmo ReadModel"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames.map(\.modelEntityType) == [.ui, .cmd, .evt, .pcr, .rmo])
    }

    @Test func parse_allEntityTypesRelaxed() throws {
        let source = "eventmodeling\ntimeframe 01 ui UI\ntimeframe 02 command Command\ntimeframe 03 event Event\ntimeframe 04 processor Processor\ntimeframe 05 readmodel ReadModel"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames.map(\.modelEntityType) == [.ui, .cmd, .evt, .pcr, .rmo])
    }

    // MARK: - Source frame references

    @Test func parse_multiSourceFrames() throws {
        let source = "eventmodeling\nrf 02 evt CartCreated\nrf 03 evt ItemAdded\ntf 01 rmo CartUI ->> 02 ->> 03"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames.count == 3)
        #expect(diagram.frames[2].sourceFrameNames == ["02", "03"])
    }

    // MARK: - Inline data

    @Test func parse_inlineData() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem { description: string }\ntf 03 evt ItemAdded { description: string }"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames[1].dataInlineValue == "description: string")
        #expect(diagram.frames[2].dataInlineValue == "description: string")
    }

    // MARK: - Data references

    @Test func parse_dataBlockReferences() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem [[AddItem01]]\ntf 03 evt ItemAdded [[ItemAdded]]\n\ndata AddItem01 {\n  description: 'john'\n  price: 20.4\n}\n\ndata ItemAdded {\n  description: string\n  price: number\n}"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames[1].dataReferenceName == "AddItem01")
        #expect(diagram.frames[2].dataReferenceName == "ItemAdded")
        #expect(diagram.dataEntities.count == 2)
        #expect(diagram.dataEntities[0].name == "AddItem01")
        #expect(diagram.dataEntities[1].name == "ItemAdded")
    }

    @Test func parse_dataBlockOpeningBraceOnNextLine() throws {
        let source = "eventmodeling\ntf 01 cmd AddItem\ntf 02 evt ItemAdded [[ItemAddedData]]\n\ndata ItemAddedData\n{\n  productId: 7\n}"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.dataEntities.count == 1)
        #expect(diagram.dataEntities[0].name == "ItemAddedData")
        #expect(diagram.dataEntities[0].dataBlockValue.contains("productId: 7"))
    }

    @Test func parse_noteBlockOpeningBraceOnNextLine() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\nnote 01\n{\n  Show cart summary\n}"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.noteEntities.count == 1)
        #expect(diagram.noteEntities[0].sourceFrameName == "01")
        #expect(diagram.noteEntities[0].dataBlockValue.contains("Show cart summary"))
    }

    // MARK: - Qualified identifiers / namespaces

    @Test func parse_namespaces() throws {
        let source = "eventmodeling\nrf 01 evt Inventory.InventoryChanged\nrf 02 evt External.InventoryChanged\ntf 03 rmo Inventory.CartItems\ntf 04 ui CartUI"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames[0].entityIdentifier == "Inventory.InventoryChanged")
        #expect(diagram.frames[1].entityIdentifier == "External.InventoryChanged")
    }

    // MARK: - GWT

    @Test func parse_gwt() throws {
        let source = "eventmodeling\nentity CartUI\nentity AddItem\nentity ItemAdded\ntf 02 cmd AddItem\ngwt 02 given ui CartUI when cmd AddItem then evt ItemAdded"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
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
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.diagramTitle == "Shopping Cart")
        #expect(diagram.accTitle == "Cart event flow")
        #expect(diagram.accDescr == "Event modeling of shopping cart use case")
    }

    // MARK: - Duplicate frame ID

    @Test func parse_duplicateFrameId() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 01 cmd AddItem"
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(eventModelingNormalizeSource(source))
        }
    }

    // MARK: - Invalid entity type

    @Test func parse_invalidEntityType() throws {
        let source = "eventmodeling\ntf 01 unknown CartUI"
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(eventModelingNormalizeSource(source))
        }
    }

    @Test func parse_uppercaseHeaderIsRejected() throws {
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(eventModelingNormalizeSource("EVENTMODELING\ntf 01 ui CartUI"))
        }
    }

    @Test func parse_missingGwtSourceFrameIsRejected() throws {
        let source = "eventmodeling\nentity CartUI\nentity AddItem\ngwt 99 given ui CartUI then cmd AddItem"
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(eventModelingNormalizeSource(source))
        }
    }

    @Test func parse_missingNoteSourceFrameIsRejected() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\nnote 99 { Missing frame }"
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(eventModelingNormalizeSource(source))
        }
    }

    @Test func parse_invalidSourceFrameTypeIsRejected() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 evt ItemAdded ->> 01"
        #expect(throws: EventModelingParserError.self) {
            _ = try parseEventModeling(eventModelingNormalizeSource(source))
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
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames.count == 6)
    }

    // MARK: - Empty diagram

    @Test func parse_emptyDiagram() throws {
        let source = "eventmodeling"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames.isEmpty)
    }

    @Test func parse_withComments() throws {
        let source = "eventmodeling\n%% this is a comment\ntf 01 ui CartUI\n%% another comment\ntf 02 cmd AddItem"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        #expect(diagram.frames.count == 2)
    }
}

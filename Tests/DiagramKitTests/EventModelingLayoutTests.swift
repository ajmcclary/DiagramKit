import Testing
import Foundation
@testable import DiagramKitModel

@Suite(.serialized)
@MainActor
struct EventModelingLayoutTests {

    @Test func layout_simpleStateChange() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.boxes.count == 3)
        #expect(positioned.swimlanes.count >= 1)
        #expect(positioned.width > 0)
        #expect(positioned.height > 0)
    }

    @Test func layout_allEntityTypes() throws {
        let source = "eventmodeling\ntf 01 ui UI\ntf 02 cmd Command\ntf 03 evt Event\ntf 04 pcr Processor\ntf 05 rmo ReadModel"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.boxes.count == 5)
        // UI and Processor share swimlane; Command and ReadModel share; Event has own
        #expect(positioned.swimlanes.count >= 2)
    }

    @Test func layout_namespaces() throws {
        let source = "eventmodeling\nrf 01 evt Inventory.InventoryChanged\nrf 02 evt External.InventoryChanged\ntf 03 rmo Inventory.CartItems\ntf 04 ui CartUI"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.boxes.count == 4)
    }

    @Test func layout_multiSwimlanes() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded\ntf 05 pcr InventoryProcessor\ntf 06 cmd ChangeInventory\ntf 07 evt Cart.InventoryChanged"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
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
        var (defaultDiagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
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
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.relations.count == 3)
    }

    @Test func layout_implicitRelationSkipsSameSwimlaneBackwardScan() throws {
        let source = "eventmodeling\ntf 01 ui A\ntf 02 ui B\ntf 03 cmd C"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.relations.count == 1)
        // C connects to B (most recent different-swimlane box, not A which shares B's swimlane)
        let rel = positioned.relations[0]
        #expect(rel.sourceBoxIndex == 1) // box index 1 = frame B
        #expect(rel.targetBoxIndex == 2) // box index 2 = frame C
    }

    @Test func layout_implicitRelationNotCreatedForFirstFrame() throws {
        let source = "eventmodeling\ntf 01 ui A"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
        let positioned = layoutEventModeling(diagram)
        #expect(positioned.relations.isEmpty)
    }

    @Test func layout_implicitRelationNotCreatedForResetFrame() throws {
        let source = "eventmodeling\ntf 01 ui A\nrf 02 cmd B\ntf 03 evt C"
        let (diagram, _) = try parseEventModeling(eventModelingNormalizeSource(source))
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

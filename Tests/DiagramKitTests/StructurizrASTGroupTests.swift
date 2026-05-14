import Foundation
import Testing
import DiagramKitStructurizr

@Suite("StructurizrModelElement.group")
struct StructurizrASTGroupTests {

    @Test("Group defaults to nil")
    func groupDefaultsToNil() {
        let element = StructurizrModelElement(
            alias: "u",
            kind: .person,
            name: "User"
        )
        #expect(element.group == nil)
    }

    @Test("Group accepts a label string")
    func groupAcceptsLabel() {
        var element = StructurizrModelElement(
            alias: "u",
            kind: .person,
            name: "User"
        )
        element.group = "Group 0"
        #expect(element.group == "Group 0")
    }
}

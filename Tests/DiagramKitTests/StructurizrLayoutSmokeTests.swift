import Testing
import DiagramKitModel
import DiagramKitStructurizr
@testable import DiagramKit

@Suite struct StructurizrLayoutSmokeTests {

    @Test("structurizr layout smoke: non-empty positioned output")
    func structurizrLayoutSmoke() throws {
        let source = """
        workspace {
            model {
                u = person "User"
                app = softwareSystem "My App"
                u -> app "Uses"
            }
            views { systemContext app { include * } }
        }
        """
        let positioned = try DiagramPipeline.layout(source)
        guard case .c4(let c4Data) = positioned.content else {
            #expect(Bool(false))
            return
        }
        #expect(!c4Data.shapes.isEmpty)
    }

    @Test("structurizr container view layout smoke")
    func structurizrContainerViewLayoutSmoke() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App" {
                    web = container "Web" "Public UI"
                }
                u -> app "Uses"
            }
            views { container app { include * } }
        }
        """
        let positioned = try DiagramPipeline.layout(source)
        guard case .c4(let c4Data) = positioned.content else { return }
        #expect(!c4Data.boundaries.isEmpty)
    }

    @Test("structurizr component view layout smoke")
    func structurizrComponentViewLayoutSmoke() throws {
        let source = """
        workspace {
            model {
                u = person "U"
                app = softwareSystem "App" {
                    web = container "Web" {
                        auth = component "Auth"
                    }
                }
                u -> web "Uses"
            }
            views { component web { include * } }
        }
        """
        let positioned = try DiagramPipeline.layout(source)
        guard case .c4(let c4Data) = positioned.content else { return }
        #expect(!c4Data.boundaries.isEmpty)
    }
}

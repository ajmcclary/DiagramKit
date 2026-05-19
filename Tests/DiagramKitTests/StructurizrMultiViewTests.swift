import Testing
import DiagramKitImport
import DiagramKitModel
@testable import DiagramKitStructurizr

@Suite("StructurizrMultiViewTests")
struct StructurizrMultiViewTests {

    @Test("multi-view workspace produces no `only the first view` diagnostic")
    func multiViewNoFirstViewOnlyDiagnostic() throws {
        let source = """
        workspace {
            model {
                customer = person "Customer"
                banking = softwareSystem "Banking System"
                customer -> banking "Uses"
            }

            views {
                systemContext banking "ContextView" {
                    include *
                }
                container banking "ContainerView" {
                    include *
                }
            }
        }
        """
        let importer = StructurizrImporter()
        let result = try importer.parse(source)
        let firstViewOnlyDiag = result.diagnostics.first { diag in
            diag.message.contains("only the first view is imported")
        }
        #expect(firstViewOnlyDiag == nil)
    }

    @Test("multi-view workspace still renders the first view")
    func multiViewFirstViewRendered() throws {
        let source = """
        workspace {
            model {
                customer = person "Customer"
                banking = softwareSystem "Banking System"
            }

            views {
                systemContext banking "ContextView" {
                    include *
                }
                container banking "ContainerView" {
                    include *
                }
            }
        }
        """
        let importer = StructurizrImporter()
        let result = try importer.parse(source)
        guard case .c4(let diagram) = result.document.payload else {
            Issue.record("expected c4 payload, got \(result.document.payload)")
            return
        }
        #expect(diagram.kind == .context)
    }
}

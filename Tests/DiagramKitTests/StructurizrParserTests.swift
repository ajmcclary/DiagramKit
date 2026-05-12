import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitStructurizr

@Suite struct StructurizrParserTests {

    let lexer = StructurizrLexer()
    let parser = StructurizrParser()

    private func parse(_ source: String) throws -> (StructurizrWorkspace, [DiagramDiagnostic]) {
        let tokens = lexer.tokenize(source)
        return try parser.parse(tokens)
    }

    @Test("parse empty workspace")
    func parseEmptyWorkspace() throws {
        let (workspace, _) = try parse("workspace { }")
        #expect(workspace.name == nil)
        #expect(workspace.description == nil)
        #expect(workspace.model == nil)
        #expect(workspace.views.isEmpty)
    }

    @Test("parse named workspace")
    func parseNamedWorkspace() throws {
        let (workspace, _) = try parse("workspace \"Name\" { }")
        #expect(workspace.name == "Name")
        #expect(workspace.description == nil)
    }

    @Test("parse named workspace with description")
    func parseNamedWorkspaceWithDescription() throws {
        let (workspace, _) = try parse("workspace \"N\" \"Desc\" { }")
        #expect(workspace.name == "N")
        #expect(workspace.description == "Desc")
    }

    @Test("parse person element")
    func parsePersonElement() throws {
        let (workspace, _) = try parse("workspace { model { u = person \"User\" } }")
        let elements = workspace.model?.elements ?? []
        #expect(elements.count == 1)
        #expect(elements[0].alias == "u")
        #expect(elements[0].kind == .person)
        #expect(elements[0].name == "User")
        #expect(elements[0].description == nil)
    }

    @Test("parse person with description")
    func parsePersonWithDescription() throws {
        let (workspace, _) = try parse("workspace { model { u = person \"User\" \"A user\" } }")
        let element = try #require(workspace.model?.elements.first)
        #expect(element.description == "A user")
    }

    @Test("parse softwareSystem")
    func parseSoftwareSystem() throws {
        let (workspace, _) = try parse("workspace { model { app = softwareSystem \"My App\" } }")
        let element = try #require(workspace.model?.elements.first)
        #expect(element.kind == .softwareSystem)
        #expect(element.name == "My App")
    }

    @Test("parse softwareSystem with description")
    func parseSoftwareSystemWithDescription() throws {
        let (workspace, _) = try parse("workspace { model { app = softwareSystem \"My App\" \"Core\" } }")
        let element = try #require(workspace.model?.elements.first)
        #expect(element.description == "Core")
    }

    @Test("parse container with description only (not technology)")
    func parseContainer() throws {
        let (workspace, _) = try parse("workspace { model { db = container \"DB\" \"PostgreSQL\" } }")
        let element = try #require(workspace.model?.elements.first)
        #expect(element.name == "DB")
        #expect(element.description == "PostgreSQL")
        #expect(element.technology == nil)
    }

    @Test("parse container with description and technology")
    func parseContainerWithTechnology() throws {
        let (workspace, _) = try parse("workspace { model { db = container \"DB\" \"PostgreSQL\" \"Stores data\" } }")
        let element = try #require(workspace.model?.elements.first)
        #expect(element.description == "PostgreSQL")
        #expect(element.technology == "Stores data")
    }

    @Test("parse component")
    func parseComponent() throws {
        let (workspace, _) = try parse("workspace { model { auth = component \"Auth\" } }")
        let element = try #require(workspace.model?.elements.first)
        #expect(element.kind == .component)
    }

    @Test("parse component with description and technology")
    func parseComponentWithDescriptionAndTech() throws {
        let (workspace, _) = try parse("workspace { model { auth = component \"Auth\" \"Handles login\" \"OAuth2\" } }")
        let element = try #require(workspace.model?.elements.first)
        #expect(element.description == "Handles login")
        #expect(element.technology == "OAuth2")
    }

    @Test("parse nested elements")
    func parseNestedElements() throws {
        let (workspace, _) = try parse("workspace { model { app = softwareSystem \"App\" { web = container \"Web\" } } }")
        let app = try #require(workspace.model?.elements.first)
        #expect(app.children.count == 1)
        #expect(app.children[0].alias == "web")
        #expect(app.children[0].parentAlias == "app")
    }

    @Test("parse scoped relationship")
    func parseScopedRelationship() throws {
        let (workspace, _) = try parse("workspace { model { app = softwareSystem \"App\" { user -> web \"Uses\" } } }")
        let rels = workspace.model?.relationships ?? []
        #expect(rels.count == 1)
        #expect(rels[0].source == "user")
        #expect(rels[0].target == "web")
        #expect(rels[0].label == "Uses")
    }

    @Test("parse relationship")
    func parseRelationship() throws {
        let (workspace, _) = try parse("workspace { model { u -> app \"Uses\" } }")
        let rel = try #require(workspace.model?.relationships.first)
        #expect(rel.source == "u")
        #expect(rel.target == "app")
        #expect(rel.label == "Uses")
    }

    @Test("parse relationship with all args")
    func parseRelationshipWithAllArgs() throws {
        let (workspace, _) = try parse("workspace { model { u -> app \"Uses\" \"HTTPS\" \"Over TLS\" } }")
        let rel = try #require(workspace.model?.relationships.first)
        #expect(rel.label == "Uses")
        #expect(rel.technology == "HTTPS")
        #expect(rel.description == "Over TLS")
    }

    @Test("parse multiple elements")
    func parseMultipleElements() throws {
        let (workspace, _) = try parse("workspace { model { u = person \"U\" app = softwareSystem \"A\" } }")
        #expect(workspace.model?.elements.count == 2)
    }

    @Test("parse systemContext view")
    func parseSystemContextView() throws {
        let (workspace, _) = try parse("workspace { views { systemContext app { include * } } }")
        let view = try #require(workspace.views.first)
        #expect(view.kind == .systemContext)
        #expect(view.scopeAlias == "app")
        #expect(view.includes.contains(.wildcard))
    }

    @Test("parse container view")
    func parseContainerView() throws {
        let (workspace, _) = try parse("workspace { views { container app { include * } } }")
        let view = try #require(workspace.views.first)
        #expect(view.kind == .container)
    }

    @Test("parse component view")
    func parseComponentView() throws {
        let (workspace, _) = try parse("workspace { views { component web { include u include db } } }")
        let view = try #require(workspace.views.first)
        #expect(view.kind == .component)
        #expect(view.includes.count == 2)
    }

    @Test("parse view with title and description")
    func parseViewWithTitleAndDescription() throws {
        let (workspace, _) = try parse("workspace { views { systemContext app \"Title\" \"Desc\" { include * } } }")
        let view = try #require(workspace.views.first)
        #expect(view.title == "Title")
        #expect(view.description == "Desc")
    }

    @Test("parse comments")
    func parseComments() throws {
        let (workspace, _) = try parse("workspace { // comment\nmodel { u = person \"U\" }\n}")
        #expect(workspace.model?.elements.count == 1)
    }

    @Test("parse throws on unbalanced braces")
    func parseThrowsOnUnbalancedBraces() throws {
        #expect(throws: DiagramError.self) {
            let _ = try parse("workspace { model { u = person \"U\"")
        }
    }
}

import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitPlantUML

@Suite struct PlantUMLC4ImporterTests {

    @Test("Parses Person and System with a relationship")
    func contextBasics() throws {
        let source = """
        @startuml
        !include <C4/C4_Context>
        Person(user, "User", "A user of the system")
        System(api, "API", "Backend service")
        Rel(user, api, "uses", "HTTPS")
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .c4(let model) = result.document.payload else {
            Issue.record("Expected c4 payload, got \(result.document.payload)")
            return
        }
        let user = model.shapes.first { $0.alias == "user" }
        let api = model.shapes.first { $0.alias == "api" }
        #expect(user?.typeC4Shape == .person)
        #expect(user?.label == "User")
        #expect(api?.typeC4Shape == .system)
        #expect(api?.label == "API")
        let rel = model.relationships.first
        #expect(rel?.from == "user")
        #expect(rel?.to == "api")
        #expect(rel?.label == "uses")
        #expect(rel?.technology == "HTTPS")
    }

    @Test("Container and ContainerDb map to .container / .container_db")
    func containers() throws {
        let source = """
        @startuml
        Container(web, "Web App", "Nginx", "Static files")
        ContainerDb(db, "Database", "Postgres", "User data")
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .c4(let model) = result.document.payload else {
            Issue.record("Expected c4 payload"); return
        }
        #expect(model.shapes.first { $0.alias == "web" }?.typeC4Shape == .container)
        #expect(model.shapes.first { $0.alias == "db" }?.typeC4Shape == .container_db)
    }

    @Test("System_Ext is recognized as external_system")
    func systemExt() throws {
        let source = """
        @startuml
        System_Ext(ext, "Third Party API")
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .c4(let model) = result.document.payload else {
            Issue.record("Expected c4 payload"); return
        }
        #expect(model.shapes.first { $0.alias == "ext" }?.typeC4Shape == .external_system)
    }
}

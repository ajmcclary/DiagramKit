import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2ArchitectureMapper")
struct D2ArchitectureMapperTests {

    @Test("Detects architecture when two or more nodes carry arch shapes")
    func detectsArchitectureFromShapes() throws {
        let source = """
        api.shape: rectangle
        db.shape: cylinder
        cache.shape: cylinder
        api -> db
        api -> cache
        """
        let parser = D2Parser()
        let (doc, _) = try parser.parse(source)
        #expect(D2ArchitectureProbe.detectsArchitecture(doc))
    }

    @Test("Maps cylinder shape to .database kind")
    func mapsCylinderToDatabase() throws {
        let source = """
        api.shape: rectangle
        db.shape: cylinder
        cache.shape: cylinder
        api -> db
        """
        let parser = D2Parser()
        let (doc, _) = try parser.parse(source)
        let (arch, _) = D2ArchitectureMapper().map(doc, markers: [])
        let db = try #require(arch.services.first(where: { $0.id == "db" }))
        #expect(db.kind == .database)
        let api = try #require(arch.services.first(where: { $0.id == "api" }))
        #expect(api.kind == .service)
    }

    @Test("Container becomes an ArchitectureGroup with parentGroupId set on members")
    func containerBecomesGroup() throws {
        let source = """
        backend: {
          api.shape: rectangle
          db.shape: cylinder
          api -> db
        }
        """
        let parser = D2Parser()
        let (doc, _) = try parser.parse(source)
        let (arch, _) = D2ArchitectureMapper().map(doc, markers: [])
        #expect(arch.groups.count == 1)
        #expect(arch.groups.first?.id == "backend")
        let db = try #require(arch.services.first(where: { $0.id == "db" }))
        #expect(db.parentGroupId == "backend")
    }
}

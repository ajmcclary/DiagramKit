import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitGraphviz

@Suite("DOTArchitectureMapper")
struct DOTArchitectureMapperTests {

    @Test("Detects architecture when two or more nodes carry arch shape attributes")
    func detectsArchitectureFromShapes() throws {
        let source = """
        digraph G {
          api [shape=box];
          db [shape=cylinder];
          cache [shape=cylinder];
          api -> db;
          api -> cache;
        }
        """
        let tokens = try DOTLexer().tokenize(source)
        let (doc, _) = try DOTParser().parse(tokens)
        #expect(DOTArchitectureProbe.detectsArchitecture(doc))
    }

    @Test("Maps cylinder shape to .database kind")
    func mapsCylinderToDatabase() throws {
        let source = """
        digraph G {
          db [shape=cylinder];
          cache [shape=cylinder];
        }
        """
        let tokens = try DOTLexer().tokenize(source)
        let (doc, _) = try DOTParser().parse(tokens)
        let (arch, _) = DOTArchitectureMapper().map(doc, markers: [])
        let db = try #require(arch.services.first(where: { $0.id == "db" }))
        #expect(db.kind == .database)
    }

    @Test("Cluster becomes an ArchitectureGroup with parentGroupId on members")
    func clusterBecomesGroup() throws {
        let source = """
        digraph G {
          subgraph cluster_backend {
            label = "Backend";
            api [shape=box];
            db [shape=cylinder];
          }
        }
        """
        let tokens = try DOTLexer().tokenize(source)
        let (doc, _) = try DOTParser().parse(tokens)
        let (arch, _) = DOTArchitectureMapper().map(doc, markers: [])
        let group = try #require(arch.groups.first)
        #expect(group.id == "backend")
        let db = try #require(arch.services.first(where: { $0.id == "db" }))
        #expect(db.parentGroupId == "backend")
    }
}

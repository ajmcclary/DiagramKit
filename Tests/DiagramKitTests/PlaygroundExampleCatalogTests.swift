import Foundation
import XCTest

final class PlaygroundExampleCatalogTests: XCTestCase {
    private struct DiagramEntry: Decodable {
        let category: String
    }

    private struct DiagramFile: Decodable {
        let diagrams: [DiagramEntry]
    }

    private let expectedGapsCategoryIDs = [
        "flowchart",
        "sequence",
        "class",
        "state",
        "er",
        "journey",
        "gantt",
        "pie",
        "quadrantChart",
        "requirement",
        "gitGraph",
        "c4",
        "mindmap",
        "timeline",
        "zenuml",
        "sankey",
        "xychart",
        "block",
        "packet",
        "kanban",
        "architecture",
        "radar",
        "treemap",
        "venn",
        "ishikawa",
        "treeView",
        "eventmodeling",
        "wardleyBeta",
    ]

    func testPlaygroundCorpusContainsEveryGapsDiagramFamily() throws {
        let diagramsURL = Self.projectRoot()
            .appendingPathComponent("Examples/DiagramPlayground/Resources/test-diagrams.json")
        let data = try Data(contentsOf: diagramsURL)
        let file = try JSONDecoder().decode(DiagramFile.self, from: data)
        let categories = Set(file.diagrams.map(\.category))

        XCTAssertEqual(categories, Set(expectedGapsCategoryIDs))
        for category in expectedGapsCategoryIDs {
            XCTAssertTrue(
                file.diagrams.contains { $0.category == category },
                "Expected at least one playground example for \(category)"
            )
        }
    }

    func testPlaygroundPickerUsesGapsCatalogOrder() throws {
        let modelURL = Self.projectRoot()
            .appendingPathComponent("Examples/DiagramPlayground/Models/SampleDiagrams.swift")
        let modelSource = try String(contentsOf: modelURL, encoding: .utf8)
        let catalogIDs = modelSource
            .components(separatedBy: "\n")
            .compactMap(Self.categoryID)

        XCTAssertEqual(catalogIDs, expectedGapsCategoryIDs)

        let sidebarURL = Self.projectRoot()
            .appendingPathComponent("Examples/DiagramPlayground/Views/SidebarView.swift")
        let sidebarSource = try String(contentsOf: sidebarURL, encoding: .utf8)
        XCTAssertTrue(sidebarSource.contains("ForEach(TestDiagrams.orderedCategories)"))
    }

    func testEmbeddedFallbackContainsEveryGapsDiagramFamily() throws {
        let modelURL = Self.projectRoot()
            .appendingPathComponent("Examples/DiagramPlayground/Models/SampleDiagrams.swift")
        let modelSource = try String(contentsOf: modelURL, encoding: .utf8)
        let fallbackCategoryIDs = Set(
            modelSource
                .components(separatedBy: "\n")
                .compactMap(Self.embeddedDiagramCategoryID)
        )

        XCTAssertEqual(fallbackCategoryIDs, Set(expectedGapsCategoryIDs))
    }

    func testLoaderHasDevelopmentResourceFallback() throws {
        let modelURL = Self.projectRoot()
            .appendingPathComponent("Examples/DiagramPlayground/Models/SampleDiagrams.swift")
        let modelSource = try String(contentsOf: modelURL, encoding: .utf8)

        XCTAssertTrue(modelSource.contains("developmentResourceURL()"))
        XCTAssertTrue(modelSource.contains("#filePath"))
        XCTAssertTrue(modelSource.contains("Resources/test-diagrams.json"))
    }

    private static func categoryID(from line: String) -> String? {
        guard let idRange = line.range(of: "TestDiagramCategory(id: \"") else {
            return nil
        }

        let idStart = idRange.upperBound
        guard let idEnd = line[idStart...].firstIndex(of: "\"") else {
            return nil
        }

        return String(line[idStart..<idEnd])
    }

    private static func embeddedDiagramCategoryID(from line: String) -> String? {
        guard line.contains("TestDiagram(id:"),
              let categoryRange = line.range(of: "category: \"")
        else {
            return nil
        }

        let categoryStart = categoryRange.upperBound
        guard let categoryEnd = line[categoryStart...].firstIndex(of: "\"") else {
            return nil
        }

        return String(line[categoryStart..<categoryEnd])
    }

    private static func projectRoot() -> URL {
        var url = URL(fileURLWithPath: #file).deletingLastPathComponent()
        while url.path != "/" {
            let package = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}

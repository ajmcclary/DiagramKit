import Foundation
import Testing
import DiagramKitCommon
import DiagramKitTestSupport

@Suite struct CorpusEntryFormatIDTests {

    private static let canonicalJSON = """
    {
      "id": "fixture-1",
      "category": "flowchart",
      "name": "Fixture 1",
      "source": "graph TD\\nA-->B",
      "sources": {
        "mermaid": "graph TD\\nA-->B",
        "d2": "A -> B"
      },
      "expectedImporters": {
        "mermaid": "mermaid",
        "d2": "d2"
      }
    }
    """

    @Test("Decodes typed expectedImporters from string keys/values")
    func decodesTyped() throws {
        let entry = try JSONDecoder().decode(
            CorpusEntry.self,
            from: Data(Self.canonicalJSON.utf8)
        )
        #expect(entry.expectedImporters?[.mermaid] == .mermaid)
        #expect(entry.expectedImporters?[.d2] == .d2)
    }

    @Test("Encodes typed expectedImporters back to JSON string map")
    func encodesTyped() throws {
        let entry = try JSONDecoder().decode(
            CorpusEntry.self,
            from: Data(Self.canonicalJSON.utf8)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let map = try #require(object?["expectedImporters"] as? [String: String])
        #expect(map["mermaid"] == "mermaid")
        #expect(map["d2"] == "d2")
    }

    @Test("Unknown formatID rawValue decodes as open RawRepresentable")
    func decodesUnknownRawValue() throws {
        let json = """
        {
          "id": "fixture-2",
          "category": "flowchart",
          "name": "Fixture 2",
          "source": "x",
          "expectedImporters": {
            "asciiart": "asciiart"
          }
        }
        """
        let entry = try JSONDecoder().decode(CorpusEntry.self, from: Data(json.utf8))
        let key = DiagramFormatID(rawValue: "asciiart")
        #expect(entry.expectedImporters?[key] == DiagramFormatID(rawValue: "asciiart"))
    }

    @Test("Round-trip decode → encode → decode preserves typed dictionary")
    func roundTrip() throws {
        let first = try JSONDecoder().decode(
            CorpusEntry.self,
            from: Data(Self.canonicalJSON.utf8)
        )
        let encoded = try JSONEncoder().encode(first)
        let second = try JSONDecoder().decode(CorpusEntry.self, from: encoded)
        #expect(first.expectedImporters == second.expectedImporters)
    }

    @Test("Duplicate normalized key surfaces CorpusEntryError")
    func duplicateKeyThrows() throws {
        // Two keys that normalize to the same lowercased form.
        let json = """
        {
          "id": "fixture-3",
          "category": "flowchart",
          "name": "Fixture 3",
          "source": "x",
          "expectedImporters": {
            "mermaid": "mermaid",
            "MERMAID": "mermaid"
          }
        }
        """
        #expect(throws: CorpusEntryError.self) {
            _ = try JSONDecoder().decode(CorpusEntry.self, from: Data(json.utf8))
        }
    }
}

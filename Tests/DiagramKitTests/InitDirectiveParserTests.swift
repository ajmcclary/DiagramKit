import Testing
@testable import DiagramKitModel

@Suite("Init Directive Parser")
struct InitDirectiveParserTests {

    @Test("Single-quoted keys/values are normalized to double quotes")
    func singleQuotedKeysNormalized() throws {
        let payload = "{'theme': 'forest'}"
        let object = try #require(InitDirectiveParser.parseJSON(payload))
        #expect(object["theme"] as? String == "forest")
    }

    @Test("Apostrophes inside double-quoted values are preserved")
    func apostropheInsideDoubleQuotedValuePreserved() throws {
        let payload = #"{"title": "O'Reilly"}"#
        let object = try #require(InitDirectiveParser.parseJSON(payload))
        #expect(object["title"] as? String == "O'Reilly")
    }

    @Test("Payload extraction requires init directive")
    func payloadExtraction() {
        #expect(InitDirectiveParser.payload(from: "%%{init: {'theme': 'forest'}}%%") != nil)
        #expect(InitDirectiveParser.payload(from: "%%{other: {}}%%") == nil)
        #expect(InitDirectiveParser.payload(from: "not a directive") == nil)
    }

    @Test("Multi-line init directive payload is extracted")
    func multiLinePayloadExtraction() throws {
        let block = """
        %%{init: {
          "theme": "forest"
        }}%%
        """
        let payload = try #require(InitDirectiveParser.payload(from: block))
        let object = try #require(InitDirectiveParser.parseJSON(payload))
        #expect(object["theme"] as? String == "forest")
    }

    @Test("Multi-line init directives are stripped from preprocessed source")
    func multiLineInitDirectiveStripped() throws {
        let source = """
        %%{init: {
          "theme": "forest"
        }}%%
        graph TD
          A --> B
        """
        let (stripped, frontmatter) = _preprocessMermaidSource(source)
        #expect(stripped.contains("%%{init") == false)
        #expect(stripped.contains("graph TD"))
        #expect(frontmatter?.shared.theme == "forest")
    }
}

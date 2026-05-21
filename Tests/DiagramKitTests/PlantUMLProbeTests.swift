import Testing
@testable import DiagramKitPlantUML

@Suite struct PlantUMLProbeTests {
    @Test func extractsJSONBody() {
        let src = "@startjson\n{ \"a\": 1 }\n@endjson"
        let result = extractPlantUMLBody(src)
        #expect(result?.startKind == "json")
        #expect(result?.body.contains("\"a\"") == true)
    }

    @Test func extractsYAMLBody() {
        let src = "@startyaml\nkey: value\n@endyaml"
        let result = extractPlantUMLBody(src)
        #expect(result?.startKind == "yaml")
        #expect(result?.body.contains("key") == true)
    }

    @Test func wbsStillRecognized() {
        let src = "@startwbs\n* root\n@endwbs"
        let result = extractPlantUMLBody(src)
        #expect(result?.startKind == "wbs")
    }

    @Test func mismatchedStartEndRejected() {
        let src = "@startjson\n{ }\n@endyaml"
        #expect(extractPlantUMLBody(src) == nil)
    }

    @Test func wbsProbeAcceptsOnlyWBS() {
        #expect(isPlantUMLWBS(startKind: "wbs", "") == true)
        #expect(isPlantUMLWBS(startKind: "mindmap", "") == false)
    }

    @Test func mindmapProbeNoLongerClaimsWBS() {
        #expect(isPlantUMLMindmap(startKind: "wbs", "") == false)
        #expect(isPlantUMLMindmap(startKind: "mindmap", "") == true)
    }

    @Test func jsonProbeAcceptsOnlyJSON() {
        #expect(isPlantUMLJSON(startKind: "json", "") == true)
        #expect(isPlantUMLJSON(startKind: "yaml", "") == false)
    }

    @Test func yamlProbeAcceptsOnlyYAML() {
        #expect(isPlantUMLYAML(startKind: "yaml", "") == true)
        #expect(isPlantUMLYAML(startKind: "json", "") == false)
    }
}

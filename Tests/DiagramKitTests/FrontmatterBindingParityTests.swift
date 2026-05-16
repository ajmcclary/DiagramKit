import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
import Foundation

@Suite struct FrontmatterBindingParityTests {

    @Test("YAML Sequence config is parsed through bindings")
    func yamlSequenceConfigViaBindings() throws {
        let yamlLines = [
            "config:",
            "  sequence:",
            "    diagramMarginX: 50",
            "    useMaxWidth: \"false\"",
            "    mirrorActors: \"true\"",
            "    wrap: \"true\"",
            "    actorFontFamily: \"Courier\"",
            "    actorFontSize: 14",
            "    hideUnusedParticipants: \"true\"",
        ]

        let fm = _parseYamlFrontmatter(yamlLines)
        #expect(fm != nil, "Frontmatter should be non-nil")

        let yamlSeq = fm?.perDiagram.sequence.config
        #expect(yamlSeq != nil, "YAML should produce sequenceConfig via bindings")
        #expect(yamlSeq?.diagramMarginX == 50)
        #expect(yamlSeq?.useMaxWidth == false)
        #expect(yamlSeq?.mirrorActors == true)
        #expect(yamlSeq?.wrap == true)
        #expect(yamlSeq?.actorFontFamily == "Courier")
        #expect(yamlSeq?.actorFontSize == 14)
        #expect(yamlSeq?.hideUnusedParticipants == true)
    }

    @Test("YAML Requirement config is parsed through bindings")
    func yamlRequirementConfigViaBindings() throws {
        let yamlLines = [
            "config:",
            "  requirement:",
            "    useMaxWidth: \"false\"",
            "    rect_fill: \"#FFEEDD\"",
            "    fontSize: 14",
            "    htmlLabels: \"true\"",
        ]

        let fm = _parseYamlFrontmatter(yamlLines)
        #expect(fm != nil)

        let yamlReq = fm?.perDiagram.requirement.config
        #expect(yamlReq != nil, "YAML should produce requirementConfig via bindings")
        #expect(yamlReq?.useMaxWidth == false)
        #expect(yamlReq?.rect_fill == "#FFEEDD")
        #expect(yamlReq?.fontSize == 14)
        #expect(yamlReq?.htmlLabels == true)
    }

    @Test("YAML legacy-only keys still work alongside bindings")
    func legacyKeysStillWork() throws {
        let yamlLines = [
            "config:",
            "  gantt:",
            "    useMaxWidth: \"false\"",
            "    barHeight: 24",
            "  theme: \"forest\"",
        ]

        let fm = _parseYamlFrontmatter(yamlLines)
        #expect(fm != nil)
        #expect(fm?.perDiagram.gantt.config != nil)
        #expect(fm?.perDiagram.gantt.config?.useMaxWidth == false)
        #expect(fm?.perDiagram.gantt.config?.barHeight == 24)
        #expect(fm?.shared.theme == "forest")
    }

    @Test("YAML Radar config is parsed through bindings")
    func yamlRadarConfigViaBindings() throws {
        let yamlLines = [
            "config:",
            "  radar:",
            "    width: 800",
            "    height: 600",
            "    useMaxWidth: \"false\"",
            "    curveTension: 0.4",
        ]

        let fm = _parseYamlFrontmatter(yamlLines)
        #expect(fm != nil)
        #expect(fm?.perDiagram.radar.config != nil)
        #expect(fm?.perDiagram.radar.config?.width == 800)
        #expect(fm?.perDiagram.radar.config?.height == 600)
        #expect(fm?.perDiagram.radar.config?.useMaxWidth == false)
    }

    @Test("YAML Ishikawa config is parsed through bindings")
    func yamlIshikawaConfigViaBindings() throws {
        let yamlLines = [
            "config:",
            "  ishikawa:",
            "    diagramPadding: 20",
            "    useMaxWidth: \"true\"",
        ]

        let fm = _parseYamlFrontmatter(yamlLines)
        #expect(fm != nil)
        #expect(fm?.perDiagram.ishikawa.config != nil)
        #expect(fm?.perDiagram.ishikawa.config?.diagramPadding == 20)
        #expect(fm?.perDiagram.ishikawa.config?.useMaxWidth == true)
    }

    @Test("YAML C4 config is parsed through bindings")
    func yamlC4ConfigViaBindings() throws {
        let yamlLines = [
            "config:",
            "  c4:",
            "    useMaxWidth: \"false\"",
        ]

        let fm = _parseYamlFrontmatter(yamlLines)
        #expect(fm != nil)
        #expect(fm?.perDiagram.c4.config != nil)
    }

    @Test("YAML TreeView config is parsed through bindings")
    func yamlTreeViewConfigViaBindings() throws {
        let yamlLines = [
            "config:",
            "  treeView:",
            "    rowIndent: 40",
            "    useMaxWidth: \"true\"",
        ]

        let fm = _parseYamlFrontmatter(yamlLines)
        #expect(fm != nil)
        #expect(fm?.perDiagram.treeView.config != nil)
        #expect(fm?.perDiagram.treeView.config?.rowIndent == 40)
        #expect(fm?.perDiagram.treeView.config?.useMaxWidth == true)
    }

    @Test("YAML Venn config is parsed through bindings")
    func yamlVennConfigViaBindings() throws {
        let yamlLines = [
            "config:",
            "  venn:",
            "    useMaxWidth: \"false\"",
            "    padding: 10",
        ]

        let fm = _parseYamlFrontmatter(yamlLines)
        #expect(fm != nil)
        #expect(fm?.perDiagram.venn.config != nil)
        #expect(fm?.perDiagram.venn.config?.useMaxWidth == false)
    }
}

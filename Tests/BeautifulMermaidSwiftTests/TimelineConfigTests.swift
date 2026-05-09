import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class TimelineConfigTests: XCTestCase {

    // MARK: - Default config

    func test_defaultConfig() {
        let config = TimelineDiagramConfig()
        XCTAssertEqual(config.diagramMarginY, 10)
        XCTAssertEqual(config.leftMargin, 150)
        XCTAssertEqual(config.padding, 50)
        XCTAssertEqual(config.taskFontFamily, "\"Open Sans\", sans-serif")
        XCTAssertEqual(config.taskFontSize, 14)
        XCTAssertEqual(config.textPlacement, "fo")
        XCTAssertEqual(config.disableMulticolor, false)
    }

    func test_defaultTheme() {
        let theme = TimelineThemeConfig()
        XCTAssertEqual(theme.cScale.count, 12)
        XCTAssertEqual(theme.cScaleLabel.count, 12)
        XCTAssertEqual(theme.cScaleInv.count, 12)
        XCTAssertEqual(theme.themeColorLimit, 12)
        XCTAssertEqual(theme.fontSize, 16)
        XCTAssertEqual(theme.useGradient, false)
        XCTAssertEqual(theme.dropShadow, "none")
    }

    // MARK: - Frontmatter timeline config

    func test_frontmatter_disableMulticolor() {
        let yaml = """
        ---
        config:
          timeline:
            disableMulticolor: true
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let config = fm?.timelineConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.disableMulticolor, true)
    }

    func test_frontmatter_leftMargin() {
        let yaml = """
        ---
        config:
          timeline:
            leftMargin: 200
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let config = fm?.timelineConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.leftMargin, 200)
    }

    func test_frontmatter_padding() {
        let yaml = """
        ---
        config:
          timeline:
            padding: 75
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let config = fm?.timelineConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.padding, 75)
    }

    func test_frontmatter_useMaxWidth() {
        let yaml = """
        ---
        config:
          timeline:
            useMaxWidth: true
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let config = fm?.timelineConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.useMaxWidth, true)
    }

    func test_frontmatter_taskFontSize() {
        let yaml = """
        ---
        config:
          timeline:
            taskFontSize: 18
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let config = fm?.timelineConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.taskFontSize, 18)
    }

    func test_frontmatter_taskFontFamily() {
        let yaml = """
        ---
        config:
          timeline:
            taskFontFamily: Arial
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let config = fm?.timelineConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.taskFontFamily, "Arial")
    }

    func test_frontmatter_textPlacement() {
        let yaml = """
        ---
        config:
          timeline:
            textPlacement: tspan
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let config = fm?.timelineConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.textPlacement, "tspan")
    }

    func test_frontmatter_width() {
        let yaml = """
        ---
        config:
          timeline:
            width: 200
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let config = fm?.timelineConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.width, 200)
    }

    func test_frontmatter_height() {
        let yaml = """
        ---
        config:
          timeline:
            height: 60
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let config = fm?.timelineConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.height, 60)
    }

    // MARK: - Theme variables

    func test_frontmatter_cScaleOverrides() {
        let yaml = """
        ---
        config:
          themeVariables:
            cScale0: "#FF0000"
            cScale1: "#00FF00"
            cScale2: "#0000FF"
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.timelineTheme
        XCTAssertNotNil(theme)
        XCTAssertEqual(theme?.cScale[0], "#FF0000")
        XCTAssertEqual(theme?.cScale[1], "#00FF00")
        XCTAssertEqual(theme?.cScale[2], "#0000FF")
    }

    func test_frontmatter_cScaleLabelOverrides() {
        let yaml = """
        ---
        config:
          themeVariables:
            cScaleLabel0: "#000000"
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.timelineTheme
        XCTAssertNotNil(theme)
        XCTAssertEqual(theme?.cScaleLabel[0], "#000000")
    }

    func test_frontmatter_cScaleInvOverrides() {
        let yaml = """
        ---
        config:
          themeVariables:
            cScaleInv0: "#111111"
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.timelineTheme
        XCTAssertNotNil(theme)
        XCTAssertEqual(theme?.cScaleInv[0], "#111111")
    }

    func test_frontmatter_themeColorLimit() {
        let yaml = """
        ---
        config:
          themeVariables:
            THEME_COLOR_LIMIT: 6
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.timelineTheme
        XCTAssertNotNil(theme)
        XCTAssertEqual(theme?.themeColorLimit, 6)
    }

    func test_frontmatter_useGradient() {
        let yaml = """
        ---
        config:
          themeVariables:
            useGradient: true
            gradientStart: "#ececff"
            gradientStop: "#ffffff"
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.timelineTheme
        XCTAssertNotNil(theme)
        XCTAssertEqual(theme?.useGradient, true)
        XCTAssertEqual(theme?.gradientStart, "#ececff")
        XCTAssertEqual(theme?.gradientStop, "#ffffff")
    }

    func test_frontmatter_themeVariables_flat() {
        let yaml = """
        ---
        themeVariables:
          cScale0: "#AAAAAA"
          fontSize: 20
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        let theme = fm?.timelineTheme
        XCTAssertNotNil(theme)
        XCTAssertEqual(theme?.cScale[0], "#AAAAAA")
        XCTAssertEqual(theme?.fontSize, 20)
    }

    // MARK: - Theme and look

    func test_frontmatter_globalTheme() {
        let yaml = """
        ---
        config:
          theme: forest
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertEqual(fm?.theme, "forest")
    }

    func test_frontmatter_globalLook() {
        let yaml = """
        ---
        config:
          look: neo
        ---
        timeline
            2020 : Event
        """
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertEqual(fm?.look, "neo")
    }

    // MARK: - colorIndex helper

    func test_colorIndex_wraps() {
        let theme = TimelineThemeConfig()
        XCTAssertEqual(theme.colorIndex(0), 0)
        XCTAssertEqual(theme.colorIndex(11), 11)
        XCTAssertEqual(theme.colorIndex(12), 0)
        XCTAssertEqual(theme.colorIndex(13), 1)
    }

    func test_colorIndex_negative() {
        let theme = TimelineThemeConfig()
        XCTAssertEqual(theme.colorIndex(-1), 11)
    }
}

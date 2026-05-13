import Testing
@testable import DiagramKitModel

@Suite("FrontmatterPrefixMatcher")
struct FrontmatterPrefixMatcherTests {

    @Test("Returns trailing key when path starts with a listed prefix")
    func extractsTrailingKey() {
        let key = FrontmatterPrefixMatcher.extractKey(
            path: "config.er.diagramPadding",
            prefixes: ["config.er.", "er."]
        )
        #expect(key == "diagramPadding")
    }

    @Test("Tries each prefix in order")
    func tiesGoToFirstMatchingPrefix() {
        let key = FrontmatterPrefixMatcher.extractKey(
            path: "er.fontSize",
            prefixes: ["config.er.", "er."]
        )
        #expect(key == "fontSize")
    }

    @Test("Returns nil when no prefix matches")
    func returnsNilWhenNoMatch() {
        let key = FrontmatterPrefixMatcher.extractKey(
            path: "unrelated.key",
            prefixes: ["config.er.", "er."]
        )
        #expect(key == nil)
    }
}

private struct TestConfig: Sendable, Equatable {
    var titleTopMargin: Double = 0
    var useMaxWidth: Bool = false
}

private struct TestTheme: Sendable, Equatable {
    var fg: String = ""
    var bg: String = ""
}

@Suite("SingleSectionBinding")
struct SingleSectionBindingTests {

    @Test("apply flips hasSection and updates config when the key matches")
    func applyMatchesPrefixAndKey() {
        var binding = SingleSectionBinding(config: TestConfig())
        let matched = binding.apply(
            path: "config.test.titleTopMargin",
            value: FrontmatterValue(raw: "12"),
            prefixes: ["config.test.", "test."]
        ) { key, value, config in
            switch key {
            case "titleTopMargin":
                guard let v = value.double else { return false }
                config.titleTopMargin = v
                return true
            default:
                return false
            }
        }
        #expect(matched == true)
        #expect(binding.hasSection == true)
        #expect(binding.config.titleTopMargin == 12)
    }

    @Test("apply returns false when no prefix matches")
    func applyReturnsFalseOnPrefixMiss() {
        var binding = SingleSectionBinding(config: TestConfig())
        let matched = binding.apply(
            path: "unrelated.titleTopMargin",
            value: FrontmatterValue(raw: "12"),
            prefixes: ["config.test.", "test."]
        ) { _, _, _ in true }
        #expect(matched == false)
        #expect(binding.hasSection == false)
        #expect(binding.config == TestConfig())
    }

    @Test("apply returns false when applyConfig rejects the value")
    func applyReturnsFalseOnApplyRejection() {
        var binding = SingleSectionBinding(config: TestConfig())
        let matched = binding.apply(
            path: "config.test.titleTopMargin",
            value: FrontmatterValue(raw: "not-a-double"),
            prefixes: ["config.test."]
        ) { key, value, config in
            switch key {
            case "titleTopMargin":
                guard let v = value.double else { return false }
                config.titleTopMargin = v
                return true
            default: return false
            }
        }
        #expect(matched == false)
        #expect(binding.hasSection == false)
    }
}

@Suite("ConfigThemeBinding")
struct ConfigThemeBindingTests {

    @Test("apply routes config-prefixed paths to the config applier")
    func applyRoutesConfigPaths() {
        var binding = ConfigThemeBinding(config: TestConfig(), theme: TestTheme())
        let matched = binding.apply(
            path: "config.packet.titleTopMargin",
            value: FrontmatterValue(raw: "8"),
            configPrefixes: ["config.packet.", "packet."],
            themePrefixes: ["config.themeVariables.packet."],
            applyConfig: { key, value, config in
                guard key == "titleTopMargin", let v = value.double else { return false }
                config.titleTopMargin = v
                return true
            },
            applyTheme: { _, _, _ in false }
        )
        #expect(matched == true)
        #expect(binding.hasConfig == true)
        #expect(binding.hasTheme == false)
        #expect(binding.config.titleTopMargin == 8)
    }

    @Test("apply routes theme-prefixed paths to the theme applier")
    func applyRoutesThemePaths() {
        var binding = ConfigThemeBinding(config: TestConfig(), theme: TestTheme())
        let matched = binding.apply(
            path: "config.themeVariables.packet.fg",
            value: FrontmatterValue(raw: "#000"),
            configPrefixes: ["config.packet."],
            themePrefixes: ["config.themeVariables.packet.", "themeVariables.packet."],
            applyConfig: { _, _, _ in false },
            applyTheme: { key, value, theme in
                guard key == "fg" else { return false }
                theme.fg = value.string
                return true
            }
        )
        #expect(matched == true)
        #expect(binding.hasConfig == false)
        #expect(binding.hasTheme == true)
        #expect(binding.theme.fg == "#000")
    }

    @Test("apply returns false when neither prefix matches")
    func applyReturnsFalseOnDoubleMiss() {
        var binding = ConfigThemeBinding(config: TestConfig(), theme: TestTheme())
        let matched = binding.apply(
            path: "totally.unrelated.key",
            value: FrontmatterValue(raw: "x"),
            configPrefixes: ["config.packet."],
            themePrefixes: ["config.themeVariables.packet."],
            applyConfig: { _, _, _ in true },
            applyTheme: { _, _, _ in true }
        )
        #expect(matched == false)
        #expect(binding.hasConfig == false)
        #expect(binding.hasTheme == false)
    }
}

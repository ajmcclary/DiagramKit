//
//  LiveEditorConfigTests.swift
//  DiagramKitTests
//
//  Tests for JSONValue encoding/decoding, key path access,
//  unknown key preservation, and config extraction logic.
//

import Foundation
import XCTest
@testable import DiagramKitModel

final class JSONValueTests: XCTestCase {

    // MARK: - Encoding/Decoding

    func testDecodeObject() throws {
        let json = """
        {"theme": "dark", "padding": 50}
        """.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case .object(let dict) = value else {
            XCTFail("Expected object, got \(value)")
            return
        }
        XCTAssertEqual(dict["theme"]?.stringValue, "dark")
        XCTAssertEqual(dict["padding"]?.doubleValue, 50)
    }

    func testDecodeNestedObject() throws {
        let json = """
        {"flowchart": {"padding": 60, "nodeSpacing": 30}}
        """.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        XCTAssertEqual(value[["flowchart", "padding"]]?.doubleValue, 60)
        XCTAssertEqual(value[["flowchart", "nodeSpacing"]]?.doubleValue, 30)
    }

    func testDecodeArray() throws {
        let json = """
        [1, 2, 3]
        """.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case .array(let items) = value else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].doubleValue, 1)
    }

    func testDecodeNull() throws {
        let json = """
        {"key": null}
        """.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case .object(let dict) = value,
              case .null = dict["key"] else {
            XCTFail("Expected null value")
            return
        }
    }

    func testDecodeBool() throws {
        let json = """
        {"enabled": true, "disabled": false}
        """.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        XCTAssertEqual(value[["enabled"]]?.boolValue, true)
        XCTAssertEqual(value[["disabled"]]?.boolValue, false)
    }

    func testRoundTripPreservesAllKeys() throws {
        let original = """
        {"theme":"dark","unknownSetting":"value123","nested":{"inner":true}}
        """
        let data = original.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        let encoded = try JSONEncoder().encode(value)
        let redecoded = try JSONDecoder().decode(JSONValue.self, from: encoded)

        // All keys should survive
        XCTAssertEqual(redecoded[["theme"]]?.stringValue, "dark")
        XCTAssertEqual(redecoded[["unknownSetting"]]?.stringValue, "value123")
        XCTAssertEqual(redecoded[["nested", "inner"]]?.boolValue, true)
    }

    func testInvalidJSONThrows() {
        let json = """
        {invalid json here}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(JSONValue.self, from: json))
    }

    // MARK: - Key path access

    func testKeyPathLookupDeeplyNested() throws {
        let json = """
        {"a": {"b": {"c": "found"}}}
        """.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        XCTAssertEqual(value[["a", "b", "c"]]?.stringValue, "found")
    }

    func testKeyPathLookupMissingReturnsNil() throws {
        let json = """
        {"a": 1}
        """.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        XCTAssertNil(value[["a", "b"]])
        XCTAssertNil(value[["nonexistent"]])
    }

    // MARK: - Flattened representation

    func testFlattenedObject() throws {
        let json = """
        {"theme": "dark", "layout": {"padding": 50}}
        """.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        let flat = value.flattened()
        let flatDict = Dictionary(uniqueKeysWithValues: flat.map { ($0.0.joined(separator: "."), $0.1) })

        XCTAssertEqual(flatDict["theme"]?.stringValue, "dark")
        XCTAssertEqual(flatDict["layout.padding"]?.doubleValue, 50)
    }

    // MARK: - Empty/edge cases

    func testEmptyObject() throws {
        let json = "{}".data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case .object(let dict) = value else {
            XCTFail("Expected object")
            return
        }
        XCTAssertTrue(dict.isEmpty)
    }

    func testEmptyArray() throws {
        let json = "[]".data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case .array(let items) = value else {
            XCTFail("Expected array")
            return
        }
        XCTAssertTrue(items.isEmpty)
    }

    func testStringWithSpecialCharacters() throws {
        let json = """
        {"message": "hello\\nworld\\t!"}
        """.data(using: .utf8)!
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        XCTAssertEqual(value[["message"]]?.stringValue, "hello\nworld\t!")
    }
}

// MARK: - Config extraction tests (using JSONValue + LayoutConfig)

final class LiveEditorConfigExtractionTests: XCTestCase {

    /// Simulates the extraction logic from LiveEditorConfig using JSONValue + LayoutConfig.
    /// These tests validate the core extraction behavior without depending on the playground target.

    func testExtractLayoutDefaultsWhenNoConfig() throws {
        let json = "{}".data(using: .utf8)!
        let tree = try JSONDecoder().decode(JSONValue.self, from: json)
        let config = extractLayout(from: tree)
        XCTAssertEqual(config.padding, 40)
        XCTAssertEqual(config.nodeSpacing, 28)
        XCTAssertEqual(config.layerSpacing, 48)
        XCTAssertEqual(config.componentSpacing, 20)
    }

    func testExtractLayoutTopLevelKeys() throws {
        let json = """
        {"padding": 60, "nodeSpacing": 35, "layerSpacing": 55, "componentSpacing": 25}
        """.data(using: .utf8)!
        let tree = try JSONDecoder().decode(JSONValue.self, from: json)
        let config = extractLayout(from: tree)
        XCTAssertEqual(config.padding, 60)
        XCTAssertEqual(config.nodeSpacing, 35)
        XCTAssertEqual(config.layerSpacing, 55)
        XCTAssertEqual(config.componentSpacing, 25)
    }

    func testExtractLayoutPartialKeysUsesDefaults() throws {
        let json = """
        {"padding": 80}
        """.data(using: .utf8)!
        let tree = try JSONDecoder().decode(JSONValue.self, from: json)
        let config = extractLayout(from: tree)
        XCTAssertEqual(config.padding, 80)
        XCTAssertEqual(config.nodeSpacing, 28)   // default
        XCTAssertEqual(config.layerSpacing, 48)  // default
    }

    func testExtractLayoutNestedFlowchartPadding() throws {
        let json = """
        {"flowchart": {"padding": 100}}
        """.data(using: .utf8)!
        let tree = try JSONDecoder().decode(JSONValue.self, from: json)
        let config = extractLayout(from: tree)
        XCTAssertEqual(config.padding, 100)
    }

    func testUnknownKeysArePreserved() throws {
        let json = """
        {"theme": "dark", "customField": "hello", "another": 42}
        """.data(using: .utf8)!
        let tree = try JSONDecoder().decode(JSONValue.self, from: json)

        // Collect unknown keys (matching LiveEditorConfig logic)
        let recognizedKeys: Set<String> = [
            "theme", "themeVariables",
            "padding", "nodeSpacing", "layerSpacing", "componentSpacing",
            "flowchart", "config"
        ]
        var unknowns: [String: JSONValue] = [:]
        if case .object(let dict) = tree {
            for (key, value) in dict {
                if !recognizedKeys.contains(key) {
                    unknowns[key] = value
                }
            }
        }

        XCTAssertEqual(unknowns.count, 2)
        XCTAssertEqual(unknowns["customField"]?.stringValue, "hello")
        XCTAssertEqual(unknowns["another"]?.doubleValue, 42)
        // Known key "theme" should not be in unknowns
        XCTAssertNil(unknowns["theme"])
    }

    func testThemeExtractionFromTopLevel() throws {
        let json = """
        {"theme": "dark"}
        """.data(using: .utf8)!
        let tree = try JSONDecoder().decode(JSONValue.self, from: json)

        // Simulate theme extraction
        var themeName: String? = nil
        if case .object(let dict) = tree, let themeValue = dict["theme"] {
            if let themeString = themeValue.stringValue {
                // Simple aliases
                switch themeString.lowercased() {
                case "dark": themeName = "Zinc Dark"
                case "light", "default": themeName = "Zinc Light"
                default: themeName = themeString
                }
            }
        }

        XCTAssertEqual(themeName, "Zinc Dark")
    }

    func testThemeExtractionDefault() throws {
        let json = """
        {"theme": "default"}
        """.data(using: .utf8)!
        let tree = try JSONDecoder().decode(JSONValue.self, from: json)

        var themeName: String? = nil
        if case .object(let dict) = tree, let themeValue = dict["theme"] {
            if let themeString = themeValue.stringValue {
                switch themeString.lowercased() {
                case "dark": themeName = "Zinc Dark"
                case "light", "default": themeName = "Zinc Light"
                default: themeName = themeString
                }
            }
        }

        XCTAssertEqual(themeName, "Zinc Light")
    }

    // MARK: - Helpers (mirrors LiveEditorConfig extraction)

    private func extractLayout(from tree: JSONValue) -> LayoutConfig {
        guard case .object(let dict) = tree else {
            return LayoutConfig()
        }

        let padding = dict["padding"]?.doubleValue
        let nodeSpacing = dict["nodeSpacing"]?.doubleValue
        let layerSpacing = dict["layerSpacing"]?.doubleValue
        let componentSpacing = dict["componentSpacing"]?.doubleValue

        let nestedPadding = dict["flowchart"]?.objectValue?["padding"]?.doubleValue
            ?? dict["config"]?.objectValue?["padding"]?.doubleValue

        return LayoutConfig(
            padding: padding ?? nestedPadding ?? 40,
            nodeSpacing: nodeSpacing ?? 28,
            layerSpacing: layerSpacing ?? 48,
            componentSpacing: componentSpacing ?? 20
        )
    }
}

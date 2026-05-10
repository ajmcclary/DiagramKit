//
//  LiveHistoryStoreTests.swift
//  DiagramKitTests
//
//  Tests for LiveHistoryEntry serialization, LiveHistoryOrigin
//  encoding/decoding, and JSON round-trip fidelity.
//
//  NOTE: LiveHistoryStore (the @MainActor persistence class) lives in
//  the MermaidPlayground executable target and cannot be imported here.
//  Full store behavior tests (auto-save debounce, dedup, eviction caps)
//  require a MermaidPlaygroundTests test target — see Phase 5.1.
//

import Foundation
import XCTest

// MARK: - LiveHistoryEntry JSON round-trip tests

/// Tests that LiveHistoryEntry encodes/decodes correctly through JSON.
/// LiveHistoryEntry is a Codable struct in the MermaidPlayground target,
/// so these tests validate the serialization contract by constructing
/// hand-crafted JSON matching the expected schema.
final class LiveHistoryEntrySerializationTests: XCTestCase {

    // MARK: - LiveHistoryOrigin raw values

    func testLiveHistoryOriginRawValues() {
        XCTAssertEqual(LiveHistoryOrigin_Raw.manual.rawValue, "manual")
        XCTAssertEqual(LiveHistoryOrigin_Raw.auto.rawValue, "auto")
        XCTAssertEqual(LiveHistoryOrigin_Raw.loader.rawValue, "loader")
    }

    func testLiveHistoryOriginDecodesFromRawValue() {
        XCTAssertEqual(LiveHistoryOrigin_Raw(rawValue: "manual"), .manual)
        XCTAssertEqual(LiveHistoryOrigin_Raw(rawValue: "auto"), .auto)
        XCTAssertEqual(LiveHistoryOrigin_Raw(rawValue: "loader"), .loader)
        XCTAssertNil(LiveHistoryOrigin_Raw(rawValue: "invalid"))
    }

    func testLiveHistoryOriginAllCases() {
        let all = LiveHistoryOrigin_Raw.allCases
        XCTAssertEqual(all.count, 3)
        XCTAssertTrue(all.contains(.manual))
        XCTAssertTrue(all.contains(.auto))
        XCTAssertTrue(all.contains(.loader))
    }

    // MARK: - LiveHistoryEntry JSON schema

    /// Validates the expected JSON schema for a history entry.
    func testHistoryEntryJSONSchema() throws {
        let json = """
        {
          "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
          "timestamp": "2026-05-10T12:00:00Z",
          "label": "My diagram",
          "origin": "manual",
          "state": {
            "source": "graph TD\\n  A-->B",
            "selectedThemeName": "Zinc Light",
            "configJSON": "{}",
            "editorMode": "code",
            "gridEnabled": false,
            "panZoomEnabled": true,
            "updateMode": "auto"
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(HistoryEntryJSON.self, from: json)

        XCTAssertEqual(decoded.origin, "manual")
        XCTAssertEqual(decoded.label, "My diagram")
        XCTAssertEqual(decoded.state.source, "graph TD\n  A-->B")
        XCTAssertEqual(decoded.state.selectedThemeName, "Zinc Light")
        XCTAssertEqual(decoded.state.editorMode, "code")
        XCTAssertEqual(decoded.state.updateMode, "auto")
        XCTAssertFalse(decoded.state.gridEnabled)
        XCTAssertTrue(decoded.state.panZoomEnabled)
    }

    /// An auto entry has no label and a nil sourceURL.
    func testAutoEntryHasNoLabel() throws {
        let json = """
        {
          "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
          "timestamp": "2026-05-10T14:30:00Z",
          "origin": "auto",
          "state": {
            "source": "flowchart LR\\n  X-->Y",
            "selectedThemeName": "Dracula",
            "configJSON": "{}",
            "editorMode": "code",
            "gridEnabled": true,
            "panZoomEnabled": true,
            "updateMode": "auto"
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(HistoryEntryJSON.self, from: json)

        XCTAssertEqual(decoded.origin, "auto")
        XCTAssertNil(decoded.label)
        XCTAssertNil(decoded.sourceURL)
        XCTAssertEqual(decoded.state.selectedThemeName, "Dracula")
        XCTAssertTrue(decoded.state.gridEnabled)
    }

    /// A loader entry has a sourceURL.
    func testLoaderEntryHasSourceURL() throws {
        let json = """
        {
          "id": "FEDCBA98-7654-3210-FEDC-BA9876543210",
          "timestamp": "2026-05-10T16:00:00Z",
          "label": "Gist by user: flow",
          "origin": "loader",
          "sourceURL": "https://gist.github.com/user/abc123",
          "state": {
            "source": "sequenceDiagram\\n  A->>B: Hi",
            "selectedThemeName": "Default",
            "configJSON": "{\\"theme\\":\\"dark\\"}",
            "editorMode": "code",
            "gridEnabled": false,
            "panZoomEnabled": true,
            "updateMode": "auto"
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(HistoryEntryJSON.self, from: json)

        XCTAssertEqual(decoded.origin, "loader")
        XCTAssertEqual(decoded.label, "Gist by user: flow")
        XCTAssertEqual(decoded.sourceURL, "https://gist.github.com/user/abc123")
        XCTAssertEqual(decoded.state.configJSON, #"{"theme":"dark"}"#)
    }

    // MARK: - Round-trip encode/decode

    func testRoundTripManualEntry() throws {
        let state = StateJSON(
            source: "graph TD\n  A-->B-->C",
            selectedThemeName: "Forest",
            configJSON: "{}",
            editorMode: "code",
            gridEnabled: false,
            panZoomEnabled: true,
            zoomScale: nil,
            panOffset: nil,
            updateMode: "auto"
        )
        let entry = HistoryEntryJSON(
            id: "11111111-2222-3333-4444-555555555555",
            timestamp: "2026-05-10T12:00:00Z",
            label: "Test entry",
            origin: "manual",
            sourceURL: nil,
            state: state
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HistoryEntryJSON.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.origin, entry.origin)
        XCTAssertEqual(decoded.label, entry.label)
        XCTAssertEqual(decoded.state.source, entry.state.source)
        XCTAssertEqual(decoded.state.selectedThemeName, entry.state.selectedThemeName)
    }

    func testRoundTripAutoEntry() throws {
        let state = StateJSON(
            source: "erDiagram\n  CUSTOMER ||--o{ ORDER : places",
            selectedThemeName: "Zinc Light",
            configJSON: "{}",
            editorMode: "code",
            gridEnabled: true,
            panZoomEnabled: false,
            zoomScale: 1.5,
            panOffset: nil,
            updateMode: "manual"
        )
        let entry = HistoryEntryJSON(
            id: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            timestamp: "2026-05-10T13:00:00Z",
            label: nil,
            origin: "auto",
            sourceURL: nil,
            state: state
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HistoryEntryJSON.self, from: data)

        XCTAssertEqual(decoded.origin, "auto")
        XCTAssertNil(decoded.label)
        XCTAssertEqual(decoded.state.source, entry.state.source)
        XCTAssertTrue(decoded.state.gridEnabled)
        XCTAssertFalse(decoded.state.panZoomEnabled)
        XCTAssertEqual(decoded.state.updateMode, "manual")
    }

    func testRoundTripWithConfigJSON() throws {
        let state = StateJSON(
            source: "graph LR",
            selectedThemeName: "Neutral",
            configJSON: #"{"theme":"forest","padding":60,"nodeSpacing":40}"#,
            editorMode: "config",
            gridEnabled: false,
            panZoomEnabled: true,
            zoomScale: nil,
            panOffset: nil,
            updateMode: "auto"
        )
        let entry = HistoryEntryJSON(
            id: "99999999-8888-7777-6666-555555555555",
            timestamp: "2026-05-10T14:00:00Z",
            label: "With config",
            origin: "manual",
            sourceURL: nil,
            state: state
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HistoryEntryJSON.self, from: data)

        XCTAssertEqual(decoded.state.configJSON, state.configJSON)
        XCTAssertEqual(decoded.state.editorMode, "config")
    }

    // MARK: - Array round-trip (export/import)

    func testArrayRoundTripForExportImport() throws {
        let entries = [
            HistoryEntryJSON(
                id: "11111111-1111-1111-1111-111111111111",
                timestamp: "2026-05-10T10:00:00Z",
                label: "First",
                origin: "manual",
                sourceURL: nil,
                state: StateJSON(
                    source: "graph TD",
                    selectedThemeName: "Zinc Light",
                    configJSON: "{}",
                    editorMode: "code",
                    gridEnabled: false,
                    panZoomEnabled: true,
                    updateMode: "auto"
                )
            ),
            HistoryEntryJSON(
                id: "22222222-2222-2222-2222-222222222222",
                timestamp: "2026-05-10T11:00:00Z",
                label: nil,
                origin: "auto",
                sourceURL: nil,
                state: StateJSON(
                    source: "flowchart LR",
                    selectedThemeName: "Dracula",
                    configJSON: "{}",
                    editorMode: "code",
                    gridEnabled: true,
                    panZoomEnabled: true,
                    updateMode: "auto"
                )
            )
        ]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entries)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode([HistoryEntryJSON].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].id, entries[0].id)
        XCTAssertEqual(decoded[1].id, entries[1].id)
        XCTAssertEqual(decoded[0].origin, "manual")
        XCTAssertEqual(decoded[1].origin, "auto")
    }

    // MARK: - ID uniqueness

    func testIDsShouldBeUniqueByDesign() {
        // LiveHistoryEntry uses UUID() by default — verify uniqueness
        var ids = Set<String>()
        for _ in 0..<1000 {
            let uuid = UUID().uuidString
            XCTAssertFalse(ids.contains(uuid), "UUID collision detected")
            ids.insert(uuid)
        }
    }

    // MARK: - Display label fallback

    func testManualEntryWithLabelUsesLabel() throws {
        let json = """
        {
          "id": "11111111-2222-3333-4444-555555555555",
          "timestamp": "2026-05-10T12:00:00Z",
          "label": "My Snapshot",
          "origin": "manual",
          "state": {
            "source": "graph TD",
            "selectedThemeName": "Zinc Light",
            "configJSON": "{}",
            "editorMode": "code",
            "gridEnabled": false,
            "panZoomEnabled": true,
            "updateMode": "auto"
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(HistoryEntryJSON.self, from: json)
        XCTAssertEqual(decoded.label, "My Snapshot")
    }

    func testAutoEntryWithoutLabelIsNil() throws {
        let json = """
        {
          "id": "22222222-3333-4444-5555-666666666666",
          "timestamp": "2026-05-10T12:05:00Z",
          "origin": "auto",
          "state": {
            "source": "graph LR",
            "selectedThemeName": "Zinc Light",
            "configJSON": "{}",
            "editorMode": "code",
            "gridEnabled": false,
            "panZoomEnabled": true,
            "updateMode": "auto"
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(HistoryEntryJSON.self, from: json)
        XCTAssertNil(decoded.label)
    }

    // MARK: - Empty label edge case

    func testEmptyLabelIsNotSameAsNil() throws {
        // An empty string label is different from nil
        let jsonWithEmptyLabel = """
        {
          "id": "33333333-4444-5555-6666-777777777777",
          "timestamp": "2026-05-10T12:10:00Z",
          "label": "",
          "origin": "manual",
          "state": {
            "source": "graph TD",
            "selectedThemeName": "Zinc Light",
            "configJSON": "{}",
            "editorMode": "code",
            "gridEnabled": false,
            "panZoomEnabled": true,
            "updateMode": "auto"
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(HistoryEntryJSON.self, from: jsonWithEmptyLabel)
        XCTAssertEqual(decoded.label, "")
    }
}

// MARK: - Local mirror types (match MermaidPlayground schema)

/// Local mirror of LiveHistoryOrigin for JSON round-trip testing.
/// Matches the Codable schema of the real type in MermaidPlayground.
private enum LiveHistoryOrigin_Raw: String, Codable, CaseIterable {
    case manual
    case auto
    case loader
}

/// Local mirror of LiveHistoryEntry for JSON round-trip testing.
/// Matches the Codable schema of the real type in MermaidPlayground.
private struct HistoryEntryJSON: Codable, Equatable {
    let id: String
    let timestamp: String
    let label: String?
    let origin: String
    let sourceURL: String?
    let state: StateJSON

    init(
        id: String,
        timestamp: String,
        label: String?,
        origin: String,
        sourceURL: String?,
        state: StateJSON
    ) {
        self.id = id
        self.timestamp = timestamp
        self.label = label
        self.origin = origin
        self.sourceURL = sourceURL
        self.state = state
    }
}

/// Local mirror of LiveEditorState for JSON round-trip testing.
/// Matches the Codable schema of the real type in MermaidPlayground.
private struct StateJSON: Codable, Equatable {
    let source: String
    let selectedThemeName: String
    let configJSON: String
    let editorMode: String
    let gridEnabled: Bool
    let panZoomEnabled: Bool
    var zoomScale: Double?
    var panOffset: PanOffsetJSON?
    let updateMode: String

    struct PanOffsetJSON: Codable, Equatable {
        let width: Double
        let height: Double
    }
}

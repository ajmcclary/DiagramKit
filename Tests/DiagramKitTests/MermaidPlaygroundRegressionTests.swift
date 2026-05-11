//
//  MermaidPlaygroundRegressionTests.swift
//  DiagramKitTests
//
//  Regression tests for the Swift-native Mermaid playground. These import
//  the actual executable target so the live-editor store, codecs, loaders,
//  and export paths are covered directly instead of mirrored in test helpers.
//

#if canImport(CoreGraphics)
import CoreGraphics
import Foundation
import XCTest
import DiagramKit
import DiagramKitModel
@testable import MermaidPlayground
#if canImport(AppKit)
import AppKit
#endif

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
@MainActor
final class MermaidPlaygroundStoreRegressionTests: XCTestCase {
    func testManualConfigThemeChangeMarksDirtyWithoutRequestingRender() {
        let store = LiveEditorStore(state: LiveEditorState(updateMode: .manual))
        let initialGeneration = store.renderGeneration

        store.setConfigJSON(#"{"theme":"dark"}"#)

        XCTAssertEqual(store.renderGeneration, initialGeneration)
        XCTAssertTrue(store.isDirty)
        XCTAssertEqual(store.state.selectedThemeName, "Zinc Dark")
    }

    func testManualSourceChangeDoesNotAdvancePreviewUntilRenderNow() {
        let originalSource = "graph TD\n  A --> B"
        let updatedSource = "graph TD\n  A --> C"
        let store = LiveEditorStore(
            state: LiveEditorState(source: originalSource, updateMode: .manual)
        )

        store.setSource(updatedSource, origin: .user)

        XCTAssertEqual(store.state.source, updatedSource)
        XCTAssertEqual(store.previewSource, originalSource)
        XCTAssertTrue(store.isDirty)

        store.renderNow()

        XCTAssertEqual(store.previewSource, updatedSource)
        XCTAssertFalse(store.isDirty)
    }

    func testPreviewZoomAndPanPersistOnEditorState() {
        let store = LiveEditorStore()

        store.setPreviewZoomScale(2.5)
        store.setPreviewPanOffset(CGSize(width: 32, height: -18))

        XCTAssertEqual(store.state.zoomScale, 2.5)
        XCTAssertEqual(store.state.panOffset, CGSize(width: 32, height: -18))
    }

    func testLiveEditorStateCodecRoundTripsActualPlaygroundState() throws {
        let state = LiveEditorState(
            source: "sequenceDiagram\n  Alice->>Bob: Hi",
            selectedThemeName: "Dracula",
            configJSON: #"{"theme":"dark","padding":80}"#,
            editorMode: .config,
            gridEnabled: true,
            panZoomEnabled: false,
            zoomScale: 1.75,
            panOffset: CGSize(width: 10, height: 20),
            updateMode: .manual
        )

        let encoded = LiveEditorStateCodec.encode(state)
        let decoded = try LiveEditorStateCodec.decode(encoded)

        XCTAssertEqual(decoded, state)
    }

    func testLiveHistoryStoreSavesAndImportsActualEntries() throws {
        let sourceURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let importURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        let store = LiveHistoryStore(storageURL: sourceURL)
        let state = LiveEditorState(source: "graph LR\n  A --> B")

        let saved = store.save(state: state, label: "Manual")
        let exported = try store.exportData()
        let importStore = LiveHistoryStore(storageURL: importURL)

        XCTAssertEqual(try importStore.importData(exported), 1)
        XCTAssertEqual(importStore.entries.first?.id, saved.id)
        XCTAssertEqual(importStore.restore(saved), state)
    }

    func testDebouncedCodeEditCommitsToOriginalEditorModeAfterModeSwitch() async throws {
        #if canImport(AppKit)
        let originalConfig = #"{"theme":"dark"}"#
        let editedSource = "sequenceDiagram\n  Alice->>Bob: Hi"
        let store = LiveEditorStore(
            state: LiveEditorState(
                source: "graph TD\n  A --> B",
                configJSON: originalConfig
            )
        )
        let coordinator = NativeCodeEditor.Coordinator(store: store, mode: .code)
        let textView = NSTextView()
        textView.string = editedSource
        coordinator.textView = textView

        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        coordinator.mode = .config
        try await Task.sleep(for: .milliseconds(450))

        XCTAssertEqual(store.state.source, editedSource)
        XCTAssertEqual(store.state.configJSON, originalConfig)
        #endif
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class MermaidPlaygroundLoaderRegressionTests: XCTestCase {
    func testGistRevisionURLExtractsGistIDNotRevisionID() throws {
        let url = try XCTUnwrap(URL(string: "https://gist.github.com/octocat/0123456789abcdef0123456789abcdef/fedcba9876543210fedcba9876543210"))

        XCTAssertEqual(
            GistLoader.extractGistID(from: url),
            "0123456789abcdef0123456789abcdef"
        )
    }

    func testSingleComponentGistURLStillExtractsID() throws {
        let url = try XCTUnwrap(URL(string: "https://gist.github.com/0123456789abcdef0123456789abcdef"))

        XCTAssertEqual(
            GistLoader.extractGistID(from: url),
            "0123456789abcdef0123456789abcdef"
        )
    }

    func testImportedConfigSanitizerPreservesSupportedSharedKeys() throws {
        let raw = """
        {
          "htmlLabels": false,
          "securityLevel": "sandbox",
          "__proto__": { "polluted": true },
          "nested": { "__defineGetter__": "polluted" }
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8))

        let cleaned = ConfigSanitizer.stripUnsafe(from: value)

        XCTAssertEqual(cleaned[["htmlLabels"]], .bool(false))
        XCTAssertEqual(cleaned[["securityLevel"]], .string("sandbox"))
        XCTAssertNil(cleaned[["__proto__"]])
        XCTAssertNil(cleaned[["nested", "__defineGetter__"]])
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class MermaidPlaygroundExportRegressionTests: XCTestCase {
    func testSVGRendererHonorsLayoutConfig() async throws {
        let source = "graph TD\n  A[Start] --> B[End]"
        let defaultSVG = try await MermaidImageRenderer(
            theme: .default,
            config: LayoutConfig()
        )
        .renderSVG(from: source)
        let paddedSVG = try await MermaidImageRenderer(
            theme: .default,
            config: LayoutConfig(padding: 140)
        )
        .renderSVG(from: source)

        XCTAssertNotEqual(defaultSVG, paddedSVG)
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class MermaidPlaygroundActionsRegressionTests: XCTestCase {
    func testRawURLLoadIsEnabledWhenOnlyConfigURLIsProvided() {
        XCTAssertFalse(ActionsView.isRawURLLoadDisabled(
            codeURLString: "",
            configURLString: "https://example.com/config.json",
            isLoading: false
        ))
        XCTAssertTrue(ActionsView.isRawURLLoadDisabled(
            codeURLString: "",
            configURLString: "",
            isLoading: false
        ))
        XCTAssertTrue(ActionsView.isRawURLLoadDisabled(
            codeURLString: "https://example.com/code.mmd",
            configURLString: "",
            isLoading: true
        ))
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class MermaidPlaygroundVersionRegressionTests: XCTestCase {
    func testVersionSecurityPanelReportsRendererVersion() {
        XCTAssertEqual(VersionSecurityPanel.diagramKitVersion, MermaidRenderer.version)
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
@MainActor
final class MermaidPlaygroundSyntaxHighlighterRegressionTests: XCTestCase {
    func testHighlightsCurrentRegistryHeaders() async throws {
        #if canImport(AppKit)
        let headers = ["venn-beta", "wardley-beta", "ishikawa", "treeView-beta"]

        for header in headers {
            let source = "\(header)\n  Root"
            let textView = NSTextView()
            textView.string = source

            await MermaidSyntaxHighlighter().highlight(
                source,
                in: textView,
                visibleRect: .zero,
                theme: .default
            )

            let color = textView.layoutManager?.temporaryAttribute(
                .foregroundColor,
                atCharacterIndex: 0,
                effectiveRange: nil
            )
            XCTAssertNotNil(color, "Expected \(header) to be highlighted as a diagram type")
        }
        #endif
    }
}
#endif

//
//  DiagramPlaygroundRegressionTests.swift
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
@testable import DiagramPlayground
#if canImport(AppKit)
import AppKit
#endif

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
@MainActor
final class DiagramPlaygroundStoreRegressionTests: XCTestCase {
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
        // The debounce in NativeCodeEditor.Coordinator is 300ms. Poll for the
        // expected commit until it lands or a generous ceiling expires —
        // exits as soon as the condition holds so the test is not pinned to
        // a sleep duration that becomes flaky on a slow runner.
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline, store.state.source != editedSource {
            try await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertEqual(store.state.source, editedSource)
        XCTAssertEqual(store.state.configJSON, originalConfig)
        #endif
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class DiagramPlaygroundLoaderRegressionTests: XCTestCase {
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
final class DiagramPlaygroundExportRegressionTests: XCTestCase {
    func testSVGRendererHonorsLayoutConfig() async throws {
        let source = "graph TD\n  A[Start] --> B[End]"
        let defaultSVG = try await DiagramImageRenderer(
            theme: .default,
            config: LayoutConfig()
        )
        .renderSVG(from: source)
        let paddedSVG = try await DiagramImageRenderer(
            theme: .default,
            config: LayoutConfig(padding: 140)
        )
        .renderSVG(from: source)

        XCTAssertNotEqual(defaultSVG, paddedSVG)
    }

    @MainActor
    func testExportSourceHonorsSelectedSourceFormatInsteadOfAutoDetecting() async throws {
        let store = LiveEditorStore(
            state: LiveEditorState(
                source: "graph TD\n  A --> B",
                sourceFormat: .structurizr
            )
        )

        do {
            _ = try await store.exportSource(to: .mermaid)
            XCTFail("Expected Structurizr parsing to reject Mermaid-shaped source")
        } catch {
            // Expected: selected source format is authoritative.
        }
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
final class DiagramPlaygroundActionsRegressionTests: XCTestCase {
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
final class DiagramPlaygroundVersionRegressionTests: XCTestCase {
    func testVersionSecurityPanelReportsRendererVersion() {
        XCTAssertEqual(VersionSecurityPanel.diagramKitVersion, DiagramEngine.version)
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
@MainActor
final class DiagramPlaygroundSyntaxHighlighterRegressionTests: XCTestCase {
    func testStaleHighlightPayloadsAreRejected() {
        XCTAssertTrue(DiagramSyntaxHighlighter.shouldApplyHighlight(
            capturedSource: "graph TD\nA --> B",
            currentText: "graph TD\nA --> B"
        ))
        XCTAssertFalse(DiagramSyntaxHighlighter.shouldApplyHighlight(
            capturedSource: "graph TD\nA --> B",
            currentText: "graph TD\nA --> C"
        ))
    }

    func testHighlightsCurrentRegistryHeaders() async throws {
        #if canImport(AppKit)
        let headers = ["venn-beta", "wardley-beta", "ishikawa", "treeView-beta"]

        for header in headers {
            let source = "\(header)\n  Root"
            let textView = NSTextView()
            textView.string = source

            await DiagramSyntaxHighlighter().highlight(
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

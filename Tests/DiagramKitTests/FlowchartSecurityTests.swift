import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class FlowchartSecurityTests: XCTestCase {

    // MARK: - URL validation in click href

    func testClickHrefWithSafeURLStoresInteraction() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "https://safe.com"
        """
        let graph = try await DiagramEngine.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        let interaction = model.nodeInteractions["A"]
        XCTAssertNotNil(interaction, "Safe href should be stored")
        if case .href(let url) = interaction?.type {
            XCTAssertEqual(url, "https://safe.com")
        } else {
            XCTFail("Expected href interaction")
        }
    }

    func testClickHrefWithJavascriptURLIsNotRendered() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "javascript:alert(1)"
        """
        let graph = try await DiagramEngine.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        // Owner ruling: the URL stays in the model (and in the exported
        // source); it never becomes a link in the SVG.
        XCTAssertNotNil(model.nodeInteractions["A"], "javascript: URL is kept in the model")
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertFalse(svg.lowercased().contains("href=\"javascript:"), "javascript: URL must not be rendered as a link")
    }

    func testClickHrefWithDataURLIsNotRendered() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "data:text/html,<script>alert(1)</script>"
        """
        let graph = try await DiagramEngine.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        // Owner ruling: the URL stays in the model (and in the exported
        // source); it never becomes a link in the SVG.
        XCTAssertNotNil(model.nodeInteractions["A"], "data: URL is kept in the model")
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertFalse(svg.lowercased().contains("href=\"data:"), "data: URL must not be rendered as a link")
    }

    func testClickHrefWithVbscriptURLIsNotRendered() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "vbscript:msgbox(1)"
        """
        let graph = try await DiagramEngine.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        // Owner ruling: the URL stays in the model (and in the exported
        // source); it never becomes a link in the SVG.
        XCTAssertNotNil(model.nodeInteractions["A"], "vbscript: URL is kept in the model")
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertFalse(svg.lowercased().contains("href=\"vbscript:"), "vbscript: URL must not be rendered as a link")
    }

    func testClickHrefWithFileURLIsRendered() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "file:///etc/passwd"
        """
        let graph = try await DiagramEngine.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        // Owner ruling: only javascript, data and vbscript are withheld (as
        // upstream's sanitize-url does); a file: URL is an ordinary link.
        XCTAssertNotNil(model.nodeInteractions["A"])
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertTrue(svg.contains("file:///etc/passwd"))
    }

    func testClickCallIsStoredUnconditionally() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A call myCallback()
        """
        let graph = try await DiagramEngine.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        let interaction = model.nodeInteractions["A"]
        XCTAssertNotNil(interaction, "call interaction should be stored regardless")
        if case .call(let funcName, _) = interaction?.type {
            XCTAssertEqual(funcName, "myCallback")
        } else {
            XCTFail("Expected call interaction")
        }
    }

    func testClickCallbackIsStoredUnconditionally() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A myCallback
        """
        let graph = try await DiagramEngine.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        let interaction = model.nodeInteractions["A"]
        XCTAssertNotNil(interaction, "callback interaction should be stored regardless")
        if case .callback(let name) = interaction?.type {
            XCTAssertEqual(name, "myCallback")
        } else {
            XCTFail("Expected callback interaction")
        }
    }

    func testClickHrefWithTargetAndTooltip() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "https://safe.com" "Go to safe" _blank
        """
        let graph = try await DiagramEngine.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        let interaction = model.nodeInteractions["A"]
        XCTAssertNotNil(interaction)
        if case .href(let url) = interaction?.type {
            XCTAssertEqual(url, "https://safe.com")
        } else {
            XCTFail("Expected href interaction")
        }
        XCTAssertEqual(interaction?.tooltip, "Go to safe")
        XCTAssertEqual(interaction?.target, "_blank")
    }

    // MARK: - SVG sandbox gating

    func testSVGWithSandboxSecurityLevelSuppressesHref() async throws {
        let source = """
        ---
        config:
          securityLevel: sandbox
        ---
        graph LR
          A[Start] --> B[End]
          click A href "https://safe.com"
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<svg"), "SVG should render")
        XCTAssertFalse(svg.contains("xlink:href=\"https://safe.com\""), "href should be suppressed in sandbox mode")
    }

    func testSVGWithLooseSecurityLevelPreservesHref() async throws {
        let source = """
        ---
        config:
          securityLevel: loose
        ---
        graph LR
          A[Start] --> B[End]
          click A href "https://safe.com"
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertTrue(svg.contains("<svg"), "SVG should render")
        XCTAssertTrue(svg.contains("xlink:href=\"https://safe.com\""), "href should be preserved in loose mode")
    }

    // MARK: - Image URL validation

    func testImageNodeWithUnsafeURLDoesNotEmitImageTag() async throws {
        let source = """
        graph LR
          A@{ img: "javascript:alert(1)", shape: image-square, label: "test" }
        """
        let svg = try await DiagramEngine.renderSVG(source: source)
        XCTAssertFalse(svg.contains("<image"), "Unsafe image URL should not produce <image> tag")
    }
}

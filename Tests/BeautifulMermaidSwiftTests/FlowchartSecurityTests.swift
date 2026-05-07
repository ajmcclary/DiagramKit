import XCTest
@testable import BeautifulMermaid

final class FlowchartSecurityTests: XCTestCase {

    // MARK: - URL validation in click href

    func testClickHrefWithSafeURLStoresInteraction() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "https://safe.com"
        """
        let graph = try await MermaidRenderer.parse(source)
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

    func testClickHrefWithJavascriptURLIsRejected() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "javascript:alert(1)"
        """
        let graph = try await MermaidRenderer.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        XCTAssertNil(model.nodeInteractions["A"], "javascript: URL should be rejected")
    }

    func testClickHrefWithDataURLIsRejected() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "data:text/html,<script>alert(1)</script>"
        """
        let graph = try await MermaidRenderer.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        XCTAssertNil(model.nodeInteractions["A"], "data: URL should be rejected")
    }

    func testClickHrefWithVbscriptURLIsRejected() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "vbscript:msgbox(1)"
        """
        let graph = try await MermaidRenderer.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        XCTAssertNil(model.nodeInteractions["A"], "vbscript: URL should be rejected")
    }

    func testClickHrefWithFileURLIsRejected() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A href "file:///etc/passwd"
        """
        let graph = try await MermaidRenderer.parse(source)
        guard case .flowchart(let model) = graph.payload else {
            XCTFail("Expected flowchart payload")
            return
        }
        XCTAssertNil(model.nodeInteractions["A"], "file: URL should be rejected")
    }

    func testClickCallIsStoredUnconditionally() async throws {
        let source = """
        graph LR
          A[Start] --> B[End]
          click A call myCallback()
        """
        let graph = try await MermaidRenderer.parse(source)
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
        let graph = try await MermaidRenderer.parse(source)
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
        let graph = try await MermaidRenderer.parse(source)
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
        let svg = try await renderMermaidSVG(source, RenderOptions())
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
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertTrue(svg.contains("<svg"), "SVG should render")
        XCTAssertTrue(svg.contains("xlink:href=\"https://safe.com\""), "href should be preserved in loose mode")
    }

    // MARK: - Image URL validation

    func testImageNodeWithUnsafeURLDoesNotEmitImageTag() async throws {
        let source = """
        graph LR
          A@{ img: "javascript:alert(1)", shape: image-square, label: "test" }
        """
        let svg = try await renderMermaidSVG(source, RenderOptions())
        XCTAssertFalse(svg.contains("<image"), "Unsafe image URL should not produce <image> tag")
    }
}

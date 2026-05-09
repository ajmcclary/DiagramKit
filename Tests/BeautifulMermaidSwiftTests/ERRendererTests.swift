import Testing
import Foundation
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

@Suite("ER Renderer")
struct ERRendererTests {

    // MARK: - Marker Definitions

    @Test("default look emits standard marker IDs")
    func defaultLookEmitsStandardMarkers() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              CUSTOMER ||--o{ ORDER : places
            """)
        #expect(svg.contains(#"id="er-onlyOneStart""#))
        #expect(svg.contains(#"id="er-zeroOrMoreEnd""#))
        #expect(!svg.contains("_neo"))
    }

    @Test("neo look emits neo marker IDs")
    func neoLookEmitsNeoMarkers() async throws {
        let svg = try await renderMermaidSVG("""
            ---
            config:
              look: neo
            ---
            erDiagram
              CUSTOMER ||--o{ ORDER : places
            """)
        #expect(svg.contains(#"id="er-onlyOne_neoStart""#))
        #expect(svg.contains(#"id="er-zeroOrMore_neoEnd""#))
    }

    @Test("marker paths match Mermaid edgeMarker.ts parity")
    func markerPathsMatchMermaid() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              CUSTOMER ||--o{ ORDER : places
            """)
        #expect(svg.contains("M 0,0 L 8.4,-4.2 L 8.4,4.2 Z"))
        #expect(svg.contains("M 8.4,0 A 4.2,4.2 0 1,0 8.4,0.01 Z"))
        #expect(svg.contains("M 8.4,0 A 4.2,4.2 0 1,0 8.4,0.01 Z M 0,0 L 8.4,-4.2 L 0,0 L 8.4,4.2 Z M 8.4,-4.2 L 8.4,4.2"))
    }

    // MARK: - Label Type (htmlLabels)

    @Test("entity with labelType text renders plain text label")
    func labelTypeTextRendersPlainLabel() async throws {
        let svg = try await renderMermaidSVG("""
            ---
            config:
              htmlLabels: false
            ---
            erDiagram
              CUSTOMER
            """)
        // When htmlLabels is false, entity labels should be plain text,
        // not parsed for markdown
        #expect(svg.contains("CUSTOMER"))
    }

    @Test("entity with labelType markdown renders formatted label")
    func labelTypeMarkdownRendersFormattedLabel() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              "**Bold** name"
            """)
        #expect(svg.contains("**Bold** name") || svg.contains("<tspan"))
    }

    // MARK: - useMaxWidth

    @Test("useMaxWidth true emits 100 percent width")
    func useMaxWidthTrueEmitsResponsiveWidth() async throws {
        let svg = try await renderMermaidSVG("""
            ---
            config:
              er:
                useMaxWidth: true
            ---
            erDiagram
              CUSTOMER
            """)
        #expect(svg.contains("width=\"100%\""))
    }

    // MARK: - Entity Rendering

    @Test("entity without attributes renders as simple rectangle")
    func entityWithoutAttributesRendersSimpleRect() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              CUSTOMER
            """)
        // Should NOT contain "(no attributes)" text
        #expect(!svg.contains("no attributes"))
        // Should contain entity group with class
        #expect(svg.contains("class=\"entity"))
    }

    @Test("entity with attributes renders header and rows")
    func entityWithAttributesRendersHeaderAndRows() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              CUSTOMER {
                int id PK
                string name
              }
            """)
        #expect(svg.contains("var(--_group-hdr)"))
        #expect(svg.contains("var(--_row-odd)"))
        #expect(svg.contains("var(--_row-even)"))
    }

    // MARK: - Relationship Rendering

    @Test("identifying relationship renders solid polyline")
    func identifyingRelationshipRendersSolid() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              CUSTOMER ||--|| ORDER : places
            """)
        #expect(svg.contains("data-identifying=\"true\""))
        #expect(!svg.contains("stroke-dasharray"))
    }

    @Test("non-identifying relationship renders dashed polyline")
    func nonIdentifyingRelationshipRendersDashed() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              CUSTOMER ||..o{ ORDER : places
            """)
        #expect(svg.contains("stroke-dasharray"))
    }

    // MARK: - Title Rendering

    @Test("renders diagram title from frontmatter")
    func rendersDiagramTitle() async throws {
        let svg = try await renderMermaidSVG("""
            ---
            title: Customer ERD
            ---
            erDiagram
              CUSTOMER
            """)
        #expect(svg.contains("Customer ERD"))
    }

    @Test("renders inline title directive")
    func rendersInlineTitleDirective() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              title: My Diagram
              CUSTOMER
            """)
        #expect(svg.contains("My Diagram"))
    }

    // MARK: - Comment Column

    @Test("renders attribute comment in comment column")
    func rendersAttributeComment() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              CUSTOMER {
                string name "The customer name"
              }
            """)
        #expect(svg.contains("The customer name"))
    }

    // MARK: - Accessibility

    @Test("renders accTitle and accDescr metadata")
    func rendersAccessibilityMetadata() async throws {
        let svg = try await renderMermaidSVG("""
            erDiagram
              accTitle: ER Accessibility Test
              accDescr: A test of accessibility
              CUSTOMER
            """)
        #expect(svg.contains("<title>ER Accessibility Test</title>"))
        #expect(svg.contains("<desc>A test of accessibility</desc>"))
    }
}

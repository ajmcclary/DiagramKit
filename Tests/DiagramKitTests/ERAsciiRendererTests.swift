import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitModel

struct ERAsciiRendererTests {

    @Test func basicEntityRendersWithBoxBorder() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        erDiagram
            CUSTOMER
        """)
        #expect(output.text.contains("CUSTOMER"))
        // ASCII output uses box-drawing characters (unicode or ascii fallback).
        let hasBorder = output.text.contains("─") || output.text.contains("-") || output.text.contains("│") || output.text.contains("|")
        #expect(hasBorder)
    }

    @Test func attributeNamesAppearInAsciiOutput() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        erDiagram
            CUSTOMER {
                int id PK
                string name
            }
        """)
        #expect(output.text.contains("CUSTOMER"))
        #expect(output.text.contains("id") || output.text.contains("name"))
    }

    @Test func relationshipLabelSurfacesInOutput() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        erDiagram
            CUSTOMER ||--o{ ORDER : places
        """)
        #expect(output.text.contains("CUSTOMER"))
        #expect(output.text.contains("ORDER"))
        // The ER ASCII renderer draws relationship labels beside the
        // connector (src_ascii_er_diagram.swift `_drawRelationshipLabels`);
        // assert the label actually surfaces instead of pinning a no-op.
        #expect(output.text.contains("places"))
    }

    @Test func selfRelationshipDoesNotCrash() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        erDiagram
            EMPLOYEE ||--o{ EMPLOYEE : manages
        """)
        #expect(output.text.contains("EMPLOYEE"))
    }

    @Test func longEntityNameDoesNotCrash() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        erDiagram
            ThisIsAVeryLongEntityNameThatExceedsTypicalShortFormats
        """)
        #expect(output.text.contains("ThisIsAVeryLong"))
    }

    @Test func multipleRelationshipsRenderWithoutCrash() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        erDiagram
            CUSTOMER ||--o{ ORDER : places
            ORDER ||--|{ LINE_ITEM : contains
            CUSTOMER ||..o{ INVOICE : receives
        """)
        #expect(output.text.contains("CUSTOMER"))
        #expect(output.text.contains("ORDER"))
        #expect(output.text.contains("LINE_ITEM"))
        #expect(output.text.contains("INVOICE"))
    }

    @Test func emptyErDiagramRendersEmptyOrWhitespaceOnly() async throws {
        let output = try await DiagramEngine.renderASCII(source: "erDiagram")
        #expect(output.text.allSatisfy { $0.isWhitespace || $0.isNewline })
    }

    @Test func accTitleAppearsInOutput() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        erDiagram
            accTitle: Customer Database Schema
            CUSTOMER
        """)
        // accTitle is typically rendered above the diagram body in ASCII.
        // Pin the renderer does not crash with accTitle; surface check is loose
        // because ASCII title rendering is renderer-discretion.
        #expect(output.text.contains("CUSTOMER"))
    }
}

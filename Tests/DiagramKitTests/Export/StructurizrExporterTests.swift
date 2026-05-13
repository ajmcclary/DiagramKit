import Testing
import DiagramKitModel
import DiagramKitStructurizr

@Suite struct StructurizrExporterTests {

    @Test("Structurizr exporter has correct name and format ID")
    func identity() {
        let exporter = StructurizrExporter()
        #expect(exporter.name == "Structurizr")
        #expect(exporter.formatID == .structurizr)
        #expect(exporter.supportedDiagramTypes.contains(.c4))
        #expect(!exporter.supportedDiagramTypes.contains(.flowchart))
    }

    @Test("Structurizr C4 export produces valid workspace source")
    func c4Export() throws {
        let c4 = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(alias: "customer", label: "Customer", typeC4Shape: .person),
                C4Shape(alias: "system", label: "System", typeC4Shape: .system, description: "A system")
            ],
            relationships: [
                C4Relationship(kind: .rel, from: "customer", to: "system", label: "Uses")
            ]
        )
        let doc = DiagramDocument(payload: .c4(c4))
        let result = try StructurizrExporter().export(doc)

        #expect(result.source.contains("workspace {"))
        #expect(result.source.contains("model {"))
        #expect(result.source.contains("views {"))
        #expect(result.source.contains("customer = person"))
        #expect(result.source.contains("system = softwareSystem"))
    }

    @Test("Structurizr C4 export escapes quoted strings for parser-compatible source")
    func c4ExportEscapesQuotedStrings() throws {
        let c4 = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(alias: "customer", label: #"Customer "A"\B"#, typeC4Shape: .person),
                C4Shape(alias: "system", label: "System", typeC4Shape: .system, description: #"Line "one"\two"#)
            ],
            relationships: [
                C4Relationship(kind: .rel, from: "customer", to: "system", label: #"Uses "API"\v1"#)
            ]
        )

        let result = try StructurizrExporter().export(DiagramDocument(payload: .c4(c4)))
        #expect(result.source.contains(#"customer = person "Customer \"A\"\\B""#))
        #expect(result.source.contains(#"system = softwareSystem "System" "Line \"one\"\\two""#))
        #expect(result.source.contains(#"customer -> system "Uses \"API\"\\v1""#))

        let reparsed = try StructurizrImporter().parse(result.source).document
        guard case .c4(let reparsedC4) = reparsed.payload else {
            Issue.record("Expected C4 payload")
            return
        }
        #expect(reparsedC4.shapes.first(where: { $0.alias == "customer" })?.label == #"Customer "A"\B"#)
        #expect(reparsedC4.shapes.first(where: { $0.alias == "system" })?.description == #"Line "one"\two"#)
        #expect(reparsedC4.relationships.first?.label == #"Uses "API"\v1"#)
    }

    @Test("Structurizr export unsupported type returns diagnostic")
    func unsupportedType() throws {
        let doc = DiagramDocument(type: .flowchart)
        let result = try StructurizrExporter().export(doc)
        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }

    // MARK: - Review Critical 6: alias sanitization

    @Test("Structurizr export sanitizes aliases with spaces and warns")
    func sanitizesAliasesWithSpaces() throws {
        let c4 = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(alias: "my customer", label: "Customer", typeC4Shape: .person),
                C4Shape(alias: "external system", label: "System", typeC4Shape: .system)
            ],
            relationships: [
                C4Relationship(kind: .rel, from: "my customer", to: "external system", label: "Uses")
            ]
        )
        let result = try StructurizrExporter().export(DiagramDocument(payload: .c4(c4)))

        #expect(!result.source.contains("my customer = "))
        #expect(!result.source.contains("external system = "))
        #expect(result.source.contains("my_customer = person"))
        #expect(result.source.contains("external_system = softwareSystem"))
        #expect(result.source.contains("my_customer -> external_system"))
        #expect(result.diagnostics.contains { $0.severity == .warning && $0.message.contains("'my customer'") })
        #expect(result.diagnostics.contains { $0.severity == .warning && $0.message.contains("'external system'") })

        // Round-trip through the parser to prove the sanitized output is valid.
        let reparsed = try StructurizrImporter().parse(result.source).document
        guard case .c4(let reparsedC4) = reparsed.payload else {
            Issue.record("Expected C4 payload")
            return
        }
        #expect(reparsedC4.shapes.contains { $0.alias == "my_customer" })
        #expect(reparsedC4.shapes.contains { $0.alias == "external_system" })
        #expect(reparsedC4.relationships.first?.from == "my_customer")
        #expect(reparsedC4.relationships.first?.to == "external_system")
    }

    @Test("Structurizr export keeps dot/hyphen aliases unchanged (lexer accepts them)")
    func keepsDotAndHyphenAliases() throws {
        let c4 = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(alias: "billing.api", label: "Billing API", typeC4Shape: .system),
                C4Shape(alias: "user-portal", label: "User Portal", typeC4Shape: .system)
            ],
            relationships: [
                C4Relationship(kind: .rel, from: "user-portal", to: "billing.api", label: "Calls")
            ]
        )
        let result = try StructurizrExporter().export(DiagramDocument(payload: .c4(c4)))

        #expect(result.source.contains("billing.api = softwareSystem"))
        #expect(result.source.contains("user-portal = softwareSystem"))
        #expect(result.source.contains("user-portal -> billing.api"))
        #expect(!result.diagnostics.contains { $0.severity == .warning })

        let reparsed = try StructurizrImporter().parse(result.source).document
        guard case .c4(let reparsedC4) = reparsed.payload else {
            Issue.record("Expected C4 payload")
            return
        }
        #expect(reparsedC4.shapes.contains { $0.alias == "billing.api" })
        #expect(reparsedC4.shapes.contains { $0.alias == "user-portal" })
    }

    @Test("Structurizr export sanitizes leading digit aliases")
    func sanitizesLeadingDigitAliases() throws {
        let c4 = C4Diagram(
            kind: .context,
            shapes: [C4Shape(alias: "2fa-service", label: "2FA", typeC4Shape: .system)]
        )
        let result = try StructurizrExporter().export(DiagramDocument(payload: .c4(c4)))

        #expect(result.source.contains("_fa-service = softwareSystem"))
        #expect(result.diagnostics.contains { $0.severity == .warning && $0.message.contains("'2fa-service'") })
        _ = try StructurizrImporter().parse(result.source)
    }

    // MARK: - Review Critical 7: drop parser-incompatible syntax

    @Test("Structurizr export drops alias tags and reports diagnostic")
    func dropsTagsAndReportsDiagnostic() throws {
        let c4 = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(
                    alias: "customer",
                    label: "Customer",
                    typeC4Shape: .person,
                    tags: "External"
                )
            ]
        )
        let result = try StructurizrExporter().export(DiagramDocument(payload: .c4(c4)))

        #expect(!result.source.contains("tags"))
        #expect(result.diagnostics.contains {
            $0.severity == .unsupported && $0.message.contains("element-scoped tags")
        })

        // Re-import should not surface any diagnostics from the parser
        // about orphan `tags` statements.
        _ = try StructurizrImporter().parse(result.source)
    }

    @Test("Structurizr export drops boundary `group` blocks and reports diagnostic")
    func dropsBoundaryGroupsAndReportsDiagnostic() throws {
        let c4 = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(alias: "customer", label: "Customer", typeC4Shape: .person, parentBoundary: "platform"),
                C4Shape(alias: "system", label: "System", typeC4Shape: .system)
            ],
            boundaries: [
                C4Boundary(alias: "platform", label: "Platform")
            ],
            relationships: [
                C4Relationship(kind: .rel, from: "customer", to: "system", label: "Uses")
            ]
        )
        let result = try StructurizrExporter().export(DiagramDocument(payload: .c4(c4)))

        #expect(!result.source.contains("group "))
        #expect(!result.source.contains("include customer"))
        #expect(result.diagnostics.contains {
            $0.severity == .unsupported && $0.message.contains("`group` boundaries")
        })

        // The bare elements still round-trip through the parser, just without
        // the boundary grouping that the parser cannot represent.
        let reparsed = try StructurizrImporter().parse(result.source).document
        guard case .c4(let reparsedC4) = reparsed.payload else {
            Issue.record("Expected C4 payload")
            return
        }
        #expect(reparsedC4.shapes.contains { $0.alias == "customer" })
        #expect(reparsedC4.shapes.contains { $0.alias == "system" })
    }
}

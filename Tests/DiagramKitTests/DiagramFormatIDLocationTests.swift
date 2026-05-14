import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport

@Suite struct DiagramFormatIDLocationTests {

    @Test("DiagramFormatID resolves from DiagramKitCommon")
    func resolvesFromCommon() {
        let fromCommon: DiagramKitCommon.DiagramFormatID = .mermaid
        #expect(fromCommon.rawValue == "mermaid")
    }

    @Test("DiagramFormatID is a single type across Import and Export")
    func sameTypeAcrossModules() {
        let viaImport: DiagramFormatID = .d2
        let viaExport: DiagramFormatID = .d2
        #expect(viaImport == viaExport)
        #expect(type(of: viaImport) == type(of: viaExport))
    }
}

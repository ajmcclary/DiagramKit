import Testing
import DiagramKit
import DiagramKitCommon
import DiagramKitModel

@Suite("Linux platform gate")
struct LinuxPlatformGateTests {

    // MARK: - DiagramError.unsupportedOnPlatform

    @Test func unsupportedOnPlatformErrorDescription() {
        let error = DiagramError.unsupportedOnPlatform(
            family: .ishikawa,
            reason: "requires CoreText text-measurement",
            platform: "Linux"
        )
        #expect(error.errorDescription == "ishikawa layout is not supported on Linux: requires CoreText text-measurement")
    }

    // MARK: - DiagramDescriptor fields

    @Test func descriptorDefaultsLinuxSupportToTrue() {
        let descriptor = DiagramRegistry.all.first { $0.type == .flowchart }
        #expect(descriptor != nil)
        #expect(descriptor?.linuxSupport == true)
        #expect(descriptor?.linuxUnsupportedReason == nil)
    }

    // MARK: - Per-family linuxSupport

    @Test func ishikawaIsLinuxUnsupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .ishikawa }
        #expect(descriptor?.linuxSupport == false)
        #expect(descriptor?.linuxUnsupportedReason?.isEmpty == false)
    }

    @Test func treeViewIsLinuxUnsupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .treeView }
        #expect(descriptor?.linuxSupport == false)
        #expect(descriptor?.linuxUnsupportedReason?.isEmpty == false)
    }

    @Test func eventModelingIsLinuxUnsupported() {
        let descriptor = DiagramRegistry.all.first { $0.type == .eventModeling }
        #expect(descriptor?.linuxSupport == false)
        #expect(descriptor?.linuxUnsupportedReason?.isEmpty == false)
    }

    @Test func exactlyThreeFamiliesAreLinuxUnsupported() {
        let unsupported = DiagramRegistry.all.filter { !$0.linuxSupport }.map(\.type)
        #expect(Set(unsupported) == Set<DiagramType>([.ishikawa, .treeView, .eventModeling]))
    }
}

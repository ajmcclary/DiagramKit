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
}

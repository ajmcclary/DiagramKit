import Testing

@Suite("Snapshot testing compatibility")
struct SnapshotTestingSupportTests {
    @Test("macOS 27 avoids the incompatible Core Image perceptual path")
    func perceptualPrecisionByOperatingSystem() {
        #expect(snapshotPixelPrecision(macOSMajorVersion: 26) == 0.99)
        #expect(snapshotPixelPrecision(macOSMajorVersion: 27) == 0.97)
        #expect(snapshotPixelPrecision(macOSMajorVersion: 28) == 0.97)
        #expect(snapshotPerceptualPrecision(macOSMajorVersion: 26) == 0.98)
        #expect(snapshotPerceptualPrecision(macOSMajorVersion: 27) == 1)
        #expect(snapshotPerceptualPrecision(macOSMajorVersion: 28) == 1)
    }
}

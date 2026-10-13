import DiagramKitModel
func bad() throws {
    throw DiagramError.malformedSource("exporters must diagnose, not throw")
}

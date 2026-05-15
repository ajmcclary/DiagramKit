import DiagramKitCommon

func exportSomething() throws {
    throw DiagramError.malformedSource(message: "exporters should emit, not throw")
}

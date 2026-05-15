import DiagramKitCommon

func emit() -> DiagramDiagnostic {
    return .lossyTransform(.idSanitization, message: "clean")
}

import DiagramKitCommon

func emit() -> DiagramDiagnostic {
    return DiagramDiagnostic(severity: .warning, message: "should fail gate")
}

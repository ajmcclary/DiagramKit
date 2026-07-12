import DiagramKitSampleDesignSystem

extension EditorDiagnostic.Severity {
    var dsStatusKind: DSStatusKind {
        switch self {
        case .error: .error
        case .warning: .warning
        case .info: .info
        }
    }

    var dsIcon: DSIcon {
        switch self {
        case .error: .error
        case .warning: .warning
        case .info: .info
        }
    }

    var dsIconColorRole: DSIconColorRole {
        switch self {
        case .error: .error
        case .warning: .warning
        case .info: .info
        }
    }
}

enum DSExportStatus {
    static func resolve(
        isWorking: Bool,
        hasPayload: Bool,
        hasError: Bool
    ) -> DSStatusKind {
        if hasError { return .error }
        if isWorking { return .info }
        return hasPayload ? .success : .info
    }
}

enum DSConvertStatus {
    static func resolve(
        isWorking: Bool,
        diagnosticCount: Int
    ) -> DSStatusKind {
        if isWorking { return .info }
        return diagnosticCount > 0 ? .warning : .success
    }
}

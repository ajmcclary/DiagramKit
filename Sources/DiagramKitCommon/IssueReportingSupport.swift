import Foundation
import IssueReporting

public protocol _RecoverableDiagramError: Error {}

@discardableResult
public func _withDiagramIssueReporting<T>(
    operation: String,
    _ work: () throws -> T
) throws -> T {
    do {
        return try work()
    } catch {
        _reportDiagramIssueIfNeeded(error, operation: operation)
        throw error
    }
}

@discardableResult
public func _withDiagramIssueReporting<T>(
    operation: String,
    _ work: () async throws -> T
) async throws -> T {
    do {
        return try await work()
    } catch {
        _reportDiagramIssueIfNeeded(error, operation: operation)
        throw error
    }
}

public func _reportDiagramIssueIfNeeded(_ error: any Error, operation: String) {
    guard !_isRecoverableDiagramError(error), !(error is CancellationError) else {
        return
    }
    reportIssue("\(operation) failed: \(error.localizedDescription)")
}

public func _reportDiagramIssue(_ message: String) {
    reportIssue(message)
}

private func _isRecoverableDiagramError(_ error: any Error) -> Bool {
    error is _RecoverableDiagramError
}



import Foundation
import IssueReporting

protocol _MermaidRecoverableError: Error {}

@discardableResult
func _withMermaidIssueReporting<T>(
    operation: String,
    _ work: () throws -> T
) throws -> T {
    do {
        return try work()
    } catch {
        _reportMermaidIssueIfNeeded(error, operation: operation)
        throw error
    }
}

@discardableResult
func _withMermaidIssueReporting<T>(
    operation: String,
    _ work: () async throws -> T
) async throws -> T {
    do {
        return try await work()
    } catch {
        _reportMermaidIssueIfNeeded(error, operation: operation)
        throw error
    }
}

func _reportMermaidIssueIfNeeded(_ error: any Error, operation: String) {
    guard !_isRecoverableMermaidError(error), !(error is CancellationError) else {
        return
    }
    reportIssue("\(operation) failed: \(error.localizedDescription)")
}

func _reportMermaidIssue(_ message: String) {
    reportIssue(message)
}

private func _isRecoverableMermaidError(_ error: any Error) -> Bool {
    error is _MermaidRecoverableError
}

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

// MARK: - Phase 0 backward-compat deprecated names

@available(*, deprecated, renamed: "_RecoverableDiagramError")
public typealias _MermaidRecoverableError = _RecoverableDiagramError

@available(*, deprecated, renamed: "_withDiagramIssueReporting(operation:_:)")
@discardableResult
public func _withMermaidIssueReporting<T>(
    operation: String,
    _ work: () throws -> T
) throws -> T {
    try _withDiagramIssueReporting(operation: operation, work)
}

@available(*, deprecated, renamed: "_withDiagramIssueReporting(operation:_:)")
@discardableResult
public func _withMermaidIssueReporting<T>(
    operation: String,
    _ work: () async throws -> T
) async throws -> T {
    try await _withDiagramIssueReporting(operation: operation, work)
}

@available(*, deprecated, renamed: "_reportDiagramIssueIfNeeded(_:operation:)")
public func _reportMermaidIssueIfNeeded(_ error: any Error, operation: String) {
    _reportDiagramIssueIfNeeded(error, operation: operation)
}

@available(*, deprecated, renamed: "_reportDiagramIssue(_:)")
public func _reportMermaidIssue(_ message: String) {
    _reportDiagramIssue(message)
}

@available(*, deprecated, renamed: "_isRecoverableDiagramError(_:)")
public func _isRecoverableMermaidError(_ error: any Error) -> Bool {
    _isRecoverableDiagramError(error)
}

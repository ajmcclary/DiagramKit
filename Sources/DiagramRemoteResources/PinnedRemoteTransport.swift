#if os(macOS)
import Darwin
import Foundation

/// Transport for untrusted URLs. curl's per-request DNS pins avoid validating
/// one answer and then allowing a networking library to resolve a second one.
enum PinnedRemoteTransport {
    static func fetch(_ original: URL, timeout: TimeInterval,
                      resolver: @Sendable (String, TimeInterval) async throws -> [String] = resolve,
                      execute: @Sendable ([String]) async throws -> Int32 = run) async throws -> (Data, HTTPURLResponse) {
        guard timeout.isFinite, timeout > 0 else { throw RemoteFetch.FetchError.timedOut }
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("diagram-fetch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let headers = directory.appendingPathComponent("headers")
        let body = directory.appendingPathComponent("body")
        var url = original
        for _ in 0..<10 {
            try Task.checkCancellation()
            try RemoteFetch.validateUserURL(url)
            let host = url.host!.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            let addresses = try await resolver(host, remaining(until: deadline))
            let args = try arguments(url: url, addresses: addresses, timeout: remaining(until: deadline), headers: headers, body: body)
            let code = try await execute(args)
            try Task.checkCancellation()
            if code == 28 { throw RemoteFetch.FetchError.timedOut }
            if code == 63 { throw RemoteFetch.FetchError.tooLarge(limit: RemoteFetch.maxBytes) }
            guard code == 0 else { throw RemoteFetch.FetchError.transportFailed(code) }
            let headerSize = (try headers.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
            guard headerSize <= 512 * 1024 else { throw RemoteFetch.FetchError.notHTTP }
            let response = try parseResponse(Data(contentsOf: headers), url: url)
            if [301, 302, 303, 307, 308].contains(response.statusCode),
               let location = response.value(forHTTPHeaderField: "Location"),
               let next = URL(string: location, relativeTo: url)?.absoluteURL {
                url = next
                continue
            }
            let size = (try body.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
            guard size <= RemoteFetch.maxBytes else { throw RemoteFetch.FetchError.tooLarge(limit: RemoteFetch.maxBytes) }
            return (try Data(contentsOf: body), response)
        }
        throw RemoteFetch.FetchError.tooManyRedirects
    }

    static func arguments(url: URL, addresses: [String], timeout: TimeInterval, headers: URL, body: URL) throws -> [String] {
        try RemoteFetch.validateUserURL(url)
        guard timeout > 0 else { throw RemoteFetch.FetchError.timedOut }
        let host = url.host!.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard !addresses.isEmpty, addresses.allSatisfy({ !RemoteFetch.isBlockedHost($0) && isNumeric($0) }) else {
            throw RemoteFetch.FetchError.disallowedHost(host)
        }
        var result = ["-q", "--silent", "--show-error", "--globoff", "--noproxy", "*",
                      "--disallow-username-in-url", "--proto", "=http,https", "--max-time", String(timeout),
                      "--max-filesize", String(RemoteFetch.maxBytes), "--dump-header", headers.path,
                      "--output", body.path]
        // Public IPv6 literals connect numerically; curl 8.7 cannot use one as
        // the hostname field of --resolve. DNS names pin all approved answers.
        if !isNumeric(host) {
            let port = url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80)
            let values = addresses.map { $0.contains(":") ? "[\($0)]" : $0 }.joined(separator: ",")
            result += ["--resolve", "\(host):\(port):\(values)"]
        }
        return result + ["--url", url.absoluteString]
    }

    static func parseResponse(_ data: Data, url: URL) throws -> HTTPURLResponse {
        let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
        guard let block = text.components(separatedBy: "\n\n").last(where: { $0.hasPrefix("HTTP/") }) else {
            throw RemoteFetch.FetchError.notHTTP
        }
        let lines = block.components(separatedBy: "\n")
        let status = lines[0].split(separator: " ")
        guard status.count >= 2, let code = Int(status[1]) else { throw RemoteFetch.FetchError.notHTTP }
        var fields: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            fields[String(line[..<colon])] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: String(status[0]), headerFields: fields) else {
            throw RemoteFetch.FetchError.notHTTP
        }
        return response
    }

    private static func remaining(until deadline: ContinuousClock.Instant) throws -> TimeInterval {
        let duration = ContinuousClock.now.duration(to: deadline).components
        let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        guard seconds > 0 else { throw RemoteFetch.FetchError.timedOut }
        return seconds
    }

    private static func isNumeric(_ host: String) -> Bool {
        var v4 = in_addr(), v6 = in6_addr()
        return inet_aton(host, &v4) != 0 || inet_pton(AF_INET6, host, &v6) == 1
    }

    static func resolve(_ host: String, timeout: TimeInterval) async throws -> [String] {
        if isNumeric(host) {
            guard !RemoteFetch.isBlockedHost(host) else { throw RemoteFetch.FetchError.disallowedHost(host) }
            return [host]
        }
        let promise = FetchPromise<[String]>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                promise.install(continuation)
                DispatchQueue.global(qos: .utility).async {
                    var hints = addrinfo()
                    hints.ai_socktype = SOCK_STREAM
                    var list: UnsafeMutablePointer<addrinfo>?
                    guard getaddrinfo(host, nil, &hints, &list) == 0, let first = list else {
                        promise.resolve(.failure(RemoteFetch.FetchError.resolutionFailed(host))); return
                    }
                    defer { freeaddrinfo(first) }
                    var addresses: [String] = []
                    var cursor: UnsafeMutablePointer<addrinfo>? = first
                    while let item = cursor {
                        var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(item.pointee.ai_addr, item.pointee.ai_addrlen, &name, socklen_t(name.count), nil, 0, NI_NUMERICHOST) == 0 {
                            let address = String(decoding: name.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
                            if RemoteFetch.isBlockedHost(address) {
                                promise.resolve(.failure(RemoteFetch.FetchError.disallowedHost(host))); return
                            }
                            if !addresses.contains(address) { addresses.append(address) }
                        }
                        cursor = item.pointee.ai_next
                    }
                    promise.resolve(addresses.isEmpty ? .failure(RemoteFetch.FetchError.resolutionFailed(host)) : .success(addresses))
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { promise.resolve(.failure(RemoteFetch.FetchError.timedOut)) }
            }
        } onCancel: { promise.resolve(.failure(CancellationError())) }
    }

    static func run(arguments: [String]) async throws -> Int32 {
        let job = FetchProcess()
        let status = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                job.start(arguments: arguments, continuation: continuation)
            }
        } onCancel: { job.cancel() }
        try Task.checkCancellation()
        return status
    }
}

/// Concurrency Contract: a lock serializes installation/completion; exactly one
/// result resumes the continuation, outside the lock, including early cancellation.
private final class FetchPromise<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, Error>?
    private var continuation: CheckedContinuation<Value, Error>?
    func install(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        if let result { lock.unlock(); continuation.resume(with: result) }
        else { self.continuation = continuation; lock.unlock() }
    }
    func resolve(_ result: Result<Value, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

/// Concurrency Contract: launch/cancellation share one lock. Completion waits for
/// process exit (and reaping) before releasing the temporary download directory.
private final class FetchProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private let promise = FetchPromise<Int32>()
    func start(arguments: [String], continuation: CheckedContinuation<Int32, Error>) {
        promise.install(continuation)
        lock.lock()
        guard !cancelled else { lock.unlock(); promise.resolve(.failure(CancellationError())); return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = arguments
        process.environment = ["PATH": "/usr/bin:/bin", "HOME": "/var/empty", "LANG": "C"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [promise] child in promise.resolve(.success(child.terminationStatus)) }
        self.process = process
        do { try process.run(); lock.unlock() }
        catch { lock.unlock(); promise.resolve(.failure(error)) }
    }
    func cancel() {
        lock.lock()
        cancelled = true
        if let process, process.isRunning { process.terminate() }
        lock.unlock()
    }
}
#endif

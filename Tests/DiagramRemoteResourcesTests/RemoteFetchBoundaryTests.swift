#if os(macOS)
import Foundation
import XCTest
@testable import DiagramRemoteResources

final class RemoteFetchBoundaryTests: XCTestCase {
    func test_literalAndScopedAddressesAreRefused() throws {
        for host in ["127.1", "0x7f000001", "2130706433", "[::ffff:127.0.0.1]", "[::127.0.0.1]", "[fe80::1%25en0]", "[ff02::1]"] {
            XCTAssertThrowsError(try RemoteFetch.validateUserURL(XCTUnwrap(URL(string: "http://\(host)/"))), host)
        }
        XCTAssertThrowsError(try RemoteFetch.validateUserURL(XCTUnwrap(URL(string: "https://user:secret@example.com/"))))
    }

    /// curl reads a `--resolve` entry that starts with `-` as "remove this
    /// pin" and then resolves the name itself, so a host such as
    /// `-rebind.attacker.example` (which Foundation's URL parser accepts)
    /// skipped the pinned, validated answers and connected to whatever a
    /// fresh DNS lookup returned. Hosts outside hostname / IP-literal
    /// syntax are refused before anything is resolved or pinned.
    func test_hostsOutsideHostnameSyntaxAreRefused() throws {
        for host in [
            "-rebind.attacker.example", "a.-b.example", "+x.example", "ex,ample.com", "ex!ample.com",
            "ex$ample.com", "ex*ample.com", "ex=ample.com", "ex'ample.com", "ex;ample.com",
            "ex&ample.com", "ex(ample.com", "ex~ample.com", "a..b",
        ] {
            let url = try XCTUnwrap(URL(string: "https://\(host)/img.png"), host)
            XCTAssertThrowsError(try RemoteFetch.validateUserURL(url), host) { error in
                guard case RemoteFetch.FetchError.disallowedHost = error else {
                    return XCTFail("\(host): expected disallowedHost, got \(error)")
                }
            }
            XCTAssertThrowsError(try PinnedRemoteTransport.arguments(url: url, addresses: ["93.184.216.34"], timeout: 1,
                headers: URL(fileURLWithPath: "/h"), body: URL(fileURLWithPath: "/b")), host)
        }
    }

    func test_leadingDashHostNeverReachesResolverOrTransport() async throws {
        do {
            _ = try await PinnedRemoteTransport.fetch(URL(string: "https://-rebind.attacker.example/img.png")!, timeout: 1,
                resolver: { host, _ in XCTFail("\(host) was resolved"); return ["93.184.216.34"] },
                execute: { args in XCTFail("reached transport with \(args)"); return 0 })
            XCTFail("expected refusal")
        } catch RemoteFetch.FetchError.disallowedHost { }
    }

    func test_ordinaryHostnamesAndLiteralsStillValidate() throws {
        for host in [
            "example.com", "example.com.", "sub-domain.example.co.uk", "a1.b2", "my_host.example.com",
            "xn--bcher-kva.example", "bücher.example", "EXAMPLE.COM", "93.184.216.34",
            "[2606:2800:220:1:248:1893:25c8:1946]", "example.com:8443",
        ] {
            XCTAssertNoThrow(try RemoteFetch.validateUserURL(XCTUnwrap(URL(string: "https://\(host)/a.png"), host)), host)
        }
    }

    /// IPv6 prefixes that carry an IPv4 address (NAT64, 6to4, Teredo) and
    /// the reserved IPv4 blocks are checked like the address itself.
    func test_prefixesEmbeddingAPrivateIPv4AreRefused() {
        for host in [
            "64:ff9b::a00:1", "64:ff9b::7f00:1", "64:ff9b:1::1",
            "2002:a00:1::1", "2002:7f00:1::",
            "2001:0:a00:1::1", "2001:0:4136:e378:8000:63bf:f5ff:fffe",
            "192.0.0.8", "198.18.0.1", "198.19.255.255",
        ] {
            XCTAssertTrue(RemoteFetch.isBlockedHost(host), host)
        }
        for host in ["64:ff9b::5db8:d822", "2002:5db8:d822::1", "2606:2800:220:1:248:1893:25c8:1946", "192.1.0.1", "198.20.0.1", "93.184.216.34"] {
            XCTAssertFalse(RemoteFetch.isBlockedHost(host), host)
        }
    }

    func test_publicDNSPinsPreserveOriginalTLSHostname() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/a"))
        let args = try PinnedRemoteTransport.arguments(url: url, addresses: ["93.184.216.34", "2606:2800:220:1:248:1893:25c8:1946"], timeout: 1, headers: URL(fileURLWithPath: "/h"), body: URL(fileURLWithPath: "/b"))
        XCTAssertEqual(args.first, "-q")
        XCTAssertTrue(args.contains("example.com:443:93.184.216.34,[2606:2800:220:1:248:1893:25c8:1946]"))
        XCTAssertEqual(args.suffix(2), ["--url", url.absoluteString])
        XCTAssertTrue(args.contains("--max-time"))
        XCTAssertTrue(args.contains("--max-filesize"))
        XCTAssertFalse(args.contains("--location"))
        XCTAssertFalse(args.contains("--insecure"))
    }

    func test_mixedPrivateAnswerNeverReachesTransport() async throws {
        do {
            _ = try await PinnedRemoteTransport.fetch(URL(string: "https://example.com/")!, timeout: 1,
                resolver: { _, _ in ["93.184.216.34", "10.0.0.1"] }, execute: { _ in
                    XCTFail("private DNS answer reached transport"); return 0
                })
            XCTFail("expected refusal")
        } catch RemoteFetch.FetchError.disallowedHost { }
    }

    func test_redirectIsResolvedAndRevalidatedBeforeConnecting() async throws {
        do {
            _ = try await PinnedRemoteTransport.fetch(URL(string: "https://example.com/")!, timeout: 1,
                resolver: { host, _ in host == "example.com" ? ["93.184.216.34"] : ["127.0.0.1"] },
                execute: { args in
                    XCTAssertEqual(args.last, "https://example.com/")
                    let headers = args[args.firstIndex(of: "--dump-header")! + 1]
                    let body = args[args.firstIndex(of: "--output")! + 1]
                    try Data("HTTP/1.1 302 Found\r\nLocation: https://rebound.example/\r\n\r\n".utf8).write(to: URL(fileURLWithPath: headers))
                    try Data().write(to: URL(fileURLWithPath: body))
                    return 0
                })
            XCTFail("expected refusal")
        } catch RemoteFetch.FetchError.disallowedHost { }
    }

    func test_timeoutAndCancellationPreventTransport() async throws {
        do {
            _ = try await PinnedRemoteTransport.fetch(URL(string: "https://example.com/")!, timeout: 0,
                execute: { _ in XCTFail("expired request connected"); return 0 })
            XCTFail("expected timeout")
        } catch RemoteFetch.FetchError.timedOut { }
        let task = Task { try await PinnedRemoteTransport.fetch(URL(string: "https://example.com/")!, timeout: 1,
            execute: { _ in XCTFail("cancelled request connected"); return 0 }) }
        task.cancel()
        do { _ = try await task.value; XCTFail("expected cancellation") } catch is CancellationError { }
    }

    func test_drippingResponseHasAnOverallDeadlineAndCanBeCancelled() async throws {
        let server = Process()
        server.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        server.arguments = ["-u", "-c", """
import socket,time
s=socket.socket();s.bind(('127.0.0.1',0));s.listen(2)
print(s.getsockname()[1],flush=True)
while True:
 c,a=s.accept()
 try:
  c.recv(8192);c.sendall(b'HTTP/1.1 200 OK\\r\\nConnection: close\\r\\n\\r\\n')
  while True: c.sendall(b'x');time.sleep(.02)
 except (BrokenPipeError,ConnectionResetError): c.close()
"""]
        let pipe = Pipe()
        server.standardOutput = pipe
        server.standardError = FileHandle.nullDevice
        try server.run()
        defer { server.terminate(); server.waitUntilExit() }
        var portData = Data()
        while let byte = try pipe.fileHandleForReading.read(upToCount: 1), !byte.isEmpty, byte != Data([10]) { portData.append(byte) }
        let port = try XCTUnwrap(String(data: portData, encoding: .utf8))
        let args = ["-q", "--noproxy", "*", "--max-time", "0.3", "--output", "/dev/null", "--url", "http://127.0.0.1:\(port)/"]
        let clock = ContinuousClock()
        let start = clock.now
        let status = try await PinnedRemoteTransport.run(arguments: args)
        XCTAssertEqual(status, 28)
        XCTAssertLessThan(start.duration(to: clock.now), .seconds(2))
        let task = Task { try await PinnedRemoteTransport.run(arguments: args) }
        try await Task.sleep(for: .milliseconds(60))
        task.cancel()
        do { _ = try await task.value; XCTFail("expected in-flight cancellation") } catch is CancellationError { }
    }

    func test_livePublicTLSControl() async throws {
        guard ProcessInfo.processInfo.environment["DIAGRAM_REMOTE_SMOKE"] == "1" else { throw XCTSkip("opt-in public HTTPS smoke") }
        let (data, response) = try await RemoteFetch.boundedData(from: URL(string: "https://example.com/")!, timeout: 10)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertFalse(data.isEmpty)
    }
}
#endif

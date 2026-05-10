//
//  LiveEditorStateCodecTests.swift
//  DiagramKitTests
//
//  Tests for Base64URL round-trip encoding/decoding.
//  The Base64URL codec lives in DiagramKitModel so it's importable
//  from this test target. LiveEditorStateCodec (in the playground)
//  wraps Base64URL with JSON encode/decode of LiveEditorState.
//

import Foundation
import XCTest
@testable import DiagramKitModel

final class Base64URLTests: XCTestCase {

    // MARK: - Basic round-trip

    func testRoundTripEmptyData() throws {
        let original = Data()
        let encoded = Base64URL.encode(original)
        let decoded = try Base64URL.decode(encoded)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(encoded, "") // empty data → empty base64url
    }

    func testRoundTripSimpleData() throws {
        let original = "hello world".data(using: .utf8)!
        let encoded = Base64URL.encode(original)
        let decoded = try Base64URL.decode(encoded)
        XCTAssertEqual(decoded, original)
    }

    func testRoundTripBinaryData() throws {
        // 256 bytes of random-ish data
        var original = Data()
        for i in 0..<256 {
            original.append(UInt8(i & 0xFF))
        }
        let encoded = Base64URL.encode(original)
        let decoded = try Base64URL.decode(encoded)
        XCTAssertEqual(decoded, original)
    }

    func testRoundTripLargeData() throws {
        // 10 KB of data
        let original = Data(repeating: 0xAB, count: 10_000)
        let encoded = Base64URL.encode(original)
        let decoded = try Base64URL.decode(encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - URL-safe character set

    func testNoPlusOrSlashInEncodedString() throws {
        let original = Data((0...255).map { UInt8($0) })
        let encoded = Base64URL.encode(original)
        XCTAssertFalse(encoded.contains("+"), "Base64URL must not contain '+'")
        XCTAssertFalse(encoded.contains("/"), "Base64URL must not contain '/'")
        XCTAssertFalse(encoded.contains("="), "Base64URL must not contain '=' padding")
    }

    func testDecodeAcceptsStandardBase64() throws {
        // Standard base64 of "hello" = "aGVsbG8="
        let standard = "aGVsbG8="
        let decoded = try Base64URL.decode(standard)
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "hello")
    }

    func testDecodeAcceptsBase64URLWithoutPadding() throws {
        // base64url of "hello" (no padding) = "aGVsbG8"
        let urlSafe = "aGVsbG8"
        let decoded = try Base64URL.decode(urlSafe)
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "hello")
    }

    func testDecodeAcceptsBase64URLChars() throws {
        // "-" and "_" must decode correctly
        // base64 of [0xFF, 0xEF] = "/+8=" → base64url = "_-8"
        let original = Data([0xFF, 0xEF])
        let encoded = Base64URL.encode(original)
        XCTAssertEqual(encoded, "_-8")
        let decoded = try Base64URL.decode("_-8")
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Error cases

    func testInvalidBase64Throws() throws {
        // "!!!###" is not valid base64
        XCTAssertThrowsError(try Base64URL.decode("!!!###")) { error in
            guard let err = error as? Base64URL.Error else {
                XCTFail("Expected Base64URL.Error, got \(type(of: error))")
                return
            }
            XCTAssertEqual(err, .invalidBase64)
        }
    }

    func testEmptyStringDecodesToEmptyData() throws {
        let decoded = try Base64URL.decode("")
        XCTAssertEqual(decoded, Data())
    }

    func testSingleCharDecodes() throws {
        // "Zg" = base64 of "f" (with padding: "Zg==")
        let decoded = try Base64URL.decode("Zg")
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "f")
    }

    // MARK: - Padding edge cases

    func testPaddingLength1() throws {
        // Base64 of "f" = "Zg==" (4 chars with 2 padding)
        // Base64url of "f" = "Zg" (no padding)
        let encoded = Base64URL.encode("f".data(using: .utf8)!)
        let decoded = try Base64URL.decode(encoded)
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "f")
    }

    func testPaddingLength2() throws {
        // Base64 of "fo" = "Zm8=" (4 chars with 1 padding)
        // Base64url of "fo" = "Zm8" (no padding)
        let encoded = Base64URL.encode("fo".data(using: .utf8)!)
        let decoded = try Base64URL.decode(encoded)
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "fo")
    }

    func testPaddingLength3() throws {
        // Base64 of "foo" = "Zm9v" (exact, no padding)
        let encoded = Base64URL.encode("foo".data(using: .utf8)!)
        let decoded = try Base64URL.decode(encoded)
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "foo")
    }
}

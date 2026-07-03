import XCTest
@testable import BoardlyKit

// MARK: - TestLogSink

/// In-memory sink for unit tests — captures SinkEntry values without writing to os_log.
final class TestLogSink: LogSink, @unchecked Sendable {
    private let lock = NSLock()
    private var _entries: [SinkEntry] = []

    var entries: [SinkEntry] { lock.withLock { _entries } }

    func log(_ entry: SinkEntry) {
        lock.withLock { _entries.append(entry) }
    }
}

// MARK: - Tests

final class BoardlyLogTests: XCTestCase {
    private var sink: TestLogSink!
    private var previousSink: any LogSink = OSLogSink()

    override func setUp() {
        super.setUp()
        previousSink = BoardlyLog.sink
        sink = TestLogSink()
        BoardlyLog.sink = sink
    }

    override func tearDown() {
        BoardlyLog.sink = previousSink
        super.tearDown()
    }

    // MARK: Tag routing

    func testTagRouting() {
        BoardlyLog.tag(.auth).info("signed in")
        BoardlyLog.tag(.network).info("request sent")
        BoardlyLog.tag(.sync).warning("behind")

        XCTAssertEqual(sink.entries[0].tag, .auth)
        XCTAssertEqual(sink.entries[1].tag, .network)
        XCTAssertEqual(sink.entries[2].tag, .sync)
    }

    // MARK: Level mapping

    func testLevelMapping() {
        BoardlyLog.tag(.board).info("loaded")
        BoardlyLog.tag(.board).warning("slow")
        BoardlyLog.tag(.board).error("failed")

        XCTAssertEqual(sink.entries[0].level, .info)
        XCTAssertEqual(sink.entries[1].level, .warning)
        XCTAssertEqual(sink.entries[2].level, .error)
    }

    // MARK: Icon prefix

    func testIconPrefixPrependsToMessage() {
        BoardlyLog.tag(.network).icon("📡").info("request started")
        XCTAssertEqual(sink.entries[0].message, "📡 request started")
    }

    func testNoIconLeavesMessageUnchanged() {
        BoardlyLog.tag(.board).info("board loaded")
        XCTAssertEqual(sink.entries[0].message, "board loaded")
    }

    // MARK: Redaction — core security guarantee

    func testRedactedValueNeverReachesSinkInPlaintext() {
        let secret = "super-secret-jwt-ABCDE12345"
        BoardlyLog.tag(.auth).info("login success", metadata: ["token": Redacted(secret)])

        let captured = sink.entries[0].metadata["token"]
        XCTAssertNotNil(captured, "metadata 'token' key should be present")
        XCTAssertEqual(captured, "<redacted>", "Redacted value must appear as '<redacted>'")
        XCTAssertFalse(
            captured?.contains(secret) ?? false,
            "Secret must never reach the sink in plaintext — got: \(captured ?? "nil")")
    }

    func testMultipleRedactedValuesInMetadata() {
        let token = "tok_secret"
        let password = "hunter2"
        BoardlyLog.tag(.auth).warning("refresh", metadata: [
            "token": Redacted(token),
            "password": Redacted(password),
            "url": "https://planka.example.com",
        ])

        let meta = sink.entries[0].metadata
        XCTAssertEqual(meta["token"], "<redacted>")
        XCTAssertEqual(meta["password"], "<redacted>")
        XCTAssertEqual(meta["url"], "https://planka.example.com")
    }

    // MARK: Plain metadata

    func testPlainMetadataPassesThroughAsString() {
        BoardlyLog.tag(.network).info("req", metadata: ["status": 200, "url": "https://x.com"])
        XCTAssertEqual(sink.entries[0].metadata["status"], "200")
        XCTAssertEqual(sink.entries[0].metadata["url"], "https://x.com")
    }

    // MARK: Error capture

    func testErrorDescriptionIsForwarded() {
        struct SampleError: Error, CustomStringConvertible {
            var description: String { "connection timed out" }
        }
        BoardlyLog.tag(.network).error("request failed", error: SampleError())
        XCTAssertTrue(sink.entries[0].errorDescription?.contains("connection timed out") ?? false)
    }

    func testNoErrorLeavesDescriptionNil() {
        BoardlyLog.tag(.network).info("request ok")
        XCTAssertNil(sink.entries[0].errorDescription)
    }
}

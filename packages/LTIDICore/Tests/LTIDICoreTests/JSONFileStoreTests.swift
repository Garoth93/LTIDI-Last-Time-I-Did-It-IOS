import XCTest
@testable import LTIDICore

final class JSONFileStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LTIDICoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testLoadReturnsNilWhenMissing() throws {
        let store = JSONFileStore<ActivityList>(url: directory.appendingPathComponent("state.json"))
        XCTAssertNil(try store.load())
    }

    func testSaveCreatesDirectoryAndLoadRoundTrips() throws {
        let url = directory.appendingPathComponent("nested/state.json")
        let store = JSONFileStore<ActivityList>(url: url)

        var list = ActivityList()
        list.add(name: "Run", lastDone: Date(timeIntervalSince1970: 1_700_000_000))
        try store.save(list)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try store.load(), list)
    }
}

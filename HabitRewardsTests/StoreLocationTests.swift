import XCTest
@testable import HabitRewards

/// Moving the store from the app's own folder into the App Group folder the widget can read.
final class StoreLocationTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func read(_ url: URL) throws -> String {
        String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }

    func testMovesTheStoreAndItsJournalFiles() throws {
        let old = root.appending(path: "app/default.store")
        let new = root.appending(path: "group/Library/Application Support/default.store")
        try write("db", to: old)
        try write("wal", to: URL(filePath: old.path + "-wal"))
        try write("shm", to: URL(filePath: old.path + "-shm"))

        XCTAssertTrue(try StoreLocation.moveStore(from: old, to: new))

        XCTAssertEqual(try read(new), "db")
        XCTAssertEqual(try read(URL(filePath: new.path + "-wal")), "wal")
        XCTAssertEqual(try read(URL(filePath: new.path + "-shm")), "shm")
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
    }

    func testNeverOverwritesAStoreAlreadyInTheNewPlace() throws {
        let old = root.appending(path: "app/default.store")
        let new = root.appending(path: "group/default.store")
        try write("old", to: old)
        try write("new", to: new)

        XCTAssertFalse(try StoreLocation.moveStore(from: old, to: new))
        XCTAssertEqual(try read(new), "new")
        XCTAssertEqual(try read(old), "old")
    }

    func testDoesNothingWhenThereIsNoOldStore() throws {
        let new = root.appending(path: "group/default.store")
        XCTAssertFalse(try StoreLocation.moveStore(from: root.appending(path: "app/default.store"), to: new))
        XCTAssertFalse(FileManager.default.fileExists(atPath: new.path))
    }
}

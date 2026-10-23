//
//  PendingImportStoreTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

final class PendingImportStoreTests: XCTestCase {
    private var container: URL!
    private var sources: URL!
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)
    private var store: PendingImportStore!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        container = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        sources = container.appendingPathComponent("sources", isDirectory: true)
        try fileManager.createDirectory(at: sources, withIntermediateDirectories: true)
        store = PendingImportStore(containerURL: container, now: { [unowned self] in self.clock })
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: container)
    }

    private func sourceFile(_ name: String, contents: String) throws -> URL {
        let url = sources.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Writes one batch holding the given (file name, contents) pairs in order.
    @discardableResult
    private func writeBatch(_ images: [(name: String, contents: String)]) throws -> PendingImportBatch {
        let draft = try store.beginDraft()
        for (index, image) in images.enumerated() {
            try draft.addImage(copying: try sourceFile(image.name, contents: image.contents), at: index)
        }
        return try draft.commit()
    }

    private func contents(of url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: writing and reading

    func test_a_written_batch_is_listed_with_its_images_in_order() throws {
        let written = try writeBatch([("a.png", "first"), ("b.jpeg", "second"), ("c", "third")])

        let listed = store.batches()

        XCTAssertEqual(listed, [written])
        XCTAssertEqual(try listed[0].imageURLs.map(contents(of:)), ["first", "second", "third"])
        XCTAssertEqual(listed[0].imageURLs.map(\.lastPathComponent), ["0.png", "1.jpeg", "2"])
    }

    func test_images_added_out_of_order_are_listed_by_index() throws {
        let draft = try store.beginDraft()
        try draft.addImage(copying: try sourceFile("x.png", contents: "second"), at: 1)
        try draft.addImage(copying: try sourceFile("y.png", contents: "first"), at: 0)
        try draft.commit()

        XCTAssertEqual(try store.batches()[0].imageURLs.map(contents(of:)), ["first", "second"])
    }

    func test_batches_are_listed_oldest_first() throws {
        let older = try writeBatch([("a.png", "older")])
        clock = clock.addingTimeInterval(60)
        let newer = try writeBatch([("b.png", "newer")])

        XCTAssertEqual(store.batches(), [older, newer])
    }

    func test_a_deleted_batch_is_gone() throws {
        let batch = try writeBatch([("a.png", "x")])

        store.delete(batch)

        XCTAssertEqual(store.batches(), [])
        XCTAssertFalse(fileManager.fileExists(atPath: batch.folderURL.path))
    }

    func test_a_missing_root_folder_lists_nothing_and_purging_does_not_crash() {
        XCTAssertEqual(store.batches(), [])
        store.purgeStale()
    }

    func test_folders_with_unknown_names_are_ignored_and_kept() throws {
        try writeBatch([("a.png", "x")])
        let stranger = store.rootURL.appendingPathComponent("not-a-batch", isDirectory: true)
        try fileManager.createDirectory(at: stranger, withIntermediateDirectories: true)

        XCTAssertEqual(store.batches().count, 1)
        clock = clock.addingTimeInterval(PendingImportStore.maximumBatchAge * 2)
        store.purgeStale()
        XCTAssertTrue(fileManager.fileExists(atPath: stranger.path))
    }

    // MARK: failing halfway

    func test_a_draft_with_a_missing_source_fails_and_discarding_it_leaves_nothing() throws {
        let draft = try store.beginDraft()
        try draft.addImage(copying: try sourceFile("a.png", contents: "x"), at: 0)

        XCTAssertThrowsError(try draft.addImage(copying: sources.appendingPathComponent("missing.png"), at: 1))
        draft.discard()

        XCTAssertEqual(store.batches(), [])
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: store.rootURL.path), [])
    }

    func test_a_draft_with_a_gap_in_its_indices_cannot_be_committed() throws {
        let draft = try store.beginDraft()
        try draft.addImage(copying: try sourceFile("a.png", contents: "x"), at: 0)
        try draft.addImage(copying: try sourceFile("c.png", contents: "z"), at: 2)

        XCTAssertThrowsError(try draft.commit())
        XCTAssertEqual(store.batches(), [], "an unfinished draft must never be listed as a batch")
        draft.discard()
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: store.rootURL.path), [])
    }

    func test_an_empty_draft_cannot_be_committed() throws {
        let draft = try store.beginDraft()

        XCTAssertThrowsError(try draft.commit())
    }

    func test_a_committed_draft_accepts_no_more_images() throws {
        let draft = try store.beginDraft()
        try draft.addImage(copying: try sourceFile("a.png", contents: "x"), at: 0)
        try draft.commit()

        XCTAssertThrowsError(try draft.addImage(copying: try sourceFile("b.png", contents: "y"), at: 1))
    }

    func test_images_added_from_several_threads_end_up_in_one_ordered_batch() throws {
        let draft = try store.beginDraft()
        let files = try (0..<8).map { try sourceFile("img\($0).png", contents: "image \($0)") }

        DispatchQueue.concurrentPerform(iterations: files.count) { index in
            do { try draft.addImage(copying: files[index], at: index) } catch { XCTFail("copy \(index) failed: \(error)") }
        }
        let batch = try draft.commit()

        XCTAssertEqual(try batch.imageURLs.map(contents(of:)), (0..<8).map { "image \($0)" })
    }

    // MARK: expiry

    func test_a_batch_older_than_24_hours_is_purged_and_a_newer_one_stays() throws {
        let old = try writeBatch([("a.png", "old")])
        clock = clock.addingTimeInterval(PendingImportStore.maximumBatchAge - 60)
        let recent = try writeBatch([("b.png", "recent")])

        clock = clock.addingTimeInterval(120)   // the first batch is now 24 hours and one minute old
        store.purgeStale()

        XCTAssertFalse(fileManager.fileExists(atPath: old.folderURL.path))
        XCTAssertEqual(store.batches(), [recent])
    }

    func test_a_draft_folder_older_than_one_hour_is_purged_and_a_newer_one_stays() throws {
        _ = try store.beginDraft()                      // left behind
        clock = clock.addingTimeInterval(PendingImportStore.maximumDraftAge - 60)
        let fresh = try store.beginDraft()

        clock = clock.addingTimeInterval(120)
        store.purgeStale()

        let remaining = try fileManager.contentsOfDirectory(atPath: store.rootURL.path)
        XCTAssertEqual(remaining.count, 1)
        try fresh.addImage(copying: try sourceFile("a.png", contents: "x"), at: 0)
        XCTAssertEqual(try fresh.commit().imageURLs.count, 1, "the newer draft must still be usable")
    }

    func test_a_folder_dated_in_the_future_is_purged_because_the_clock_was_set_back() throws {
        clock = clock.addingTimeInterval(3 * 24 * 60 * 60)
        let future = try writeBatch([("a.png", "x")])

        clock = clock.addingTimeInterval(-3 * 24 * 60 * 60)   // the clock is corrected back
        store.purgeStale()

        XCTAssertFalse(fileManager.fileExists(atPath: future.folderURL.path))
    }

    func test_a_folder_dated_slightly_in_the_future_stays() throws {
        clock = clock.addingTimeInterval(60)
        let batch = try writeBatch([("a.png", "x")])

        clock = clock.addingTimeInterval(-60)
        store.purgeStale()

        XCTAssertEqual(store.batches(), [batch])
    }

    // MARK: privacy

    func test_the_pending_folder_is_excluded_from_backup() throws {
        try writeBatch([("a.png", "x")])

        let values = try store.rootURL.resourceValues(forKeys: [.isExcludedFromBackupKey])

        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    /// The simulator ignores file protection, so what can be checked is that protection is requested for the
    /// pending folder, the draft folder and every image. Whether the system then keeps the files unreadable
    /// while the device is locked is verified on a real device.
    func test_protection_is_requested_for_the_folders_and_every_image() throws {
        var protectedNames: [String] = []
        store = PendingImportStore(containerURL: container, now: { [unowned self] in self.clock }, protection: { url in
            protectedNames.append(url.lastPathComponent)
        })

        try writeBatch([("a.png", "x"), ("b.jpeg", "y")])

        XCTAssertTrue(protectedNames.contains("PendingImports"))
        XCTAssertTrue(protectedNames.contains { $0.hasPrefix(".tmp-") }, "the draft folder is not protected")
        XCTAssertTrue(protectedNames.contains("0.png"))
        XCTAssertTrue(protectedNames.contains("1.jpeg"))
    }

    func test_a_failing_protection_stops_the_write_instead_of_leaving_an_unprotected_image() throws {
        struct Refused: Error {}
        store = PendingImportStore(containerURL: container, now: { [unowned self] in self.clock }, protection: { url in
            if url.lastPathComponent == "0.png" { throw Refused() }
        })
        let draft = try store.beginDraft()

        XCTAssertThrowsError(try draft.addImage(copying: try sourceFile("a.png", contents: "x"), at: 0))
        draft.discard()
        XCTAssertEqual(store.batches(), [])
    }

    func test_the_real_protection_can_be_applied() throws {
        // Applying the default protection must not throw, on a device or in the simulator.
        _ = try writeBatch([("a.png", "x")])
    }

    func test_the_app_group_store_lives_inside_the_app_group_container() throws {
        let groupStore = try XCTUnwrap(PendingImportStore.forAppGroup())
        let container = try XCTUnwrap(
            fileManager.containerURL(forSecurityApplicationGroupIdentifier: PendingImportStore.appGroupIdentifier))

        XCTAssertTrue(groupStore.rootURL.standardizedFileURL.path.hasPrefix(container.standardizedFileURL.path))
    }

    func test_an_unknown_app_group_has_no_store() {
        XCTAssertNil(PendingImportStore.forAppGroup("group.does.not.exist"))
    }
}

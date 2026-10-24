//
//  ShareImageImporterTests.swift
//  MyTaiwanStockTests
//

import XCTest
import UniformTypeIdentifiers
@testable import MyTaiwanStock

final class ShareImageImporterTests: XCTestCase {
    private var container: URL!
    private var store: PendingImportStore!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        container = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: container, withIntermediateDirectories: true)
        store = PendingImportStore(containerURL: container)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: container)
    }

    /// A provider that offers a PNG file, like a screenshot shared from the photo library.
    private func imageProvider(_ name: String, contents: String) throws -> NSItemProvider {
        let url = container.appendingPathComponent("\(UUID().uuidString)-\(name)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return try XCTUnwrap(NSItemProvider(contentsOf: url))
    }

    /// A provider whose image cannot be loaded, like a photo whose download from iCloud failed.
    private func failingImageProvider() -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.png.identifier, fileOptions: [], visibility: .all
        ) { completion in
            completion(nil, false, ShareImageImporterError.imageUnavailable)
            return nil
        }
        return provider
    }

    private func importResult(_ providers: [NSItemProvider]) -> Result<PendingImportBatch, Error> {
        var result: Result<PendingImportBatch, Error>?
        let done = expectation(description: "import finished")
        ShareImageImporter.importImages(from: providers, into: store) {
            result = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return result!
    }

    private func contents(of url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func test_shared_images_become_one_batch_in_the_order_they_were_shared() throws {
        let providers = [
            try imageProvider("first.png", contents: "first"),
            try imageProvider("second.png", contents: "second"),
            try imageProvider("third.png", contents: "third"),
        ]

        let batch = try importResult(providers).get()

        XCTAssertEqual(try batch.imageURLs.map(contents(of:)), ["first", "second", "third"])
        XCTAssertEqual(store.batches(), [batch])
    }

    func test_a_slow_image_keeps_its_place_in_the_batch() throws {
        let slowURL = container.appendingPathComponent("\(UUID().uuidString)-slow.png")
        try "slow".write(to: slowURL, atomically: true, encoding: .utf8)
        let slow = NSItemProvider()
        slow.registerFileRepresentation(
            forTypeIdentifier: UTType.png.identifier, fileOptions: [], visibility: .all
        ) { completion in
            // Finishes after the other image, like a photo that is still downloading from iCloud.
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { completion(slowURL, false, nil) }
            return nil
        }

        let batch = try importResult([slow, try imageProvider("fast.png", contents: "fast")]).get()

        XCTAssertEqual(try batch.imageURLs.map(contents(of:)), ["slow", "fast"])
    }

    func test_attachments_that_are_not_images_are_ignored() throws {
        let note = try XCTUnwrap(NSItemProvider(item: "some text" as NSString, typeIdentifier: UTType.plainText.identifier))
        let providers = [note, try imageProvider("shot.png", contents: "shot")]

        let batch = try importResult(providers).get()

        XCTAssertEqual(try batch.imageURLs.map(contents(of:)), ["shot"])
    }

    func test_sharing_only_non_images_fails_and_creates_no_batch() throws {
        let note = try XCTUnwrap(NSItemProvider(item: "some text" as NSString, typeIdentifier: UTType.plainText.identifier))

        let result = importResult([note])

        guard case .failure(let error) = result, case ShareImageImporterError.noImages = error else {
            return XCTFail("expected noImages, got \(result)")
        }
        XCTAssertEqual(store.batches(), [])
    }

    func test_one_image_that_cannot_be_loaded_fails_the_whole_share_and_leaves_nothing() throws {
        let providers = [try imageProvider("ok.png", contents: "ok"), failingImageProvider()]

        let result = importResult(providers)

        guard case .failure = result else { return XCTFail("expected a failure, got \(result)") }
        XCTAssertEqual(store.batches(), [])
        let leftovers = (try? fileManager.contentsOfDirectory(atPath: store.rootURL.path)) ?? []
        XCTAssertEqual(leftovers, [], "the draft folder must be removed")
    }

    /// A provider whose image arrives after `delay`, like a photo that is still downloading from iCloud.
    private func slowImageProvider(delay: TimeInterval) throws -> NSItemProvider {
        let url = container.appendingPathComponent("\(UUID().uuidString)-slow.png")
        try "slow".write(to: url, atomically: true, encoding: .utf8)
        let provider = NSItemProvider()
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.png.identifier, fileOptions: [], visibility: .all
        ) { completion in
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { completion(url, false, nil) }
            return nil
        }
        return provider
    }

    func test_cancelling_a_share_that_is_still_loading_removes_the_draft_and_never_completes() throws {
        var completed = false
        let handle = ShareImageImporter.importImages(
            from: [try imageProvider("fast.png", contents: "fast"), try slowImageProvider(delay: 0.3)], into: store
        ) { _ in completed = true }
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: store.rootURL.path).count, 1, "the draft exists while loading")

        handle.cancel()
        let settled = expectation(description: "the slow image arrived")
        settled.isInverted = true
        wait(for: [settled], timeout: 0.8)

        XCTAssertFalse(completed)
        XCTAssertEqual(store.batches(), [])
        XCTAssertEqual(try fileManager.contentsOfDirectory(atPath: store.rootURL.path), [], "nothing is left behind")
    }

    func test_cancelling_a_share_that_already_finished_keeps_its_batch() throws {
        var result: Result<PendingImportBatch, Error>?
        let done = expectation(description: "import finished")
        let handle = ShareImageImporter.importImages(from: [try imageProvider("a.png", contents: "a")], into: store) {
            result = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        let batch = try XCTUnwrap(result).get()

        handle.cancel()

        XCTAssertEqual(store.batches(), [batch])
    }

    func test_an_unavailable_container_fails_the_share() throws {
        // A file where the pending folder should be: the folder cannot be created.
        try "x".write(to: container.appendingPathComponent("PendingImports"), atomically: true, encoding: .utf8)

        let result = importResult([try imageProvider("a.png", contents: "a")])

        guard case .failure = result else { return XCTFail("expected a failure, got \(result)") }
    }
}

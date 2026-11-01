//
//  TradeTextRecognizerTests.swift
//  MyTaiwanStockTests
//

import XCTest
import UIKit
@testable import MyTaiwanStock

final class TradeTextRecognizerTests: XCTestCase {

    func test_invalid_image_data_throws_and_returns_no_boxes() async {
        do {
            let boxes = try await TradeTextRecognizer().recognize(imageData: Data("not an image".utf8))
            XCTFail("expected an error, got \(boxes.count) boxes")
        } catch {
            // expected
        }
    }

    func test_empty_data_throws() async {
        do {
            _ = try await TradeTextRecognizer().recognize(imageData: Data())
            XCTFail("expected an error")
        } catch {
            // expected
        }
    }

    func test_traditional_chinese_text_is_recognized_with_vision_coordinates() async throws {
        let size = CGSize(width: 900, height: 400)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64), .foregroundColor: UIColor.black,
            ]
            // Upper line near the top, lower line near the bottom.
            "元大台灣50".draw(at: CGPoint(x: 40, y: 40), withAttributes: attributes)
            "盤中零股買進".draw(at: CGPoint(x: 40, y: 280), withAttributes: attributes)
        }

        let boxes = try await TradeTextRecognizer().recognize(imageData: image.pngData()!)

        let upper = try XCTUnwrap(boxes.first { $0.text.contains("台灣") })
        let lower = try XCTUnwrap(boxes.first { $0.text.contains("買進") })
        XCTAssertGreaterThan(upper.midY, lower.midY, "Vision coordinates put the upper line at a larger y")
        XCTAssertTrue((0...1).contains(upper.midX) && (0...1).contains(upper.midY))
    }
}

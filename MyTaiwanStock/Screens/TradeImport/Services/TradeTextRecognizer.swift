//
//  TradeTextRecognizer.swift
//  MyTaiwanStock
//

import Foundation
import Vision

protocol TradeTextRecognizing: Sendable {
    func recognize(imageData: Data) async throws -> [RecognizedTextBox]
}

enum TradeTextRecognizerError: Error {
    case invalidImage
}

/// Reads the text of a screenshot on the device with Vision. Nothing leaves the phone.
struct TradeTextRecognizer: TradeTextRecognizing {

    /// The returned boxes use Vision coordinates: normalized, origin at the lower left.
    /// Throws when the data is not a readable image or recognition fails.
    func recognize(imageData: Data) async throws -> [RecognizedTextBox] {
        guard !imageData.isEmpty else { throw TradeTextRecognizerError.invalidImage }

        // `perform` is synchronous and heavy, so it runs off the caller's thread.
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hant", "en-US"]
            // Language correction rewrites stock names and digits; the raw text is what we parse.
            request.usesLanguageCorrection = false

            try VNImageRequestHandler(data: imageData, options: [:]).perform([request])

            return (request.results ?? []).compactMap { observation in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return RecognizedTextBox(text: candidate.string, boundingBox: observation.boundingBox)
            }
        }.value
    }
}

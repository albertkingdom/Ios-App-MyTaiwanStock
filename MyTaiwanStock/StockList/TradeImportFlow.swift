//
//  TradeImportFlow.swift
//  MyTaiwanStock
//

import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Runs the screenshot import: pick screenshots, recognize them on the device, then push the
/// preview onto the home screen's navigation stack. The preview is pushed (not presented as a
/// sheet) so returning to the home screen runs its normal appear and reload path.
@MainActor
final class TradeImportFlow: NSObject {
    private let navigationController: UINavigationController
    private let listNames: [String]
    private let currentListName: String?
    private let onImported: () -> Void
    private let recognizer: TradeTextRecognizing
    private let onFinished: () -> Void

    private var loadingAlert: UIAlertController?

    init(
        navigationController: UINavigationController,
        listNames: [String],
        currentListName: String?,
        onImported: @escaping () -> Void,
        onFinished: @escaping () -> Void,
        recognizer: TradeTextRecognizing = TradeTextRecognizer()
    ) {
        self.navigationController = navigationController
        self.listNames = listNames
        self.currentListName = currentListName
        self.onImported = onImported
        self.onFinished = onFinished
        self.recognizer = recognizer
    }

    func start() {
        // PHPicker runs out of process and needs no photo library permission.
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 0
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        navigationController.present(picker, animated: true)
    }

    // MARK: recognition

    private func process(_ results: [PHPickerResult]) {
        showLoading()
        Task {
            do {
                var trades: [ParsedTrade] = []
                for result in results {
                    let data = try await Self.imageData(of: result)
                    let boxes = try await recognizer.recognize(imageData: data)
                    trades += TradeScreenshotParser.parse(boxes: boxes)
                }
                hideLoading { self.showPreview(trades) }
            } catch {
                hideLoading { self.showMessage(title: "無法讀取圖片", message: "圖片載入或辨識失敗，請換一張截圖再試。") }
            }
        }
    }

    private static func imageData(of result: PHPickerResult) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? TradeTextRecognizerError.invalidImage)
                }
            }
        }
    }

    // MARK: presenting

    private func showPreview(_ trades: [ParsedTrade]) {
        guard !trades.isEmpty else {
            showMessage(title: "找不到可匯入的成交紀錄", message: "請確認截圖是投資先生「交易 → 明細」的畫面。")
            return
        }
        let repository = StockListRepository.shared
        let viewModel = TradeImportViewModel(
            trades: trades,
            resolver: StockNameResolver(entries: repository.entries),
            isKnownCode: { repository.contains(code: $0) },
            store: DefaultTradeImportStore(),
            listNames: listNames,
            currentListName: currentListName)
        let preview = TradeImportPreviewViewController(viewModel: viewModel) { [weak self] in
            guard let self else { return }
            navigationController.popToRootViewController(animated: true)
            onImported()
            onFinished()
        }
        navigationController.pushViewController(preview, animated: true)
    }

    private func showLoading() {
        let alert = UIAlertController(title: "辨識截圖中…", message: "\n", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        alert.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20),
        ])
        loadingAlert = alert
        navigationController.present(alert, animated: true)
    }

    private func hideLoading(then completion: @escaping () -> Void) {
        guard let alert = loadingAlert else { return completion() }
        loadingAlert = nil
        alert.dismiss(animated: true, completion: completion)
    }

    private func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { [weak self] _ in self?.onFinished() })
        navigationController.present(alert, animated: true)
    }
}

extension TradeImportFlow: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            if results.isEmpty {
                onFinished()
            } else {
                process(results)
            }
        }
    }
}

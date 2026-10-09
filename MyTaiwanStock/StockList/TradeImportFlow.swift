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

    private var loadingScreen: TradeImportLoadingViewController?

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
        let started = ContinuousClock.now
        Task {
            let outcome: Result<[ParsedTrade], Error>
            do {
                var trades: [ParsedTrade] = []
                for result in results {
                    let data = try await Self.imageData(of: result)
                    let boxes = try await recognizer.recognize(imageData: data)
                    trades += TradeScreenshotParser.parse(boxes: boxes)
                }
                outcome = .success(trades)
            } catch {
                outcome = .failure(error)
            }
            await keepLoadingVisible(since: started)
            hideLoading {
                switch outcome {
                case .success(let trades):
                    self.showPreview(trades)
                case .failure:
                    self.showMessage(title: "無法讀取圖片", message: "圖片載入或辨識失敗，請換一張截圖再試。")
                }
            }
        }
    }

    /// Recognition often finishes in a fraction of a second, which would make the loading screen
    /// flash away before its animation is seen. Hold it for one scan sweep at least, unless
    /// Reduce Motion is on and there is no animation to wait for.
    private static let minimumLoadingDuration = Duration.milliseconds(1500)

    private func keepLoadingVisible(since started: ContinuousClock.Instant) async {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let remaining = Self.minimumLoadingDuration - (ContinuousClock.now - started)
        if remaining > .zero { try? await Task.sleep(for: remaining) }
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
        let loading = TradeImportLoadingViewController()
        loadingScreen = loading
        navigationController.present(loading, animated: true)
    }

    private func hideLoading(then completion: @escaping () -> Void) {
        guard let loading = loadingScreen else { return completion() }
        loadingScreen = nil
        loading.dismiss(animated: true, completion: completion)
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

/// Shown while Vision reads the screenshots: a frosted card over a dimmed screen.
///
/// Separate from `showLoadingIcon()` in ViewController+extension.swift on purpose: that one is a
/// small spinner added to a screen while it loads data, while this is a full-screen modal that
/// blocks the import flow and carries a message about the work being done on the device.
private final class TradeImportLoadingViewController: UIViewController {

    private static let scannerSize: CGFloat = 72
    private static let scanTravel: CGFloat = 20

    private let scanLine = UIView()

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true

        let iconView = UIImageView(image: UIImage(systemName: "viewfinder"))
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 64, weight: .ultraLight)
        iconView.tintColor = .tintColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        scanLine.backgroundColor = .tintColor
        scanLine.layer.cornerRadius = 1
        scanLine.translatesAutoresizingMaskIntoConstraints = false

        let scanner = UIView()
        scanner.addSubview(iconView)
        scanner.addSubview(scanLine)
        NSLayoutConstraint.activate([
            scanner.widthAnchor.constraint(equalToConstant: Self.scannerSize),
            scanner.heightAnchor.constraint(equalToConstant: Self.scannerSize),
            iconView.centerXAnchor.constraint(equalTo: scanner.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: scanner.centerYAnchor),
            scanLine.centerXAnchor.constraint(equalTo: scanner.centerXAnchor),
            scanLine.centerYAnchor.constraint(equalTo: scanner.centerYAnchor),
            scanLine.widthAnchor.constraint(equalToConstant: Self.scannerSize - 24),
            scanLine.heightAnchor.constraint(equalToConstant: 2),
        ])

        let titleLabel = UILabel()
        titleLabel.text = "辨識截圖中…"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center

        let detailLabel = UILabel()
        detailLabel.text = "在手機上處理，不會上傳"
        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [scanner, titleLabel, detailLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.setCustomSpacing(16, after: scanner)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(card)
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            card.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -64),
            card.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -24),
        ])

        view.isAccessibilityElement = true
        view.accessibilityLabel = "辨識截圖中"

        // UIKit drops running animations when the app goes to the background.
        NotificationCenter.default.addObserver(
            self, selector: #selector(startScanning), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }

    @objc private func startScanning() {
        guard !UIAccessibility.isReduceMotionEnabled, view.window != nil else { return }
        scanLine.layer.removeAllAnimations()
        scanLine.transform = CGAffineTransform(translationX: 0, y: -Self.scanTravel)
        UIView.animate(
            withDuration: 1.1, delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut]
        ) {
            self.scanLine.transform = CGAffineTransform(translationX: 0, y: Self.scanTravel)
        }
    }
}

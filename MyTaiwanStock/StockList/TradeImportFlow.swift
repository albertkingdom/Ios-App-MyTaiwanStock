//
//  TradeImportFlow.swift
//  MyTaiwanStock
//

import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// Runs the screenshot import: recognize the screenshots of an image source on the device, then push
/// the preview onto the home screen's navigation stack. The preview is pushed (not presented as a
/// sheet) so returning to the home screen runs its normal appear and reload path.
///
/// The flow is in progress from its creation until it ends, once, whichever way: the preview is closed
/// or its import finished, a message was dismissed, the picker was cancelled, or the recognition was
/// interrupted.
@MainActor
final class TradeImportFlow: NSObject {
    enum State: Equatable {
        case inProgress
        case finished
    }

    enum Ending: Equatable {
        /// The user is done: imported, went back, dismissed a message or cancelled the picker.
        case completed
        /// The system interrupted the recognition (the app left the foreground, the device was locked).
        /// Nothing was shown, and the source keeps its images for another try.
        case interrupted
    }

    typealias MakeViewModel = (_ trades: [ParsedTrade], _ listNames: [String], _ currentListName: String?) -> TradeImportViewModel

    private(set) var state: State = .inProgress

    private let navigationController: UINavigationController
    private let listNames: [String]
    private let currentListName: String?
    private let onImported: () -> Void
    private let recognizer: TradeTextRecognizing
    private let onFinished: (Ending) -> Void
    private let makeViewModel: MakeViewModel
    private let minimumLoadingDuration: Duration
    private let isAppActive: () -> Bool

    private var loadingScreen: TradeImportLoadingViewController?

    /// Recognition often finishes in a fraction of a second, which would make the loading screen
    /// flash away before its animation is seen. By default it is held for one scan sweep at least,
    /// unless Reduce Motion is on and there is no animation to wait for.
    static let defaultMinimumLoadingDuration = Duration.milliseconds(1500)

    init(
        navigationController: UINavigationController,
        listNames: [String],
        currentListName: String?,
        onImported: @escaping () -> Void,
        onFinished: @escaping (Ending) -> Void,
        recognizer: TradeTextRecognizing = TradeTextRecognizer(),
        makeViewModel: @escaping MakeViewModel = TradeImportFlow.makeStoredViewModel,
        minimumLoadingDuration: Duration = TradeImportFlow.defaultMinimumLoadingDuration,
        isAppActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active }
    ) {
        self.navigationController = navigationController
        self.listNames = listNames
        self.currentListName = currentListName
        self.onImported = onImported
        self.onFinished = onFinished
        self.recognizer = recognizer
        self.makeViewModel = makeViewModel
        self.minimumLoadingDuration = minimumLoadingDuration
        self.isAppActive = isAppActive
    }

    /// Lets the user pick screenshots from the photo library, then recognizes them.
    func start() {
        // PHPicker runs out of process and needs no photo library permission.
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 0
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        navigationController.present(picker, animated: true)
    }

    /// Recognizes the images of a source that already holds them, such as a pending batch.
    func start(importing source: TradeImageSource) {
        process(source)
    }

    /// The preview of the trades in the app's own storage.
    static func makeStoredViewModel(trades: [ParsedTrade], listNames: [String], currentListName: String?) -> TradeImportViewModel {
        let repository = StockListRepository.shared
        return TradeImportViewModel(
            trades: trades,
            resolver: StockNameResolver(entries: repository.entries),
            isKnownCode: { repository.contains(code: $0) },
            store: DefaultTradeImportStore(),
            listNames: listNames,
            currentListName: currentListName)
    }

    // MARK: ending

    private func finish(_ ending: Ending) {
        guard state == .inProgress else { return }
        state = .finished
        onFinished(ending)
    }

    /// The import in the preview was written and acknowledged. Going back to the root closes the preview,
    /// which ends the flow a second time; only the first one counts.
    func previewDidImport() {
        navigationController.popToRootViewController(animated: true)
        onImported()
        finish(.completed)
    }

    /// The preview left the navigation stack, for example through the back button.
    func previewDidClose() {
        finish(.completed)
    }

    // MARK: recognition

    private enum Outcome {
        case trades([ParsedTrade])
        case failed
        case interrupted
    }

    private func process(_ source: TradeImageSource) {
        showLoading()
        let started = ContinuousClock.now
        Task {
            let outcome = await recognize(source)
            if case .interrupted = outcome {
                hideLoading { self.finish(.interrupted) }
                return
            }
            // A result is known, so the images are no longer needed, before anything is shown.
            source.recognitionDidFinish()
            await keepLoadingVisible(since: started)
            hideLoading {
                switch outcome {
                case .trades(let trades):
                    self.showPreview(trades)
                case .failed, .interrupted:
                    self.showMessage(title: "無法讀取圖片", message: "圖片載入或辨識失敗，請換一張截圖再試。")
                }
            }
        }
    }

    private func recognize(_ source: TradeImageSource) async -> Outcome {
        do {
            var trades: [ParsedTrade] = []
            for index in 0..<source.count {
                let data = try await source.imageData(at: index)
                let boxes = try await recognizer.recognize(imageData: data)
                trades += TradeScreenshotParser.parse(boxes: boxes)
            }
            return .trades(trades)
        } catch {
            // Reading fails while the device is locked and Vision may fail in the background. Neither says
            // anything about the images, so they are kept rather than reported as unreadable.
            return error is CancellationError || !isAppActive() ? .interrupted : .failed
        }
    }

    private func keepLoadingVisible(since started: ContinuousClock.Instant) async {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let remaining = minimumLoadingDuration - (ContinuousClock.now - started)
        if remaining > .zero { try? await Task.sleep(for: remaining) }
    }

    // MARK: presenting

    private func showPreview(_ trades: [ParsedTrade]) {
        guard !trades.isEmpty else {
            showMessage(title: "找不到可匯入的成交紀錄", message: "請確認截圖是投資先生「交易 → 明細」的畫面。")
            return
        }
        let preview = TradeImportPreviewViewController(
            viewModel: makeViewModel(trades, listNames, currentListName),
            onImported: { [weak self] in self?.previewDidImport() },
            onClosed: { [weak self] in self?.previewDidClose() })
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
        alert.addAction(UIAlertAction(title: "好", style: .default) { [weak self] _ in self?.finish(.completed) })
        navigationController.present(alert, animated: true)
    }
}

extension TradeImportFlow: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            if results.isEmpty {
                finish(.completed)
            } else {
                process(PhotoPickerImageSource(results: results))
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

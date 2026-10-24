//
//  ShareViewController.swift
//  ShareExtension
//

import UIKit

/// The share sheet entry of the app. It only copies the shared images into the pending import folder
/// (see ShareImageImporter) and then finishes; recognizing them and showing the confirmation preview
/// happen in the app, after the user opens it.
final class ShareViewController: UIViewController {
    private let spinner = UIActivityIndicatorView(style: .large)
    private let iconView = UIImageView()
    private let messageLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private var didStart = false
    private var currentImport: ShareImageImport?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        iconView.contentMode = .scaleAspectFit
        iconView.isHidden = true

        messageLabel.text = "正在加入待匯入…"
        messageLabel.font = .preferredFont(forTextStyle: .headline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        spinner.startAnimating()

        cancelButton.setTitle("取消", for: .normal)
        cancelButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        cancelButton.titleLabel?.adjustsFontForContentSizeCategory = true
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [iconView, spinner, messageLabel, cancelButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        startImport()
    }

    private func startImport() {
        guard let store = PendingImportStore.forAppGroup() else {
            return fail("無法使用共用資料夾，請稍後再試。")
        }
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        currentImport = ShareImageImporter.importImages(from: attachments, into: store) { [weak self] result in
            switch result {
            case .success:
                self?.showDone()
            case .failure(let error):
                self?.fail(Self.message(for: error))
            }
        }
    }

    /// Gives up on a share that is still copying, for example a photo that is slow to download from iCloud.
    @objc private func cancelTapped() {
        currentImport?.cancel()
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    private func showDone() {
        spinner.stopAnimating()
        cancelButton.isHidden = true
        iconView.image = UIImage(systemName: "checkmark.circle.fill")
        iconView.tintColor = .systemGreen
        iconView.isHidden = false
        let message = "已加入待匯入，請開啟 MyTaiwanStock 確認"
        messageLabel.text = message
        UIAccessibility.post(notification: .announcement, argument: message)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func fail(_ message: String) {
        spinner.stopAnimating()
        cancelButton.isHidden = true
        let alert = UIAlertController(title: "無法加入待匯入", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 1))
        })
        present(alert, animated: true)
    }

    private static func message(for error: Error) -> String {
        switch error as? ShareImageImporterError {
        case .noImages:
            return "分享的內容裡沒有圖片。"
        default:
            return "圖片載入或複製失敗，請再試一次。"
        }
    }
}

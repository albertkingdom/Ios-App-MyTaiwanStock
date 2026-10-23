//
//  ShareViewController.swift
//  ShareExtension
//

import UIKit

/// Entry point of the share extension. Copying the shared images into the pending import folder is
/// added with the extension's behavior; for now it only presents an empty screen.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }
}

//
//  WriteReasonViewController.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/6/9.
//

import UIKit

class MemoViewController: UIViewController, UITextViewDelegate {

    @IBOutlet weak var contentTextView: UITextView!
    let placeholderText = "請輸入投資筆記"
    var viewModel: AddHistoryViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initView()
        setupNotifications()
    }
    func initView() {
        contentTextView.delegate = self
        contentTextView.text = placeholderText
        contentTextView.textColor = .lightGray
        contentTextView.font = .systemFont(ofSize: 24)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if textView.text == placeholderText {
            textView.text = ""
            textView.textColor = .label
        }
        return true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = placeholderText
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        viewModel?.memo = textView.text
    }
    
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    @objc func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        contentTextView.contentInset = contentInsets
        contentTextView.scrollIndicatorInsets = contentInsets
        if let selectedRange = contentTextView.selectedTextRange {
            contentTextView.scrollRangeToVisible(contentTextView.selectedRange)
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        let contentInsets = UIEdgeInsets.zero
        contentTextView.contentInset = contentInsets
        contentTextView.scrollIndicatorInsets = contentInsets
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

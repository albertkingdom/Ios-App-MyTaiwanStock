//
//  EditFeeViewController.swift
//  MyTaiwanStock
//
//  Created by YKLin on 8/31/22.
//

import UIKit

class EditFeeViewController: UITableViewController {
    @IBOutlet weak var feeTextField: UITextField!
    /// Where the fixed fee is saved; tests pass a store of their own.
    var userDefaults: UserDefaults = .standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save".localized, style: .done, target: self, action: #selector(onTapSave(_:)))
        
        initView()
        
    }
    @objc func onTapSave(_ sender: UIBarButtonItem) {
        do {
            let amount = try ValidInputService().validUserDefinedFee(feeTextField.text)
            FeeSettings.saveFixedAmount(amount, userDefaults: userDefaults)
            navigationController?.popViewController(animated: true)
        } catch {
            let alert = UIAlertController(title: "手續費無法儲存", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default))
            present(alert, animated: true)
        }
    }
    
    func initView() {
        self.navigationItem.title = "編輯手續費"
        
        tableView.separatorStyle = .none
        tableView.backgroundColor = .secondarySystemBackground
        
        feeTextField.text = "\(FeeSettings.currentFixedAmount(userDefaults: userDefaults))"
        feeTextField.placeholder = "新台幣"
        feeTextField.borderStyle = .roundedRect
//        feeTextField.backgroundColor = .lightGray
        feeTextField.keyboardType = .decimalPad
        feeTextField.inputAccessoryView = toolBar()
    }
    
}

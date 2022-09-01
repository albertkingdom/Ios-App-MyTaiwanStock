//
//  EditFeeViewController.swift
//  MyTaiwanStock
//
//  Created by YKLin on 8/31/22.
//

import UIKit

class EditFeeViewController: UITableViewController {
    @IBOutlet weak var feeTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(onTapSave(_:)))
        
        initView()
        
    }
    @objc func onTapSave(_ sender: UIBarButtonItem) {
        print("onTapSave")
        // save to userdefault
        guard let fee = feeTextField.text,
              let feeDouble = Double(fee)
        else {
            return
        }
        print("fee double \(feeDouble)")
        UserDefaults.standard.set(feeDouble, forKey: UserDefaults.userDefinedFeeInDollarsKey)
        navigationController?.popViewController(animated: true)
    }
    
    func initView() {
        self.navigationItem.title = "編輯手續費"
        
        tableView.separatorStyle = .none
        tableView.backgroundColor = .secondarySystemBackground
    }
    
}

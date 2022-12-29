//
//  AddDividendViewController.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/22/22.
//

import UIKit

class AddDividendViewController: UITableViewController {
    var stockNo: String!
    var viewModel = AddDividendViewModel()
    var selectedDate = Date()
    @IBOutlet weak var stockNoLabel: UILabel!
    @IBOutlet weak var cashDividend: UITextField! //現金股利
    @IBOutlet weak var stockDividend: UITextField! //股票股利
    @IBAction func dateValueChanged(_ sender: UIDatePicker) {
        selectedDate = sender.date
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        tableView.rowHeight=50
        tableView.separatorStyle = .none
        navigationItem.title = "新增股利"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(pressCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "儲存", style: .plain, target: self, action: #selector(pressSave))
        stockNoLabel.text = stockNo
        
        // keyboard
        cashDividend.keyboardType = .numberPad
        stockDividend.keyboardType = .numberPad
        
    }
    @objc func pressCancel() {
        navigationController?.popViewController(animated: true)
    }
    @objc func pressSave() {
        var hasValue = false
        dismissKeyboard()
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        if let cashDividendStr = cashDividend.text,
           let cashDividendInt = Int(cashDividendStr),
           cashDividendInt>0 {
            viewModel.saveCashDividend(stockNo: stockNo, amount: cashDividendInt, date: selectedDate)
            hasValue = true
        }
        if let stockDividendStr = stockDividend.text,
           let stockDividendInt = Int(stockDividendStr),
           stockDividendInt>0 {
            viewModel.saveStockDividend(stockNo: stockNo, amount: stockDividendInt, date: selectedDate)
            hasValue = true
        }
        if hasValue {
            showToast(message: "成功新增一筆紀錄")
        
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.navigationController?.popViewController(animated: true)
            }
        } else {
            showToast(message: "請填入數字")
        }
        
    }
   

    

    
   
}

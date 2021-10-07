//
//  AddHistoryViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/6.
//

import UIKit

class AddHistoryViewController: UITableViewController {
    var history: [History]!
    var stockNo: String!
    var date: Date! = Date()
    @IBOutlet weak var stockNoTextField: UITextField!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var buyOrSell: UISegmentedControl!
    
    @IBAction func datePickerChanged(_ sender: UIDatePicker) {
        
        print(sender.date)
        
        date = sender.date
    }
    @IBAction func saveNewRecord(_ sender: Any){

        guard let stockNo = stockNoTextField.text,
        let price = Float(priceTextField.text ?? "0"),
        let amount = Int(amountTextField.text ?? "0"),
        let date = date else { return }
        let newId = HistoryList.createId(historyList: HistoryList.historyList)
        let newRecord = History(id: newId, stockNo: stockNo, date: date, price: price, amount: amount, status: buyOrSell.selectedSegmentIndex)
        
        
        print("new record, \(newRecord)")
        HistoryList.saveToDisk(newHistory: newRecord)
        print("buyorsell, \(buyOrSell.selectedSegmentIndex)")
        navigationController?.popViewController(animated: true)
    }
    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        stockNoTextField.text = stockNo
        stockNoTextField.keyboardType = .numberPad
        priceTextField.keyboardType = .decimalPad
        amountTextField.keyboardType = .numberPad
        // Do any additional setup after loading the view.
        
        navigationItem.title = "新增一筆"
    }
    
    func dateFormat(date: Date) -> String {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyyMMdd"
        let datestr = dateFormatter.string(from: date)
        
        return datestr
    }
   

}


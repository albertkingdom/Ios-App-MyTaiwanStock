//
//  AddHistoryViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/6.
//
import CoreData
import UIKit

class AddHistoryViewController: UITableViewController {
    var context: NSManagedObjectContext?

    var stockNo: String!
    var date: Date! = Date()
    var buyOrSellStatus: Int! = 0
    @IBOutlet weak var stockNoTextField: UITextField!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
  
    
    @IBAction func setSegmentControl(_ sender: UISegmentedControl) {

        switch sender.selectedSegmentIndex {
        case 0:
            buyOrSellStatus = 0
        case 1:
            buyOrSellStatus = 1
        default:
            buyOrSellStatus = 0
        }
    }
    @IBAction func datePickerChanged(_ sender: UIDatePicker) {
        
        //print(sender.date)
        
        date = sender.date
    }
    
    @IBAction func saveNewRecord(_ sender: Any){

        guard let stockNo = stockNoTextField.text,
        let price = Float(priceTextField.text ?? "0"),
        let amount = Int(amountTextField.text ?? "0"),
        let date = date else { return }

        
        /// core data
        guard let context = self.context else { return }
        let newInvestHistory = InvestHistory(context: context)
        newInvestHistory.stockNo = stockNo
        newInvestHistory.price = price
        newInvestHistory.amount = Int16(amount)
        newInvestHistory.date = date
        newInvestHistory.status = Int16(buyOrSellStatus)
        
        do {
            try context.save()
        } catch {
            fatalError("\(error.localizedDescription)")
        }

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
       
        stockNoTextField.inputAccessoryView = toolBar()
        priceTextField.inputAccessoryView = toolBar()
        amountTextField.inputAccessoryView = toolBar()
        navigationItem.title = "新增一筆"
    }
    
    func dateFormat(date: Date) -> String {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyyMMdd"
        let datestr = dateFormatter.string(from: date)
        
        return datestr
    }
   

}

extension UIViewController {
    // toolbar on the top of keyboard
    func toolBar() -> UIToolbar {
        let toolBar = UIToolbar(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 44)))
       
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(dismissKeyboard))
        
        toolBar.setItems([space, doneButton], animated: true)
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        toolBar.sizeToFit()
        return toolBar
    }
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

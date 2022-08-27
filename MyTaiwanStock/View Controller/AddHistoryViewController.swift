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
    let validationService = ValidInputService()
    var stockNo: String!
    
    let viewModel = AddHistoryViewModel()
    
    @IBOutlet weak var stockNoTextField: UITextField!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var reasonTextView: UITextView!
    
    @IBAction func setSegmentControl(_ sender: UISegmentedControl) {

        switch sender.selectedSegmentIndex {
        case 0:
            viewModel.buyOrSellStatus = 0
        case 1:
            viewModel.buyOrSellStatus = 1
        default:
            viewModel.buyOrSellStatus = 0
        }
    }
    @IBAction func datePickerChanged(_ sender: UIDatePicker) {
        
        //print(sender.date)
        
        viewModel.date = sender.date
    }
    
    @IBAction func saveNewRecord(_ sender: Any){
        
        do {
            let stockNo = try validationService.validStockNo(stockNoTextField.text)
            let price = try validationService.validStockPriceInput(priceTextField.text)
            let amount = try validationService.validStockAmountInput(amountTextField.text)
            let reason = reasonTextView.text ?? ""
            viewModel.saveNewRecord(
                stockNo: stockNo,
                price: price,
                amount: amount,
                reason: reason
            )
            showToast(message: "成功新增一筆投資紀錄")
            navigationController?.popViewController(animated: true)
        } catch {
            showToast(message: error.localizedDescription)
        }

    }
    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.context = context
        
        stockNoTextField.text = stockNo
        stockNoTextField.keyboardType = .numberPad
        priceTextField.keyboardType = .decimalPad
        amountTextField.keyboardType = .numberPad
       
        stockNoTextField.inputAccessoryView = toolBar()
        priceTextField.inputAccessoryView = toolBar()
        amountTextField.inputAccessoryView = toolBar()
        navigationItem.title = "新增一筆"
        reasonTextView.layer.borderColor = UIColor.lightGray.cgColor
        reasonTextView.layer.borderWidth = 2
        reasonTextView.layer.cornerRadius = 5
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

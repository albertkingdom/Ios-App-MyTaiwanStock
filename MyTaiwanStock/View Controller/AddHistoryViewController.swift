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
    //var date: Date! = Date()
    //var buyOrSellStatus: Int! = 0
    
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
        
        guard let stockNo = stockNoTextField.text,
              let price = Float(priceTextField.text ?? "0"),
              let amount = Int(amountTextField.text ?? "0")
        else { return }
        let reason = reasonTextView.text ?? ""
        

        viewModel.saveNewRecord(
            stockNo: stockNo,
            price: price,
            amount: amount,
            reason: reason
        )
        navigationController?.popViewController(animated: true)
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
        navigationItem.title = "????????????"
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

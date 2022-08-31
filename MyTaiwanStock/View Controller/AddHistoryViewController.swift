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
    let feeCategory = ["折數","盤中零股", "自訂(元)"]
    let feePercent = (1...10).map{ int -> String in
        if int < 10 {
            return "\(int)折"
        } else {
            return "無折扣"
        }
    }
    var fee: Fee!
    @IBOutlet weak var stockNoLabel: UILabel!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var reasonTextView: UITextView!
    @IBOutlet weak var feePicker: UIPickerView!
    @IBOutlet weak var feeTextField: UITextField!
    
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
        dismissKeyboard()

        do {
            
            let price = try validationService.validStockPriceInput(priceTextField.text)
            let amount = try validationService.validStockAmountInput(amountTextField.text)
            let reason = reasonTextView.text ?? ""
            switch fee {
            case .Percent(let percent):
                print("fee percent \(percent)")
            case .userDefined:
                guard let str = feeTextField.text, let userDefinedFee = Int(str) else { return }
                print("userDefinedFee \(userDefinedFee)")
            case .OneDollar:
                print("1")
            default:break
            }
            
//            viewModel.saveNewRecord(
//                stockNo: stockNo,
//                price: price,
//                amount: amount,
//                reason: reason
//            )
//            showToast(message: "成功新增一筆投資紀錄")
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                self.navigationController?.popViewController(animated: true)
//            }
        } catch {
            switch error {
            case ValidationError.invalidAmount:
                amountTextField.textColor = .red
            case ValidationError.invalidPrice:
                priceTextField.textColor = .red
            
            default:
                return
            }
            showToast(message: error.localizedDescription)
        }

    }
    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.context = context
        
        stockNoLabel.text = stockNo
        priceTextField.keyboardType = .decimalPad
        amountTextField.keyboardType = .numberPad
       

        priceTextField.inputAccessoryView = toolBar()
        amountTextField.inputAccessoryView = toolBar()
        navigationItem.title = "新增一筆"
        reasonTextView.layer.borderColor = UIColor.lightGray.cgColor
        reasonTextView.layer.borderWidth = 2
        reasonTextView.layer.cornerRadius = 5
        
        priceTextField.delegate = self
        amountTextField.delegate = self
        
        feePicker.dataSource = self
        feePicker.delegate = self
        feePicker.selectRow(9, inComponent: 1, animated: true)
        
        feeTextField.delegate = self
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

extension AddHistoryViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        textField.textColor = .label
        
        if textField.tag == 1 {
            let strippedString = "$$"
            print("range \(range),  string \(string)")
//               // replace current content with stripped content
//               if let replaceStart = textField.position(from: textField.beginningOfDocument, offset: range.location),
//                   let replaceEnd = textField.position(from: replaceStart, offset: range.length),
//                   let textRange = textField.textRange(from: replaceStart, to: replaceEnd) {
//
//                   textField.replace(textRange, withText: "\(textField.text) strippedString")
//               }
        }
        return true
    }
}


extension AddHistoryViewController: UIPickerViewDelegate, UIPickerViewDataSource {
   
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return 3
        }
        if pickerView.selectedRow(inComponent: 0) == 1 {
            return 1
        }
        if pickerView.selectedRow(inComponent: 0) == 2 {
            return 1
        }
        return feePercent.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if component == 0 {
            return feeCategory[row]
        }
        if pickerView.selectedRow(inComponent: 0) == 1 {
            return "1元"
        }
        if pickerView.selectedRow(inComponent: 0) == 2 {
            return "自訂"
        }
        
        return feePercent[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        //print("pickerview did select component \(component) row \(row)")
        pickerView.reloadComponent(1)

        switch pickerView.selectedRow(inComponent: 0) {
        case 0:
            // 折數
            feeTextField.text = feePercent[row]
            guard let priceStr = priceTextField.text,
                  let amountStr = amountTextField.text,
                  let priceFloat = Float(priceStr),
                  let amountFloat = Float(amountStr)
            else {return}
            let multiplier = Float(row+1)*0.1
            let calculatedFee = calFee(price: priceFloat, amount: amountFloat, multiplier: multiplier)
            feeTextField.text = "\(calculatedFee) 元"
            feeTextField.isEnabled = false
            fee = Fee.Percent(multiplier)
        case 1:
            // 1元
            feeTextField.text = "1元"
            feeTextField.isEnabled = false
            fee = Fee.OneDollar
        case 2:
            feeTextField.isEnabled = true
            feeTextField.placeholder = "輸入手續費"
            feeTextField.text = ""
            fee = Fee.userDefined
        default: break
        }
    }
    
    func calFee(price: Float, amount: Float, multiplier: Float) -> Float{
        let total = price*amount*multiplier*0.001425
        return total<20 ? 20 : total
    }
}

enum Fee {
    case Percent(Float)
    case userDefined
    case OneDollar
    
}

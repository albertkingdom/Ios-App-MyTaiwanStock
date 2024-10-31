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
    
    var viewModel: AddHistoryViewModel!

    var feeType: FeeType!
    var fee: Fee = Fee()
    var userDefinedFee: Double = 0 // 從userdefault取使用者預設值
    var userDefinedDiscount: Int = 0 // 從userdefault取使用者預設折數

    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var stockNoLabel: UILabel!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var memoLabel: UILabel!
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
            let reason = memoLabel.text ?? ""
            switch feeType {
            case .Percent(let percent):
                print("fee percent \(percent)")
            case .userDefined:
                let feeInt = try validationService.validUserDefinedFee(feeTextField.text)
                print("userDefinedFee \(feeInt)")
            case .OneDollar:
                print("1")
            default:break
            }
            

            viewModel.saveNewInvestRecord(stockNo: stockNo, price: price, amount: amount, reason: reason)
            showToast(message: "成功新增一筆投資紀錄")
            saveButton.isEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.navigationController?.popViewController(animated: true)
            }
        } catch {
            switch error {
            case ValidationError.invalidAmount:
                amountTextField.textColor = .red
            case ValidationError.invalidPrice:
                priceTextField.textColor = .red
            case ValidationError.invalidUserDefinedFee:
                print("ValidationError.invalidUserDefinedFee")
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

        viewModel = AddHistoryViewModel()
        
        stockNoLabel.text = stockNo
        priceTextField.keyboardType = .decimalPad
        amountTextField.keyboardType = .numberPad
        priceTextField.backgroundColor = UIColor(hex: "#eeeeee")
        amountTextField.backgroundColor = UIColor(hex: "#eeeeee")
        priceTextField.borderStyle = .roundedRect
        amountTextField.borderStyle = .roundedRect
        priceTextField.inputAccessoryView = toolBar()
        amountTextField.inputAccessoryView = toolBar()
        navigationItem.title = "新增一筆"

        memoLabel.text = viewModel.memo
        memoLabel.numberOfLines = 1
        memoLabel.lineBreakMode = .byTruncatingTail
        priceTextField.delegate = self
        amountTextField.delegate = self
        
        feePicker.dataSource = self
        feePicker.delegate = self
        
        feeTextField.delegate = self
        
        userDefinedFee = UserDefaults.standard.double(forKey: UserDefaults.userDefinedFeeInDollarsKey)
        userDefinedDiscount = UserDefaults.standard.integer(forKey: UserDefaults.userDefinedFeeDiscountKey)
        feePicker.selectRow(userDefinedDiscount, inComponent: 1, animated: true)
        feeTextField.text = fee.feePercentValues[userDefinedDiscount]
        
        viewModel.updateFeeAmount = { digit in
            self.feeTextField.text = "\(digit) 元"
        }
        
    }
    override func viewWillAppear(_ animated: Bool) {
        memoLabel.text = viewModel.memo
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "writeReasonSegue" {
            logger.debug("writeReasonSegue")
        }
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 6 {
            let nextVC = self.storyboard?.instantiateViewController(withIdentifier: "writeReasonVC") as! MemoViewController
            nextVC.viewModel = viewModel
            self.navigationController?.pushViewController(nextVC, animated: true)
        }
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
        
        if let amountText = amountTextField.text,
           let priceText = priceTextField.text,
           let amountFloat = Float(amountText),
           let priceFloat = Float(priceText)
        {
            if !amountText.isEmpty && !priceText.isEmpty{
                viewModel.calculateFeeAndTax(price: priceFloat, amount: amountFloat, buyOrSell: 0)
            }
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
        return fee.feePercentValues.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if component == 0 {
            return fee.feeCategory[row]
        }
        if pickerView.selectedRow(inComponent: 0) == 1 {
            return "1元"
        }
        if pickerView.selectedRow(inComponent: 0) == 2 {
            return "自訂"
        }
        
        return fee.feePercentValues[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        //print("pickerview did select component \(component) row \(row)")
        pickerView.reloadComponent(1)

        switch pickerView.selectedRow(inComponent: 0) {
        case 0:
            // 折數
            feeTextField.text = fee.feePercentValues[row]
            
            guard let priceStr = priceTextField.text,
                  let amountStr = amountTextField.text,
                  let priceFloat = Float(priceStr),
                  let amountFloat = Float(amountStr)
            else {return}
            let multiplier = Float(row+1)*0.1
            viewModel.updateFeeMultiplier(multiplier: multiplier)
            viewModel.calculateFeeAndTax(price: priceFloat, amount: amountFloat, buyOrSell: 0)
//            let calculatedFee = fee.calFee(price: priceFloat, amount: amountFloat, multiplier: multiplier)
//            feeTextField.text = "\(calculatedFee) 元"
            feeTextField.isEnabled = false
            feeType = FeeType.Percent(multiplier)
        case 1:
            // 1元
            feeTextField.text = "1元"
            feeTextField.isEnabled = false
            feeType = FeeType.OneDollar
        case 2:
            feeTextField.isEnabled = false
            feeTextField.placeholder = "輸入手續費"
            feeTextField.text = "\(userDefinedFee)"
            feeType = FeeType.userDefined
        default: break
        }
    }
}

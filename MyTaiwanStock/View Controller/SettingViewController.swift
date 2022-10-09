//
//  SettingViewController.swift
//  MyTaiwanStock
//
//  Created by YKLin on 8/31/22.
//

import UIKit

class SettingViewController: UITableViewController {

    
    @IBOutlet weak var userDefinedFeeLabel: UILabel! // 自訂fee數字
    @IBOutlet weak var feeDiscountTextfield: UITextField!

    var pickerView = UIPickerView()
    var fee: Fee = Fee()

    override func viewDidLoad() {
        super.viewDidLoad()
        initView()
        
    }
    override func viewDidAppear(_ animated: Bool) {
        let feeInDollars = UserDefaults.standard.double(forKey: UserDefaults.userDefinedFeeInDollarsKey)
        let feeDiscountIndex = UserDefaults.standard.integer(forKey: UserDefaults.userDefinedFeeDiscountKey)
        print("viewDidAppear feeInDollars \(feeInDollars)")
        userDefinedFeeLabel.text = "\(feeInDollars) 元"
        feeDiscountTextfield.text = fee.feePercentValues[feeDiscountIndex]
    }
    func initView() {
        navigationItem.title = "設定"
        
        tableView.backgroundColor = .secondarySystemBackground
        tableView.separatorStyle = .none
        
        feeDiscountTextfield.inputView = pickerView
        feeDiscountTextfield.borderStyle = .none
        feeDiscountTextfield.delegate = self
        feeDiscountTextfield.tintColor = .clear
        
        pickerView.delegate = self
        pickerView.dataSource = self
        
        
    }

    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return ""
        case 1: return "手續費"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && indexPath.row == 0 {
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "editFeeVC") as! EditFeeViewController
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
        if indexPath.section == 0 && indexPath.row == 0 {
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "accountVC") as! AccountViewController
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
   


}

extension SettingViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        print("textFieldDidEndEditing \(textField.text)")
    }

}

extension SettingViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return fee.feePercentValues.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return fee.feePercentValues[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        feeDiscountTextfield.text = fee.feePercentValues[row]
        
        UserDefaults.standard.set(row, forKey: UserDefaults.userDefinedFeeDiscountKey)
        feeDiscountTextfield.resignFirstResponder()
    }
}

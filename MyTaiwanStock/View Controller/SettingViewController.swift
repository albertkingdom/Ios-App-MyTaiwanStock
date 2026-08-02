//
//  SettingViewController.swift
//  MyTaiwanStock
//
//  Created by YKLin on 8/31/22.
//

import UIKit
import FirebaseAuth

class SettingViewController: UITableViewController {

    
    @IBOutlet weak var userDefinedFeeLabel: UILabel! // 自訂fee數字
    @IBOutlet weak var feeDiscountTextfield: UITextField!
    @IBOutlet weak var syncSwitch: UISwitch!
    var pickerView = UIPickerView()
    var fee: Fee = Fee()

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        tableView.contentInsetAdjustmentBehavior = .automatic
        syncSwitch.isOn = UserPreferences.shared.syncPreference == .iCloud
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .never
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        initView()
    }
    @IBAction func syncSwitchChanged(_ sender: UISwitch) {
        UserPreferences.shared.syncPreference = sender.isOn ? .iCloud : .local
    }
    func setup() {
        navigationItem.title = "設定"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "立即備份",
            style: .plain,
            target: self,
            action: #selector(manualBackupTapped)
        )

        tableView.backgroundColor = .secondarySystemBackground
        tableView.separatorStyle = .none
        tableView.estimatedSectionFooterHeight = 80
        tableView.sectionFooterHeight = UITableView.automaticDimension

        feeDiscountTextfield.inputView = pickerView
        feeDiscountTextfield.borderStyle = .none
        feeDiscountTextfield.delegate = self
        feeDiscountTextfield.tintColor = .clear
        feeDiscountTextfield.inputAccessoryView = toolBar()
        pickerView.delegate = self
        pickerView.dataSource = self
    }

    @objc private func manualBackupTapped() {
        navigationItem.rightBarButtonItem?.isEnabled = false
        Task { [weak self] in
            do {
                try await DefaultICloudBackupService.shared.manualBackupNow()
                guard let self else { return }
                await MainActor.run {
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.presentBackupResultAlert(message: "已完成備份到 iCloud。")
                }
            } catch {
                guard let self else { return }
                await MainActor.run {
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.presentBackupResultAlert(message: "備份失敗：\(error.localizedDescription)")
                }
            }
        }
    }

    private func presentBackupResultAlert(message: String) {
        let alert = UIAlertController(title: "iCloud 備份", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func initView() {
        let feeInDollars = UserDefaults.standard.double(forKey: UserDefaults.userDefinedFeeInDollarsKey)
        let feeDiscountIndex = UserDefaults.standard.integer(forKey: UserDefaults.userDefinedFeeDiscountKey)
        print("viewDidAppear feeInDollars \(feeInDollars)")
        userDefinedFeeLabel.text = "\(feeInDollars) 元"
        feeDiscountTextfield.text = fee.feePercentValues[feeDiscountIndex]
    }

    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "帳號"
        case 1: return "手續費"
        default: return nil
        }
    }

    private func section0FooterText() -> String {
        var text = "iCloud 備份：開啟後，App 會定期將你的持股清單與交易紀錄備份到 iCloud，供你日後在新裝置上復原。此備份非即時同步，多裝置間可能會有些微延遲。\n\n帳號登入：登入後，你的資料會即時同步到雲端，並可在 Android 版本上使用相同帳號查看。"

        let iCloudBackupEnabled = UserPreferences.shared.syncPreference == .iCloud
        let hasFirebaseLogin = Auth.auth().currentUser != nil
        if !iCloudBackupEnabled && !hasFirebaseLogin {
            text += "\n\n你目前未啟用任何備份或跨裝置同步，若刪除 App 或更換裝置，資料將無法復原。"
        }
        return text
    }

    // A plain `titleForFooterInSection` string can render as a single truncated line
    // in this static table view; a custom footer view with an explicit multi-line
    // label guarantees the explanatory text wraps in full.
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard section == 0 else { return nil }

        let container = UIView()
        let label = UILabel()
        label.text = section0FooterText()
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.layoutMarginsGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        return container
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == 0 ? UITableView.automaticDimension : 0
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
//        feeDiscountTextfield.resignFirstResponder()
    }
}

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
    /// Where the fee settings are read from and saved to; tests pass a store of their own.
    var userDefaults: UserDefaults = .standard
    /// Chooses how the fee is charged: with a discount, or as a fixed amount. It sits in the header of the
    /// fee section, so the storyboard does not need another row.
    let feeModeControl = UISegmentedControl(items: ["折數", "固定金額"])
    /// Injectable so tests can simulate "device not signed into iCloud" without touching
    /// the real `FileManager.default.ubiquityIdentityToken`.
    var iCloudAvailabilityChecking: ICloudAvailabilityChecking = DefaultICloudAvailabilityChecker()

    /// How far the table was pushed up so the discount row stays above the keyboard; 0 when it was not needed.
    private var keyboardInsetAdded: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
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
        matchNavigationBarToPageBackground(.secondarySystemBackground)
        pinSwitchToContentViewTrailing()
        tableView.separatorStyle = .none
        tableView.estimatedSectionFooterHeight = 80
        tableView.sectionFooterHeight = UITableView.automaticDimension

        feeDiscountTextfield.keyboardType = .decimalPad
        feeDiscountTextfield.borderStyle = .none
        feeDiscountTextfield.delegate = self
        feeDiscountTextfield.inputAccessoryView = toolBar()
        feeModeControl.addTarget(self, action: #selector(feeModeChanged), for: .valueChanged)
    }

    /// The table normally scrolls the edited row above the keyboard by itself. On a wide window, where the
    /// content is short and fits on the screen, it does not, and the keyboard covers the discount row. So once
    /// the keyboard is up, whatever still hides the row is added as bottom inset and scrolled away.
    @objc private func keyboardDidShow(_ notification: Notification) {
        guard feeDiscountTextfield.isFirstResponder, let cell = discountCell, let window = view.window,
              let keyboard = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }
        let keyboardTop = window.convert(keyboard, from: window.screen.coordinateSpace).minY
        let rowBottom = cell.convert(cell.bounds, to: window).maxY + 8
        let hidden = rowBottom - keyboardTop
        guard hidden > 0 else { return }
        keyboardInsetAdded += hidden
        tableView.contentInset.bottom += hidden
        tableView.verticalScrollIndicatorInsets.bottom += hidden
        tableView.setContentOffset(CGPoint(x: 0, y: tableView.contentOffset.y + hidden), animated: true)
    }

    @objc private func keyboardWillHide() {
        guard keyboardInsetAdded > 0 else { return }
        tableView.contentInset.bottom -= keyboardInsetAdded
        tableView.verticalScrollIndicatorInsets.bottom -= keyboardInsetAdded
        keyboardInsetAdded = 0
    }

    @objc private func feeModeChanged() {
        view.endEditing(true)
        FeeSettings.saveMode(fixedAmount: feeModeControl.selectedSegmentIndex == 1, userDefaults: userDefaults)
        updateFeeRows()
    }

    /// The storyboard pins the switch to the content view's trailing layout margin. Under a vertical bar the
    /// table's right margin is the whole safe area, so once the content view is inset by it no margin is
    /// left and the switch sits on the content view's edge and is clipped. A fixed offset keeps its 20pt.
    private func pinSwitchToContentViewTrailing() {
        guard let contentView = syncSwitch.superview else { return }
        contentView.constraints
            .filter { $0.firstAttribute == .trailingMargin && $0.secondItem === syncSwitch }
            .forEach { $0.isActive = false }
        syncSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20).isActive = true
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
            } catch ICloudBackupServiceError.iCloudUnavailable {
                guard let self else { return }
                await MainActor.run {
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.presentBackupResultAlert(message: "尚未登入 iCloud，無法備份。請至「設定」App 登入 iCloud 帳號後再試一次。")
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
        userDefinedFeeLabel.text = "\(FeeSettings.currentFixedAmount(userDefaults: userDefaults)) 元"
        feeDiscountTextfield.text = Self.discountText(FeeSettings.currentDiscount(userDefaults: userDefaults))
        feeModeControl.selectedSegmentIndex = FeeSettings.usesFixedAmount(userDefaults: userDefaults) ? 1 : 0
        updateFeeRows()
    }

    /// Only the row of the mode in use is shown. A static table cannot drop a row, so the other one is
    /// hidden and given a height of 0.
    private func updateFeeRows() {
        let usesFixedAmount = feeModeControl.selectedSegmentIndex == 1
        fixedAmountCell?.isHidden = !usesFixedAmount
        discountCell?.isHidden = usesFixedAmount
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let usesFixedAmount = feeModeControl.selectedSegmentIndex == 1
        let hidden = usesFixedAmount ? discountCell : fixedAmountCell
        // For a static table, super returns the cell the storyboard defines for this row.
        if let hidden, super.tableView(tableView, cellForRowAt: indexPath) === hidden { return 0 }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    private var fixedAmountCell: UITableViewCell? { userDefinedFeeLabel.enclosingCell }
    private var discountCell: UITableViewCell? { feeDiscountTextfield.enclosingCell }

    /// "6 折", or "無折扣" for 10.
    static func discountText(_ discount: Decimal) -> String {
        discount == FeeSettings.noDiscount ? "無折扣" : "\(discount) 折"
    }

    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "帳號"
        case 1: return nil   // a header view with the fee mode control, see viewForHeaderInSection
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1 else { return nil }

        let container = UIView()
        let title = UILabel()
        title.text = "手續費"
        title.font = .preferredFont(forTextStyle: .footnote)
        title.textColor = .secondaryLabel
        title.adjustsFontForContentSizeCategory = true
        let stack = UIStackView(arrangedSubviews: [title, feeModeControl])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        // Same edges as the footer: at least 8pt from the leading edge, the layout margins otherwise.
        let leading = stack.leadingAnchor.constraint(equalTo: container.layoutMarginsGuide.leadingAnchor)
        leading.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
            leading,
            stack.trailingAnchor.constraint(equalTo: container.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])
        return container
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 1 ? UITableView.automaticDimension : super.tableView(tableView, heightForHeaderInSection: section)
    }

    func section0FooterText() -> String {
        var text = "iCloud 備份：開啟後，App 會定期將你的持股清單與交易紀錄備份到 iCloud，供你日後在新裝置上復原。此備份非即時同步，多裝置間可能會有些微延遲。\n\n帳號登入：登入後，你的資料會即時同步到雲端，並可在 Android 版本上使用相同帳號查看。"

        let iCloudBackupEnabled = UserPreferences.shared.syncPreference == .iCloud
        let hasFirebaseLogin = Auth.auth().currentUser != nil
        let iCloudActuallyAvailable = iCloudAvailabilityChecking.isICloudAvailable()

        if !iCloudBackupEnabled && !hasFirebaseLogin {
            text += "\n\n你目前未啟用任何備份或跨裝置同步，若刪除 App 或更換裝置，資料將無法復原。"
        } else if iCloudBackupEnabled && !iCloudActuallyAvailable && !hasFirebaseLogin {
            text += "\n\n你目前未啟用任何備份或跨裝置同步，若刪除 App 或更換裝置，資料將無法復原。iCloud 備份要求裝置需先登入 iCloud，請至「設定」App 登入後再試一次。"
        }
        return text
    }

    // A plain `titleForFooterInSection` string can render as a single truncated line
    // in this static table view; a custom footer view with an explicit multi-line
    // label guarantees the explanatory text wraps in full. The layout margins are zero on the leading side
    // under a vertical bar, so the text keeps at least 8pt there. The trailing side stays on the layout
    // margins: they include the safe area while the table measures the footer, the safe area guide does not.
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
        let leading = label.leadingAnchor.constraint(equalTo: container.layoutMarginsGuide.leadingAnchor)
        leading.priority = .defaultHigh
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 8),
            leading,
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
        if let cell = tableView.cellForRow(at: indexPath), cell === fixedAmountCell {
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "editFeeVC") as! EditFeeViewController
            vc.userDefaults = userDefaults
            self.navigationController?.pushViewController(vc, animated: true)
        }
        if let cell = tableView.cellForRow(at: indexPath), cell === discountCell {
            feeDiscountTextfield.becomeFirstResponder()
        }
        if indexPath.section == 0 && indexPath.row == 0 {
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "accountVC") as! AccountViewController
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
   


}

extension SettingViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Edit the number itself, without the unit.
        textField.text = "\(FeeSettings.currentDiscount(userDefaults: userDefaults))"
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        do {
            let discount = try FeeSettings.parseDiscount(textField.text)
            FeeSettings.saveDiscount(discount, userDefaults: userDefaults)
        } catch {
            let alert = UIAlertController(title: "折數無法儲存", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default))
            present(alert, animated: true)
        }
        textField.text = Self.discountText(FeeSettings.currentDiscount(userDefaults: userDefaults))
    }
}

private extension UIView {
    /// The table view cell this view is in.
    var enclosingCell: UITableViewCell? {
        var view: UIView? = self
        while let current = view {
            if let cell = current as? UITableViewCell { return cell }
            view = current.superview
        }
        return nil
    }
}

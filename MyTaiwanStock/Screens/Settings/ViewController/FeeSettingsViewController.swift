//
//  FeeSettingsViewController.swift
//  MyTaiwanStock
//

import UIKit

/// The page behind the fee row of the settings screen: the discount and both minimum fees, saved together.
class FeeSettingsViewController: UITableViewController {
    let discountField = UITextField()
    let wholeLotMinimumField = UITextField()
    let oddLotMinimumField = UITextField()
    let userDefaults: UserDefaults
    /// Shows a validation error. The default presents an alert; tests replace it to collect the messages.
    var showError: (String) -> Void = { _ in }
    private var rowCells: [UITableViewCell] = []

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        super.init(style: .insetGrouped)
        showError = { [weak self] message in self?.presentError(message) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "手續費"
        matchNavigationBarToPageBackground(.systemGroupedBackground)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "儲存", style: .done, target: self, action: #selector(saveTapped))

        let settings = FeeSettings.current(userDefaults: userDefaults)
        discountField.text = "\(settings.discount)"
        wholeLotMinimumField.text = "\(settings.wholeLotMinimumFee)"
        oddLotMinimumField.text = "\(settings.oddLotMinimumFee)"

        configure(discountField, keyboardType: .decimalPad)
        configure(wholeLotMinimumField, keyboardType: .numberPad)
        configure(oddLotMinimumField, keyboardType: .numberPad)

        rowCells = [
            makeRow(title: "折數", field: discountField, unit: "折"),
            makeRow(title: "整股最低手續費", field: wholeLotMinimumField, unit: "元"),
            makeRow(title: "零股最低手續費", field: oddLotMinimumField, unit: "元"),
        ]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rowCells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        rowCells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        [discountField, wholeLotMinimumField, oddLotMinimumField][indexPath.row].becomeFirstResponder()
    }

    /// A fixed space above the rows. A grouped table gives a section without a header view no space at all in
    /// a short window such as the Duo's, and the rows would touch the navigation bar.
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        UIView()
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        24
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "折數 10 代表無折扣。最低手續費是算出來的手續費不足時改收的金額，整股指 1000 股以上，0 代表沒有最低收費。"
    }

    /// Validates the three fields together. When any of them is invalid, nothing is saved and the page stays open.
    func save() {
        do {
            let settings = try FeeSettings.parse(
                discountText: discountField.text,
                wholeLotMinimumText: wholeLotMinimumField.text,
                oddLotMinimumText: oddLotMinimumField.text)
            FeeSettings.save(settings, userDefaults: userDefaults)
            navigationController?.popViewController(animated: true)
        } catch {
            showError(error.localizedDescription)
        }
    }

    @objc private func saveTapped() {
        save()
    }

    private func configure(_ field: UITextField, keyboardType: UIKeyboardType) {
        field.keyboardType = keyboardType
        field.textAlignment = .right
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.borderStyle = .none
        field.inputAccessoryView = toolBar()
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func makeRow(title: String, field: UITextField, unit: String) -> UITableViewCell {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let unitLabel = UILabel()
        unitLabel.text = unit
        unitLabel.font = .preferredFont(forTextStyle: .body)
        unitLabel.adjustsFontForContentSizeCategory = true
        unitLabel.textColor = .secondaryLabel
        unitLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [titleLabel, field, unitLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.bottomAnchor),
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 96),
        ])
        return cell
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "手續費無法儲存", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }
}

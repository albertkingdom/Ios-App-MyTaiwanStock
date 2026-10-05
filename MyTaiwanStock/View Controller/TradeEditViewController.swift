//
//  TradeEditViewController.swift
//  MyTaiwanStock
//

import UIKit

/// Edits one trade of the import preview: stock number, price, shares, date and direction.
final class TradeEditViewController: UITableViewController {
    private enum Row: Int, CaseIterable {
        case stockNo, price, amount, date, side

        var title: String {
            switch self {
            case .stockNo: return "股號"
            case .price: return "價格"
            case .amount: return "股數"
            case .date: return "日期"
            case .side: return "買賣"
            }
        }
    }

    private let item: TradePreviewItem
    private let onSave: (_ stockNo: String, _ price: Float?, _ amount: Int?, _ date: Date, _ side: TradeSide) -> Void

    private let stockNoField = UITextField()
    private let priceField = UITextField()
    private let amountField = UITextField()
    private let datePicker = UIDatePicker()
    private let sideControl = UISegmentedControl(items: ["買進", "賣出"])

    init(
        item: TradePreviewItem,
        onSave: @escaping (_ stockNo: String, _ price: Float?, _ amount: Int?, _ date: Date, _ side: TradeSide) -> Void
    ) {
        self.item = item
        self.onSave = onSave
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = item.stockName.isEmpty ? "編輯成交紀錄" : item.stockName
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "儲存", style: .done, target: self, action: #selector(save))

        configure(stockNoField, placeholder: "例如 2330", keyboard: .numbersAndPunctuation, text: item.stockNo)
        configure(priceField, placeholder: "價格", keyboard: .decimalPad, text: item.price.map { String($0) })
        configure(amountField, placeholder: "1 到 32767", keyboard: .numberPad, text: item.amount.map(String.init))

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.timeZone = TaipeiCalendar.timeZone
        datePicker.date = item.date ?? Date()

        sideControl.selectedSegmentIndex = item.side == .sell ? 1 : 0
        sideControl.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func configure(_ field: UITextField, placeholder: String, keyboard: UIKeyboardType, text: String?) {
        field.placeholder = placeholder
        field.keyboardType = keyboard
        field.text = text
        field.textAlignment = .right
        field.clearButtonMode = .whileEditing
    }

    private func control(for row: Row) -> UIView {
        switch row {
        case .stockNo: return stockNoField
        case .price: return priceField
        case .amount: return amountField
        case .date: return datePicker
        case .side: return sideControl
        }
    }

    // MARK: table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = Row(rawValue: indexPath.row)!
        let cell = UITableViewCell()
        cell.selectionStyle = .none

        var content = cell.defaultContentConfiguration()
        content.text = row.title
        cell.contentConfiguration = content

        let control = control(for: row)
        // A table cell's accessory view is laid out by frame, so give it its natural size.
        let width: CGFloat = control is UITextField ? 180 : control.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        control.frame = CGRect(x: 0, y: 0, width: width, height: 36)
        cell.accessoryView = control
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "儲存後，這筆成交紀錄會依新的內容重新檢查是否重複或不完整。"
    }

    // MARK: actions

    @objc private func save() {
        view.endEditing(true)
        let digits = amountField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        onSave(
            stockNoField.text?.trimmingCharacters(in: .whitespaces) ?? "",
            Float(priceField.text ?? ""),
            Int(digits),
            datePicker.date,
            sideControl.selectedSegmentIndex == 1 ? .sell : .buy)
        navigationController?.popViewController(animated: true)
    }
}

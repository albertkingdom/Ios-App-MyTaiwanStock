//
//  TradeEditViewController.swift
//  MyTaiwanStock
//

import UIKit

/// Edits one trade of the import preview: stock number, price, shares, date and direction.
final class TradeEditViewController: UIViewController {
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
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = item.stockName.isEmpty ? "編輯成交紀錄" : item.stockName
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "儲存", style: .done, target: self, action: #selector(save))

        configure(stockNoField, placeholder: "股號，例如 2330", keyboard: .numbersAndPunctuation, text: item.stockNo)
        configure(priceField, placeholder: "價格", keyboard: .decimalPad, text: item.price.map { String($0) })
        configure(amountField, placeholder: "股數（1 到 32767）", keyboard: .numberPad, text: item.amount.map(String.init))

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.timeZone = TaipeiCalendar.timeZone
        datePicker.date = item.date ?? Date()

        sideControl.selectedSegmentIndex = item.side == .sell ? 1 : 0

        let rows: [(String, UIView)] = [
            ("股號", stockNoField), ("價格", priceField), ("股數", amountField),
            ("日期", datePicker), ("買賣", sideControl),
        ]
        let stack = UIStackView(arrangedSubviews: rows.map(makeRow))
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func configure(_ field: UITextField, placeholder: String, keyboard: UIKeyboardType, text: String?) {
        field.placeholder = placeholder
        field.keyboardType = keyboard
        field.text = text
        field.borderStyle = .roundedRect
        field.clearButtonMode = .whileEditing
    }

    private func makeRow(title: String, control: UIView) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .body)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.widthAnchor.constraint(equalToConstant: 56).isActive = true
        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        return row
    }

    @objc private func save() {
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

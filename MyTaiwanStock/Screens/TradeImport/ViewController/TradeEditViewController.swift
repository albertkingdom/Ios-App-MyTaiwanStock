//
//  TradeEditViewController.swift
//  MyTaiwanStock
//

import UIKit

/// Edits one trade of the import preview: stock number, price, shares, date, direction, fee and, for a
/// sell, tax. The fee and the tax show the estimate until the user types a value.
final class TradeEditViewController: UITableViewController {
    private enum Row: Int, CaseIterable {
        case stockNo, price, amount, date, side, fee, tax

        var title: String {
            switch self {
            case .stockNo: return "股號"
            case .price: return "價格"
            case .amount: return "股數"
            case .date: return "日期"
            case .side: return "買賣"
            case .fee: return "手續費（元）"
            case .tax: return "證交稅（元）"
            }
        }
    }

    /// `feeText` and `taxText` are nil while the user left the field to the estimate.
    typealias SaveHandler = (
        _ stockNo: String, _ price: Float?, _ amount: Int?, _ date: Date, _ side: TradeSide,
        _ feeText: String?, _ taxText: String?
    ) -> Void
    typealias Estimator = (_ stockNo: String?, _ price: Float?, _ amount: Int?, _ side: TradeSide) -> FeeAndTax?

    private let item: TradePreviewItem
    private let estimate: Estimator
    private let onSave: SaveHandler

    private let stockNoField = UITextField()
    private let priceField = UITextField()
    private let amountField = UITextField()
    private let datePicker = UIDatePicker()
    private let sideControl = UISegmentedControl(items: ["買進", "賣出"])
    private let feeField = UITextField()
    private let taxField = UITextField()
    /// What the fee and the tax fields hold, and which of them the user typed.
    private var fields: FeeTaxFields

    init(item: TradePreviewItem, estimate: @escaping Estimator, onSave: @escaping SaveHandler) {
        self.item = item
        self.estimate = estimate
        self.onSave = onSave
        self.fields = item.fields
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
        sideControl.addTarget(self, action: #selector(sideChanged), for: .valueChanged)

        configure(feeField, placeholder: "估算值", keyboard: .numberPad, text: item.feeText)
        configure(taxField, placeholder: "估算值", keyboard: .numberPad, text: item.taxText)
        // An earlier invalid value is shown as such again.
        updateColor(of: feeField)
        updateColor(of: taxField)
        for field in [stockNoField, priceField, amountField] {
            field.addTarget(self, action: #selector(inputChanged), for: .editingChanged)
        }
        for field in [feeField, taxField] {
            field.addTarget(self, action: #selector(amountTyped(_:)), for: .editingChanged)
            field.addTarget(self, action: #selector(amountEndedEditing(_:)), for: .editingDidEnd)
        }
    }

    private var side: TradeSide { sideControl.selectedSegmentIndex == 1 ? .sell : .buy }

    /// A buy pays no tax, so its editor has no tax row.
    private var rows: [Row] { side == .sell ? Row.allCases : Row.allCases.filter { $0 != .tax } }

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
        case .fee: return feeField
        case .tax: return taxField
        }
    }

    // MARK: table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
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
        "手續費與稅是依設定估算的，可以直接修改；清空會恢復估算值。儲存後，這筆成交紀錄會依新的內容重新檢查是否重複或不完整。"
    }

    // MARK: estimates

    private var draftStockNo: String? {
        let text = stockNoField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        return text.isEmpty ? nil : text
    }

    /// Shows the estimate for the fee and the tax the user has not typed.
    private func refreshEstimates() {
        fields.refresh(with: estimate(draftStockNo, Float(priceField.text ?? ""), Int(amountField.text ?? ""), side), side: side)
        // A field the user is typing in already shows its text; writing it again would move the cursor.
        if feeField.text != fields.feeText { feeField.text = fields.feeText }
        if taxField.text != fields.taxText { taxField.text = fields.taxText }
    }

    @objc private func inputChanged() { refreshEstimates() }

    @objc private func sideChanged() {
        view.endEditing(true)
        refreshEstimates()
        tableView.reloadData()
    }

    @objc private func amountTyped(_ field: UITextField) {
        if field === feeField { fields.editFee(field.text ?? "") } else { fields.editTax(field.text ?? "") }
        updateColor(of: field)
    }

    /// A value the trade cannot be saved with is shown in red.
    private func updateColor(of field: UITextField) {
        let valid = (try? ValidInputService().validFeeOrTaxInput(field.text)) != nil
        field.textColor = valid || (field.text ?? "").isEmpty ? .label : .systemRed
    }

    /// A field left empty shows the estimate again and goes back to following the other values.
    @objc private func amountEndedEditing(_ field: UITextField) {
        if field === feeField { fields.endEditingFee() } else { fields.endEditingTax() }
        refreshEstimates()
        updateColor(of: field)
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
            side,
            fields.feeIsManual ? fields.feeText : nil,
            side == .sell && fields.taxIsManual ? fields.taxText : nil)
        navigationController?.popViewController(animated: true)
    }
}

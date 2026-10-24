//
//  AddHistoryViewController.swift
//  MyTaiwanStock
//
import CoreData
import UIKit

class AddHistoryViewController: UITableViewController {
    var context: NSManagedObjectContext?
    let validationService = ValidInputService()
    var stockNo: String!
    var viewModel = AddHistoryViewModel()

    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var stockNoLabel: UILabel!
    @IBOutlet weak var priceTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var memoLabel: UILabel!
    @IBOutlet weak var memoCell: UITableViewCell!
    @IBOutlet weak var feeTextField: UITextField!
    @IBOutlet weak var taxTextField: UITextField!
    @IBOutlet weak var taxCategoryButton: UIButton!
    @IBOutlet weak var taxCategoryCell: UITableViewCell!
    @IBOutlet weak var taxCell: UITableViewCell!

    @IBAction func setSegmentControl(_ sender: UISegmentedControl) {
        view.endEditing(true)
        viewModel.didSelect(side: sender.selectedSegmentIndex == 1 ? .sell : .buy)
    }

    @IBAction func datePickerChanged(_ sender: UIDatePicker) {
        viewModel.date = sender.date
    }

    @IBAction func saveNewRecord(_ sender: Any) {
        dismissKeyboard()
        do {
            try viewModel.save(stockNo: stockNo, priceText: priceTextField.text, amountText: amountTextField.text)
            showToast(message: "成功新增一筆投資紀錄")
            saveButton.isEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        } catch {
            switch error {
            case ValidationError.invalidAmount:
                amountTextField.textColor = .red
            case ValidationError.invalidPrice:
                priceTextField.textColor = .red
            case ValidationError.invalidFeeOrTax:
                if (try? validationService.validFeeOrTaxInput(feeTextField.text)) == nil {
                    feeTextField.textColor = .red
                }
                if viewModel.side == .sell,
                   (try? validationService.validFeeOrTaxInput(taxTextField.text)) == nil {
                    taxTextField.textColor = .red
                }
            default: return
            }
            showToast(message: error.localizedDescription)
        }
    }

    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        stockNoLabel.text = stockNo
        navigationItem.title = "新增一筆"
        for field in [priceTextField!, amountTextField!, feeTextField!, taxTextField!] {
            field.delegate = self
            field.keyboardType = field === priceTextField ? .decimalPad : .numberPad
            field.inputAccessoryView = toolBar()
        }
        for field in [priceTextField!, amountTextField!] {
            field.backgroundColor = UIColor(hex: "#eeeeee")
            field.borderStyle = .roundedRect
            field.addTarget(self, action: #selector(tradeInputChanged), for: .editingChanged)
        }
        for field in [feeTextField!, taxTextField!] {
            let unit = UILabel()
            unit.text = " 元"
            unit.sizeToFit()
            field.rightView = unit
            field.rightViewMode = .always
            field.addTarget(self, action: #selector(costInputChanged(_:)), for: .editingChanged)
            field.addTarget(self, action: #selector(costInputEnded(_:)), for: .editingDidEnd)
        }
        memoLabel.numberOfLines = 1
        memoLabel.lineBreakMode = .byTruncatingTail
        taxCategoryButton.showsMenuAsPrimaryAction = true
        taxCategoryButton.changesSelectionAsPrimaryAction = true
        viewModel.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        memoLabel.text = viewModel.memo
    }

    @objc private func tradeInputChanged() {
        viewModel.didChange(priceText: priceTextField.text, amountText: amountTextField.text)
    }

    @objc private func costInputChanged(_ field: UITextField) {
        if field === feeTextField { viewModel.didEditFee(field.text) }
        else { viewModel.didEditTax(field.text) }
    }

    @objc private func costInputEnded(_ field: UITextField) {
        if field === feeTextField { viewModel.didEndEditingFee() }
        else { viewModel.didEndEditingTax() }
    }

    private func refresh() {
        if feeTextField.text != viewModel.feeText { feeTextField.text = viewModel.feeText }
        if taxTextField.text != viewModel.taxText { taxTextField.text = viewModel.taxText }
        let hideTax = viewModel.side == .buy
        let visibilityChanged = taxCell.isHidden != hideTax
        taxCategoryCell.isHidden = hideTax
        taxCell.isHidden = hideTax
        taxCategoryButton.menu = UIMenu(options: .singleSelection, children: TaxCategory.allCases.map { category in
            UIAction(title: category.title, state: category == viewModel.taxCategory ? .on : .off) { [weak self] _ in
                self?.viewModel.didSelect(taxCategory: category)
            }
        })
        if visibilityChanged {
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if viewModel.side == .buy, cell === taxCell || cell === taxCategoryCell { return 0 }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "writeReasonSegue" {
            (segue.destination as? MemoViewController)?.viewModel = viewModel
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard tableView.cellForRow(at: indexPath) === memoCell,
              let editor = storyboard?.instantiateViewController(withIdentifier: "writeReasonVC") as? MemoViewController
        else { return }
        editor.viewModel = viewModel
        navigationController?.pushViewController(editor, animated: true)
    }
}

extension AddHistoryViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        textField.textColor = .label
        if textField === feeTextField || textField === taxTextField {
            return string.allSatisfy { $0.isASCII && $0.isNumber }
        }
        return true
    }
}

private extension TaxCategory {
    var title: String {
        switch self {
        case .stock: return "一般股票"
        case .dayTrade: return "現股當沖"
        case .etf: return "ETF"
        case .exempt: return "免稅"
        }
    }
}

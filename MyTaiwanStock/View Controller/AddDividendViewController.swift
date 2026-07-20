//
//  AddDividendViewController.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/22/22.
//

import UIKit

class AddDividendViewController: UITableViewController {
    var stockNo: String!
    var viewModel = AddDividendViewModel()
    var selectedDate = Date()
    
    private lazy var cashDividend: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = UIColor(hex: "#eeeeee")
        textField.borderStyle = .roundedRect
        textField.keyboardType = .numberPad
        textField.inputAccessoryView = toolBar()
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        return textField
    }()
    
    private lazy var stockDividend: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = UIColor(hex: "#eeeeee")
        textField.borderStyle = .roundedRect
        textField.keyboardType = .numberPad
        textField.inputAccessoryView = toolBar()
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    @objc func dateValueChanged(_ sender: UIDatePicker) {
        selectedDate = sender.date
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        cashDividend.backgroundColor = UIColor(hex: "#eeeeee")
        cashDividend.borderStyle = .roundedRect
        stockDividend.backgroundColor = UIColor(hex: "#eeeeee")
        stockDividend.borderStyle = .roundedRect
        tableView.separatorStyle = .none
        navigationItem.title = "新增股利"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel".localized, style: .plain, target: self, action: #selector(pressCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save".localized, style: .plain, target: self, action: #selector(pressSave))
    }
    func changeTextFieldBorderColor(_ textField: UITextField, to color: UIColor) {
        textField.layer.borderColor = color.cgColor
        textField.layer.borderWidth = textField.layer.borderWidth > 0 ? textField.layer.borderWidth : 1.0
        textField.layer.cornerRadius = 5.0
        
        textField.borderStyle = .none
        // Adjust padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: textField.frame.height))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = paddingView
        textField.rightViewMode = .always
    }
    func restoreTextFieldAppearence(_ textField: UITextField) {
        textField.borderStyle = .roundedRect
        textField.layer.borderColor = UIColor.clear.cgColor // or use textField.backgroundColor?.cgColor
        textField.layer.borderWidth = 0
        textField.layer.cornerRadius = 0 //
        // Remove padding
        textField.leftView = nil
        textField.rightView = nil
        
    }
    @objc func pressCancel() {
        navigationController?.popViewController(animated: true)
    }
    @objc func pressSave() {
        dismissKeyboard()
        let cashAmount = viewModel.validateCashDividend(cashDividend.text)
        let stockAmount = viewModel.validateStockDividend(stockDividend.text)
        guard let cashAmount = cashAmount else {
            changeTextFieldBorderColor(cashDividend, to: .red)
            return
        }
        restoreTextFieldAppearence(cashDividend)
        guard let stockAmount = stockAmount else {
            changeTextFieldBorderColor(stockDividend, to: .red)
            return
        }
        restoreTextFieldAppearence(stockDividend)
        if viewModel.saveDividends(stockNo: stockNo, cashAmount: cashAmount, stockAmount: stockAmount, date: selectedDate) {
            navigationItem.rightBarButtonItem?.isEnabled = false
            
            showToast(message: "成功新增一筆紀錄")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.navigationController?.popViewController(animated: true)
            }
        } else {
            showToast(message: "請填入有效數字")
        }
    }
}

extension AddDividendViewController {
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        
        // Create stack view
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create label
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Create right view (textfield or datepicker)
        let rightView: UIView
        
        switch indexPath.row {
        case 0:
            label.text = "股票代號"
            let textField = UITextField()
            textField.text = stockNo
            textField.isEnabled = false
            textField.backgroundColor = UIColor(hex: "#eeeeee")
            textField.borderStyle = .roundedRect
            rightView = textField
        case 1:
            label.text = "現金股利"
            rightView = cashDividend
        case 2:
            label.text = "股票股利"
            rightView = stockDividend
        case 3:
            label.text = "選擇日期"
            let datePicker = UIDatePicker()
            datePicker.datePickerMode = .date
            datePicker.addTarget(self, action: #selector(dateValueChanged(_:)), for: .valueChanged)
            rightView = datePicker
        default:
            rightView = UIView()
        }
        
        // Add views to stack view
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(rightView)
        
        // Add stack view to cell
        cell.contentView.addSubview(stackView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8)
        ])
        
        cell.selectionStyle = .none
        return cell
        
    }
}

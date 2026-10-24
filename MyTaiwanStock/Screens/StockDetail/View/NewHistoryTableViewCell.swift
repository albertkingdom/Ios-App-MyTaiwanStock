//
//  NewHistoryTableViewCell.swift
//  MyTaiwanStock
//
//  Created by YKLin on 11/25/22.
//

import UIKit

class NewHistoryTableViewCell: UITableViewCell {
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var revenueLabel: UILabel!
    @IBOutlet weak var feeTaxLabel: UILabel!
    
    static let identifier = "newHistoryCell"
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // The row grows with the text size, so the numbers wrap instead of being cut off.
        for label in [statusLabel, dateLabel, priceLabel, amountLabel, revenueLabel] {
            label?.font = .preferredFont(forTextStyle: .subheadline)
            label?.adjustsFontForContentSizeCategory = true
            label?.numberOfLines = 0
        }
        feeTaxLabel.font = .preferredFont(forTextStyle: .caption1)
        feeTaxLabel.adjustsFontForContentSizeCategory = true
        feeTaxLabel.textColor = .secondaryLabel
        feeTaxLabel.numberOfLines = 0
        updateColumnLayout(for: traitCollection.preferredContentSizeCategory)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: NewHistoryTableViewCell, _) in
            cell.updateColumnLayout(for: cell.traitCollection.preferredContentSizeCategory)
        }
    }

    /// Five columns do not fit side by side at the accessibility text sizes, where a number would break
    /// in the middle. There each value gets its own line, in the same order as the columns of the header.
    func updateColumnLayout(for category: UIContentSizeCategory) {
        let stacked = category.isAccessibilityCategory
        stackView.axis = stacked ? .vertical : .horizontal
        stackView.distribution = stacked ? .fill : .fillEqually
        stackView.alignment = stacked ? .leading : .center
        stackView.spacing = stacked ? 4 : 0
        let alignment: NSTextAlignment = stacked ? .left : .center
        for label in [statusLabel, dateLabel, priceLabel, amountLabel, revenueLabel, feeTaxLabel] {
            label?.textAlignment = alignment
        }
    }


    func configure(with viewModel: HistoryCellModel) {
        
        statusLabel.text = viewModel.status == 0 ? "買" : "賣" //??
        dateLabel.text = viewModel.dateString
        priceLabel.text = viewModel.priceString
        amountLabel.text = viewModel.amountString
        revenueLabel.text = viewModel.revenueString
        feeTaxLabel.text = viewModel.feeTaxString
        
        // The color comes from the number, not from the text that is shown.
        if let revenue = viewModel.revenueValue, revenue > 0 {
            revenueLabel.textColor = .red
        } else if let revenue = viewModel.revenueValue, revenue < 0 {
            revenueLabel.textColor = .green
        } else {
            revenueLabel.textColor = .label
        }
    }
}

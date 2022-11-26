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
    
    static let identifier = "newHistoryCell"
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }


    func configure(with viewModel: HistoryCellViewModel) {
        
        statusLabel.text = viewModel.status == 0 ? "買" : "賣" //??
        dateLabel.text = viewModel.dateString
        priceLabel.text = viewModel.priceString
        amountLabel.text = viewModel.amountString
        revenueLabel.text = viewModel.revenueString
        
        if viewModel.revenueFloat > 0 && viewModel.status == 0 {
            revenueLabel.textColor = .red
        }else if viewModel.revenueFloat < 0 && viewModel.status == 0 {
            revenueLabel.textColor = .green
        }else {
            revenueLabel.textColor = .label
        }
    }
}

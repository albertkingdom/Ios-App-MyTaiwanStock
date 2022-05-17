//
//  HistoryTableViewCell.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/6.
//

import UIKit

class HistoryTableViewCell: UITableViewCell {
    var stockPrice: String!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var revenueLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        stackView.layer.borderWidth = 1
        stackView.layer.cornerRadius = 5
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = contentView.frame.inset(by: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
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
            revenueLabel.textColor = .black
        }
    }

}

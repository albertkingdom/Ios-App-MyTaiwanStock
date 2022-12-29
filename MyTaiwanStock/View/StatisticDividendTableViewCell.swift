//
//  StatisticDividendTableViewCell.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/23/22.
//

import UIKit

class StatisticDividendTableViewCell: UITableViewCell {
    static let identifier = "dividendCell"
    @IBOutlet weak var stockNoLabel: UILabel!
    @IBOutlet weak var cashDividendAmountLabel: UILabel!
    @IBOutlet weak var shareDividendAmountLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func update(with dividend: Dividend) {
        stockNoLabel.text = dividend.stockNo
        cashDividendAmountLabel.text = "\(dividend.cash)"
        shareDividendAmountLabel.text = "\(dividend.share)"
    }
    
}

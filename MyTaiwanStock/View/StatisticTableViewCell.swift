//
//  StatisticTableViewCell.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/1/6.
//

import UIKit

class StatisticTableViewCell: UITableViewCell {
    @IBOutlet weak var stockNoLabel: UILabel!
    @IBOutlet weak var assetLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    func update(with statisticDetail:StockStatistic) {
        stockNoLabel.text = statisticDetail.stockNo
        assetLabel.text = String(format:"%.0f", statisticDetail.totalAssets)
    }
}

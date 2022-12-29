//
//  StatisticStockTableViewCell.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/23/22.
//

import UIKit

class StatisticStockTableViewCell: UITableViewCell {
    @IBOutlet weak var stockNoLabel: UILabel!
    @IBOutlet weak var assetLabel: UILabel!
    @IBOutlet weak var stockAmountLabel: UILabel!
    static let identifier = "statisticStockCell"
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func update(with statisticDetail:StockStatistic) {
        stockNoLabel.text = statisticDetail.stockNo

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .currencyISOCode
        assetLabel.text = formatter.string(from: NSNumber(value: statisticDetail.totalAssets))
        stockAmountLabel.text = "\(statisticDetail.stockAmount)"
    }
}

//
//  StatisticTableViewCell.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/1/6.
//

import UIKit

class StatisticTableViewCell: UITableViewCell {
    @IBOutlet weak var container: UIStackView!
    @IBOutlet weak var stockNoLabel: UILabel!
    @IBOutlet weak var assetLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        backgroundColor = .clear
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 5
        container.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    func update(with statisticDetail:StockStatistic) {
        stockNoLabel.text = statisticDetail.stockNo
//        assetLabel.text = String(format:"%.0f", statisticDetail.totalAssets)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .currencyISOCode
        assetLabel.text = formatter.string(from: NSNumber(value: statisticDetail.totalAssets))
    }
}

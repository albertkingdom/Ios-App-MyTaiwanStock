//
//  HistoryTableViewCell.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/6.
//

import UIKit

class HistoryTableViewCell: UITableViewCell {
    var stockPrice: String!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var revenueLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func update(with historyData: InvestHistory, stockPrice: String) {
        
        self.stockPrice = stockPrice
        dateLabel.text = dateFormat(date: historyData.date!)
        priceLabel.text = String(historyData.price)
        amountLabel.text = String(historyData.amount)
        let revenue = calcRevenue(price: historyData.price)
        revenueLabel.text = "\(revenue) %"
        
        if let revenueFloat = Float(revenue) {
            revenueLabel.textColor = revenueFloat > 0 ? .red : .green
        }
    }
    func dateFormat(date: Date) -> String {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyyMMdd"
        let datestr = dateFormatter.string(from: date)
        
        return datestr
    }
    
    func calcRevenue(price: Float) -> String {
        var revenueStr: String! = "-"
        if stockPrice != "-" {
            if let StockPriceFloat = Float(stockPrice) {
                let result = (StockPriceFloat - price) / price * 100
                revenueStr = String(format:"%.2f", result)
            }
        }
        return revenueStr
    }
}

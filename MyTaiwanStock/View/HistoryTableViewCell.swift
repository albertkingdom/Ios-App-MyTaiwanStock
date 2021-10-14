//
//  HistoryTableViewCell.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/6.
//

import UIKit

class HistoryTableViewCell: UITableViewCell {
    var stockPrice: String!
    @IBOutlet weak var statusLabel: UILabel!
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
        let revenue = calcRevenue(price: historyData.price)
        
        statusLabel.text = historyData.status == 0 ? "買" : "賣"
        dateLabel.text = dateFormat(date: historyData.date!)
        priceLabel.text = String(historyData.price)
        amountLabel.text = String(historyData.amount)
        revenueLabel.text = historyData.status == 0 ? "\(revenue) %" : "N/A"
        
        if let revenueFloat = Float(revenue), historyData.status == 0 {
          
            if revenueFloat > 0 {
                revenueLabel.textColor = .red
            }else if revenueFloat < 0 {
                revenueLabel.textColor = .green
            }else {
                revenueLabel.textColor = .black
            }
        }
    }
    func dateFormat(date: Date) -> String {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy\nMM-dd"
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

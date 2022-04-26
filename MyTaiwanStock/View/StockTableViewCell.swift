//
//  StockTableViewCell.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//

import UIKit

class StockTableViewCell: UITableViewCell {

    @IBOutlet weak var stockNo: UILabel!
    @IBOutlet weak var stockName: UILabel!
    @IBOutlet weak var stockPrice: UILabel!
    @IBOutlet weak var stockPriceDiff: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    func update(with stockPriceDetail:OneDayStockInfoDetail) {
        stockNo.text = stockPriceDetail.stockNo
        stockName.text = stockPriceDetail.shortName
        if let currentPrice = Float(stockPriceDetail.current) {
            stockPrice.text = String(format: "%.2f", currentPrice)
        } else {
            stockPrice.text = "-"
        }
        
        
        if let currentPrice = Float(stockPriceDetail.current), let openPrice = Float(stockPriceDetail.open) {
            let diff = currentPrice - openPrice
            stockPriceDiff.text = String(format: "%.2f", diff)
            stockPriceDiff.backgroundColor = diff > 0 ? UIColor.systemRed : UIColor.systemGreen
        } else {
            stockPriceDiff.text = "-"
        }
    }

}

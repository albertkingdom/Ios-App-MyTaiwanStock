//
//  StockTableViewCell.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//

import UIKit

class StockTableViewCell: UITableViewCell {

    @IBOutlet weak var container: UIStackView!
    @IBOutlet weak var stockNo: UILabel!
    @IBOutlet weak var stockName: UILabel!
    @IBOutlet weak var stockPrice: UILabel!
    @IBOutlet weak var stockPriceDiff: UILabel!
    
   
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        backgroundColor = .clear
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 5
        stockPriceDiff.layer.cornerRadius = 5
        stockPriceDiff.layer.masksToBounds = true
        stockNo.font = UIFont.systemFont(ofSize: 20, weight: .bold)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    

    
    func update(with stockViewModel: StockCellViewModel) {
        stockNo.text = stockViewModel.stockNo
        stockName.text = stockViewModel.stockShortName
        stockPrice.text = stockViewModel.stockPrice
        stockPriceDiff.text = stockViewModel.stockPriceDiff
        stockPriceDiff.textColor = UIColor.label
        stockPriceDiff.backgroundColor = nil
        if let diff = Float(stockViewModel.stockPriceDiff) {
            stockPriceDiff.textColor = UIColor.label
            if diff > 0 {
                stockPriceDiff.backgroundColor = UIColor.systemRed
                stockPriceDiff.textColor = UIColor.white
            }
            
            if diff < 0 {
                stockPriceDiff.backgroundColor = UIColor.systemGreen
                stockPriceDiff.textColor = UIColor.white
            }
        }
 
    }

}

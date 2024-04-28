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
    
    var viewController: StockListViewController?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        backgroundColor = .clear
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 5
        stockPriceDiff.layer.cornerRadius = 5
        stockPriceDiff.layer.masksToBounds = true
        stockNo.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        
        stockPriceDiff.isUserInteractionEnabled = true
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(labelTapped))
        stockPriceDiff.addGestureRecognizer(tapGestureRecognizer)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    

    @objc func labelTapped() {
        print("Label tapped!")
            // Notifying the delegate (view controller) about the tap
            NotificationCenter.default.post(name: NSNotification.Name("labelTapped"), object: nil)
        }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let labelHitView = stockPriceDiff.hitTest(convert(point, to: stockPriceDiff), with: event)
        if labelHitView != nil {
            // If the tap is on the label, return the label view
            return labelHitView
        } else {
            // If the tap is not on the label, return the cell view
            return super.hitTest(point, with: event)
        }
    }
    func update(with stockViewModel: StockCellViewModel, isPercentFormat: Bool) {
        print("update \(isPercentFormat)")
        stockNo.text = stockViewModel.stockNo
        stockName.text = stockViewModel.stockShortName
        stockPrice.text = stockViewModel.stockPrice
        if isPercentFormat {
            stockPriceDiff.text = stockViewModel.stockPriceDiffPercent
        } else {
            stockPriceDiff.text = stockViewModel.stockPriceDiff
        }

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

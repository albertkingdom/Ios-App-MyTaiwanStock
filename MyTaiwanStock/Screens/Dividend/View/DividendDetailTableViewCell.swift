//
//  DividendDetailTableViewCell.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/24/22.
//

import UIKit

class DividendDetailTableViewCell: UITableViewCell {
    static let identifier = "dividendDetailCell"
    
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var cashAmount: UILabel!
    @IBOutlet weak var shareAmount: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
     
    }
    
    func update(with detail: Dividend) {
        date.text = dateFormat(date: detail.date!)
        cashAmount.text = "\(detail.cash)"
        shareAmount.text = "\(detail.share)"
    }
    func dateFormat(date: Date) -> String {
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd"
        let datestr = dateFormatter.string(from: date)
        
        return datestr
    }
}

//
//  AddStockTableViewCell.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/3/15.
//

import UIKit

class AddStockTableViewCell: UITableViewCell {
    @IBOutlet weak var stockName:UILabel!
    @IBOutlet weak var confirmButton: UIButton!
    
    @IBAction func touchConfirmButton() {
        
        let stockNumberString = String(stockName.text!.split(separator: " ")[0])
        addNewStockToDB(stockNumberString)

        isInFollowingList = true
        
        
    }
    var stockListNo: Int16!
    var isInFollowingList: Bool = false {
        didSet {
            
            if (isInFollowingList) {
                
                confirmButton.setImage(UIImage(systemName: "star.fill"), for: .normal)
            } else {
                
                confirmButton.setImage(UIImage(systemName: "star"), for: .normal)
            }
        }
    }
    var addNewStockToDB: ((String) -> ())!


    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    
    func configure(with stockViewModel: AddStockCellViewModel) {
        stockName.text = stockViewModel.stockNumberAndName
        isInFollowingList = stockViewModel.isFollowing
    }
}

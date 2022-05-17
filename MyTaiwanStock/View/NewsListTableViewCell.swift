//
//  NewsListTableViewCell.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 10/11/21.
//

import UIKit
import Kingfisher
class NewsListTableViewCell: UITableViewCell {

    @IBOutlet weak var imagePreview: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var detail: UILabel!
    @IBOutlet weak var date: UILabel!
    
    
    func configure(with data: NewsListCellViewModel) {
        title.text = data.title
        detail.text = data.detail
        date.text = data.dateString
        if let url = data.imageURL {
            imagePreview.kf.setImage(with: url)
        }
    }
}




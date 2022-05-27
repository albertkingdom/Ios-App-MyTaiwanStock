//
//  NewsListTableViewCell.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 10/11/21.
//

import UIKit
import Kingfisher
class NewsListTableViewCell: UITableViewCell {
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var imagePreview: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var detail: UILabel!
    @IBOutlet weak var date: UILabel!
    
    override func awakeFromNib() {
        contentView.backgroundColor = UIColor(red: 211/256, green: 211/256, blue: 211/256, alpha: 1)
        stackView.layer.cornerRadius = 5
        stackView.layer.masksToBounds = true
    }
    func configure(with data: NewsListCellViewModel) {
        imagePreview.contentMode = .scaleAspectFill
        title.text = data.title
        detail.text = data.detail
        date.text = data.dateString
        if let url = data.imageURL {
            imagePreview.kf.setImage(with: url)
        }
    }
}




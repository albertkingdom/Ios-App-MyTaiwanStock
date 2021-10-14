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
    
    func update(with NewsContent: Article) {
        title.text = NewsContent.title
        detail.text = NewsContent.description
        date.text = formatDate(NewsContent.publishedAt)
        imagePreview.kf.setImage(with: URL(string: NewsContent.urlToImage))
    }
}


func formatDate(_ dateStr: String) -> String {
    let dateformatter = DateFormatter()
    dateformatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    let date = dateformatter.date(from: dateStr)

    dateformatter.dateFormat = "yyyy-MM-dd"
    return dateformatter.string(from: date!)
}

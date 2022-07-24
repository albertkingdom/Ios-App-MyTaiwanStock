import UIKit
import Kingfisher

class NewsListTableViewCell2: UITableViewCell {
    @IBOutlet weak var imagePreview: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var date: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()

        title.backgroundColor = .clear
        title.textColor = .white
        title.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        
        date.backgroundColor = .clear
        date.textColor = .white
        date.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        
        imagePreview.layer.cornerRadius = 10
        imagePreview.contentMode = .scaleToFill
        
        
    }
    
    func configure(with data: NewsListCellViewModel) {
        
        title.text = data.title
        date.text = data.dateString

        if let url = data.imageURL {
            imagePreview.kf.setImage(with: url)
        }
        addGradient()
    }
    
    func addGradient() {
        let gradient = CAGradientLayer()
        let height = bounds.height // get the correct size in real device
        let width = bounds.width
        gradient.frame = CGRect(x: 0, y: height/2, width: width, height: height/2)
        let startColor = UIColor.white
        let endColor = UIColor.black.cgColor
        gradient.colors = [startColor, endColor]
        imagePreview.layer.addSublayer(gradient)
    }
}

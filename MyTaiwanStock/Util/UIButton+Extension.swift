//
//  UIButton+Extension.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/18/22.
//
import UIKit
import Foundation

extension UIButton {
    
    func rightIcon(with rightImage: UIImage) {
        let imageView = UIImageView(image: rightImage)
        imageView.tintColor = .label
        imageView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(imageView)

        titleEdgeInsets.right += 10
        titleLabel?.textColor = .black
        NSLayoutConstraint.activate([
            imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10),
            imageView.centerYAnchor.constraint(equalTo: self.titleLabel!.centerYAnchor, constant: 0),
            imageView.widthAnchor.constraint(equalTo: titleLabel!.heightAnchor, multiplier: 0.9),
            imageView.heightAnchor.constraint(equalTo: titleLabel!.heightAnchor, multiplier: 0.9)
        ])
    }
}

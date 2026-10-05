//
//  File.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/11/30.
//
import UIKit

class FloatingButton: UIButton {
    init() {
        super.init(frame: .zero)
        configure()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure() {
        setImage(
            UIImage(
                systemName: "plus",
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: 20, weight: .medium)),
            for: .normal)
        backgroundColor = .black
        tintColor = .white
        layer.cornerRadius = 25
        layer.shadowColor = UIColor.label.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 5, height: 5)
        layer.shadowRadius = 10
        setTitle(nil, for: .normal)
    
        translatesAutoresizingMaskIntoConstraints = false

    }
}

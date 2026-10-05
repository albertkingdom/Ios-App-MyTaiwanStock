//
//  FloatingButton.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/11/30.
//
import UIKit

/// The round plus button on the home screen. Tapping it opens a standard iOS pull-down menu
/// (assigned by the screen), so there is no custom expand animation to maintain.
class FloatingButton: UIButton {
    static let diameter: CGFloat = 56

    init() {
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(
            systemName: "plus",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .tintColor
        configuration.baseForegroundColor = .white
        self.configuration = configuration

        showsMenuAsPrimaryAction = true
        accessibilityLabel = "新增"

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8

        translatesAutoresizingMaskIntoConstraints = false
    }
}

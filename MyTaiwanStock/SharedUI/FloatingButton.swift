//
//  FloatingButton.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/11/30.
//
import UIKit

/// The round plus button on the home screen. `FloatingButtonManager` rotates it into a close
/// button while the action menu is open.
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
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold))
        configuration.cornerStyle = .capsule
        // Adapts to dark mode: a dark button with a light plus in light mode, and the reverse.
        configuration.baseBackgroundColor = .label
        configuration.baseForegroundColor = .systemBackground
        self.configuration = configuration

        accessibilityLabel = "新增"

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 10

        translatesAutoresizingMaskIntoConstraints = false
    }
}

//
//  FloatingButtonManager.swift
//  MyTaiwanStock
//
//  Created by yklin on 2025/1/25.
//

import Foundation
import UIKit

protocol FloatingButtonManagerDelegate: AnyObject {
    func didTapSecondaryButton1()
    func didTapSecondaryButton2()
    
}

class FloatingButtonManager {
    private weak var parentView: UIView?
    private var floatingButton: UIButton
    private weak var delegate: FloatingButtonManagerDelegate?
    private var secondaryButton1 = UIButton(type: .custom)
    private var secondaryButton2 = UIButton(type: .custom)
    private var blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    init(parentView: UIView, floatingButton: UIButton, delegate: FloatingButtonManagerDelegate) {
        self.parentView = parentView
        self.floatingButton = floatingButton
        self.delegate = delegate
        setupSecondaryButtons()
        setupBlurEffectView()
    }
    
    // Setup secondary buttons
    private func setupSecondaryButtons() {
        [secondaryButton1, secondaryButton2].forEach {
            var config = UIButton.Configuration.filled()
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20) // Custom padding
            $0.configuration = config
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.backgroundColor = .systemBlue
            $0.layer.cornerRadius = 10
            $0.setTitleColor(.white, for: .normal)
            $0.alpha = 0
            parentView?.addSubview($0)
            
        }
        
        configureButton(secondaryButton1, title: "新增清單", offsetY: -90, action: #selector(secondaryButton1Tapped))
        configureButton(secondaryButton2, title: "新增股票", offsetY: -150, action: #selector(secondaryButton2Tapped))
    }
    
    private func configureButton(_ button: UIButton, title: String, offsetY: CGFloat, action: Selector) {
        
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 40),
            button.trailingAnchor.constraint(equalTo: floatingButton.trailingAnchor, constant: 0),
            button.bottomAnchor.constraint(equalTo: floatingButton.bottomAnchor, constant: offsetY),
        ])
    }
    
    private func setupBlurEffectView() {
        guard let parentView = parentView else { return }
        
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        blurEffectView.alpha = 0
        parentView.insertSubview(blurEffectView, belowSubview: floatingButton)
        
        NSLayoutConstraint.activate([
            blurEffectView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            blurEffectView.topAnchor.constraint(equalTo: parentView.topAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
        ])
    }
    
    func toggleSecondaryButtons(hasMoreThanOneList: Bool, parentFloatingButton: UIButton) {
        let buttonsAreHidden = (secondaryButton1.alpha == 0)
        
        UIViewPropertyAnimator(duration: 0.3, dampingRatio: 0.7) {
            self.secondaryButton1.alpha = buttonsAreHidden ? 1 : 0
            self.secondaryButton2.alpha = buttonsAreHidden && hasMoreThanOneList ? 1 : 0
            self.blurEffectView.alpha = buttonsAreHidden ? 0.5 : 0
        }.startAnimation()
    }
    
    func resetFloatingButtonState() {
          secondaryButton1.alpha = 0
          secondaryButton2.alpha = 0
          blurEffectView.alpha = 0
    }
    @objc private func secondaryButton1Tapped() {
        delegate?.didTapSecondaryButton1()
    }
    
    @objc private func secondaryButton2Tapped() {
        delegate?.didTapSecondaryButton2()
    }
}

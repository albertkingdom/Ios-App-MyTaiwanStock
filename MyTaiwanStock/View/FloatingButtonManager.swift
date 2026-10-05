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
    func didTapSecondaryButton3()
}

/// One row of the action menu: a colored icon badge and a title inside a frosted capsule.
private final class ActionPill: UIControl {
    init(title: String, symbol: String, color: UIColor) {
        super.init(frame: .zero)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        blur.isUserInteractionEnabled = false
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        let badge = UIImageView(image: UIImage(
            systemName: symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)))
        badge.tintColor = .white
        badge.contentMode = .center
        badge.backgroundColor = color
        badge.layer.cornerRadius = 18
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label

        let row = UIStackView(arrangedSubviews: [badge, label])
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            badge.widthAnchor.constraint(equalToConstant: 36),
            badge.heightAnchor.constraint(equalToConstant: 36),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 8
        accessibilityLabel = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.first?.layer.cornerRadius = bounds.height / 2
    }

    override var isHighlighted: Bool {
        didSet { UIView.animate(withDuration: 0.12) { self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity } }
    }
}

/// Opens and closes the action menu above the plus button: a dimmed blur over the screen and
/// a column of action pills that spring up from the button one after another.
class FloatingButtonManager {
    private weak var parentView: UIView?
    private var floatingButton: UIButton
    private weak var delegate: FloatingButtonManagerDelegate?

    private let importPill = ActionPill(title: "截圖匯入", symbol: "photo.on.rectangle.angled", color: .systemPurple)
    private let addStockPill = ActionPill(title: "新增股票", symbol: "plus", color: .systemBlue)
    private let addListPill = ActionPill(title: "新增清單", symbol: "list.bullet", color: .systemOrange)
    private let pillStack = UIStackView()
    private let dimView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private(set) var isExpanded = false

    /// Pills from the one nearest the button upwards.
    private var pillsFromButton: [ActionPill] { [addListPill, addStockPill, importPill] }

    init(parentView: UIView, floatingButton: UIButton, delegate: FloatingButtonManagerDelegate) {
        self.parentView = parentView
        self.floatingButton = floatingButton
        self.delegate = delegate
        setUpDimView()
        setUpPills()
        resetFloatingButtonState()
    }

    // MARK: setup

    private func setUpDimView() {
        guard let parentView else { return }
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.alpha = 0
        dimView.isUserInteractionEnabled = false
        dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissTapped)))
        parentView.insertSubview(dimView, belowSubview: floatingButton)
        NSLayoutConstraint.activate([
            dimView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            dimView.topAnchor.constraint(equalTo: parentView.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
        ])
    }

    private func setUpPills() {
        guard let parentView else { return }
        // Top to bottom, so the pill nearest the button is last.
        pillStack.addArrangedSubview(importPill)
        pillStack.addArrangedSubview(addStockPill)
        pillStack.addArrangedSubview(addListPill)
        pillStack.axis = .vertical
        pillStack.alignment = .trailing
        pillStack.spacing = 12
        pillStack.translatesAutoresizingMaskIntoConstraints = false
        parentView.insertSubview(pillStack, belowSubview: floatingButton)
        NSLayoutConstraint.activate([
            pillStack.trailingAnchor.constraint(equalTo: floatingButton.trailingAnchor),
            pillStack.bottomAnchor.constraint(equalTo: floatingButton.topAnchor, constant: -16),
        ])

        importPill.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        addStockPill.addTarget(self, action: #selector(addStockTapped), for: .touchUpInside)
        addListPill.addTarget(self, action: #selector(addListTapped), for: .touchUpInside)
    }

    // MARK: open and close

    /// Opens the menu when it is closed and closes it when it is open.
    /// `hasMoreThanOneList` is true once at least one list exists; adding a stock needs a list.
    func toggleSecondaryButtons(hasMoreThanOneList: Bool, parentFloatingButton: UIButton) {
        if isExpanded {
            setExpanded(false, animated: true)
        } else {
            addStockPill.isHidden = !hasMoreThanOneList
            setExpanded(true, animated: true)
        }
    }

    /// Closes the menu immediately, without animation.
    func resetFloatingButtonState() {
        setExpanded(false, animated: false)
    }

    private func setExpanded(_ expanded: Bool, animated: Bool) {
        isExpanded = expanded
        dimView.isUserInteractionEnabled = expanded
        let pills = pillsFromButton.filter { !$0.isHidden || !expanded }
        let hiddenOffset = CGAffineTransform(translationX: 0, y: 24).scaledBy(x: 0.85, y: 0.85)

        // Finish any pending layout now. Otherwise the first layout pass happens inside the
        // animation blocks below and the pills' subviews (such as the round icon badges)
        // animate from a zero frame, which shows up as squashed ellipses mid-animation.
        parentView?.layoutIfNeeded()

        let apply = {
            self.dimView.alpha = expanded ? 1 : 0
            self.floatingButton.transform = expanded ? CGAffineTransform(rotationAngle: .pi / 4) : .identity
        }
        if !animated {
            apply()
            pillsFromButton.forEach {
                $0.alpha = expanded ? 1 : 0
                $0.transform = expanded ? .identity : hiddenOffset
                $0.isUserInteractionEnabled = expanded
            }
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut], animations: apply)
        for (index, pill) in pills.enumerated() {
            pill.isUserInteractionEnabled = expanded
            if expanded {
                pill.alpha = 0
                pill.transform = hiddenOffset
            }
            // Open: spring up one after another, nearest first. Close: fade out together.
            UIView.animate(
                withDuration: expanded ? 0.5 : 0.18, delay: expanded ? Double(index) * 0.05 : 0,
                usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5,
                options: [.beginFromCurrentState]
            ) {
                pill.alpha = expanded ? 1 : 0
                pill.transform = expanded ? .identity : hiddenOffset
            }
        }
    }

    // MARK: actions

    @objc private func dismissTapped() {
        setExpanded(false, animated: true)
    }

    @objc private func importTapped() {
        setExpanded(false, animated: true)
        delegate?.didTapSecondaryButton3()
    }

    @objc private func addStockTapped() {
        setExpanded(false, animated: true)
        delegate?.didTapSecondaryButton2()
    }

    @objc private func addListTapped() {
        setExpanded(false, animated: true)
        delegate?.didTapSecondaryButton1()
    }
}

//
//  FloatingButtonManagerTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

private final class SpyDelegate: FloatingButtonManagerDelegate {
    var taps: [Int] = []
    func didTapSecondaryButton1() { taps.append(1) }
    func didTapSecondaryButton2() { taps.append(2) }
    func didTapSecondaryButton3() { taps.append(3) }
}

@MainActor
final class FloatingButtonManagerTests: XCTestCase {

    private var window: UIWindow!
    private var button: FloatingButton!
    private var manager: FloatingButtonManager!
    private let delegate = SpyDelegate()

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        button = FloatingButton()
        controller.view.addSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 56),
            button.heightAnchor.constraint(equalToConstant: 56),
            button.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -20),
            button.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor, constant: -100),
        ])
        manager = FloatingButtonManager(parentView: controller.view, floatingButton: button, delegate: delegate)
        controller.view.layoutIfNeeded()
    }

    /// The round icon badge of every action pill (36 by 36 points, fully rounded).
    private func badges() -> [UIView] {
        var found: [UIView] = []
        func walk(_ view: UIView) {
            if view.layer.cornerRadius == 18 { found.append(view) }
            view.subviews.forEach(walk)
        }
        walk(window)
        return found
    }

    private func run(for seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    func test_icon_badges_stay_round_during_the_whole_open_animation() {
        manager.toggleSecondaryButtons(hasMoreThanOneList: true, parentFloatingButton: button)

        var samples = 0
        for _ in 0..<40 {
            run(for: 0.025)
            for badge in badges() {
                let size = (badge.layer.presentation() ?? badge.layer).bounds.size
                XCTAssertEqual(size.width, size.height, accuracy: 0.5, "badge is \(size) at sample \(samples)")
                samples += 1
            }
        }
        XCTAssertGreaterThan(samples, 0)
        XCTAssertEqual(badges().count, 3)
    }

    func test_pill_transforms_never_stretch_one_axis_only() {
        manager.toggleSecondaryButtons(hasMoreThanOneList: true, parentFloatingButton: button)

        for _ in 0..<40 {
            run(for: 0.025)
            var pills: [UIView] = []
            func walk(_ view: UIView) {
                if view is UIControl, view !== button { pills.append(view) }
                view.subviews.forEach(walk)
            }
            walk(window)
            for pill in pills {
                let transform = (pill.layer.presentation() ?? pill.layer).affineTransform()
                XCTAssertEqual(transform.a, transform.d, accuracy: 0.01, "x scale \(transform.a) vs y scale \(transform.d)")
            }
        }
    }

    func test_tapping_an_action_closes_the_menu_and_calls_the_delegate() {
        manager.toggleSecondaryButtons(hasMoreThanOneList: true, parentFloatingButton: button)
        run(for: 0.8)

        var pills: [UIControl] = []
        func walk(_ view: UIView) {
            if let control = view as? UIControl, control !== button { pills.append(control) }
            view.subviews.forEach(walk)
        }
        walk(window)
        XCTAssertEqual(pills.count, 3)
        pills.first?.sendActions(for: .touchUpInside)

        XCTAssertFalse(manager.isExpanded)
        XCTAssertEqual(delegate.taps.count, 1)
    }

    func test_without_a_list_the_add_stock_action_is_hidden() {
        manager.toggleSecondaryButtons(hasMoreThanOneList: false, parentFloatingButton: button)
        run(for: 0.8)

        XCTAssertEqual(badges().filter { !$0.isHidden && !($0.superview?.superview?.isHidden ?? false) }.count, 2)
    }
}

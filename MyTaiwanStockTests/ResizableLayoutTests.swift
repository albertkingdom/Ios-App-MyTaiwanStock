//
//  ResizableLayoutTests.swift
//  MyTaiwanStockTests
//

import XCTest
@testable import MyTaiwanStock

/// The scene can change size while the app runs (iPhone Duo folding, Split View, Stage Manager) and
/// can put a vertical bar on a leading or trailing edge. Layout has to follow the current bounds and
/// safe area instead of the size the view had when it loaded.
@MainActor
final class ResizableLayoutTests: XCTestCase {

    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func mainStoryboard() -> UIStoryboard {
        UIStoryboard(name: "Main", bundle: Bundle(for: AddListViewController.self))
    }

    /// Loads the view and lays it out at `size`. No window, so the controller never appears and
    /// never starts its network work.
    private func layout(_ controller: UIViewController, size: CGSize) {
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    // MARK: - AddListViewController

    func test_addList_floatingButton_stays_clear_of_a_trailing_vertical_bar() {
        let controller = mainStoryboard().instantiateViewController(withIdentifier: "addListVC") as! AddListViewController
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 60)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        window.layoutIfNeeded()

        let button = controller.floatingButton
        let view = controller.view!
        XCTAssertLessThanOrEqual(button.frame.maxX, view.bounds.width - view.safeAreaInsets.right,
                                 "button \(button.frame) sits under the trailing bar")
        XCTAssertLessThanOrEqual(button.frame.maxY, view.bounds.height - view.safeAreaInsets.bottom,
                                 "button \(button.frame) sits under the bottom inset")
    }

    // MARK: - StockListViewController

    /// Checked through the constraint instead of a measured frame: the list cannot be shown in a test
    /// (appearing needs a view model and presents the first-launch walkthrough), and without being
    /// shown it has no safe area to measure.
    func test_stockList_floatingButton_is_pinned_to_the_safe_area_trailing_edge() throws {
        let controller = mainStoryboard().instantiateViewController(withIdentifier: "stockListVC") as! StockListViewController
        controller.loadViewIfNeeded()

        let view = controller.view!
        let button = try XCTUnwrap(view.subviews.compactMap { $0 as? FloatingButton }.first)
        let trailing = try XCTUnwrap(view.constraints.first { $0.firstItem === button && $0.firstAttribute == .trailing })
        XCTAssertTrue(trailing.secondItem === view.safeAreaLayoutGuide,
                      "the button is pinned to the view's edge, so a trailing vertical bar covers it")
    }

    // MARK: - TradeImportPreviewViewController

    /// Same limit as the stock list test: without a shown window there is no safe area to measure, so the
    /// button's side constraints are checked instead.
    private func makeTradeImportPreview() -> TradeImportPreviewViewController {
        let viewModel = TradeImportViewModel(
            trades: [], resolver: StockNameResolver(entries: []), isKnownCode: { _ in true },
            store: FakeTradeImportStore(), listNames: ["我的清單"], currentListName: "我的清單")
        let controller = TradeImportPreviewViewController(viewModel: viewModel, onImported: {})
        controller.loadViewIfNeeded()
        return controller
    }

    /// The app draws its navigation bars white. On this grey grouped page that leaves a white band, which
    /// also runs under a vertical bar, so at the scroll edge the bar has to take the page's colour.
    func test_tradeImportPreview_navigationBar_matches_the_grey_page_at_the_scroll_edge() throws {
        let controller = makeTradeImportPreview()

        let appearance = try XCTUnwrap(controller.navigationItem.scrollEdgeAppearance)
        XCTAssertEqual(appearance.backgroundColor, UIColor.systemGroupedBackground)
        XCTAssertEqual(controller.view.backgroundColor, UIColor.systemGroupedBackground)
    }

    func test_tradeImportPreview_importButton_is_pinned_to_the_safe_area_sides() throws {
        let controller = makeTradeImportPreview()

        func descendants(of view: UIView) -> [UIView] { view.subviews + view.subviews.flatMap(descendants) }
        let button = try XCTUnwrap(descendants(of: controller.view)
            .compactMap { $0 as? UIButton }
            .first { $0.configuration?.title?.hasPrefix("匯入") == true })
        let bar = try XCTUnwrap(button.superview)

        for attribute in [NSLayoutConstraint.Attribute.leading, .trailing] {
            let constraint = try XCTUnwrap(bar.constraints.first { $0.firstItem === button && $0.firstAttribute == attribute })
            XCTAssertTrue(constraint.secondItem === bar.safeAreaLayoutGuide,
                          "the import button's \(attribute == .leading ? "leading" : "trailing") side is pinned to the bar's edge, so a vertical bar covers it")
        }
    }

    // MARK: - SettingViewController

    private func makeSettings() throws -> SettingViewController {
        let tab = mainStoryboard().instantiateViewController(withIdentifier: "customTabVC") as! UITabBarController
        let nav = try XCTUnwrap(tab.viewControllers?.compactMap { $0 as? UINavigationController }
            .first { $0.viewControllers.first is SettingViewController })
        let settings = try XCTUnwrap(nav.viewControllers.first as? SettingViewController)
        settings.loadViewIfNeeded()
        return settings
    }

    func test_settings_navigationBar_matches_the_grey_page_at_the_scroll_edge() throws {
        let settings = try makeSettings()

        let appearance = try XCTUnwrap(settings.navigationItem.scrollEdgeAppearance)
        XCTAssertEqual(appearance.backgroundColor, settings.tableView.backgroundColor)
    }

    /// Under a vertical bar the table's right layout margin is the whole safe area. The content view is
    /// already inset by it, so no margin is left, and a switch pinned to that margin sits on the content
    /// view's edge and is clipped. Checked through the constraints because the margins only collapse under a
    /// system-provided safe area, which a test window cannot give.
    func test_settings_syncSwitch_is_not_pinned_to_the_collapsing_trailing_margin() throws {
        let settings = try makeSettings()
        let contentView = try XCTUnwrap(settings.syncSwitch.superview)

        let pinnedToMargin = contentView.constraints.contains {
            $0.isActive && $0.firstAttribute == .trailingMargin && $0.secondItem === settings.syncSwitch
        }
        XCTAssertFalse(pinnedToMargin, "the switch is pinned to the content view's trailing layout margin")
        let trailing = try XCTUnwrap(contentView.constraints.first {
            $0.isActive && $0.firstItem === settings.syncSwitch && $0.firstAttribute == .trailing && $0.secondItem === contentView
        })
        XCTAssertEqual(trailing.constant, -20)
    }

    /// The footer's layout margins are zero on the leading side under a vertical bar (the phone's is 8), so
    /// the text needs its own minimum margin. The trailing side keeps the layout margins on purpose: they
    /// include the safe area while the table measures the footer, which the safe area guide does not, and
    /// without it the footer is measured too short and the text is cut off.
    func test_settings_footer_text_keeps_a_leading_margin_when_the_layout_margins_are_zero() throws {
        let settings = try makeSettings()
        let footer = try XCTUnwrap(settings.tableView(settings.tableView, viewForFooterInSection: 0))
        let label = try XCTUnwrap(footer.subviews.compactMap { $0 as? UILabel }.first)

        let minimum = try XCTUnwrap(footer.constraints.first {
            $0.firstItem === label && $0.firstAttribute == .leading && $0.relation == .greaterThanOrEqual && $0.secondItem === footer
        })
        XCTAssertEqual(minimum.constant, 8)
        XCTAssertEqual(minimum.priority, .required)
        let usesSafeAreaGuide = footer.constraints.contains { $0.firstItem === label && $0.secondItem === footer.safeAreaLayoutGuide }
        XCTAssertFalse(usesSafeAreaGuide, "the safe area guide is zero while the table measures the footer, so the footer comes out too short")
    }

    // MARK: - DividendDetailViewController

    func test_dividendDetail_tableView_fills_the_view_after_it_resizes() {
        let controller = DividendDetailViewController(stockNo: "2330")

        layout(controller, size: CGSize(width: 400, height: 800))
        XCTAssertEqual(controller.tableView.frame, controller.view.bounds)

        layout(controller, size: CGSize(width: 700, height: 400))
        XCTAssertEqual(controller.tableView.frame, controller.view.bounds)
    }

    // MARK: - StockViewController

    func test_stockDetail_tableHeader_keeps_every_row_readable_at_any_size() {
        let viewModel = StockDetailViewModel(stockNo: "2330", currentStockPrice: "100", repository: NetworkServiceImpl())
        let controller = mainStoryboard().instantiateViewController(withIdentifier: "stockViewController") as! StockViewController
        controller.configure(with: viewModel)
        controller.stockName = "台積電"
        controller.stockPrice = "100"
        controller.timeString = "10-23"

        let sizes = [
            CGSize(width: 400, height: 800),     // portrait phone
            CGSize(width: 800, height: 400),     // landscape phone
            CGSize(width: 932, height: 430),     // landscape Pro Max
            CGSize(width: 1024, height: 1366),   // tall iPad window
        ]
        for size in sizes {
            layout(controller, size: size)
            let header = controller.containerTableView.tableHeaderView!
            header.layoutIfNeeded()
            let label = "at \(size)"

            // The overview block keeps the height its labels need.
            let overviewNeeds = controller.overviewInfo.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            XCTAssertGreaterThanOrEqual(controller.overviewInfo.frame.height, overviewNeeds - 0.5,
                                        "overview row is squeezed \(label)")
            // The plot info row keeps its fixed height instead of being stretched to fill the header.
            XCTAssertEqual(controller.plotInfo.frame.height, 30, accuracy: 0.5, "plot info row is stretched \(label)")
            // The header is as tall as its content, no more and no less.
            let fitting = header.systemLayoutSizeFitting(
                CGSize(width: header.bounds.width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel).height
            XCTAssertEqual(header.frame.height, fitting, accuracy: 1, "header height does not match its content \(label)")
        }
    }

    // MARK: - StatisticViewController

    private func statisticController() throws -> StatisticViewController {
        let tabBar = mainStoryboard().instantiateViewController(withIdentifier: "customTabVC") as! UITabBarController
        return try XCTUnwrap(
            tabBar.viewControllers?
                .compactMap { ($0 as? UINavigationController)?.viewControllers.first ?? $0 }
                .compactMap { $0 as? StatisticViewController }
                .first)
    }

    func test_statistic_scrollView_holds_two_pages_of_the_current_width() throws {
        let controller = try statisticController()

        layout(controller, size: CGSize(width: 400, height: 800))
        XCTAssertEqual(controller.scrollView.contentSize.width, 800, accuracy: 0.5)

        layout(controller, size: CGSize(width: 700, height: 400))
        XCTAssertEqual(controller.scrollView.contentSize.width, 1400, accuracy: 0.5)
    }

    func test_statistic_second_page_stays_in_view_after_a_swipe_and_a_resize() throws {
        let controller = try statisticController()
        layout(controller, size: CGSize(width: 400, height: 800))
        // UIKit only calls the handlers it can see through the Objective-C runtime.
        let delegate = try XCTUnwrap(controller.scrollView.delegate)
        XCTAssertTrue(delegate.responds(to: #selector(UIScrollViewDelegate.scrollViewDidEndDecelerating(_:))))
        XCTAssertTrue(delegate.responds(to: #selector(UIScrollViewDelegate.scrollViewDidEndDragging(_:willDecelerate:))))

        controller.scrollView.contentOffset.x = 400            // the user swiped to the dividend page
        controller.scrollViewDidEndDecelerating(controller.scrollView)

        layout(controller, size: CGSize(width: 700, height: 400))
        XCTAssertEqual(controller.scrollView.contentOffset.x, 700, accuracy: 0.5, "wider: offset is not on the second page")

        layout(controller, size: CGSize(width: 300, height: 600))
        XCTAssertEqual(controller.scrollView.contentOffset.x, 300, accuracy: 0.5, "narrower: offset is not on the second page")
    }

    func test_statistic_second_page_stays_in_view_after_a_segment_tap_and_a_resize() throws {
        let controller = try statisticController()
        layout(controller, size: CGSize(width: 400, height: 800))
        controller.segment.selectedSegmentIndex = 1
        controller.tapSegment(controller.segment)

        layout(controller, size: CGSize(width: 700, height: 400))
        XCTAssertEqual(controller.scrollView.contentOffset.x, 700, accuracy: 0.5)
    }

    func test_statistic_scrolling_the_dividend_table_does_not_change_the_page() throws {
        let controller = try statisticController()
        layout(controller, size: CGSize(width: 400, height: 800))
        controller.segment.selectedSegmentIndex = 1
        controller.tapSegment(controller.segment)

        // The dividend table uses the controller as its delegate too; its own scrolling ends at x = 0.
        controller.scrollViewDidEndDecelerating(controller.tableView2)

        layout(controller, size: CGSize(width: 700, height: 400))
        XCTAssertEqual(controller.scrollView.contentOffset.x, 700, accuracy: 0.5)
    }

    func test_statistic_first_page_stays_in_view_after_it_resizes() throws {
        let controller = try statisticController()
        layout(controller, size: CGSize(width: 400, height: 800))

        layout(controller, size: CGSize(width: 700, height: 400))
        XCTAssertEqual(controller.scrollView.contentOffset.x, 0, accuracy: 0.5)
    }

    func test_statistic_segment_scrolls_to_the_second_page_of_the_current_width() throws {
        let controller = try statisticController()
        layout(controller, size: CGSize(width: 700, height: 400))

        controller.segment.selectedSegmentIndex = 1
        controller.tapSegment(controller.segment)

        XCTAssertEqual(controller.scrollView.contentOffset.x, controller.scrollView.bounds.width, accuracy: 0.5)
    }
}

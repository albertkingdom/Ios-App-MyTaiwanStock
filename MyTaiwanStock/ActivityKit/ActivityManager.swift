import ActivityKit
import Combine
import OSLog

private let activityLogger = Logger(subsystem: "com.a2006mike.MyTaiwanStock", category: "ActivityManager")

@available(iOS 16.1, *)
class ActivityManager {
    static let shared = ActivityManager()

    let isActive = CurrentValueSubject<Bool, Never>(false)

    var trackedStockNo: String? {
        return currentActivity?.attributes.stockNo
    }

    private var currentActivity: Activity<StockActivityAttributes>?
    private var cancellables = Set<AnyCancellable>()

    func start(stockNo: String,
               stockName: String,
               currentPrice: String,
               priceChange: String,
               priceChangePercent: String,
               yesterDayPrice: String,
               time: String) -> Bool {
        if currentActivity != nil {
            end()
        }

        guard !stockNo.isEmpty, !stockName.isEmpty else {
            activityLogger.warning("Activity start failed: empty stockNo or stockName")
            return false
        }

        let attributes = StockActivityAttributes(
            stockNo: stockNo,
            stockName: stockName
        )

        let contentState = StockActivityAttributes.ContentState(
            currentPrice: currentPrice,
            priceChange: priceChange,
            priceChangePercent: priceChangePercent,
            yesterDayPrice: yesterDayPrice,
            time: time
        )

        do {
            let activity = try Activity<StockActivityAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            currentActivity = activity
            observeActivityState(activity)
            isActive.send(true)
            activityLogger.info("Live Activity started for \(stockNo) (\(stockName)), price: \(currentPrice)")
            return true
        } catch {
            activityLogger.error("Live Activity request failed: \(error.localizedDescription)")
            return false
        }
    }

    func update(currentPrice: String,
                priceChange: String,
                priceChangePercent: String,
                yesterDayPrice: String,
                time: String) {
        guard let activity = currentActivity else { return }

        let contentState = StockActivityAttributes.ContentState(
            currentPrice: currentPrice,
            priceChange: priceChange,
            priceChangePercent: priceChangePercent,
            yesterDayPrice: yesterDayPrice,
            time: time
        )

        Task {
            await activity.update(using: contentState)
            activityLogger.debug("Live Activity updated: \(currentPrice)")
        }
    }

    func end() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(dismissalPolicy: .immediate)
            activityLogger.info("Live Activity ended")
            self.currentActivity = nil
            await MainActor.run {
                self.isActive.send(false)
            }
        }
    }

    private func observeActivityState(_ activity: Activity<StockActivityAttributes>) {
        Task {
            for await state in activity.activityStateUpdates {
                if state == .dismissed || state == .ended {
                    self.currentActivity = nil
                    await MainActor.run {
                        self.isActive.send(false)
                    }
                }
            }
        }
    }
}

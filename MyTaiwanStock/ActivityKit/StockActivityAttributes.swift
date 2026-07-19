import ActivityKit

struct StockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentPrice: String
        var priceChange: String
        var priceChangePercent: String
        var yesterDayPrice: String
        var time: String
    }

    var stockNo: String
    var stockName: String
}

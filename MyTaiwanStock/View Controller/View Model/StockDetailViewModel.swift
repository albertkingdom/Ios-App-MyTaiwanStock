import Charts
//
//  StockDetailViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//
import Combine
import CoreData
import Foundation

class StockDetailViewModel {
    var stockInfoForCandleStickChartCombine = CurrentValueSubject<
        [[String]], Never
    >([])
    var stockNo: String
    var currentStockPriceString: String
    var chartService: ChartService!

    var historyCombine = CurrentValueSubject<[HistoryCellModel], Never>([])
    var totalAmountCombine = CurrentValueSubject<Int, Never>(0)  //持股數
    var avgBuyPriceCombine = CurrentValueSubject<String, Never>("")  // 買入均價
    var avgSellPriceCombine = CurrentValueSubject<String, Never>("")  //賣出均價
    var totalAssetCombine = CurrentValueSubject<String, Never>("")  //市值
    @Published var coreDataObjectsCombine: [InvestHistory] = []
    @Published var highlightChartIndex: Int = -1
    var subscription = Set<AnyCancellable>()

    private let repository: any NetworkService

    init(
        stockNo: String, currentStockPrice: String,
        repository: any NetworkService
    ) {
        self.stockNo = stockNo
        self.currentStockPriceString = currentStockPrice
        self.repository = repository
        setupHistoryData()

    }

    func setupHistoryData() {
        $coreDataObjectsCombine
            .map { investHistoryList -> [HistoryCellModel] in

                return investHistoryList.map { investHistory in
                    HistoryCellModel(
                        historyData: investHistory,
                        currentStockPrice: self.currentStockPriceString)
                }

            }
            .sink { [weak self] cellViewModels in
                print("cellViewModels count \(cellViewModels.count)")
                self?.historyCombine.send(cellViewModels)
                self?.calOverView(with: cellViewModels)
            }
            .store(in: &subscription)
    }

    func fetchRemoteData(to chart: CombinedChartView) async {
        let data = await repository.fetchTwoMonthCandleData(stockNo: stockNo)
        DispatchQueue.main.async {
            self.stockInfoForCandleStickChartCombine.send(data)
            self.chartService = ChartService(
                candleStickData: data, stockNo: self.stockNo)
            self.chartService.prepareForCombinedChart(combinedChartView: chart)
        }
    }
    func fetchDB() {
        coreDataObjectsCombine = repository.historyList(with: stockNo)
    }

    func deleteHistory(at index: Int) {
        let itemToDelete = coreDataObjectsCombine[index]

        repository.deleteHistory(historyObject: itemToDelete)
        coreDataObjectsCombine = coreDataObjectsCombine.filter({ object in
            object != itemToDelete
        })
    }

    func findClickHistoryDate(index: Int) {
        if let date = coreDataObjectsCombine[index].date {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "zh_TW")
            dateFormatter.setLocalizedDateFormatFromTemplate("yyyy/MM/dd")

            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents(
                [.year, .month, .day], from: date)
            if var year = components.year, let month = components.month,
                let day = components.day
            {
                // convert date to following format like:  111/03/18
                year = year - 1911
                let fullMonth = month > 9 ? "\(month)" : "0\(month)"
                let fullDay = day > 9 ? "\(day)" : "0\(day)"
                let targetDateString = "\(year)/\(fullMonth)/\(fullDay)"
                logger.debug("targetDateString \(targetDateString)")
                stockInfoForCandleStickChartCombine.value.enumerated().forEach {
                    index, candleData in
                    // find the index of date in stockInfoForCandleStickChart
                    if candleData[0] == targetDateString {
                        logger.debug("yes match date!!!!")
                        highlightChartIndex = index
                    }
                }

            }

        }

    }

    func calOverView(with historys: [HistoryCellModel]) {
        let currentStockPriceFloat = Float(self.currentStockPriceString)
        let calculator = OverViewCalculator(
            historys: historys,
            stockPrice: currentStockPriceFloat
        )
        if let totalAsset = calculator.totalAsset() {
            totalAssetCombine.send(String(totalAsset))
        }
        avgSellPriceCombine.send(String(calculator.averageSellPrice()))
        avgBuyPriceCombine.send(String(calculator.averageBuyPrice()))
        totalAmountCombine.send(calculator.amount)
    }

}

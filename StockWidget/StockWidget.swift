//
//  StockWidget.swift
//  StockWidget
//
//  Created by Albert Lin on 2022/4/2.
//

import WidgetKit
import SwiftUI
import os

let logger = Logger(subsystem: "com.a2006mike.MyTaiwanStock", category: "YourCategory")

struct Provider: TimelineProvider {
    let repository = TWSEStockInfoFetcher()

    // fake data showed before real data
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), stockList: [WidgetStockData(stockNo: "0050",
                                                              current: "130",
                                                              shortName: "台50",
                                                              yesterDayPrice: "1.0")])
    }
    // preview when picking widget
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), stockList: [WidgetStockData(stockNo: "0050",
                                                                          current: "130",
                                                                          shortName: "台50",
                                                                          yesterDayPrice: "1.0")])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let reloadDate = Calendar.current.date(byAdding: .minute,
                                                  value: 15,
                                                  to: currentDate)!
        let stockNos = retrieveStockNos()

        guard !stockNos.isEmpty else {
            let entry = placeholderEntry()
            let timeline = Timeline(entries: [entry], policy: .after(reloadDate))
            completion(timeline)
            return
        }

        repository.fetchOneDayStockInfo(stockList: stockNos) { result in
            switch result {
            case .success(let data):
                guard !data.msgArray.isEmpty else {
                    let entry = placeholderEntry()
                    let timeline = Timeline(entries: [entry], policy: .after(reloadDate))
                    completion(timeline)
                    return
                }
                var stockDatas = data.msgArray.map { priceData in
                    WidgetStockData(stockNo: priceData.stockNo,
                                    current: priceData.current,
                                    shortName: priceData.shortName,
                                    yesterDayPrice: priceData.yesterDayPrice)
                }
                if stockDatas.count > 3 {
                    stockDatas = Array(stockDatas[0...2])
                }
                let entry = SimpleEntry(date: currentDate, stockList: stockDatas)
                let timeline = Timeline(entries: [entry], policy: .after(reloadDate))
                completion(timeline)
            case .failure(let error):
                logger.error("Widget fetch failed: \(error.localizedDescription)")
                let entry = placeholderEntry()
                let timeline = Timeline(entries: [entry], policy: .after(reloadDate))
                completion(timeline)
            }
        }
    }

    private func placeholderEntry() -> SimpleEntry {
        SimpleEntry(date: Date(), stockList: [
            WidgetStockData(stockNo: "請開啟App",
                            current: "載入中",
                            shortName: "",
                            yesterDayPrice: "0")
        ])
    }
    
    func retrieveStockNos() -> [String] {
        let userDefault = UserDefaults(suiteName: "group.a2006mike.myTaiwanStock")
        guard let stockNos = userDefault?.object(forKey: "stockNos") as? [String] else { return [] }
        return stockNos.filter { !$0.isEmpty }
    }
}
    

struct SimpleEntry: TimelineEntry {
    let date: Date
    let stockList: [WidgetStockData]
}


struct StockWidgetEntryView : View {
    var entry: Provider.Entry

    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd hh:mm a"
        return dateFormatter
    }()
    
   
    var body: some View {

        
        VStack(spacing: 0) {
            ForEach(entry.stockList) { item in
                HStack(alignment: .center) {
                    VStack {
                        Text(item.stockNo)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fontWeight(Font.Weight.bold)
                            .frame(maxWidth: .infinity)
                        
                        Text(item.shortName)
                            .font(Font.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                    Text(formatString(price: item.current, fallback: item.yesterDayPrice))
                        .fontWeight(Font.Weight.bold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(item.diff)
                        .fontWeight(Font.Weight.bold)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(formatColor(diff: item.diff))

                }
                .padding(.trailing)
                .frame(maxWidth: .infinity)
                
                Divider()
            }
            
            Spacer()
            HStack(){
                Image(systemName: "clock")
                Text(dateFormatter.string(from: entry.date))
            }
            .padding(.all, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(.secondary)
            .font(.system(size: 12))
            
           
            
                
        }
        .frame(maxHeight: .infinity)
        .padding([.top,.bottom], 0)
        .padding([.horizontal], 10)
        .widgetBackground(Color(.systemBackground))

    }
    
    func formatString(price: String, fallback: String) -> String {

        if let currentPrice = Float(price) {
            return String(format: "%.2f", currentPrice)
        } else if let fallbackPrice = Float(fallback) {
            return String(format: "%.2f", fallbackPrice)
        } else {
            return "-"
        }
    }
    func formatColor(diff: String) -> Color {
        if diff == "-" {
            return .primary
        }
        if let floatDiff = Float(diff), floatDiff > 0.0 {
            return Color.red
        } else {
            return Color.green
        }
    }
}


@main
struct StockWidget: Widget {
    let kind: String = "StockWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StockWidgetEntryView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .configurationDisplayName("即時股價")
        .description("檢閱追蹤清單的即時股價。")
        .supportedFamilies([.systemMedium])
    }
}

struct StockWidget_Previews: PreviewProvider {
    static let entryTemplate = SimpleEntry(
        date: Date(),
        stockList: [
            WidgetStockData(stockNo: "0050", current: "130.0", shortName: "台50", yesterDayPrice: "1.0"),
            WidgetStockData(stockNo: "0056", current: "30", shortName: "台56", yesterDayPrice: "29.0"),
            WidgetStockData(stockNo: "0050", current: "130.0", shortName: "台50", yesterDayPrice: "1.0"),
            WidgetStockData(stockNo: "0056", current: "30", shortName: "台56", yesterDayPrice: "29.0")
        ]
    )
    
    static var previews: some View {
        StockWidgetEntryView(
            entry: entryTemplate
        ).previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}

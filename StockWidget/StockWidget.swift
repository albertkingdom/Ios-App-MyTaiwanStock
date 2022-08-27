//
//  StockWidget.swift
//  StockWidget
//
//  Created by Albert Lin on 2022/4/2.
//

import WidgetKit
import SwiftUI


struct Provider: TimelineProvider {
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
        var entries: [SimpleEntry] = []

        
        let currentDate = Date()
        let stockNos = retrieveStockNos()
        
        OneDayStockInfo.fetchOneDayStockInfo(stockList: stockNos) { result in
            switch result {
            case .success(let data):
                //print("success \(data)")
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
                entries.append(entry)
                // create timeline
                let timeline = Timeline(entries: entries, policy: .after(currentDate.addingTimeInterval(60)))
                completion(timeline)
            case .failure(let error):
                print(error)
                
            }
        }
        
        
    }
    
    func retrieveStockNos() -> [String] {
        let userDefault = UserDefaults(suiteName: "group.a2006mike.myTaiwanStock")
        
        guard let stockNos = userDefault?.object(forKey: "stockNos") as? [String] else { return [] }
        
        
        return stockNos
    }
}
    

struct SimpleEntry: TimelineEntry {
    let date: Date
    let stockList: [WidgetStockData]
}


struct StockWidgetEntryView : View {
    var entry: Provider.Entry
    
    @Environment(\.widgetFamily) var family
    
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
                            .foregroundColor(Color.white)
                            .fontWeight(Font.Weight.bold)
                            .frame(maxWidth: .infinity)
                        
                        Text(item.shortName)
                            .font(Font.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(Color.gray)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                    switch family {
                    case .systemSmall:
                        Text(formatString(price:item.current))
                            .font(Font.system(size: 15, weight: .bold, design: .default))
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            
                        
                    default:
                        Text(formatString(price:item.current))
                            .fontWeight(Font.Weight.bold)
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        Text(item.diff)
                            .fontWeight(Font.Weight.bold)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundColor(formatColor(diff: item.diff))
                        
                        
                    }
                    
                }
                .padding(.trailing)
                .background(Color.black)
                .frame(maxWidth: .infinity)
                
                Divider()
            }
            
            Spacer()
            HStack(){
                Image(systemName: "clock")
                switch family {
                case .systemSmall:
                    Text(entry.date, style: .time)
                default:
                    Text(dateFormatter.string(from: entry.date))
                }
                
            }
            .padding(.all, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
            .foregroundColor(Color.white)
            .font(.system(size: 12))
            
           
            
                
        }
        .frame(maxHeight: .infinity)
        .padding([.top,.bottom], 0)
        .padding([.horizontal], 10)
        
    }
    
    func formatString(price: String) -> String {

        if let currentPrice = Float(price) {
            return String(format: "%.2f", currentPrice)
        } else {
            return "-"
        }
    }
    func formatColor(diff: String) -> Color {
        if diff == "-" {
            return Color.white
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
                .frame( maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
        .configurationDisplayName("即時股價")
        .description("檢閱追蹤清單的即時股價。")
        .supportedFamilies([.systemSmall, .systemMedium])
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
        
        StockWidgetEntryView(
            entry: entryTemplate
        ).previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}

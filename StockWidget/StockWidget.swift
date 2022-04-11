//
//  StockWidget.swift
//  StockWidget
//
//  Created by Albert Lin on 2022/4/2.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), stockList: [CommonStockInfo(stockNo: "0050", current: "130", shortName: "台50", yesterDayPrice: "1.0")])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), stockList: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
       
        
        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let stockList = getStockList()
        //print("widget stockList \(stockList)")
        let currentDate = Date()
        for hourOffset in 0 ..< 1 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, stockList: stockList)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}
func getStockList() -> [CommonStockInfo] {
    let userDefault = UserDefaults(suiteName: "group.com.albertkingdom.mytaiwanstock.test")
    guard let stockListData = userDefault?.object(forKey: "stockList") as? Data else {
        return []
    }
    do{
        let decoder = JSONDecoder()
        let stockList = try decoder.decode([CommonStockInfo].self, from: stockListData)
        return Array(stockList[0...2])
    }catch let err{
        print(err)
        return []
    }
}
struct SimpleEntry: TimelineEntry {
    let date: Date
    let stockList: [CommonStockInfo]

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
struct StockWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    var body: some View {

        
        VStack(spacing: 0) {
            ForEach(entry.stockList) { item in
                HStack(alignment: .center) {
                    VStack {
                        Text(item.stockNo)
                            .foregroundColor(Color.white)
                            .fontWeight(Font.Weight.bold)
                            .frame(maxWidth: .infinity)
                        
                        Text(item.shortName)
                            .font(Font.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(Color.gray)
                            .multilineTextAlignment(.center)
                    }
                    switch family {
                    case .systemSmall:
                        Text(formatString(price:item.current))
                            .fontWeight(Font.Weight.bold)
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            
                        
                    default:
                        Text(formatString(price:item.current))
                            .fontWeight(Font.Weight.bold)
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        Text(item.diff)
                            .fontWeight(Font.Weight.bold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(formatColor(diff: item.diff))
                        
                        
                    }
                    
                }
                .background(Color.black)
                .frame(maxWidth: .infinity)
                Divider()
            }
            
            
        }
        .frame(maxHeight: .infinity)
        .padding([.top,.bottom], 0)
        .padding([.horizontal], 10)
        
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
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct StockWidget_Previews: PreviewProvider {
    static var previews: some View {
        StockWidgetEntryView(
            entry: SimpleEntry(date: Date(),
                               stockList: [
                                CommonStockInfo(stockNo: "0050", current: "130.0000", shortName: "台50", yesterDayPrice: "1.0"),
                                CommonStockInfo(stockNo: "0050", current: "130", shortName: "台50", yesterDayPrice: "1.0")
                               ]
                              )
        )
            .padding()
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}

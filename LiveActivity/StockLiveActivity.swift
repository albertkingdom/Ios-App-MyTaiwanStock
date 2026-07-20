import ActivityKit
import SwiftUI
import WidgetKit

@main
struct StockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StockActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.stockNo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(context.attributes.stockName)
                                .font(.headline)
                            Spacer()
                            Text(context.state.currentPrice)
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        HStack {
                            Text(context.state.priceChange)
                                .foregroundColor(changeColor(context.state.priceChange))
                                .font(.subheadline)
                            Text(context.state.priceChangePercent)
                                .foregroundColor(changeColor(context.state.priceChange))
                                .font(.subheadline)
                            Spacer()
                            Text("昨收 \(context.state.yesterDayPrice)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                Text(context.attributes.stockNo)
                    .font(.caption2)
                    .fontWeight(.bold)
            } compactTrailing: {
                Text(context.state.priceChange)
                    .font(.caption2)
                    .foregroundColor(changeColor(context.state.priceChange))
            } minimal: {
                HStack(spacing: 4) {
                    Text(context.attributes.stockNo)
                        .font(.caption2)
                    Text(context.state.priceChange)
                        .font(.caption2)
                        .foregroundColor(changeColor(context.state.priceChange))
                }
            }
        }
    }

    private func changeColor(_ priceChange: String) -> Color {
        if priceChange.hasPrefix("+") {
            return .red
        } else if priceChange.hasPrefix("-") {
            return .green
        }
        return .primary
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<StockActivityAttributes>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(context.attributes.stockNo)
                    .font(.headline)
                Text(context.attributes.stockName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(context.state.time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            HStack(alignment: .firstTextBaseline) {
                Spacer()
                Text(context.state.currentPrice)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                Spacer()
            }
            .padding(.top, 8)

            HStack(spacing: 8) {
                Text(context.state.priceChange)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(changeColor(context.state.priceChange))
                Text(context.state.priceChangePercent)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(changeColor(context.state.priceChange))
                Spacer()
                Text("昨收 \(context.state.yesterDayPrice)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func changeColor(_ priceChange: String) -> Color {
        if priceChange.hasPrefix("+") {
            return .red
        } else if priceChange.hasPrefix("-") {
            return .green
        }
        return .primary
    }
}

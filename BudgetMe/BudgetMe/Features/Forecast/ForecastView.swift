import SwiftUI
import Charts

struct ForecastView: View {
    @EnvironmentObject private var store: AppStore

    @State private var horizon = 15                 // free tier
    @State private var dismissed: Set<String> = []  // merchants excluded from forecast

    private var code: String { store.profile.currencyCode }

    private var recurring: [RecurringItem] {
        ForecastService.detectRecurring(store.transactions)
            .filter { !dismissed.contains($0.merchant.lowercased()) }
    }

    private var points: [ForecastPoint] {
        ForecastService.project(transactions: store.transactions, confirmed: recurring, horizon: horizon)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    horizonPicker
                    if let neg = ForecastService.firstNegativeDate(in: points) {
                        negativeBanner(neg)
                    }
                    chartCard
                    recurringCard
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Forecast")
        }
    }

    private var horizonPicker: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Projection window").font(.subheadline.bold())
                    Spacer()
                    if store.profile.tier == .free { PaidBadge() }
                }
                Picker("Horizon", selection: $horizon) {
                    Text("15d").tag(15)
                    Text("30d").tag(30)
                    Text("60d").tag(60)
                    Text("90d").tag(90)
                }
                .pickerStyle(.segmented)
                .disabled(store.profile.tier == .free)
                if store.profile.tier == .free {
                    Text("Free plan shows 15 days. Upgrade for 30/60/90-day forecasts and manual planning.")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                }
            }
        }
    }

    private var chartCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Projected net change").font(.subheadline.bold())
                Chart(points) { p in
                    LineMark(x: .value("Date", p.date), y: .value("Balance", p.balance))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Theme.primary)
                    AreaMark(x: .value("Date", p.date), y: .value("Balance", p.balance))
                        .foregroundStyle(Theme.primary.opacity(0.12))
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Money.format(v, code: code))
                            }
                        }
                    }
                }
                .frame(height: 200)
                Text("End of window: \(Money.format(points.last?.balance ?? 0, code: code, showSign: true))")
                    .font(.caption).foregroundStyle(Theme.subtleText)
            }
        }
    }

    private var recurringCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Detected recurring").font(.subheadline.bold())
                let all = ForecastService.detectRecurring(store.transactions)
                if all.isEmpty {
                    Text("No recurring transactions detected yet.")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                }
                ForEach(all) { item in
                    HStack {
                        CategoryIcon(category: item.category, size: 30)
                        VStack(alignment: .leading) {
                            Text(item.merchant).font(.subheadline)
                            Text("\(item.cadence.rawValue.capitalized) · \(Money.format(item.amount, code: code))")
                                .font(.caption).foregroundStyle(Theme.subtleText)
                        }
                        Spacer()
                        let isOn = !dismissed.contains(item.merchant.lowercased())
                        Button {
                            let key = item.merchant.lowercased()
                            if isOn { dismissed.insert(key) } else { dismissed.remove(key) }
                        } label: {
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isOn ? Theme.primary : Theme.subtleText)
                        }
                    }
                }
            }
        }
    }

    private func negativeBanner(_ date: Date) -> some View {
        CardView {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.danger)
                VStack(alignment: .leading) {
                    Text("Heads up").font(.subheadline.bold())
                    Text("At this rate your net position dips below zero around \(date.formatted(date: .abbreviated, time: .omitted)).")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                }
            }
        }
    }
}

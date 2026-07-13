import SwiftUI

struct BudgetView: View {
    @EnvironmentObject private var store: AppStore

    private var code: String { store.profile.currencyCode }

    private var statuses: [BucketStatus] {
        BudgetService.fiftyThirtyTwenty(
            income: store.profile.monthlyIncome,
            transactions: store.currentMonthTransactions
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    frameworkSelector
                    ForEach(statuses) { bucketCard($0) }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Budget")
        }
    }

    private var frameworkSelector: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Framework").font(.headline)
                ForEach(BudgetFramework.allCases) { fw in
                    HStack {
                        Image(systemName: fw == store.profile.framework ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(fw == store.profile.framework ? Theme.primary : Theme.subtleText)
                        VStack(alignment: .leading) {
                            Text(fw.rawValue).font(.subheadline.weight(.medium))
                            Text(fw.blurb).font(.caption).foregroundStyle(Theme.subtleText)
                        }
                        Spacer()
                        if !fw.isFree { PaidBadge() }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if fw.isFree { store.profile.framework = fw }
                    }
                    .opacity(fw.isFree ? 1 : 0.5)
                    if fw != BudgetFramework.allCases.last { Divider() }
                }
            }
        }
    }

    private func bucketCard(_ s: BucketStatus) -> some View {
        let cats = Category.allCases.filter { $0.bucket == s.bucket && !$0.isIncome }
        let spendByCat = store.spendByCategory()
        return CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle().fill(s.bucket.color).frame(width: 10, height: 10)
                    Text(s.bucket.rawValue).font(.headline)
                    Spacer()
                    Text("\(Int(s.bucket.targetShare * 100))%")
                        .font(.subheadline).foregroundStyle(Theme.subtleText)
                }
                BudgetBar(spent: s.spent, limit: s.limit, tint: s.bucket.color)
                HStack {
                    Text(Money.format(s.spent, code: code)).font(.subheadline.bold())
                    Text("of \(Money.format(s.limit, code: code))")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                    Spacer()
                    Text(s.isOver ? "Over \(Money.format(-s.remaining, code: code))"
                                  : "\(Money.format(s.remaining, code: code)) left")
                        .font(.caption).foregroundStyle(s.isOver ? Theme.danger : Theme.primary)
                }
                let active = spendByCat.filter { item in cats.contains(item.category) }
                if !active.isEmpty {
                    Divider()
                    ForEach(active, id: \.category) { item in
                        HStack {
                            CategoryIcon(category: item.category, size: 26)
                            Text(item.category.displayName).font(.caption)
                            Spacer()
                            Text(Money.format(item.amount, code: code)).font(.caption.bold())
                        }
                    }
                }
            }
        }
    }
}

import SwiftUI

/// Pushed inside Settings' NavigationStack.
struct DebtPlannerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingAdd = false
    @State private var extraText = ""
    @State private var strategy: DebtStrategy = .avalanche

    private var code: String { store.profile.currencyCode }
    private var extra: Double { Double(extraText) ?? 0 }
    private var result: DebtStrategyResult {
        DebtPlanner.simulate(debts: store.debts, extraPerMonth: extra, strategy: strategy)
    }
    private var otherResult: DebtStrategyResult {
        DebtPlanner.simulate(debts: store.debts, extraPerMonth: extra, strategy: strategy.other)
    }

    var body: some View {
        List {
            if store.debts.isEmpty {
                Section {
                    Text("Add your debts to see your payoff plan, debt-free date and interest saved.")
                        .font(.subheadline).foregroundStyle(Theme.subtleText)
                }
            } else {
                strategySection
                extraSection
                resultSection
                timelineSection
            }
        }
        .navigationTitle("Debt Planner")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { endEditing() } }
        }
        .sheet(isPresented: $showingAdd) { AddDebtView() }
    }

    private var strategySection: some View {
        Section {
            Picker("Strategy", selection: $strategy) {
                ForEach(DebtStrategy.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(strategy.blurb).font(.caption).foregroundStyle(Theme.subtleText)
        }
    }

    private var extraSection: some View {
        Section {
            HStack {
                Text("Extra monthly payment")
                Spacer()
                TextField("0", text: $extraText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
            }
        } footer: {
            Text("On top of the minimums, this goes toward your priority debt each month.")
        }
    }

    private var resultSection: some View {
        Section {
            HStack {
                Text("Debt-free date").bold()
                Spacer()
                Text(result.cappedOut ? "Not at this rate"
                     : result.debtFreeDate.formatted(.dateTime.month(.wide).year()))
                    .bold()
                    .foregroundStyle(result.cappedOut ? Theme.danger : Theme.primary)
            }
            HStack {
                Text("Total interest paid")
                Spacer()
                Text(Money.format(result.totalInterest, code: code)).foregroundStyle(Theme.subtleText)
            }
            comparisonRow
        } footer: {
            if result.cappedOut {
                Text("Your minimum payments barely cover interest. Add an extra monthly payment to make progress.")
            }
        }
    }

    @ViewBuilder private var comparisonRow: some View {
        let savings = otherResult.totalInterest - result.totalInterest
        if savings > 1 {
            Text("\(strategy.rawValue) saves \(Money.format(savings, code: code)) in interest vs \(strategy.other.rawValue).")
                .font(.caption).foregroundStyle(Theme.primary)
        } else if savings < -1 {
            Text("\(strategy.other.rawValue) would save \(Money.format(-savings, code: code)) more in interest.")
                .font(.caption).foregroundStyle(Theme.subtleText)
        }
    }

    private var timelineSection: some View {
        Section("Payoff timeline") {
            ForEach(store.debts) { debt in
                let m = result.clearMonth[debt.id]
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(debt.name).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(m != nil ? monthLabel(m!) : "—")
                            .font(.caption).foregroundStyle(Theme.subtleText)
                    }
                    GeometryReader { geo in
                        let frac = CGFloat(Double(m ?? result.months) / Double(max(result.months, 1)))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemFill))
                            Capsule().fill(debt.balance > 0 ? Theme.primary : Theme.subtleText)
                                .frame(width: geo.size.width * min(max(frac, 0.02), 1))
                        }
                    }
                    .frame(height: 8)
                    Text("\(Money.format(debt.balance, code: code)) · \(Int(debt.apr))% APR · min \(Money.format(debt.minPayment, code: code))")
                        .font(.caption2).foregroundStyle(Theme.subtleText)
                }
                .padding(.vertical, 2)
            }
            .onDelete { idx in idx.map { store.debts[$0] }.forEach(store.deleteDebt) }
        }
    }

    private func monthLabel(_ m: Int) -> String {
        let date = Calendar.current.date(byAdding: .month, value: m, to: Date()) ?? Date()
        return date.formatted(.dateTime.month(.abbreviated).year())
    }
}

struct AddDebtView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var balance = ""
    @State private var apr = ""
    @State private var minPayment = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Debt") {
                    TextField("Name (e.g. Car loan)", text: $name)
                    TextField("Current balance", text: $balance).keyboardType(.decimalPad)
                    TextField("Interest rate (APR %)", text: $apr).keyboardType(.decimalPad)
                    TextField("Minimum monthly payment", text: $minPayment).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Debt")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { endEditing() } }
            }
        }
    }

    private var canSave: Bool {
        !name.isEmpty && (Double(balance) ?? 0) > 0
    }

    private func save() {
        store.addDebt(Debt(
            name: name,
            balance: Double(balance) ?? 0,
            apr: Double(apr) ?? 0,
            minPayment: Double(minPayment) ?? 0
        ))
        dismiss()
    }
}

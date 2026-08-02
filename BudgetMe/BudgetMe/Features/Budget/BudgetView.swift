import SwiftUI

/// Dismiss the keyboard from anywhere (shared by the budget input screens).
func endEditing() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct BudgetView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Budget")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(BudgetFramework.allCases) { fw in
                                Button { selectFramework(fw) } label: {
                                    if store.profile.framework == fw {
                                        Label(fw.rawValue, systemImage: "checkmark")
                                    } else if !fw.isFree && store.profile.tier != .paid {
                                        Label(fw.rawValue, systemImage: "lock.fill")
                                    } else {
                                        Text(fw.rawValue)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(store.profile.framework.rawValue)
                                Image(systemName: "chevron.down")
                            }
                            .font(.subheadline)
                        }
                    }
                }
                .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    @ViewBuilder private var content: some View {
        switch store.profile.framework {
        case .fiftyThirtyTwenty: FiftyThirtyTwentyView()
        case .zeroBased: ZeroBasedView()
        case .payYourselfFirst: PayYourselfFirstView()
        case .custom: CustomBudgetView()
        }
    }

    private func selectFramework(_ fw: BudgetFramework) {
        if fw.isFree || store.profile.tier == .paid {
            store.profile.framework = fw
        } else {
            showPaywall = true
        }
    }
}

// MARK: - 50/30/20 (free)

struct FiftyThirtyTwentyView: View {
    @EnvironmentObject private var store: AppStore
    private var code: String { store.profile.currencyCode }

    private var statuses: [BucketStatus] {
        BudgetService.fiftyThirtyTwenty(
            income: store.profile.monthlyIncome,
            transactions: store.currentMonthTransactions
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(statuses) { s in
                    CardView {
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
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.background)
    }
}

// MARK: - Reusable category allocation row (Zero-Based & Custom)

struct CategoryBudgetRow: View {
    @EnvironmentObject private var store: AppStore
    let category: Category
    private var code: String { store.profile.currencyCode }

    var body: some View {
        let thisSpent = store.spent(categoryID: category.id, monthOffset: 0)
        let lastSpent = store.spent(categoryID: category.id, monthOffset: -1)
        let base = store.limit(for: category.id)
        let rolloverOn = store.isRolloverOn(category.id)
        let rollover = rolloverOn ? max(0, base - lastSpent) : 0
        let effective = base + rollover

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CategoryIcon(category: category, size: 28)
                Text(category.displayName).font(.subheadline)
                Spacer()
                TextField("0", value: Binding(
                    get: { store.limit(for: category.id) },
                    set: { store.setLimit($0, for: category.id) }
                ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            }
            BudgetBar(spent: thisSpent, limit: effective, tint: category.color)
            HStack {
                Text("\(Money.format(thisSpent, code: code)) of \(Money.format(effective, code: code))")
                    .font(.caption2).foregroundStyle(Theme.subtleText)
                Spacer()
                if rollover > 0 {
                    Text("+\(Money.format(rollover, code: code)) rolled over")
                        .font(.caption2).foregroundStyle(Theme.primary)
                }
            }
            Toggle("Roll unspent to next month", isOn: Binding(
                get: { store.isRolloverOn(category.id) },
                set: { store.setRollover($0, for: category.id) }
            ))
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Zero-Based (paid)

struct ZeroBasedView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingAdd = false
    @State private var newName = ""
    private var code: String { store.profile.currencyCode }

    private var categories: [Category] {
        Category.allCases.filter { !$0.isIncome && $0.id != Category.uncategorized.id }
            + store.customCategories.map { Category($0) }
    }
    private var allocated: Double { categories.reduce(0) { $0 + store.limit(for: $1.id) } }
    private var toAssign: Double { store.profile.monthlyIncome - allocated }

    var body: some View {
        Form {
            Section {
                summaryRow("Income", store.profile.monthlyIncome, color: .primary)
                summaryRow("Allocated", allocated, color: .primary)
                HStack {
                    Text("To assign").bold()
                    Spacer()
                    Text(Money.format(toAssign, code: code)).bold()
                        .foregroundStyle(abs(toAssign) < 0.01 ? Theme.primary
                                         : (toAssign < 0 ? Theme.danger : Theme.warning))
                }
            } footer: {
                Text("Give every unit of income a job until 'To assign' reaches zero.")
            }
            Section("Categories") {
                ForEach(categories) { CategoryBudgetRow(category: $0) }
            }
            Section {
                Button { showingAdd = true } label: {
                    Label("Add category", systemImage: "plus.circle")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { endEditing() } } }
        .alert("New category", isPresented: $showingAdd) {
            TextField("Name", text: $newName)
            Button("Add") { store.addCustomCategory(newName); newName = "" }
            Button("Cancel", role: .cancel) { newName = "" }
        } message: {
            Text("Create a category to budget for.")
        }
    }

    private func summaryRow(_ label: String, _ value: Double, color: Color) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(Money.format(value, code: code)).foregroundStyle(color)
        }
    }
}

// MARK: - Pay Yourself First (paid)

struct PayYourselfFirstView: View {
    @EnvironmentObject private var store: AppStore
    private var code: String { store.profile.currencyCode }

    private var spent: Double { store.totalSpentThisMonth }
    private var spendable: Double { max(store.profile.monthlyIncome - store.profile.savingsTarget, 0) }
    private var safeToSpend: Double { spendable - spent }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Savings target")
                    Spacer()
                    TextField("0", value: Binding(
                        get: { store.profile.savingsTarget },
                        set: { store.profile.savingsTarget = $0 }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
                }
            } header: {
                Text("Pay yourself first")
            } footer: {
                Text("This amount is set aside before anything else. What's left is yours to spend freely — no categories needed.")
            }

            Section {
                row("Income", store.profile.monthlyIncome)
                row("Locked for savings", store.profile.savingsTarget)
                row("Spent so far", spent)
                HStack {
                    Text("Safe to spend").bold()
                    Spacer()
                    Text(Money.format(safeToSpend, code: code)).bold()
                        .foregroundStyle(safeToSpend < 0 ? Theme.danger : Theme.primary)
                }
                BudgetBar(spent: spent, limit: spendable, tint: Theme.primary)
                    .padding(.vertical, 4)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { endEditing() } } }
    }

    private func row(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(Money.format(value, code: code)).foregroundStyle(Theme.subtleText)
        }
    }
}

// MARK: - Custom (paid)

struct CustomBudgetView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingAdd = false
    @State private var newName = ""
    private var code: String { store.profile.currencyCode }

    private var categories: [Category] { store.customCategories.map { Category($0) } }
    private var totalLimit: Double { categories.reduce(0) { $0 + store.limit(for: $1.id) } }
    private var totalSpent: Double { categories.reduce(0) { $0 + store.spent(categoryID: $1.id) } }

    var body: some View {
        Form {
            Section {
                HStack { Text("Total budgeted"); Spacer(); Text(Money.format(totalLimit, code: code)) }
                HStack {
                    Text("Spent")
                    Spacer()
                    Text(Money.format(totalSpent, code: code)).foregroundStyle(Theme.subtleText)
                }
            }
            Section("Your categories") {
                if categories.isEmpty {
                    Text("Add your own categories and set a monthly limit for each.")
                        .font(.caption).foregroundStyle(Theme.subtleText)
                }
                ForEach(categories) { CategoryBudgetRow(category: $0) }
            }
            Section {
                Button { showingAdd = true } label: {
                    Label("Add category", systemImage: "plus.circle")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { endEditing() } } }
        .alert("New category", isPresented: $showingAdd) {
            TextField("Name", text: $newName)
            Button("Add") {
                store.addCustomCategory(newName)
                newName = ""
            }
            Button("Cancel", role: .cancel) { newName = "" }
        } message: {
            Text("Create a category to budget for.")
        }
    }
}

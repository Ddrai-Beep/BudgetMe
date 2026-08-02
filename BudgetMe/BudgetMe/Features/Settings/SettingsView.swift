import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("autoDetectRecurringIncome") private var autoDetectIncome = true
    @AppStorage("devShowStatement") private var devShowStatement = false
    @State private var showResetConfirm = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                budgetSection
                forecastSection
                applePaySection
                planSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var forecastSection: some View {
        Section {
            Toggle("Auto-detect recurring income", isOn: $autoDetectIncome)
        } header: {
            Text("Forecast")
        } footer: {
            Text("When on, BudgetMe treats your income as a monthly deposit so your forecast reflects money coming in. Turn off if your income is irregular.")
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            TextField("Name", text: $store.profile.name)
            Picker("Currency", selection: currencyBinding) {
                ForEach(SupportedCurrency.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            HStack {
                Text("Monthly income")
                Spacer()
                TextField("0", value: $store.profile.monthlyIncome, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            }
        }
    }

    private var currencyBinding: Binding<String> {
        Binding(get: { store.profile.currencyCode }, set: { store.profile.currencyCode = $0 })
    }

    private var budgetSection: some View {
        Section("Budget framework") {
            ForEach(BudgetFramework.allCases) { fw in
                Button {
                    if fw.isFree || store.profile.tier == .paid {
                        store.profile.framework = fw
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack {
                        Text(fw.rawValue).foregroundStyle(.primary)
                        Spacer()
                        if fw == store.profile.framework { Image(systemName: "checkmark").foregroundStyle(Theme.primary) }
                        if !fw.isFree && store.profile.tier != .paid { PaidBadge() }
                    }
                }
            }
        }
    }

    private var applePaySection: some View {
        Section("Apple Pay auto-tracking") {
            NavigationLink {
                ShortcutSetupView()
            } label: {
                Label("Set up automatic logging", systemImage: "wave.3.right")
            }
        }
    }

    private var planSection: some View {
        Section("Plan") {
            HStack {
                Text("Current plan")
                Spacer()
                Text(store.profile.tier == .paid ? "Paid" : "Free")
                    .foregroundStyle(Theme.subtleText)
            }
            if store.profile.tier != .paid {
                Button {
                    showPaywall = true
                } label: {
                    Label("Upgrade to Paid", systemImage: "crown.fill")
                }
            }
            // Dev toggle to preview paid features until StoreKit lands (iteration 2).
            Toggle("Simulate Paid (dev)", isOn: Binding(
                get: { store.profile.tier == .paid },
                set: { store.profile.tier = $0 ? .paid : .free }
            ))
            Toggle("Show statement parser (dev)", isOn: $devShowStatement)
            if store.profile.tier == .free {
                Text("\(store.remainingFreeTransactions) of \(UserProfile.freeTransactionCap) transactions left this week.")
                    .font(.caption).foregroundStyle(Theme.subtleText)
            }
        }
    }

    /// Writes the CSV to a temp file so the share sheet offers a real .csv to save/send.
    private var exportedCSVFile: URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BudgetMe-transactions.csv")
        try? store.exportCSV().data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private var dataSection: some View {
        Section {
            ShareLink(item: exportedCSVFile) {
                Label("Export transactions (CSV)", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) { showResetConfirm = true } label: {
                Label("Delete all data", systemImage: "trash")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("To bring in charges Apple Pay misses, use “Analyze a statement with AI” on the home screen.")
        }
        .confirmationDialog("Delete all data? This can't be undone.",
                            isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { store.clearAllData() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var aboutSection: some View {
        Section {
            Label("Your transaction data stays on your device.", systemImage: "lock.shield")
                .font(.caption).foregroundStyle(Theme.subtleText)
        } footer: {
            Text("BudgetMe v0.1.0 · MVP")
        }
    }
}

/// Step-by-step guide for the one-time Shortcuts personal automation.
struct ShortcutSetupView: View {
    var body: some View {
        ScrollView {
            AutoTrackSetupContent(showsHeader: false)
                .padding()
        }
        .background(Theme.background)
        .navigationTitle("Auto-tracking")
        .navigationBarTitleDisplayMode(.inline)
    }
}
